enum gmsa_learn_tier { CUSTOM, COUNT, LINEAR }

// Creation
function __gmsa_learn_model_create(_tier, _tier_name, _params) {
    var _half = __gmsa_param(_params, "half_life", 50);
    if (!is_numeric(_half) || _half <= 0) throw "GMSA: learn half_life must be above 0";
    var _k = __gmsa_param(_params, "confidence_k", 20);
    if (!is_numeric(_k) || _k <= 0) throw "GMSA: learn confidence_k must be above 0";
    return {
        tier          : _tier,
        tier_name     : _tier_name,
        actions       : [],         // action names, the position is the action id
        action_lookup : {},		    
        inputs        : [],         // feature names, the position is the input id
        input_lookup  : {},		    
        situational   : [],         // per input id: true when the input doesn't depend on the target
        samples       : 0,          // decayed amount of observed data
        half_life     : _half,
        decay         : power(0.5, 1 / _half),
        confidence_k  : _k,
        frozen        : false,
        data          : {},
        observe       : undefined,  // function(sample)
        predict       : undefined,  // function(sample, out), fills out.p and out.confidence
        explain       : undefined,  // function(sample, i), returns an array of lines
        save_data     : undefined,  // function(), returns a JSON-ready struct
        load_data     : undefined,  // function(data)
        reset_data    : undefined,  // function(), also called once at creation
        __bindings    : [],
        __sample      : { situation : [], options : [], chosen : -1, weight : 1 },
        __pool        : [],
        __out         : { p : [], confidence : 0 },
    };
}

function gmsa_learn_custom(_methods, _params = {}) {
    if (!is_struct(_methods)) throw "GMSA: learn custom needs a struct of methods";
    var _model = __gmsa_learn_model_create(gmsa_learn_tier.CUSTOM, __gmsa_param(_params, "name", "custom"), _params);
    var _names = ["observe", "predict", "explain", "save_data", "load_data", "reset_data"];
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _fn = __gmsa_param(_methods, _names[_i], undefined);
        if (_fn == undefined) continue;
        if (!is_callable(_fn)) throw "GMSA: learn custom " + _names[_i] + " must be callable";
        _model[$ _names[_i]] = method(_model, _fn);
    }
    if (_model.observe == undefined || _model.predict == undefined) throw "GMSA: learn custom needs observe and predict";
    if (_model.reset_data != undefined) _model.reset_data();
    return _model;
}

// Training and prediction
function gmsa_learn_observe(_model, _decision) {
    if (_model.frozen) return false;
    if (_decision.chosen < 0) throw "GMSA: learn observe needs a decision with a chosen option";
    var _sample = __gmsa_learn_sample(_model, _decision, _decision.chosen);
    _model.samples = _model.samples * _model.decay + 1;
    _model.observe(_sample);
    return true;
}

function gmsa_learn_predict(_model, _decision) {
    var _out = _model.__out;
    var _n = array_length(_decision.options);
    array_resize(_out.p, _n);
    _out.confidence = 0;
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
}

// Persistence
function gmsa_learn_save(_model) {
    var _data = (_model.save_data != undefined) ? _model.save_data() : {};
    return json_stringify({
        format      : "gmsa_learn",
        version     : 1,
        tier        : _model.tier_name,
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
    return true;
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
    _sample.weight = 1;
    return _sample;
}