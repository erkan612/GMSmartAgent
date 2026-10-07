function gmsa_learn_tdnn_create(_params = {}) {
    static _next_id = 0;
    var _length = __gmsa_param(_params, "length", 3);
    if (!__gmsa_net_whole(_length)) throw "GMSA: tdnn length must be a whole number of 1 or more";
    var _hidden = __gmsa_param(_params, "layers", [32, 16]);
    if (!is_array(_hidden) || array_length(_hidden) == 0) throw "GMSA: tdnn layers must be a non-empty array of layer sizes";
    for (var _i = 0; _i < array_length(_hidden); _i++) {
        if (!__gmsa_net_whole(_hidden[_i])) throw "GMSA: tdnn layer sizes must be whole numbers of 1 or more";
    }
    var _lr = __gmsa_param(_params, "learn_rate", 0.01);
    if (!__gmsa_net_above_zero(_lr)) throw "GMSA: tdnn learn_rate must be above 0";
    var _replay = __gmsa_param(_params, "replay", 4);
    if (!is_numeric(_replay) || _replay < 0 || frac(_replay) != 0) throw "GMSA: tdnn replay must be a whole number of 0 or more";
    var _memory = __gmsa_param(_params, "memory", 64);
    if (!__gmsa_net_whole(_memory)) throw "GMSA: tdnn memory must be a whole number of 1 or more";
    var _remember = __gmsa_param(_params, "remember", []);
    if (!is_array(_remember)) throw "GMSA: tdnn remember must be an array of input names";
    for (var _i = 0; _i < array_length(_remember); _i++) {
        if (!is_string(_remember[_i])) throw "GMSA: tdnn remember must be an array of input names";
    }
    var _fdepth = __gmsa_param(_params, "familiar_depth", 1);
    if (!is_numeric(_fdepth) || _fdepth < 0 || frac(_fdepth) != 0) throw "GMSA: tdnn familiar_depth must be a whole number of 0 or more";
    var _fbins = __gmsa_param(_params, "familiar_bins", 2);
    if (!__gmsa_net_whole(_fbins)) throw "GMSA: tdnn familiar_bins must be a whole number of 1 or more";
    var _fk = __gmsa_param(_params, "familiar_k", 3);
    if (!__gmsa_net_above_zero(_fk)) throw "GMSA: tdnn familiar_k must be above 0";
    var _fcap = __gmsa_param(_params, "familiar_capacity", 1024);
    if (!__gmsa_net_whole(_fcap)) throw "GMSA: tdnn familiar_capacity must be a whole number of 1 or more";

    var _model = __gmsa_learn_model_create(gmsa_learn_tier.TDNN, "tdnn", {
        half_life    : __gmsa_param(_params, "half_life", 200),
        confidence_k : __gmsa_param(_params, "confidence_k", 50),
        learns       : __gmsa_param(_params, "learns", gmsa_learn_target.CHOICES),
        temperature  : __gmsa_param(_params, "temperature", 0.1),
    });
    var _layers = [];
    for (var _i = 0; _i < array_length(_hidden); _i++) array_push(_layers, _hidden[_i]);
    array_push(_layers, 1);
    _model.tdnn = {
        id                : _next_id,
        gen               : 0,
        length            : _length,
        layers            : _layers,
        activation        : __gmsa_param(_params, "activation", gmsa_net_activation.LEAKY_RELU),
        optimizer         : __gmsa_param(_params, "optimizer", gmsa_net_optimizer.ADAM),
        learn_rate        : _lr,
        seed              : __gmsa_param(_params, "seed", 1),
        replay            : _replay,
        memory            : _memory,
        remember          : _remember,
        familiar_depth    : _fdepth,
        familiar_bins     : _fbins,
        familiar_k        : _fk,
        familiar_capacity : _fcap,
    };
    _next_id += 1;
    __gmsa_learn_tdnn_net(_model, 1); // validates the network settings now, not on first use

    _model.__x = [];     // an encoded option
    _model.__s = [];     // scores of the last sample
    _model.__g = [];     // score gradients
    _model.__p = [];     // softmax of the last sample
    _model.__ids = [];   // the history in use, oldest first
    _model.__memo = [];  // per history entry, the remembered inputs of that choice
    _model.__mem = [];   // replay memory: recent choices, encoded
    _model.__mem_next = 0;
    _model.__mem_count = 0;
    _model.__rng = gmsa_rng_create(_model.tdnn.seed);
    _model.observe    = method(_model, __gmsa_learn_tdnn_observe);
    _model.predict    = method(_model, __gmsa_learn_tdnn_predict);
    _model.explain    = method(_model, __gmsa_learn_tdnn_explain);
    _model.save_data  = method(_model, __gmsa_learn_tdnn_save);
    _model.load_data  = method(_model, __gmsa_learn_tdnn_load);
    _model.reset_data = method(_model, __gmsa_learn_tdnn_reset);
    _model.reset_data();
    return _model;
}

// the agent's chain of choices ends here: what comes next starts a new history
function gmsa_learn_tdnn_break(_model, _agent) {
    if (!is_struct(_model) || _model[$ "tdnn"] == undefined) throw "GMSA: tdnn break needs a model from gmsa_learn_tdnn_create";
    var _h = __gmsa_learn_tdnn_history(_model, _agent);
    array_resize(_h.ids, 0);
    array_resize(_h.memo, 0);
    array_push(_h.ids, -1); // the start: what comes first is a habit too
    array_push(_h.memo, array_create(array_length(_model.tdnn.remember), 0));
    var _tracker = _agent[$ "__history"];
    if (_tracker != undefined) _h.cut = _tracker.clock(); // tracked decisions from before now no longer count
}

// Methods, run with the model as self
function __gmsa_learn_tdnn_reset() {
    data = { net : undefined, slots : 0, input_slot : [], action_slot : [], hist_slot : [], memo_slot : [],
             clock : 0, familiar : {}, familiar_count : 0 };
    __mem_next = 0;
    __mem_count = 0;
    tdnn.gen += 1; // every agent's history for this model starts over
}

function __gmsa_learn_tdnn_observe(_sample) {
    var _outcomes = (learns == gmsa_learn_target.OUTCOMES);
    var _h = __gmsa_learn_tdnn_history(self, _sample.agent);
    if (_outcomes) __gmsa_learn_tdnn_tracked(self, _sample.agent, _h, _sample.from);
    else __gmsa_learn_tdnn_use(self, _h);
    __gmsa_learn_tdnn_grow(self);

    // learn from it, then from a few earlier ones in memory
    var _new = __gmsa_learn_tdnn_store(self, _sample);
    __gmsa_learn_tdnn_train(self, __mem[_new]);
    var _others = __mem_count - 1;
    if (_others > 0) {
        repeat (min(tdnn.replay, _others)) {
            var _pick = (_new + 1 + floor(gmsa_rng_next(__rng) * _others)) mod __mem_count;
            __gmsa_learn_tdnn_train(self, __mem[_pick]);
        }
    }

    // how familiar this kind of moment is
    data.clock += 1;
    var _key = __gmsa_learn_tdnn_familiar_key(self, _sample);
    var _f = data.familiar[$ _key];
    if (_f == undefined) {
        _f = { n : 0, last : data.clock };
        data.familiar[$ _key] = _f;
        data.familiar_count += 1;
    }
    _f.n = _f.n * power(decay, data.clock - _f.last) + 1;
    _f.last = data.clock;
    __gmsa_learn_tdnn_trim(self);

    if (!_outcomes) { // choices keep their own history, outcomes read the tracker's
        var _chosen = _sample.options[_sample.chosen];
        array_push(_h.ids, _chosen.action);
        array_push(_h.memo, __gmsa_learn_tdnn_memo(self, _chosen.inputs, undefined));
        if (array_length(_h.ids) > tdnn.length) {
            array_delete(_h.ids, 0, 1);
            array_delete(_h.memo, 0, 1);
        }
    }
}

function __gmsa_learn_tdnn_predict(_sample, _out) {
    var _h = __gmsa_learn_tdnn_history(self, _sample.agent);
    if (learns == gmsa_learn_target.OUTCOMES) __gmsa_learn_tdnn_tracked(self, _sample.agent, _h, undefined);
    else __gmsa_learn_tdnn_use(self, _h);
    __gmsa_learn_tdnn_grow(self);
    var _n = array_length(_sample.options);
    __gmsa_learn_tdnn_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, _n);
    for (var _i = 0; _i < _n; _i++) _out.p[_i] = __p[_i];
    // how much it has learned, scaled down in moments unlike the ones it learned from
    _out.confidence = gmsa_learn_confidence(self) * __gmsa_learn_tdnn_familiar(self, _sample);
}

function __gmsa_learn_tdnn_explain(_sample, _index) {
    var _h = __gmsa_learn_tdnn_history(self, _sample.agent);
    if (learns == gmsa_learn_target.OUTCOMES) __gmsa_learn_tdnn_tracked(self, _sample.agent, _h, undefined);
    else __gmsa_learn_tdnn_use(self, _h);
    __gmsa_learn_tdnn_grow(self);
    __gmsa_learn_tdnn_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, array_length(_sample.options));

    // what each part adds to the score: an input, or one of the last choices
    var _o = _sample.options[_index];
    __gmsa_learn_tdnn_encode(self, _o, __x);
    var _net = data.net;
    var _score = __gmsa_learn_tdnn_score(_net, __x);
    var _names = [];
    var _shares = [];
    var _d = data;
    var _k = min(array_length(_d.input_slot), array_length(_o.inputs));
    for (var _j = 0; _j < _k; _j++) {
        var _slot = _d.input_slot[_j];
        var _keep = __x[_slot];
        __x[_slot] = 0;
        array_push(_names, inputs[_j]);
        array_push(_shares, _score - __gmsa_learn_tdnn_score(_net, __x));
        __x[_slot] = _keep;
    }
    var _n = array_length(__ids);
    var _R = array_length(tdnn.remember);
    for (var _j = 1; _j <= min(tdnn.length, _n); _j++) {
        var _id = __ids[_n - _j];
        __x[_d.hist_slot[_j - 1][_id + 1]] = 0;
        var _ms = _d.memo_slot[_j - 1];
        for (var _r = 0; _r < _R; _r++) __x[_ms[_r]] = 0;
        array_push(_names, string(_j) + " back: " + ((_id < 0) ? "the start" : actions[_id]));
        array_push(_shares, _score - __gmsa_learn_tdnn_score(_net, __x));
        __gmsa_learn_tdnn_encode(self, _o, __x);
    }

    var _used = array_create(array_length(_shares), false);
    var _parts = "";
    for (var _r = 0; _r < min(3, array_length(_shares)); _r++) {
        var _best = -1;
        var _best_abs = 0;
        for (var _j = 0; _j < array_length(_shares); _j++) {
            if (_used[_j]) continue;
            if (abs(_shares[_j]) > _best_abs) {
                _best_abs = abs(_shares[_j]);
                _best = _j;
            }
        }
        if (_best < 0) break;
        _used[_best] = true;
        _parts += _names[_best] + " " + __gmsa_learn_signed(_shares[_best]) + ", ";
    }
    return [actions[_o.action] + ": " + _parts + "score " + __gmsa_learn_signed(_score) + " (p " + string_format(__p[_index], 1, 2) + ")"];
}

function __gmsa_learn_tdnn_save() {
    return {
        slots       : data.slots,
        input_slot  : data.input_slot,
        action_slot : data.action_slot,
        hist_slot   : data.hist_slot,
        memo_slot   : data.memo_slot,
        remember    : tdnn.remember,
        clock       : data.clock,
        familiar    : data.familiar,
        net         : (data.net == undefined) ? 0 : gmsa_net_save(data.net),
    };
}

function __gmsa_learn_tdnn_load(_data) {
    if (!is_numeric(_data[$ "slots"]) || !is_array(_data[$ "input_slot"]) || !is_array(_data[$ "action_slot"])
        || !is_array(_data[$ "hist_slot"]) || !is_array(_data[$ "memo_slot"]) || !is_array(_data[$ "remember"])) {
        throw "GMSA: tdnn save is malformed";
    }
    var _same = (array_length(_data.remember) == array_length(tdnn.remember));
    for (var _i = 0; _same && _i < array_length(_data.remember); _i++) _same = (_data.remember[_i] == tdnn.remember[_i]);
    if (!_same) throw "GMSA: tdnn save remembers different inputs than the model";
    var _net = undefined;
    if (is_struct(_data[$ "net"])) {
        _net = __gmsa_learn_tdnn_net(self, max(1, _data.slots));
        gmsa_net_load(_net, _data.net); // throws when the layers differ
    }
    data = { net : _net, slots : _data.slots, input_slot : _data.input_slot, action_slot : _data.action_slot,
             hist_slot : _data.hist_slot, memo_slot : _data.memo_slot, clock : _data.clock, familiar : _data.familiar,
             familiar_count : array_length(variable_struct_get_names(_data.familiar)) };
    __mem_next = 0;   // the replay memory isn't saved
    __mem_count = 0;
    tdnn.gen += 1;    // histories aren't saved, the next choices start fresh
}

// Internal
function __gmsa_learn_tdnn_net(_model, _inputs) {
    var _t = _model.tdnn;
    return gmsa_net_create(_inputs, _t.layers, {
        activation : _t.activation,
        output     : gmsa_net_activation.LINEAR,
        optimizer  : _t.optimizer,
        learn_rate : _t.learn_rate,
        seed       : _t.seed,
        sparse     : true, // one-hot actions and history: most inputs are 0
    });
}

function __gmsa_learn_tdnn_grow(_model) {
    __gmsa_learn_slots_grow(_model);
    var _d = _model.data;
    var _A = array_length(_model.actions);
    var _R = array_length(_model.tdnn.remember);
    while (array_length(_d.hist_slot) < _model.tdnn.length) {
        array_push(_d.hist_slot, []);
        array_push(_d.memo_slot, []);
    }
    for (var _j = 0; _j < _model.tdnn.length; _j++) {
        var _hs = _d.hist_slot[_j];
        while (array_length(_hs) < _A + 1) { // the start of a history, then each action
            array_push(_hs, _d.slots);
            _d.slots += 1;
        }
        var _ms = _d.memo_slot[_j];
        while (array_length(_ms) < _R) {
            array_push(_ms, _d.slots);
            _d.slots += 1;
        }
    }
    if (_d.slots == 0) return;
    if (_d.net == undefined) {
        _d.net = __gmsa_learn_tdnn_net(_model, _d.slots);
        // output weights start at 0: every option scores the same until something is learned
        var _last = _d.net.layers[array_length(_d.net.layers) - 1];
        for (var _k = 0; _k < array_length(_last.w); _k++) _last.w[_k] = 0;
    } else if (_d.net.inputs < _d.slots) {
        gmsa_net_grow_inputs(_d.net, _d.slots - _d.net.inputs);
    }
}

function __gmsa_learn_tdnn_encode(_model, _option, _dst) {
    var _d = _model.data;
    var _slots = _d.slots;
    array_resize(_dst, _slots);
    for (var _s = 0; _s < _slots; _s++) _dst[@ _s] = 0;
    var _inputs = _option.inputs;
    var _k = min(array_length(_d.input_slot), array_length(_inputs));
    for (var _j = 0; _j < _k; _j++) {
        var _v = _inputs[_j];
        _dst[@ _d.input_slot[_j]] = _model.situational[_j] ? _v * 2 - 1 : _v;
    }
    _dst[@ _d.action_slot[_option.action]] = 1;
    var _ids = _model.__ids;
    var _memo = _model.__memo;
    var _n = array_length(_ids);
    var _R = array_length(_model.tdnn.remember);
    for (var _j = 1; _j <= min(_model.tdnn.length, _n); _j++) {
        _dst[@ _d.hist_slot[_j - 1][_ids[_n - _j] + 1]] = 1;
        var _mv = _memo[_n - _j];
        var _ms = _d.memo_slot[_j - 1];
        for (var _r = 0; _r < _R; _r++) _dst[@ _ms[_r]] = _mv[_r];
    }
}

function __gmsa_learn_tdnn_score(_net, _x) {
    var _out = gmsa_net_forward(_net, _x);
    return _out[0];
}

function __gmsa_learn_tdnn_scores(_model, _sample) {
    var _n = array_length(_sample.options);
    array_resize(_model.__s, _n);
    for (var _i = 0; _i < _n; _i++) {
        __gmsa_learn_tdnn_encode(_model, _sample.options[_i], _model.__x);
        _model.__s[_i] = __gmsa_learn_tdnn_score(_model.data.net, _model.__x);
    }
}

function __gmsa_learn_tdnn_store(_model, _sample) {
    var _i = _model.__mem_next;
    while (array_length(_model.__mem) <= _i) array_push(_model.__mem, { xs : [], n : 0, chosen : 0, weight : 1, reward : 0 });
    var _e = _model.__mem[_i];
    if (_model.learns == gmsa_learn_target.OUTCOMES) {
        if (array_length(_e.xs) < 1) array_push(_e.xs, []);
        __gmsa_learn_tdnn_encode(_model, _sample.options[_sample.chosen], _e.xs[0]);
        _e.n = 1;
        _e.chosen = 0;
        _e.reward = _sample.reward;
    } else {
        var _n = array_length(_sample.options);
        while (array_length(_e.xs) < _n) array_push(_e.xs, []);
        for (var _o = 0; _o < _n; _o++) __gmsa_learn_tdnn_encode(_model, _sample.options[_o], _e.xs[_o]);
        _e.n = _n;
        _e.chosen = _sample.chosen;
        _e.reward = 0;
    }
    _e.weight = _sample.weight;
    _model.__mem_next = (_i + 1) mod _model.tdnn.memory;
    _model.__mem_count = min(_model.__mem_count + 1, _model.tdnn.memory);
    return _i;
}

function __gmsa_learn_tdnn_train(_model, _e) {
    var _net = _model.data.net;
    if (_model.learns == gmsa_learn_target.OUTCOMES) {
        var _out = gmsa_net_forward(_net, _e.xs[0]);
        gmsa_net_backward(_net, _e.weight * (_out[0] - _e.reward));
        gmsa_net_step(_net);
        return;
    }
    var _n = _e.n;
    if (_n < 2) return; // a single option teaches no preference
    array_resize(_model.__s, _n);
    array_resize(_model.__g, _n);
    var _max = -infinity;
    for (var _i = 0; _i < _n; _i++) {
        _model.__s[_i] = __gmsa_learn_tdnn_score(_net, _e.xs[_i]);
        _max = max(_max, _model.__s[_i]);
    }
    var _sum = 0;
    for (var _i = 0; _i < _n; _i++) {
        _model.__g[_i] = exp(_model.__s[_i] - _max);
        _sum += _model.__g[_i];
    }
    for (var _i = 0; _i < _n; _i++) _model.__g[_i] = _e.weight * (_model.__g[_i] / _sum - ((_i == _e.chosen) ? 1 : 0));
    // the last option is still in the network from the pass above
    gmsa_net_backward(_net, _model.__g[_n - 1]);
    for (var _i = 0; _i < _n - 1; _i++) {
        gmsa_net_forward(_net, _e.xs[_i]);
        gmsa_net_backward(_net, _model.__g[_i]);
    }
    gmsa_net_step(_net);
}

function __gmsa_learn_tdnn_memo(_model, _inputs, _binding) {
    var _names = _model.tdnn.remember;
    var _R = array_length(_names);
    var _out = array_create(_R, 0);
    for (var _r = 0; _r < _R; _r++) {
        var _id = variable_struct_exists(_model.input_lookup, _names[_r]) ? _model.input_lookup[$ _names[_r]] : -1;
        if (_id < 0) continue;
        if (_binding == undefined) {
            if (_id < array_length(_inputs)) _out[_r] = _inputs[_id];
        } else {
            for (var _f = 0; _f < array_length(_binding.inputs); _f++) {
                if (_binding.inputs[_f] == _id && _f < array_length(_inputs)) {
                    _out[_r] = _inputs[_f];
                    break;
                }
            }
        }
    }
    return _out;
}

function __gmsa_learn_tdnn_history(_model, _agent) {
    if (!is_struct(_agent) || !is_struct(_agent[$ "profile"]) || _agent.profile[$ "__decision"] != undefined) {
        throw "GMSA: the tdnn learner needs an agent's history, learn spaces have none";
    }
    var _all = _agent[$ "__tdnn"];
    if (_all == undefined) {
        _all = {};
        _agent.__tdnn = _all;
    }
    var _key = string(_model.tdnn.id);
    var _h = _all[$ _key];
    if (_h == undefined || _h.gen != _model.tdnn.gen) {
        // -1 marks the start of a history
        _h = { gen : _model.tdnn.gen, ids : [-1], memo : [array_create(array_length(_model.tdnn.remember), 0)], cut : -infinity };
        _all[$ _key] = _h;
    }
    return _h;
}

function __gmsa_learn_tdnn_use(_model, _h) {
    var _n = array_length(_h.ids);
    array_resize(_model.__ids, _n);
    array_resize(_model.__memo, _n);
    array_copy(_model.__ids, 0, _h.ids, 0, _n);
    array_copy(_model.__memo, 0, _h.memo, 0, _n);
}

function __gmsa_learn_tdnn_tracked(_model, _agent, _h, _upto) {
    var _tracker = _agent[$ "__history"];
    if (_tracker == undefined) throw "GMSA: a tdnn learner from outcomes needs a tracked agent, start with gmsa_learn_track";
    if (_tracker.size <= _model.tdnn.length) {
        throw "GMSA: the tdnn length is " + string(_model.tdnn.length) + ", track the agent with a size of at least "
            + string(_model.tdnn.length + 1) + " (gmsa_learn_track(agent, { size : " + string(_model.tdnn.length + 1) + " }))";
    }
    var _entries = _tracker.entries;
    var _end = array_length(_entries);
    if (_upto != undefined) {
        for (var _i = 0; _i < array_length(_entries); _i++) {
            if (_entries[_i] == _upto) {
                _end = _i;
                break;
            }
        }
    }
    var _first = 0;
    while (_first < _end && _entries[_first].start < _h.cut) _first += 1;
    // the start is known after a break, or while the tracker hasn't dropped anything yet
    var _known = (_h.cut > -infinity) || (array_length(_entries) < _tracker.size);
    var _binding = __gmsa_learn_bind(_model, _agent.profile);
    array_resize(_model.__ids, 0);
    array_resize(_model.__memo, 0);
    if (_known) {
        array_push(_model.__ids, -1);
        array_push(_model.__memo, array_create(array_length(_model.tdnn.remember), 0));
    }
    for (var _i = _first; _i < _end; _i++) {
        var _o = _entries[_i].options[_entries[_i].chosen];
        array_push(_model.__ids, _binding.actions[_o.action.index]);
        array_push(_model.__memo, __gmsa_learn_tdnn_memo(_model, _o.inputs, _binding));
    }
    var _extra = array_length(_model.__ids) - _model.tdnn.length;
    if (_extra > 0) {
        array_delete(_model.__ids, 0, _extra);
        array_delete(_model.__memo, 0, _extra);
    }
}

function __gmsa_learn_tdnn_familiar_key(_model, _sample) {
    var _key = "";
    var _ids = _model.__ids;
    var _n = array_length(_ids);
    for (var _j = 1; _j <= _model.tdnn.familiar_depth; _j++) _key += ((_j <= _n) ? string(_ids[_n - _j]) : "_") + ",";
    var _bins = _model.tdnn.familiar_bins;
    for (var _j = 0; _j < array_length(_sample.situation); _j++) {
        if (!_model.situational[_j]) continue;
        _key += ":" + string(min(_bins - 1, floor(clamp(_sample.situation[_j], 0, 1) * _bins)));
    }
    return _key;
}

function __gmsa_learn_tdnn_familiar(_model, _sample) {
    var _d = _model.data;
    var _f = _d.familiar[$ __gmsa_learn_tdnn_familiar_key(_model, _sample)];
    if (_f == undefined) return 0;
    var _n = _f.n * power(_model.decay, _d.clock - _f.last);
    return _n / (_n + _model.tdnn.familiar_k);
}

function __gmsa_learn_tdnn_trim(_model) {
    var _d = _model.data;
    var _cap = _model.tdnn.familiar_capacity;
    if (_d.familiar_count <= _cap) return;
    var _names = variable_struct_get_names(_d.familiar);
    var _n = array_length(_names);
    var _list = array_create(_n, undefined);
    for (var _i = 0; _i < _n; _i++) _list[_i] = { k : _names[_i], last : _d.familiar[$ _names[_i]].last };
    array_sort(_list, function(_x, _y) { return _x.last - _y.last; });
    var _drop = min(_n, _n - _cap + max(1, _cap div 10));
    for (var _i = 0; _i < _drop; _i++) variable_struct_remove(_d.familiar, _list[_i].k);
    _d.familiar_count = _n - _drop;
}