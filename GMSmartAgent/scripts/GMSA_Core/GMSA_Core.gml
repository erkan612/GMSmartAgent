/*********************************************************************************************
*                                        MIT License                                         *
*--------------------------------------------------------------------------------------------*
* Copyright (c) 2026 erkan612                                                                *
*                                                                                            *
* Permission is hereby granted, free of charge, to any person obtaining a copy of this       *
* software and associated documentation files (the "Software"), to deal in the Software      *
* without restriction, including without limitation the rights to use, copy, modify, merge,  *
* publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons *
* to whom the Software is furnished to do so, subject to the following conditions:           *
*                                                                                            *
* The above copyright notice and this permission notice shall be included in all copies or   *
* substantial portions of the Software.                                                      *
*                                                                                            *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,        *
* INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR   *
* PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE  *
* FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR       *
* OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER     *
* DEALINGS IN THE SOFTWARE.                                                                  *
**********************************************************************************************
*--------------------------------------------------------------------------------------------*
*   	 *****************************************************************************       *
*        ┌╦════┌╦═╦═╦┐╔═══╗┌╦═╦═╦┐┌╦═══╦┐┌╦═══╗┌═╤╦╤═┐┌╦═══╦┐┌╦════┌╦═══┐┌╦╗ ╦┐┌═╤╦╤═┐       *
*        │║ ══╗│║ ║ ║│╚═══╗│║ ║ ║││╟───╢│├╬══╦╝  │║│  │╟───╢││║ ══╗│╠══  │║╚╗║│  │║│         *
*        └╩═══╝└╩ ╩ ╩┘╚═══╝└╩ ╩ ╩┘└╩   ╩┘└╩  ╩┘  ╧╩╧  └╩   ╩┘└╩═══╝└╩═══┘└╩ ╚╩┘  ╧╩╧         *
*   						Decision-Weighting AI for GameMaker								 *
*   						          Version 1.9.10										 *
*   																                         *
*   						           by erkan612											 *
*   	 *****************************************************************************       *
*********************************************************************************************/


enum gmsa_source  { PULL, PUSH }
enum gmsa_select  { BEST, TOP_N_WEIGHTED }
enum gmsa_chooser { AGENT, OBSERVED, EVALUATED }

// Inputs
function gmsa_input_pull(_name, _callback, _min = 0, _max = 1, _per_target = false) {
    if (!is_callable(_callback)) throw "GMSA: pull input '" + string(_name) + "' needs a callable callback";
    return __gmsa_input_make(_name, gmsa_source.PULL, _callback, _min, _max, _per_target, _min);
}

function gmsa_input_push(_name, _min = 0, _max = 1, _default = undefined) {
    if (_default == undefined) _default = _min;
    return __gmsa_input_make(_name, gmsa_source.PUSH, undefined, _min, _max, false, _default);
}

function gmsa_input_normalize(_input, _raw) {
    if (!is_numeric(_raw) || is_nan(_raw)) return 0;
    return clamp((_raw - _input.min) / (_input.max - _input.min), 0, 1);
}

function __gmsa_input_make(_name, _source, _callback, _min, _max, _per_target, _default) {
    if (!is_string(_name) || _name == "") throw "GMSA: input name must be a non-empty string";
    if (_min == _max) throw "GMSA: input '" + _name + "' has min equal to max";
    return {
        name          : _name,
        source        : _source,
        callback      : _callback,
        min           : _min,
        max           : _max,
        per_target    : _per_target,
        default_value : _default,
    };
}

// Profiles
function gmsa_profile_create(_name, _params = {}) {
    return {
        name         : _name,
        inputs       : [],
        actions      : [],
        select       : __gmsa_param(_params, "select", gmsa_select.BEST),
        top_n        : __gmsa_param(_params, "top_n", 3),
        commitment   : __gmsa_param(_params, "commitment", 0),
        model        : undefined, // reserved for Learn
        influence    : 0,         // reserved for Learn
        model_inputs : undefined, // reserved for Learn
        features     : undefined, // resolved feature input indices, set at build
        built        : false,
        input_index  : {},
        action_index : {},
    };
}

function gmsa_profile_add_input(_profile, _input) {
    __gmsa_profile_assert_editable(_profile);
    array_push(_profile.inputs, _input);
    return _input;
}

function gmsa_profile_set_features(_profile, _names) {
    __gmsa_profile_assert_editable(_profile);
    _profile.model_inputs = _names;
}

function gmsa_profile_add_action(_profile, _name, _params = {}) {
    __gmsa_profile_assert_editable(_profile);
    if (!is_string(_name) || _name == "") throw "GMSA: action name must be a non-empty string";
    var _action = {
        name           : _name,
        weight         : __gmsa_param(_params, "weight", 1),
        cooldown       : __gmsa_param(_params, "cooldown", 0),
        targets        : __gmsa_param(_params, "targets", undefined),
        considerations : [],
        index          : -1,
        locked         : false,
    };
    array_push(_profile.actions, _action);
    return _action;
}

function gmsa_action_add_consideration(_action, _input_name, _curve) {
    if (_action.locked) throw "GMSA: action '" + _action.name + "' belongs to a built profile";
    array_push(_action.considerations, { input : _input_name, curve : _curve, input_index : -1 });
    return _action;
}

function gmsa_profile_build(_profile) {
    __gmsa_profile_assert_editable(_profile);
    var _pname = "GMSA: profile '" + string(_profile.name) + "'";
    var _input_count  = array_length(_profile.inputs);
    var _action_count = array_length(_profile.actions);

    if (_action_count == 0) throw _pname + " has no actions";
    if (_profile.select != gmsa_select.BEST && _profile.select != gmsa_select.TOP_N_WEIGHTED) throw _pname + " has an unknown select policy";
    if (!is_numeric(_profile.top_n) || _profile.top_n < 1) throw _pname + " top_n must be at least 1";
    if (!is_numeric(_profile.commitment) || _profile.commitment < 0) throw _pname + " commitment must be 0 or more";
    if (!is_numeric(_profile.influence) || _profile.influence < 0 || _profile.influence > 1) throw _pname + " influence must be between 0 and 1";

    var _input_index = {};
    for (var _i = 0; _i < _input_count; _i++) {
        var _input_name = _profile.inputs[_i].name;
        if (variable_struct_exists(_input_index, _input_name)) throw _pname + " has duplicate input '" + _input_name + "'";
        _input_index[$ _input_name] = _i;
    }
	
    var _features = _profile.model_inputs;
    if (_features == undefined && _profile.model != undefined) {
        _features = [];
        for (var _i = 0; _i < _input_count; _i++) array_push(_features, _profile.inputs[_i].name);
    }
    var _feature_index = undefined;
    if (_features != undefined) {
        if (!is_array(_features) || array_length(_features) == 0) throw _pname + " features must be a non-empty array of input names";
        _feature_index = array_create(array_length(_features), 0);
        var _seen = {};
        for (var _f = 0; _f < array_length(_features); _f++) {
            var _fname = _features[_f];
            if (!is_string(_fname) || !variable_struct_exists(_input_index, _fname)) throw _pname + " has unknown feature '" + string(_fname) + "'";
            if (variable_struct_exists(_seen, _fname)) throw _pname + " has duplicate feature '" + _fname + "'";
            _seen[$ _fname] = true;
            _feature_index[_f] = _input_index[$ _fname];
        }
    }

    var _action_index = {};
    for (var _a = 0; _a < _action_count; _a++) {
        var _action = _profile.actions[_a];
        var _aname  = _pname + " action '" + _action.name + "'";
        if (variable_struct_exists(_action_index, _action.name)) throw _pname + " has duplicate action '" + _action.name + "'";
        _action_index[$ _action.name] = _a;

        if (!is_numeric(_action.weight) || _action.weight < 0) throw _aname + " weight must be 0 or more";
        if (!is_numeric(_action.cooldown) || _action.cooldown < 0) throw _aname + " cooldown must be 0 or more";
        if (_action.targets != undefined && !is_callable(_action.targets)) throw _aname + " targets must be callable";

        var _cons = _action.considerations;
        for (var _c = 0; _c < array_length(_cons); _c++) {
            var _in = _cons[_c].input;
            if (!is_string(_in) || !variable_struct_exists(_input_index, _in)) throw _aname + " uses unknown input '" + string(_in) + "'";
            if (!is_struct(_cons[_c].curve)) throw _aname + " consideration '" + _in + "' needs a curve from gmsa_curve_make";
            if (_profile.inputs[_input_index[$ _in]].per_target && _action.targets == undefined) {
                throw _aname + " uses per-target input '" + _in + "' but has no targets callback";
            }
        }
    }

    // everything is valid, resolve and lock
    for (var _a = 0; _a < _action_count; _a++) {
        var _action = _profile.actions[_a];
        _action.index  = _a;
        _action.locked = true;
        var _cons = _action.considerations;
        for (var _c = 0; _c < array_length(_cons); _c++) {
            _cons[_c].input_index = _input_index[$ _cons[_c].input];
        }
    }
    _profile.input_index  = _input_index;
    _profile.action_index = _action_index;
    _profile.built        = true;
    _profile.features     = _feature_index;
    return _profile;
}

function gmsa_profile_input_index(_profile, _name) {
    return variable_struct_exists(_profile.input_index, _name) ? _profile.input_index[$ _name] : -1;
}

function gmsa_profile_action_index(_profile, _name) {
    return variable_struct_exists(_profile.action_index, _name) ? _profile.action_index[$ _name] : -1;
}

function __gmsa_profile_assert_editable(_profile) {
    if (_profile.built) throw "GMSA: profile '" + string(_profile.name) + "' is built and can't be changed";
}

// Agents
function gmsa_agent_create(_profile, _owner = undefined, _params = {}) {
    if (!is_struct(_profile) || !_profile.built) throw "GMSA: agent needs a built profile";
    var _on_decide = __gmsa_param(_params, "on_decide", undefined);
    if (_on_decide != undefined && !is_callable(_on_decide)) throw "GMSA: on_decide must be callable";

    var _input_count = array_length(_profile.inputs);
    var _push = array_create(_input_count, 0);
    for (var _i = 0; _i < _input_count; _i++) _push[_i] = _profile.inputs[_i].default_value;

    var _agent = {
        profile    : _profile,
        owner      : _owner,
        priority   : __gmsa_param(_params, "priority", 0),
        interval   : __gmsa_param(_params, "interval", 0),
        on_decide  : _on_decide,
        push       : _push,
        cooldowns  : array_create(array_length(_profile.actions), 0),  // time each action is ready again
        current    : undefined,
        last_think : undefined,
        rng        : undefined,  // set by the scheduler, falls back to the default generator
        model      : undefined,  // reserved for Learn
        influence  : 0,          // used with the agent's own model
        decision   : undefined,
        __cache    : __gmsa_cache_create(_input_count, array_length(_profile.actions)),  // per-think input cache and option pool
        __scheduler: undefined,  // { scheduler, tier }, set by gmsa_scheduler_add
        __eval      : undefined, // evaluation struct and its own option pool, created on first evaluate
        __track     : undefined, // outcome tracking hook, set by Learn's gmsa_learn_track
    };
    _agent.decision = {
        agent   : _agent,
        chooser : gmsa_chooser.AGENT,
        time    : 0,
        options : [],
        chosen  : -1,
        fresh   : false,
    };
    return _agent;
}

function gmsa_agent_set_input(_agent, _input, _value) {
    var _profile = _agent.profile;
    var _idx = __gmsa_resolve_index(_profile.input_index, _input, array_length(_profile.inputs), "input");
    if (_profile.inputs[_idx].source != gmsa_source.PUSH) throw "GMSA: input '" + _profile.inputs[_idx].name + "' is a pull input and can't be set";
    _agent.push[_idx] = _value;
}

function gmsa_agent_set_current(_agent, _action, _target = undefined) {
    var _profile = _agent.profile;
    var _idx = __gmsa_resolve_index(_profile.action_index, _action, array_length(_profile.actions), "action");
    if (_agent.current == undefined) _agent.current = { action : _idx, target : _target };
    else {
        _agent.current.action = _idx;
        _agent.current.target = _target;
    }
}

function gmsa_agent_clear_current(_agent) {
    _agent.current = undefined;
    if (_agent.__track != undefined) _agent.__track(undefined, false);
}

function gmsa_agent_consume(_agent) {
    var _decision = _agent.decision;
    if (!_decision.fresh) return undefined;
    _decision.fresh = false;
    return _decision;
}

// Random generator (xorshift32)
function gmsa_rng_create(_seed = 1) {
    var _rng = { state : 0 };
    gmsa_rng_seed(_rng, _seed);
    return _rng;
}

function gmsa_rng_seed(_rng, _seed) {
    var _s = int64(floor(abs(_seed))) & $FFFFFFFF;
    if (_s == 0) _s = $9E3779B9; // xorshift gets stuck at 0
    _rng.state = _s;
}

function gmsa_rng_next(_rng) { // returns a value in [0, 1)
    var _s = _rng.state;
    _s ^= (_s << 13) & $FFFFFFFF;
    _s ^= _s >> 17;
    _s ^= (_s << 5) & $FFFFFFFF;
    _rng.state = _s;
    return _s / 4294967296;
}

function __gmsa_default_rng() {
    static _rng = gmsa_rng_create(1);
    return _rng;
}

// Helpers
function __gmsa_param(_params, _name, _default) {
    if (is_struct(_params) && variable_struct_exists(_params, _name)) return _params[$ _name];
    return _default;
}

function __gmsa_callable(_fn) {
    return is_method(_fn) || is_callable(_fn);
}

function __gmsa_resolve_index(_map, _key, _count, _kind) {
    if (is_string(_key)) {
        if (!variable_struct_exists(_map, _key)) throw "GMSA: unknown " + _kind + " '" + _key + "'";
        return _map[$ _key];
    }
    if (is_numeric(_key) && frac(_key) == 0 && _key >= 0 && _key < _count) return _key;
    throw "GMSA: invalid " + _kind + " " + string(_key);
}

function gmsa_agent_set_current_option(_agent, _option) {
    if (_option == undefined) {
        gmsa_agent_clear_current(_agent);
        return;
    }
    var _actions = _agent.profile.actions;
    var _idx = _option.action.index;
    if (_idx < 0 || _idx >= array_length(_actions) || _actions[_idx] != _option.action) {
        throw "GMSA: option '" + string(_option.action.name) + "' belongs to another profile";
    }
    var _cur = _agent.current;
    var _same = (_cur != undefined && _cur.action == _idx && _cur.target == _option.target);
    gmsa_agent_set_current(_agent, _idx, _option.target);
    if (_agent.__track != undefined) _agent.__track(_option, _same);
}