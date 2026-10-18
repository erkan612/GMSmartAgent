function gmsa_learn_space(_name, _actions, _inputs, _params = {}) {
    if (!is_string(_name) || _name == "") throw "GMSA: learn space needs a name";
    if (!is_array(_actions) || array_length(_actions) == 0) throw "GMSA: learn space '" + _name + "' needs at least one action";
    if (!is_array(_inputs)) throw "GMSA: learn space '" + _name + "' inputs must be an array of names";
    var _sit = __gmsa_param(_params, "situational", undefined);
    if (_sit != undefined && (!is_array(_sit) || array_length(_sit) != array_length(_inputs))) {
        throw "GMSA: learn space '" + _name + "' situational needs one bool per input";
    }
    var _space = { name : _name, actions : [], inputs : [], features : [], __pool : [] };
    var _seen = {};
    for (var _a = 0; _a < array_length(_actions); _a++) {
        var _an = _actions[_a];
        if (!is_string(_an) || _an == "" || variable_struct_exists(_seen, _an)) {
            throw "GMSA: learn space '" + _name + "' actions must be unique names";
        }
        _seen[$ _an] = true;
        array_push(_space.actions, { name : _an, index : _a });
    }
    _seen = {};
    for (var _i = 0; _i < array_length(_inputs); _i++) {
        var _in = _inputs[_i];
        if (!is_string(_in) || _in == "" || variable_struct_exists(_seen, _in)) {
            throw "GMSA: learn space '" + _name + "' inputs must be unique names";
        }
        _seen[$ _in] = true;
        array_push(_space.inputs, { name : _in, per_target : (_sit == undefined) ? false : !_sit[_i] });
        array_push(_space.features, _i);
    }
    // the same shapes as an agent's decision and a tracked decision, reused by every call
    _space.__decision = { agent : { profile : _space }, options : [], chosen : -1 };
    _space.__entry = { agent : _space.__decision.agent, options : undefined, chosen : -1, probability : 1 };
    return _space;
}

function gmsa_learn_space_predict(_model, _space, _options) {
    __gmsa_learn_check_model(_model);
    return gmsa_learn_predict(_model, __gmsa_learn_space_fill(_space, _options));
}

function gmsa_learn_space_observe(_model, _space, _options, _chosen, _note = undefined) {
    __gmsa_learn_check_model(_model);
    var _d = __gmsa_learn_space_fill(_space, _options);
    __gmsa_learn_space_check_chosen(_space, _d, _chosen);
    _d.chosen = _chosen;
    return gmsa_learn_observe(_model, _d, _note);
}

function gmsa_learn_space_outcome(_model, _space, _options, _chosen, _probability, _reward, _credit = 1, _note = undefined) {
    __gmsa_learn_check_outcome(_model, _reward);
    if (!__gmsa_net_above_zero(_probability) || _probability > 1) throw "GMSA: learn space probability must be above 0 and at most 1";
    if (!__gmsa_net_above_zero(_credit) || _credit > 1) throw "GMSA: learn space credit must be above 0 and at most 1";
    var _d = __gmsa_learn_space_fill(_space, _options);
    __gmsa_learn_space_check_chosen(_space, _d, _chosen);
    if (_model.frozen) return false;
    var _e = _space.__entry;
    _e.options = _d.options;
    _e.chosen = _chosen;
    _e.probability = _probability;
    __gmsa_learn_outcome_one(_model, _e, _reward, _credit, _note);
    __gmsa_learn_invalidate(_model);
    return true;
}

function gmsa_learn_space_explain(_model, _space, _options, _index) {
    __gmsa_learn_check_model(_model);
    return gmsa_learn_explain(_model, __gmsa_learn_space_fill(_space, _options), _index);
}

// Internal
function __gmsa_learn_space_fill(_space, _options) {
    if (!is_struct(_space) || _space[$ "__decision"] == undefined) throw "GMSA: expected a space from gmsa_learn_space";
    if (!is_array(_options) || array_length(_options) == 0) throw "GMSA: learn space '" + _space.name + "' needs at least one option";
    var _d = _space.__decision;
    var _n = array_length(_options);
    var _k = array_length(_space.inputs);
    while (array_length(_space.__pool) < _n) array_push(_space.__pool, { action : undefined, inputs : undefined });
    array_resize(_d.options, _n);
    for (var _i = 0; _i < _n; _i++) {
        var _o = _options[_i];
        var _a = _o.action;
        if (!is_numeric(_a) || _a < 0 || _a >= array_length(_space.actions) || frac(_a) != 0) {
            throw "GMSA: learn space '" + _space.name + "' option " + string(_i) + " has no valid action index";
        }
        if (!is_array(_o.inputs) || array_length(_o.inputs) != _k) {
            throw "GMSA: learn space '" + _space.name + "' option " + string(_i) + " needs " + string(_k) + " inputs";
        }
        var _so = _space.__pool[_i];
        _so.action = _space.actions[_a];
        _so.inputs = _o.inputs;
        _d.options[_i] = _so;
    }
    _d.chosen = -1;
    return _d;
}

function __gmsa_learn_space_check_chosen(_space, _d, _chosen) {
    if (!is_numeric(_chosen) || _chosen < 0 || _chosen >= array_length(_d.options) || frac(_chosen) != 0) {
        throw "GMSA: learn space '" + _space.name + "' chosen must be an option index";
    }
}