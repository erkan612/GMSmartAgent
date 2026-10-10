/* GMSA Kit; planning
*  a domain from one struct, its steps carrying their own
*  code like actions do, and actions that run a plan:
*  an action with plan : "name" on an agent with a domain.
*/

function gmsa_kit_domain(_name, _def = undefined) { // a domain from one struct, built the first time and the same domain every time after. def: { facts, steps, tasks, goals, prepare }
    var _store = __gmsa_kit_domains();
    if (!is_string(_name) || _name == "") throw "GMSA: a Kit domain needs a name";
    var _have = _store[$ _name];
    if (_have != undefined) return _have;
    if (!is_struct(_def)) throw "GMSA: Kit domain '" + _name + "' needs its definition the first time it's asked for";
    var _where = "Kit domain '" + _name + "'";
    __gmsa_kit_check_keys(_def, ["facts", "steps", "tasks", "goals", "prepare"], _where);
    var _d = gmsa_plan_domain_create(_name);

    var _facts = __gmsa_kit_def_struct(_def, "facts", _where);
    var _fn = __gmsa_kit_sorted_names(_facts);
    for (var _i = 0; _i < array_length(_fn); _i++) {
        var _f = _facts[$ _fn[_i]];
        var _fw = _where + " fact '" + _fn[_i] + "'";
        if (__gmsa_kit_is_function(_f)) {
            gmsa_plan_add_fact(_d, _fn[_i], _f);
        } else if (is_struct(_f)) {
            __gmsa_kit_check_keys(_f, ["read", "min", "max"], _fw);
            if (!__gmsa_kit_is_function(_f[$ "read"])) throw "GMSA: " + _fw + " read must be a function (owner)";
            gmsa_plan_add_fact(_d, _fn[_i], _f.read, __gmsa_kit_defined(_f, ["min", "max"]));
        } else {
            throw "GMSA: " + _fw + " must be a function (owner), or { read, min, max }";
        }
    }

    var _steps = __gmsa_kit_def_struct(_def, "steps", _where);
    var _sn = __gmsa_kit_sorted_names(_steps);
    if (array_length(_sn) == 0) throw "GMSA: " + _where + " needs at least one step";
    var _handlers = {};
    for (var _i = 0; _i < array_length(_sn); _i++) {
        var _s = _steps[$ _sn[_i]];
        var _sw = _where + " step '" + _sn[_i] + "'";
        if (!is_struct(_s)) throw "GMSA: " + _sw + " must be a struct, {} for one with nothing to set";
        __gmsa_kit_check_keys(_s, ["requires", "effects", "check", "targets", "score", "cost", "start", "step", "stop"], _sw);
        var _params = __gmsa_kit_defined(_s, ["check", "targets", "score", "cost"]);
        _params.requires = __gmsa_kit_conditions(_s[$ "requires"], _sw + " requires");
        _params.effects = __gmsa_kit_conditions(_s[$ "effects"], _sw + " effects");
        gmsa_plan_add_step(_d, _sn[_i], _params);
        var _h = { start : _s[$ "start"], step : _s[$ "step"], stop : _s[$ "stop"], plan : undefined };
        if (_h.start != undefined && !__gmsa_kit_is_function(_h.start)) throw "GMSA: " + _sw + " start must be a function";
        if (_h.step != undefined && !__gmsa_kit_is_function(_h.step)) throw "GMSA: " + _sw + " step must be a function";
        if (_h.stop != undefined && !__gmsa_kit_is_function(_h.stop)) throw "GMSA: " + _sw + " stop must be a function";
        _handlers[$ _sn[_i]] = _h;
    }

    var _tasks = __gmsa_kit_def_struct(_def, "tasks", _where);
    var _tn = __gmsa_kit_sorted_names(_tasks);
    var _made = {};
    for (var _i = 0; _i < array_length(_tn); _i++) {
        var _t = _tasks[$ _tn[_i]];
        var _tw = _where + " task '" + _tn[_i] + "'";
        var _methods = _t;
        var _tparams = {};
        if (is_struct(_t)) {
            __gmsa_kit_check_keys(_t, ["methods", "select", "top_n"], _tw);
            _methods = _t[$ "methods"];
            _tparams = __gmsa_kit_defined(_t, ["select", "top_n"]);
        }
        if (!is_array(_methods) || array_length(_methods) == 0) throw "GMSA: " + _tw + " must be an array of methods, tried in order, or { methods, select, top_n }";
        var _task = gmsa_plan_add_task(_d, _tn[_i], _tparams);
        for (var _m = 0; _m < array_length(_methods); _m++) {
            var _md = _methods[_m];
            var _mw = _tw + " method " + string(_m);
            if (!is_struct(_md)) throw "GMSA: " + _mw + " must be a struct { name, requires, subtasks }";
            __gmsa_kit_check_keys(_md, ["name", "requires", "subtasks", "check", "score"], _mw);
            if (!is_string(_md[$ "name"]) || _md.name == "") throw "GMSA: " + _mw + " needs a name";
            var _subs = _md[$ "subtasks"];
            if (is_string(_subs)) _subs = [_subs];
            if (!is_array(_subs)) throw "GMSA: " + _tw + " method '" + _md.name + "' subtasks must be a name or an array of step, task and goal names";
            var _mparams = __gmsa_kit_defined(_md, ["check", "score"]);
            _mparams.subtasks = _subs;
            _mparams.requires = __gmsa_kit_conditions(_md[$ "requires"], _tw + " method '" + _md.name + "' requires");
            gmsa_plan_add_method(_task, _md.name, _mparams);
        }
        _made[$ _tn[_i]] = _task;
    }

    var _goals = __gmsa_kit_def_struct(_def, "goals", _where);
    var _gn = __gmsa_kit_sorted_names(_goals);
    for (var _i = 0; _i < array_length(_gn); _i++) {
        var _g = _goals[$ _gn[_i]];
        var _gw = _where + " goal '" + _gn[_i] + "'";
        if (!is_struct(_g)) throw "GMSA: " + _gw + " must be a struct { want, actions, variety }";
        __gmsa_kit_check_keys(_g, ["want", "actions", "variety", "prune"], _gw);
        var _gparams = __gmsa_kit_defined(_g, ["actions", "variety", "prune"]);
        _gparams.conditions = __gmsa_kit_conditions(_g[$ "want"], _gw + " want");
        gmsa_plan_add_goal(_d, _gn[_i], _gparams);
    }

    var _prepare = _def[$ "prepare"];
    if (_prepare != undefined) {
        if (!__gmsa_kit_is_function(_prepare)) throw "GMSA: " + _where + " prepare must be a function (domain, tasks)";
        _prepare(_d, _made);
    }
    gmsa_plan_domain_build(_d);
    _d.kit = { handlers : _handlers };
    _store[$ _name] = _d;
    return _d;
}

function gmsa_kit_domain_forget(_name) { // forgets a Kit domain, so the next gmsa_kit_domain with its name builds it again
    var _store = __gmsa_kit_domains();
    if (variable_struct_exists(_store, _name)) variable_struct_remove(_store, _name);
}

function gmsa_kit_agent_plan_step(_agent) { // the step its plan is on, "" when it isn't running one
    var _kit = __gmsa_kit_state(_agent);
    if (_kit.action == undefined || _kit.handler.plan == undefined) return "";
    var _step = gmsa_plan_current(_kit.planner);
    return (_step == undefined) ? "" : _step;
}

function gmsa_kit_agent_planner(_agent) { // its planner, for gmsa_plan_lines, gmsa_plan_explain and every other plain plan call. undefined without a domain
    return __gmsa_kit_state(_agent).planner;
}

// Internal
function __gmsa_kit_domains() {
    static _store = {};
    return _store;
}

function __gmsa_kit_def_struct(_def, _key, _where) {
    var _v = _def[$ _key];
    if (_v == undefined) return {};
    if (!is_struct(_v)) throw "GMSA: " + _where + " " + _key + " must be a struct of name : definition";
    return _v;
}

function __gmsa_kit_sorted_names(_struct) {
    var _names = variable_struct_get_names(_struct);
    array_sort(_names, true);
    return _names;
}

function __gmsa_kit_defined(_from, _keys) {
    var _out = {};
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _v = _from[$ _keys[_i]];
        if (_v != undefined) _out[$ _keys[_i]] = _v;
    }
    return _out;
}

function __gmsa_kit_conditions(_v, _where) {
    if (_v == undefined) return [];
    if (is_array(_v)) return _v;
    if (!is_struct(_v)) throw "GMSA: " + _where + " must be a struct of fact : value, or [[fact, value], ...]";
    var _names = __gmsa_kit_sorted_names(_v);
    var _out = array_create(array_length(_names), undefined);
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _x = _v[$ _names[_i]];
        if (is_array(_x)) {
            if (array_length(_x) != 2) throw "GMSA: " + _where + " '" + _names[_i] + "' must be a value, or [operator, value]";
            _out[_i] = [_names[_i], _x[0], _x[1]];
        } else {
            _out[_i] = [_names[_i], _x];
        }
    }
    return _out;
}

function __gmsa_kit_plan_setup(_agent, _params, _where) {
    var _kit = _agent.kit;
    var _domain = _params[$ "domain"];
    var _names = __gmsa_kit_sorted_names(_kit.handlers);
    var _planned = [];
    for (var _i = 0; _i < array_length(_names); _i++) if (_kit.handlers[$ _names[_i]].plan != undefined) array_push(_planned, _names[_i]);
    if (_domain == undefined) {
        if (variable_struct_exists(_params, "planner")) throw "GMSA: " + _where + " has planner settings but no domain";
        if (array_length(_planned) > 0) throw "GMSA: " + _where + " action '" + _planned[0] + "' runs a plan, so the agent needs a domain";
        return;
    }
    if (!_kit.thinks) throw "GMSA: " + _where + " doesn't think, so it runs no plans and needs no domain";
    if (!is_struct(_domain) || _domain[$ "lookup"] == undefined || _domain[$ "built"] != true) throw "GMSA: " + _where + " domain must be built, from gmsa_kit_domain or gmsa_plan_domain_build";
    for (var _i = 0; _i < array_length(_planned); _i++) {
        var _plan = _kit.handlers[$ _planned[_i]].plan;
        if (!variable_struct_exists(_domain.lookup, _plan)) throw "GMSA: " + _where + " action '" + _planned[_i] + "' runs '" + _plan + "', which domain '" + _domain.name + "' doesn't have";
    }
    var _settings = _params[$ "planner"];
    if (_settings == undefined) _settings = {};
    if (!is_struct(_settings)) throw "GMSA: " + _where + " planner must be a struct of planner settings";
    _kit.planner = gmsa_plan_planner_create(_domain, _agent.owner, _settings);
    var _dk = _domain[$ "kit"];
    _kit.phandlers = is_struct(_dk) ? _dk.handlers : {};
    if (_kit.scheduler != undefined) gmsa_plan_schedule(_kit.planner, _kit.scheduler, _agent.priority);
}

function __gmsa_kit_plan_update(_agent, _kit) {
    var _p = _kit.planner;
    if (gmsa_plan_get_status(_p) == gmsa_plan_status.PLANNING && _kit.scheduler == undefined) gmsa_plan_work(_p);
    if (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING) {
        var _serial = _kit.serial;
        __gmsa_kit_plan_run(_agent, _kit, _p);
        if (_kit.serial != _serial) return;
    }
    var _status = gmsa_plan_get_status(_p);
    if (_status == gmsa_plan_status.RUNNING || _status == gmsa_plan_status.PLANNING) return;
    __gmsa_kit_finish(_agent, _kit, (_status == gmsa_plan_status.DONE) ? gmsa_kit_step.DONE : gmsa_kit_step.FAILED);
}

function __gmsa_kit_plan_run(_agent, _kit, _p) {
    var _name = gmsa_plan_current(_p);
    var _target = gmsa_plan_target(_p);
    if (_kit.pstep != _name || _kit.ptarget != _target) {
        __gmsa_kit_plan_step_end(_agent, _kit);
        var _h = _kit.phandlers[$ _name];
        _kit.pstep = _name;
        _kit.ptarget = _target;
        _kit.phandler = (_h != undefined) ? _h : __gmsa_kit_no_handler();
        _kit.pinstance = __gmsa_kit_is_instance(_target);
        if (_kit.phandler.start != undefined) {
            var _serial = _kit.serial;
            _kit.phandler.start(_agent.owner, _target, _agent);
            if (_kit.serial != _serial || _kit.pstep != _name) return;
        }
    }
    var _r = gmsa_kit_step.DONE;
    if (_kit.pinstance && !instance_exists(_kit.ptarget)) {
        _r = gmsa_kit_step.FAILED;
    } else if (_kit.phandler.step != undefined) {
        var _serial = _kit.serial;
        _r = _kit.phandler.step(_agent.owner, _kit.ptarget, _agent);
        if (_kit.serial != _serial || _kit.pstep != _name) return;
        _r = __gmsa_kit_step_result(_r, "plan step '" + _name + "'");
    }
    if (_r == gmsa_kit_step.RUNNING) return;
    __gmsa_kit_plan_step_end(_agent, _kit);
    if (_r == gmsa_kit_step.FAILED) gmsa_plan_step_failed(_p);
    else gmsa_plan_step_done(_p);
}

function __gmsa_kit_plan_step_end(_agent, _kit) {
    if (_kit.pstep == undefined) return;
    var _stop = _kit.phandler.stop;
    var _target = _kit.ptarget;
    _kit.pstep = undefined;
    _kit.ptarget = undefined;
    _kit.phandler = undefined;
    _kit.pinstance = false;
    if (_stop != undefined) _stop(_agent.owner, _target, _agent);
}

function __gmsa_kit_plan_halt(_agent, _kit) {
    __gmsa_kit_plan_step_end(_agent, _kit);
    var _status = gmsa_plan_get_status(_kit.planner);
    if (_status == gmsa_plan_status.RUNNING || _status == gmsa_plan_status.PLANNING) gmsa_plan_stop(_kit.planner);
}