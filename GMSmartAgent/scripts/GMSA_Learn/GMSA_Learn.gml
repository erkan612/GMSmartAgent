enum gmsa_learn_tier { CUSTOM, COUNT, LINEAR, RANKNET, LAMBDAMART, NGRAM, TDNN }
enum gmsa_learn_target { CHOICES, OUTCOMES }

#macro GMSA_LEARN_ODDS_CLIP 10 // largest correction for rarely chosen options

// Creation
function __gmsa_learn_model_create(_tier, _tier_name, _params) {
    var _half = __gmsa_param(_params, "half_life", 50);
    if (!is_numeric(_half) || _half <= 0) throw "GMSA: learn half_life must be above 0";
    var _k = __gmsa_param(_params, "confidence_k", 20);
    if (!is_numeric(_k) || _k <= 0) throw "GMSA: learn confidence_k must be above 0";
    var _learns = __gmsa_param(_params, "learns", gmsa_learn_target.CHOICES);
    if (_learns != gmsa_learn_target.CHOICES && _learns != gmsa_learn_target.OUTCOMES) throw "GMSA: learn learns must be a gmsa_learn_target";
    var _temperature = __gmsa_param(_params, "temperature", 0.1);
    if (!__gmsa_net_above_zero(_temperature)) throw "GMSA: learn temperature must be above 0";
    var _model = {
        tier          : _tier,
        tier_name     : _tier_name,
        learns        : _learns,       // gmsa_learn_target: who is learned from, the player's choices or the agent's outcomes
        temperature   : _temperature,  // outcome models: how sharply value differences become preferences
        actions       : [],            // action names, the position is the action id
        action_lookup : {},
        inputs        : [],            // feature names, the position is the input id
        input_lookup  : {},
        situational   : [],            // per input id: true when the input doesn't depend on the target
        samples       : 0,             // decayed amount of observed data
        half_life     : _half,
        decay         : power(0.5, 1 / _half),
        confidence_k  : _k,
        frozen        : false,
        data          : {},
        observe       : undefined,     // function(sample)
        predict       : undefined,     // function(sample, out), fills out.p and out.confidence
        explain       : undefined,     // function(sample, i), returns an array of lines
        save_data     : undefined,     // function(), returns a JSON-ready struct
        load_data     : undefined,     // function(data)
        reset_data    : undefined,     // function(), also called once at creation
        train         : undefined,     // function(budget), returns true when finished, batch tiers only
        waiting       : undefined,     // function(), true when train has work, so gmsa_learn_schedule skips idle models
        __work        : undefined,     // the scheduler work from gmsa_learn_schedule
        __bindings    : [],
        __sample      : { situation : [], options : [], chosen : -1, weight : 1, reward : undefined, agent : undefined, from : undefined },
        __pool        : [],
        __out         : { p : [], confidence : 0, best : -1, sure : 0 },
        __predictions : [],            // cached predictions for gmsa_learn_input, one per observed agent
    };
    _model.__adjust = method(_model, __gmsa_learn_adjust); // called by Core's think when the model is attached
    return _model;
}

function gmsa_learn_custom(_methods, _params = {}) {
    if (!is_struct(_methods)) throw "GMSA: learn custom needs a struct of methods";
    var _model = __gmsa_learn_model_create(gmsa_learn_tier.CUSTOM, __gmsa_param(_params, "name", "custom"), _params);
    var _names = ["observe", "predict", "explain", "save_data", "load_data", "reset_data", "train", "waiting"];
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _fn = __gmsa_param(_methods, _names[_i], undefined);
        if (_fn == undefined) continue;
        if (!__gmsa_callable(_fn)) throw "GMSA: learn custom " + _names[_i] + " must be callable";
        _model[$ _names[_i]] = method(_model, _fn);
    }
    if (_model.observe == undefined || _model.predict == undefined) throw "GMSA: learn custom needs observe and predict";
    if (_model.reset_data != undefined) _model.reset_data();
    return _model;
}

// Training and prediction
function gmsa_learn_observe(_model, _decision) {
    if (_model.learns != gmsa_learn_target.CHOICES) {
        throw "GMSA: this model learns from outcomes, report them with gmsa_learn_outcome or gmsa_learn_reward";
    }
    if (_model.frozen) return false;
    if (_decision.chosen < 0) throw "GMSA: learn observe needs a decision with a chosen option";
    var _sample = __gmsa_learn_sample(_model, _decision, _decision.chosen);
    _model.samples = _model.samples * _model.decay + 1;
    _model.observe(_sample);
    __gmsa_learn_invalidate(_model);
    return true;
}

function gmsa_learn_predict(_model, _decision) {
    var _out = _model.__out;
    var _n = array_length(_decision.options);
    array_resize(_out.p, _n);
    _out.confidence = 0;
    _out.best = -1;
    _out.sure = 0;
    if (_n == 0) return _out;
    for (var _i = 0; _i < _n; _i++) _out.p[_i] = 0;

    var _sample = __gmsa_learn_sample(_model, _decision, -1);
    _model.predict(_sample, _out);

    var _sum = 0;
    for (var _i = 0; _i < _n; _i++) {
        var _v = _out.p[_i];
        if (!is_numeric(_v) || is_nan(_v) || _v < 0) _v = 0;
        _out.p[_i] = _v;
        _sum += _v;
    }
    if (_sum <= 0) {
        for (var _i = 0; _i < _n; _i++) _out.p[_i] = 1 / _n;
    } else {
        for (var _i = 0; _i < _n; _i++) _out.p[_i] /= _sum;
    }
    var _c = _out.confidence;
    _out.confidence = (is_numeric(_c) && !is_nan(_c)) ? clamp(_c, 0, 1) : 0;

    var _best = 0;
    for (var _i = 1; _i < _n; _i++) if (_out.p[_i] > _out.p[_best]) _best = _i;
    _out.best = _best;
    _out.sure = _out.confidence * _out.p[_best];
    return _out;
}

function gmsa_learn_explain(_model, _decision, _index) {
    if (_model.explain == undefined) return ["no explanation available"];
    var _sample = __gmsa_learn_sample(_model, _decision, -1);
    return _model.explain(_sample, _index);
}

function gmsa_learn_confidence(_model, _n = undefined) {
    if (_n == undefined) _n = _model.samples;
    return _n / (_n + _model.confidence_k);
}

function gmsa_learn_freeze(_model, _frozen = true) {
    _model.frozen = _frozen;
}

function gmsa_learn_reset(_model) {
    _model.samples = 0;
    if (_model.reset_data != undefined) _model.reset_data();
	__gmsa_learn_invalidate(_model);
}

// Persistence
function gmsa_learn_save(_model) {
    var _data = (_model.save_data != undefined) ? _model.save_data() : {};
    return json_stringify({
        format      : "gmsa_learn",
        version     : 1,
        tier        : _model.tier_name,
        learns      : (_model.learns == gmsa_learn_target.OUTCOMES) ? "outcomes" : "choices",
        actions     : _model.actions,
        inputs      : _model.inputs,
        situational : _model.situational,
        samples     : _model.samples,
        data        : _data,
    });
}

function gmsa_learn_load(_model, _json) {
    var _s = json_parse(_json);
    if (!is_struct(_s) || __gmsa_param(_s, "format", "") != "gmsa_learn") throw "GMSA: not a GMSA learn save";
    if (_s.version > 1) throw "GMSA: learn save version " + string(_s.version) + " is newer than this GMSmartAgent";
    if (_s.tier != _model.tier_name) throw "GMSA: learn save is for tier '" + string(_s.tier) + "', the model is '" + _model.tier_name + "'";
    var _learns = __gmsa_param(_s, "learns", "choices");
    var _mine = (_model.learns == gmsa_learn_target.OUTCOMES) ? "outcomes" : "choices";
    if (_learns != _mine) throw "GMSA: learn save is from a model that learns from " + string(_learns) + ", this model learns from " + _mine;

    var _old = {
        actions : _model.actions, inputs : _model.inputs, situational : _model.situational,
        action_lookup : _model.action_lookup, input_lookup : _model.input_lookup,
        samples : _model.samples, bindings : _model.__bindings, data : _model.data,
    };
    try {
        _model.actions       = _s.actions;
        _model.inputs        = _s.inputs;
        _model.situational   = _s.situational;
        _model.action_lookup = {};
        _model.input_lookup  = {};
        for (var _i = 0; _i < array_length(_model.actions); _i++) _model.action_lookup[$ _model.actions[_i]] = _i;
        for (var _i = 0; _i < array_length(_model.inputs); _i++)  _model.input_lookup[$ _model.inputs[_i]] = _i;
        _model.samples    = _s.samples;
        _model.__bindings = [];
        if (_model.reset_data != undefined) _model.reset_data();
        if (_model.load_data != undefined) _model.load_data(_s.data);
    } catch (_e) {
        _model.actions       = _old.actions;
        _model.inputs        = _old.inputs;
        _model.situational   = _old.situational;
        _model.action_lookup = _old.action_lookup;
        _model.input_lookup  = _old.input_lookup;
        _model.samples       = _old.samples;
        _model.__bindings    = _old.bindings;
        _model.data          = _old.data;
        throw _e;
    }
    __gmsa_learn_invalidate(_model);
    return true;
}

// Re-ranking
function gmsa_profile_set_model(_profile, _model, _influence) {
    __gmsa_profile_assert_editable(_profile);
    __gmsa_learn_check_model(_model);
    __gmsa_learn_check_influence(_influence);
    _profile.model = _model;
    _profile.influence = _influence;
}

function gmsa_agent_set_model(_agent, _model, _influence = 0) {
    if (_model == undefined) {
        _agent.model = undefined;
        _agent.influence = 0;
        return;
    }
    __gmsa_learn_check_model(_model);
    __gmsa_learn_check_influence(_influence);
    if (_agent.profile.features == undefined) {
        throw "GMSA: profile '" + string(_agent.profile.name) + "' has no features, declare them or attach the model to the profile before build";
    }
    _agent.model = _model;
    _agent.influence = _influence;
}

function gmsa_learn_set_influence(_target, _influence) {
    __gmsa_learn_check_influence(_influence);
    if (!is_struct(_target) || !variable_struct_exists(_target, "influence")) throw "GMSA: set influence needs a profile or an agent";
    _target.influence = _influence;
}

function __gmsa_learn_adjust(_decision, _influence) {
    static _compare = function(_a, _b) {
        if (_a.score != _b.score) return (_b.score > _a.score) ? 1 : -1;
        return _a.order - _b.order;
    };
    var _out = gmsa_learn_predict(self, _decision);
    var _w = _influence * _out.confidence;
    if (_w <= 0) return;
    var _options = _decision.options;
    var _n = array_length(_options);
    var _best = 0;
    for (var _i = 0; _i < _n; _i++) _best = max(_best, _out.p[_i]);
    if (_best <= 0) return;
    for (var _i = 0; _i < _n; _i++) {
        _options[_i].score *= max(0.0001, lerp(1, _out.p[_i] / _best, _w));
    }
    array_sort(_options, _compare);
}

function __gmsa_learn_check_model(_model) {
    if (!is_struct(_model) || !variable_struct_exists(_model, "__adjust")) throw "GMSA: expected a model from gmsa_learn_*_create or gmsa_learn_custom";
}

function __gmsa_learn_check_influence(_influence) {
    if (!is_numeric(_influence) || _influence < 0 || _influence > 1) throw "GMSA: influence must be between 0 and 1";
}

// Prediction as an input
function gmsa_learn_input(_model, _observed, _action, _params = {}) {
    __gmsa_learn_check_model(_model);
    if (!is_struct(_observed) || !variable_struct_exists(_observed, "profile")) throw "GMSA: learn input needs the observed agent";
    if (_observed.profile.features == undefined) {
        throw "GMSA: profile '" + string(_observed.profile.name) + "' has no features, declare them with gmsa_profile_set_features before build";
    }
    if (gmsa_profile_action_index(_observed.profile, _action) < 0) {
        throw "GMSA: profile '" + string(_observed.profile.name) + "' has no action '" + string(_action) + "'";
    }
    var _fallback = __gmsa_param(_params, "fallback", 0);
    if (!is_numeric(_fallback) || _fallback < 0 || _fallback > 1) throw "GMSA: learn input fallback must be between 0 and 1";
    var _refresh = __gmsa_param(_params, "refresh", 1000000 / game_get_speed(gamespeed_fps));
    if (!is_numeric(_refresh) || _refresh < 0) throw "GMSA: learn input refresh must be 0 or more";
    var _clock = __gmsa_param(_params, "clock", get_timer);
    if (!is_callable(_clock)) throw "GMSA: learn input clock must be callable";

    var _ctx = { model : _model, observed : _observed, action : _action, fallback : _fallback, refresh : _refresh, clock : _clock };
    return method(_ctx, function(_agent, _target) {
        if (_agent == observed) throw "GMSA: a learn input can't be read by the agent it observes";
        var _entry = __gmsa_learn_prediction(model, observed, clock, refresh);
        if (!variable_struct_exists(_entry.actions, action)) return 0;
        return _entry.actions[$ action] * _entry.confidence + fallback * (1 - _entry.confidence);
    });
}

function __gmsa_learn_prediction(_model, _observed, _clock, _refresh) {
    var _now = _clock();
    var _cache = _model.__predictions;
    var _entry = undefined;
    for (var _i = 0; _i < array_length(_cache); _i++) {
        if (_cache[_i].agent == _observed) { _entry = _cache[_i]; break; }
    }
    if (_entry == undefined) {
        _entry = { agent : _observed, time : 0, fresh : false, actions : {}, confidence : 0 };
        array_push(_cache, _entry);
    }
    if (_entry.fresh && _now - _entry.time < _refresh) return _entry;

    var _e = gmsa_agent_evaluate(_observed, _now);
    var _out = gmsa_learn_predict(_model, _e);
    _entry.actions = {};
    for (var _i = 0; _i < array_length(_e.options); _i++) {
        var _name = _e.options[_i].action.name;
        var _sum = variable_struct_exists(_entry.actions, _name) ? _entry.actions[$ _name] : 0;
        _entry.actions[$ _name] = _sum + _out.p[_i];
    }
    _entry.confidence = _out.confidence;
    _entry.time = _now;
    _entry.fresh = true;
    return _entry;
}

function __gmsa_learn_invalidate(_model) {
    var _cache = _model.__predictions;
    for (var _i = 0; _i < array_length(_cache); _i++) _cache[_i].fresh = false;
}

// train
function gmsa_learn_train(_model, _budget = undefined) {
    if (!is_struct(_model) || _model[$ "tier"] == undefined) throw "GMSA: learn train needs a model";
    if (_budget != undefined && (!is_numeric(_budget) || _budget < 0)) throw "GMSA: learn train budget must be 0 or more";
    if (_model.frozen || _model.train == undefined) return true;
    var _done = (_model.train(_budget) != false); // anything but false finishes, a missing return can't loop forever
    if (_done) __gmsa_learn_invalidate(_model);
    return _done;
}

function __gmsa_learn_slots_grow(_model) {
    var _d = _model.data;
    while (array_length(_d.input_slot) < array_length(_model.inputs)) {
        array_push(_d.input_slot, _d.slots);
        _d.slots += 1;
    }
    while (array_length(_d.action_slot) < array_length(_model.actions)) {
        array_push(_d.action_slot, _d.slots);
        _d.slots += 1;
    }
}

function __gmsa_learn_slots_encode(_model, _option) {
    var _d = _model.data;
    var _slots = _d.slots;
    if (array_length(_model.__x) != _slots) {
        array_resize(_model.__x, _slots);
        for (var _s = 0; _s < _slots; _s++) _model.__x[_s] = 0;
        _model.__x_action = -1;
    }
    if (_model.__x_action >= 0) _model.__x[_model.__x_action] = 0;
    var _inputs = _option.inputs;
    var _k = array_length(_d.input_slot);
    var _m = min(_k, array_length(_inputs));
    for (var _j = 0; _j < _m; _j++) _model.__x[_d.input_slot[_j]] = _inputs[_j];
    for (var _j = _m; _j < _k; _j++) _model.__x[_d.input_slot[_j]] = 0;
    var _slot = _d.action_slot[_option.action];
    _model.__x[_slot] = 1;
    _model.__x_action = _slot;
}

function __gmsa_learn_softmax_scores(_model, _n) {
    var _t = (_model.learns == gmsa_learn_target.OUTCOMES) ? _model.temperature : 1;
    array_resize(_model.__p, _n);
    var _max = -infinity;
    for (var _i = 0; _i < _n; _i++) if (_model.__s[_i] > _max) _max = _model.__s[_i];
    var _sum = 0;
    for (var _i = 0; _i < _n; _i++) {
        _model.__p[_i] = exp((_model.__s[_i] - _max) / _t);
        _sum += _model.__p[_i];
    }
    for (var _i = 0; _i < _n; _i++) _model.__p[_i] /= _sum;
}

function __gmsa_learn_explain_line(_model, _sample, _index, _score_x) {
    var _o = _sample.options[_index];
    __gmsa_learn_slots_encode(_model, _o);
    var _score = _score_x(_model);
    var _d = _model.data;
    var _k = min(array_length(_d.input_slot), array_length(_o.inputs));
    var _share = array_create(_k, 0);
    for (var _j = 0; _j < _k; _j++) {
        var _slot = _d.input_slot[_j];
        var _keep = _model.__x[_slot];
        _model.__x[_slot] = 0;
        _share[_j] = _score - _score_x(_model);
        _model.__x[_slot] = _keep;
    }

    var _used = array_create(_k, false);
    var _parts = "";
    for (var _r = 0; _r < min(3, _k); _r++) {
        var _best = -1, _best_abs = 0;
        for (var _j = 0; _j < _k; _j++) {
            if (_used[_j]) continue;
            if (abs(_share[_j]) > _best_abs) { _best_abs = abs(_share[_j]); _best = _j; }
        }
        if (_best < 0) break;
        _used[_best] = true;
        _parts += _model.inputs[_best] + " " + __gmsa_learn_signed(_share[_best]) + ", ";
    }
    return [_model.actions[_o.action] + ": " + _parts + "score " + __gmsa_learn_signed(_score)
        + " (p " + string_format(_model.__p[_index], 1, 2) + ")"];
}

// Internal
function __gmsa_learn_bind(_model, _profile) {
    var _bindings = _model.__bindings;
    for (var _i = 0; _i < array_length(_bindings); _i++) {
        if (_bindings[_i].profile == _profile) return _bindings[_i];
    }
    var _features = _profile.features;
    if (_features == undefined) {
        throw "GMSA: profile '" + string(_profile.name) + "' has no features, declare them with gmsa_profile_set_features before build";
    }
    var _inputs = array_create(array_length(_features), 0);
    for (var _f = 0; _f < array_length(_features); _f++) {
        var _input = _profile.inputs[_features[_f]];
        _inputs[_f] = __gmsa_learn_input_id(_model, _input.name, !_input.per_target);
    }
    var _actions = array_create(array_length(_profile.actions), 0);
    for (var _a = 0; _a < array_length(_profile.actions); _a++) {
        _actions[_a] = __gmsa_learn_action_id(_model, _profile.actions[_a].name);
    }
    var _binding = { profile : _profile, inputs : _inputs, actions : _actions };
    array_push(_bindings, _binding);
    return _binding;
}

function __gmsa_learn_input_id(_model, _name, _situational) {
    if (variable_struct_exists(_model.input_lookup, _name)) return _model.input_lookup[$ _name];
    var _id = array_length(_model.inputs);
    array_push(_model.inputs, _name);
    array_push(_model.situational, _situational);
    _model.input_lookup[$ _name] = _id;
    return _id;
}

function __gmsa_learn_action_id(_model, _name) {
    if (variable_struct_exists(_model.action_lookup, _name)) return _model.action_lookup[$ _name];
    var _id = array_length(_model.actions);
    array_push(_model.actions, _name);
    _model.action_lookup[$ _name] = _id;
    return _id;
}

function __gmsa_learn_sample(_model, _decision, _chosen) {
    var _options = _decision.options;
    var _n = array_length(_options);
    var _binding = __gmsa_learn_bind(_model, _decision.agent.profile);
    var _k = array_length(_model.inputs);
    var _map = _binding.inputs;
    var _sample = _model.__sample;
    var _pool = _model.__pool;

    while (array_length(_pool) < _n) array_push(_pool, { action : 0, inputs : [] });
    array_resize(_sample.options, _n);
    array_resize(_sample.situation, _k);
    for (var _j = 0; _j < _k; _j++) _sample.situation[_j] = 0;

    for (var _i = 0; _i < _n; _i++) {
        var _o = _options[_i];
        if (!is_array(_o.inputs)) throw "GMSA: decision options have no inputs, declare features on the profile";
        var _so = _pool[_i];
        _so.action = _binding.actions[_o.action.index];
        array_resize(_so.inputs, _k);
        for (var _j = 0; _j < _k; _j++) _so.inputs[_j] = 0;
        for (var _f = 0; _f < array_length(_map); _f++) _so.inputs[_map[_f]] = _o.inputs[_f];
        _sample.options[_i] = _so;
    }
    if (_n > 0) {
        var _first = _sample.options[0].inputs;
        for (var _j = 0; _j < _k; _j++) {
            if (_model.situational[_j]) _sample.situation[_j] = _first[_j];
        }
    }
    _sample.chosen = _chosen;
    _sample.agent = _decision.agent;
    _sample.from = _decision;
    _sample.weight = 1;
    _sample.reward = undefined;
    return _sample;
}

function __gmsa_learn_forget_oldest(_entries, _keep) {
    var _names = variable_struct_get_names(_entries);
    var _n = array_length(_names);
    var _need = _n - _keep;
    if (_need <= 0) return _n;
    var _lasts = array_create(_n, 0);
    var _lo = infinity;
    var _hi = -infinity;
    for (var _i = 0; _i < _n; _i++) {
        var _l = _entries[$ _names[_i]].last;
        _lasts[_i] = _l;
        _lo = min(_lo, _l);
        _hi = max(_hi, _l);
    }
    var _span = _hi - _lo + 1;
    var _B = min(256, ceil(_span));
    var _hist = array_create(_B, 0);
    for (var _i = 0; _i < _n; _i++) _hist[min(_B - 1, floor((_lasts[_i] - _lo) * _B / _span))] += 1;
    var _sum = 0;
    var _b = 0;
    while (_b < _B && _sum < _need) {
        _sum += _hist[_b];
        _b += 1;
    }
    var _cut = _lo + _b * _span / _B; // the buckets below go
    var _left = _n;
    for (var _i = 0; _i < _n; _i++) {
        if (_lasts[_i] < _cut) {
            variable_struct_remove(_entries, _names[_i]);
            _left -= 1;
        }
    }
    return _left;
}