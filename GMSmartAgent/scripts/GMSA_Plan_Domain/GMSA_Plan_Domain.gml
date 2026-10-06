enum gmsa_plan_op { EQ, NE, LT, LE, GT, GE, SET, ADD, SUB }

function gmsa_plan_domain_create(_name) {
    if (!is_string(_name) || _name == "") throw "GMSA: plan domain needs a name";
    return { name : _name, facts : [], steps : [], tasks : [], goals : [], built : false, fact_lookup : {}, lookup : {}, listeners : [], step_chance : undefined };
}

function gmsa_plan_add_fact(_domain, _name, _read, _params = {}) {
    __gmsa_plan_check_open(_domain);
    if (!is_string(_name) || _name == "") throw "GMSA: plan fact needs a name";
    if (!__gmsa_callable(_read)) throw "GMSA: plan fact '" + _name + "' needs a read function";
    var _min = __gmsa_param(_params, "min", undefined);
    var _max = __gmsa_param(_params, "max", undefined);
    if ((_min == undefined) != (_max == undefined)) throw "GMSA: plan fact '" + _name + "' needs both min and max, or neither";
    if (_min != undefined && (!is_numeric(_min) || !is_numeric(_max) || !(_max > _min))) {
        throw "GMSA: plan fact '" + _name + "' range needs numbers with max above min";
    }
    array_push(_domain.facts, { name : _name, read : _read, min : _min, max : _max });
    return _domain;
}

function gmsa_plan_add_step(_domain, _name, _params = {}) {
    __gmsa_plan_check_open(_domain);
    if (!is_string(_name) || _name == "") throw "GMSA: plan step needs a name";
    var _step = {
        name     : _name,
        requires : __gmsa_param(_params, "requires", []),
        effects  : __gmsa_param(_params, "effects", []),
        check    : __gmsa_param(_params, "check", undefined),    // function(state), for conditions data can't express
        targets  : __gmsa_param(_params, "targets", undefined),  // function(owner), the game's candidates
        score    : __gmsa_param(_params, "score", undefined),    // function(owner, target), picks among them
        cost     : __gmsa_param(_params, "cost", 1),             // a number above 0 or function(owner, state), used when a goal searches
    };
    array_push(_domain.steps, _step);
    return _step;
}

function gmsa_plan_add_task(_domain, _name, _params = {}) {
    __gmsa_plan_check_open(_domain);
    if (!is_string(_name) || _name == "") throw "GMSA: plan task needs a name";
    var _select = __gmsa_param(_params, "select", gmsa_select.BEST);
    var _top_n = __gmsa_param(_params, "top_n", 3);
    if (_select != gmsa_select.BEST && _select != gmsa_select.TOP_N_WEIGHTED) {
        throw "GMSA: plan task '" + _name + "' select must be gmsa_select.BEST or gmsa_select.TOP_N_WEIGHTED";
    }
    if (!is_numeric(_top_n) || _top_n < 1) throw "GMSA: plan task '" + _name + "' top_n must be at least 1";
    var _adjust = __gmsa_param(_params, "adjust", undefined);
    if (_adjust != undefined && !__gmsa_callable(_adjust)) throw "GMSA: plan task '" + _name + "' adjust must be callable";
    var _task = { name : _name, domain : _domain, methods : [], select : _select, top_n : floor(_top_n), adjust : _adjust };
    array_push(_domain.tasks, _task);
    return _task;
}

function gmsa_plan_add_method(_task, _name, _params) {
    if (!is_struct(_task) || _task[$ "methods"] == undefined) throw "GMSA: plan method needs a task from gmsa_plan_add_task";
    __gmsa_plan_check_open(_task.domain);
    if (!is_string(_name) || _name == "") throw "GMSA: plan method needs a name";
    var _method = {
        name     : _name,
        subtasks : __gmsa_param(_params, "subtasks", []),
        requires : __gmsa_param(_params, "requires", []),
        check    : __gmsa_param(_params, "check", undefined),   // function(state)
        score    : __gmsa_param(_params, "score", undefined),   // function(owner, state), methods with scores are tried best first
    };
    array_push(_task.methods, _method);
    return _method;
}

function gmsa_plan_add_goal(_domain, _name, _params = {}) {
    __gmsa_plan_check_open(_domain);
    if (!is_string(_name) || _name == "") throw "GMSA: plan goal needs a name";
    var _goal = {
        name       : _name,
        conditions : __gmsa_param(_params, "conditions", []),
        actions    : __gmsa_param(_params, "actions", undefined), // names of the steps the search may use, every step when undefined
        variety    : __gmsa_param(_params, "variety", 0),         // each search multiplies action costs by 1 to 1 + variety
        prune      : __gmsa_param(_params, "prune", true),        // leave out steps that can't help reach the conditions
    };
    array_push(_domain.goals, _goal);
    return _goal;
}

function gmsa_plan_domain_build(_domain) {
    __gmsa_plan_check_open(_domain);
    var _where = "domain '" + _domain.name + "'";
    if (array_length(_domain.steps) == 0) throw "GMSA: plan " + _where + " has no steps";

    var _facts = {};
    for (var _i = 0; _i < array_length(_domain.facts); _i++) {
        var _fname = _domain.facts[_i].name;
        if (variable_struct_exists(_facts, _fname)) throw "GMSA: plan " + _where + " has two facts named '" + _fname + "'";
        _facts[$ _fname] = _i;
    }
    // one namespace: kind 0 a step, 1 a task, 3 a goal (2 is the end of a task in the planner's to-do list)
    var _names = {};
    for (var _i = 0; _i < array_length(_domain.steps); _i++) {
        var _sname = _domain.steps[_i].name;
        if (variable_struct_exists(_names, _sname)) throw "GMSA: plan " + _where + " has two steps named '" + _sname + "'";
        _names[$ _sname] = { kind : 0, index : _i };
    }
    for (var _i = 0; _i < array_length(_domain.tasks); _i++) {
        var _tname = _domain.tasks[_i].name;
        if (variable_struct_exists(_names, _tname)) throw "GMSA: plan " + _where + " uses the name '" + _tname + "' twice";
        _names[$ _tname] = { kind : 1, index : _i };
    }
    for (var _i = 0; _i < array_length(_domain.goals); _i++) {
        var _gname = _domain.goals[_i].name;
        if (variable_struct_exists(_names, _gname)) throw "GMSA: plan " + _where + " uses the name '" + _gname + "' twice";
        _names[$ _gname] = { kind : 3, index : _i };
    }

    // compile into new structures, the domain is only changed once all of it is valid
    var _steps = array_create(array_length(_domain.steps), undefined);
    for (var _i = 0; _i < array_length(_domain.steps); _i++) {
        var _s = _domain.steps[_i];
        var _at = "step '" + _s.name + "'";
        __gmsa_plan_check_callable(_s.check, _at + " check");
        __gmsa_plan_check_callable(_s.targets, _at + " targets");
        __gmsa_plan_check_callable(_s.score, _at + " score");
        var _cost = _s.cost;
        var _cost_fn = undefined;
        if (is_numeric(_cost)) {
            if (!(_cost * 1000000000000 > 0)) throw "GMSA: plan " + _at + " cost must be above 0, or a function";
        } else if (__gmsa_callable(_cost)) {
            _cost_fn = _cost;
            _cost = 1;
        } else {
            throw "GMSA: plan " + _at + " cost must be a number or a function";
        }
        _steps[_i] = {
            name : _s.name, index : _i,
            requires : __gmsa_plan_compile(_facts, _s.requires, false, _at + " requires"),
            effects  : __gmsa_plan_compile(_facts, _s.effects, true, _at + " effects"),
            check : _s.check, targets : _s.targets, score : _s.score,
            cost : _cost, cost_fn : _cost_fn, // cost_fn, when set, replaces cost
        };
    }
    var _tasks = array_create(array_length(_domain.tasks), undefined);
    for (var _i = 0; _i < array_length(_domain.tasks); _i++) {
        var _t = _domain.tasks[_i];
        if (array_length(_t.methods) == 0) throw "GMSA: plan task '" + _t.name + "' has no methods";
        var _methods = array_create(array_length(_t.methods), undefined);
        for (var _m = 0; _m < array_length(_t.methods); _m++) {
            var _md = _t.methods[_m];
            var _at = "method '" + _t.name + "." + _md.name + "'";
            __gmsa_plan_check_callable(_md.check, _at + " check");
            __gmsa_plan_check_callable(_md.score, _at + " score");
            if (!is_array(_md.subtasks)) throw "GMSA: plan " + _at + " subtasks must be an array";
            var _subs = array_create(array_length(_md.subtasks), undefined);
            for (var _k = 0; _k < array_length(_md.subtasks); _k++) {
                var _sub = _md.subtasks[_k];
                if (!is_string(_sub) || !variable_struct_exists(_names, _sub)) throw "GMSA: plan " + _at + " uses unknown step, task or goal '" + string(_sub) + "'";
                _subs[_k] = _names[$ _sub]; // { kind : 0 step, 1 task or 3 goal, index }
            }
            _methods[_m] = {
                name : _md.name, task : _i, index : _m, subtasks : _subs,
                requires : __gmsa_plan_compile(_facts, _md.requires, false, _at + " requires"),
                check : _md.check, score : _md.score,
            };
        }
        _tasks[_i] = { name : _t.name, index : _i, methods : _methods, select : _t.select, top_n : _t.top_n, adjust : _t.adjust };
    }
    var _goals = array_create(array_length(_domain.goals), undefined);
    for (var _i = 0; _i < array_length(_domain.goals); _i++) {
        var _g = _domain.goals[_i];
        var _at = "goal '" + _g.name + "'";
        var _cond = __gmsa_plan_compile(_facts, _g.conditions, false, _at + " conditions");
        if (_cond.count == 0) throw "GMSA: plan " + _at + " needs at least one condition";
        if (!is_numeric(_g.variety) || _g.variety < 0) throw "GMSA: plan " + _at + " variety must be a number of 0 or more";
        var _acts;
        if (_g.actions == undefined) {
            _acts = array_create(array_length(_steps), 0);
            for (var _k = 0; _k < array_length(_steps); _k++) _acts[_k] = _k;
        } else {
            if (!is_array(_g.actions) || array_length(_g.actions) == 0) throw "GMSA: plan " + _at + " actions must be a non-empty array of step names";
            _acts = array_create(array_length(_g.actions), 0);
            var _seen = {};
            for (var _k = 0; _k < array_length(_g.actions); _k++) {
                var _an = _g.actions[_k];
                if (!is_string(_an) || !variable_struct_exists(_names, _an) || _names[$ _an].kind != 0) throw "GMSA: plan " + _at + " action '" + string(_an) + "' isn't a step";
                if (variable_struct_exists(_seen, _an)) throw "GMSA: plan " + _at + " lists the action '" + _an + "' twice";
                _seen[$ _an] = true;
                _acts[_k] = _names[$ _an].index;
            }
        }
        if (!is_bool(_g.prune)) throw "GMSA: plan " + _at + " prune must be true or false";
        var _before = array_length(_acts);
        if (_g.prune) _acts = __gmsa_plan_relevant(_steps, _acts, _cond, array_length(_domain.facts));
        var _most = 0;
        var _cheapest = infinity;
        var _changed = array_create(_cond.count, false);
        for (var _a = 0; _a < array_length(_acts); _a++) {
            var _st = _steps[_acts[_a]];
            if (_st.cost_fn == undefined) _cheapest = min(_cheapest, _st.cost);
            var _n = 0;
            for (var _c = 0; _c < _cond.count; _c++) {
                for (var _e = 0; _e < _st.effects.count; _e++) {
                    if (_st.effects.fact[_e] != _cond.fact[_c]) continue;
                    _n += 1;
                    _changed[_c] = true;
                    break;
                }
            }
            _most = max(_most, _n);
        }
        _goals[_i] = {
            name : _g.name, index : _i, conditions : _cond, actions : _acts, variety : _g.variety, pruned : _before - array_length(_acts),
            most : max(1, _most), cheapest : (_cheapest == infinity) ? 0 : _cheapest, changed : _changed,
        };
    }

    _domain.fact_lookup = _facts;
    _domain.lookup = _names;
    _domain.steps = _steps;
    _domain.tasks = _tasks;
    _domain.goals = _goals;
    _domain.built = true;
    return _domain;
}

function gmsa_plan_fact_index(_domain, _name) {
    return variable_struct_exists(_domain.fact_lookup, _name) ? _domain.fact_lookup[$ _name] : -1;
}

function gmsa_plan_add_listener(_domain, _listener) {
    if (!is_struct(_domain) || _domain[$ "built"] == undefined) throw "GMSA: plan listener needs a domain from gmsa_plan_domain_create";
    if (!__gmsa_callable(_listener)) throw "GMSA: plan listener must be callable";
    array_push(_domain.listeners, _listener);
}

function gmsa_plan_set_step_chance(_domain, _chance) {
    if (!is_struct(_domain) || _domain[$ "built"] == undefined) throw "GMSA: plan step chance needs a domain from gmsa_plan_domain_create";
    if (_chance != undefined && !__gmsa_callable(_chance)) throw "GMSA: plan step chance must be callable";
    _domain.step_chance = _chance;
}

// Internal
function __gmsa_plan_check_open(_domain) {
    if (!is_struct(_domain) || _domain[$ "built"] == undefined) throw "GMSA: plan needs a domain from gmsa_plan_domain_create";
    if (_domain.built) throw "GMSA: plan domain '" + _domain.name + "' is built and locked";
}

function __gmsa_plan_check_callable(_fn, _what) {
    if (_fn != undefined && !__gmsa_callable(_fn)) throw "GMSA: plan " + _what + " must be callable";
}

function __gmsa_plan_compile(_facts, _list, _effects, _where) {
    if (!is_array(_list)) throw "GMSA: plan " + _where + " must be an array";
    var _n = array_length(_list);
    var _out = { count : _n, fact : array_create(_n, 0), op : array_create(_n, 0), value : array_create(_n, 0) };
    for (var _i = 0; _i < _n; _i++) {
        var _c = _list[_i];
        if (!is_array(_c) || (array_length(_c) != 2 && array_length(_c) != 3)) {
            throw "GMSA: plan " + _where + " entry " + string(_i) + " must be [fact, value] or [fact, op, value]";
        }
        var _fname = _c[0];
        if (!is_string(_fname) || !variable_struct_exists(_facts, _fname)) throw "GMSA: plan " + _where + " uses unknown fact '" + string(_fname) + "'";
        var _op = _effects ? gmsa_plan_op.SET : gmsa_plan_op.EQ;
        if (array_length(_c) == 3) _op = __gmsa_plan_parse_op(_c[1], _effects, _where);
        var _v = _c[array_length(_c) - 1];
        if (is_bool(_v)) _v = _v ? 1 : 0;
        if (!is_numeric(_v)) throw "GMSA: plan " + _where + " value for '" + _fname + "' must be a number or a bool";
        _out.fact[_i] = _facts[$ _fname];
        _out.op[_i] = _op;
        _out.value[_i] = _v;
    }
    return _out;
}

function __gmsa_plan_parse_op(_text, _effects, _where) {
    if (_effects) {
        switch (_text) {
            case "=": return gmsa_plan_op.SET;
            case "+": return gmsa_plan_op.ADD;
            case "-": return gmsa_plan_op.SUB;
        }
        throw "GMSA: plan " + _where + " effect operator must be \"=\", \"+\" or \"-\"";
    }
    switch (_text) {
        case "==": return gmsa_plan_op.EQ;
        case "!=": return gmsa_plan_op.NE;
        case "<":  return gmsa_plan_op.LT;
        case "<=": return gmsa_plan_op.LE;
        case ">":  return gmsa_plan_op.GT;
        case ">=": return gmsa_plan_op.GE;
    }
    throw "GMSA: plan " + _where + " condition operator must be \"==\", \"!=\", \"<\", \"<=\", \">\" or \">=\"";
}

function __gmsa_plan_met(_state, _cond) {
    for (var _i = 0; _i < _cond.count; _i++) {
        var _a = _state[_cond.fact[_i]];
        var _b = _cond.value[_i];
        switch (_cond.op[_i]) {
            case gmsa_plan_op.EQ: if (_a != _b) return false; break;
            case gmsa_plan_op.NE: if (_a == _b) return false; break;
            case gmsa_plan_op.LT: if (!(_a < _b)) return false; break;
            case gmsa_plan_op.LE: if (!(_a <= _b)) return false; break;
            case gmsa_plan_op.GT: if (!(_a > _b)) return false; break;
            case gmsa_plan_op.GE: if (!(_a >= _b)) return false; break;
        }
    }
    return true;
}

function __gmsa_plan_apply(_holder, _effects) {
    for (var _i = 0; _i < _effects.count; _i++) {
        var _f = _effects.fact[_i];
        var _u = _holder.undo_count;
        _holder.undo_fact[_u] = _f;
        _holder.undo_value[_u] = _holder.state[_f];
        _holder.undo_count = _u + 1;
        switch (_effects.op[_i]) {
            case gmsa_plan_op.SET: _holder.state[_f] = _effects.value[_i]; break;
            case gmsa_plan_op.ADD: _holder.state[_f] += _effects.value[_i]; break;
            case gmsa_plan_op.SUB: _holder.state[_f] -= _effects.value[_i]; break;
        }
    }
}

function __gmsa_plan_undo(_holder, _mark) {
    while (_holder.undo_count > _mark) {
        _holder.undo_count -= 1;
        var _u = _holder.undo_count;
        _holder.state[_holder.undo_fact[_u]] = _holder.undo_value[_u];
    }
}

function __gmsa_plan_read_facts(_domain, _owner, _holder) {
    var _facts = _domain.facts;
    var _bools = variable_struct_exists(_holder, "__fact_bool");
    for (var _i = 0; _i < array_length(_facts); _i++) {
        var _v = _facts[_i].read(_owner);
        var _is_bool = is_bool(_v);
        if (_is_bool) _v = _v ? 1 : 0;
        if (!is_numeric(_v)) throw "GMSA: plan fact '" + _facts[_i].name + "' must read a number or a bool";
        _holder.state[_i] = _v;
        if (_bools) _holder.__fact_bool[_i] = _is_bool;
    }
}

function __gmsa_plan_relevant(_steps, _acts, _cond, _nf) {
    var _fact = array_create(_nf, false);
    for (var _c = 0; _c < _cond.count; _c++) _fact[_cond.fact[_c]] = true;
    var _n = array_length(_acts);
    var _keep = array_create(_n, false);
    var _grew = true;
    while (_grew) {
        _grew = false;
        for (var _a = 0; _a < _n; _a++) {
            if (_keep[_a]) continue;
            var _st = _steps[_acts[_a]];
            var _helps = false;
            for (var _e = 0; _e < _st.effects.count; _e++) {
                if (_fact[_st.effects.fact[_e]]) {
                    _helps = true;
                    break;
                }
            }
            if (!_helps) continue;
            if (_st.check != undefined) return _acts;
            _keep[_a] = true;
            _grew = true;
            for (var _r = 0; _r < _st.requires.count; _r++) _fact[_st.requires.fact[_r]] = true;
        }
    }
    var _out = [];
    for (var _a = 0; _a < _n; _a++) if (_keep[_a]) array_push(_out, _acts[_a]);
    return _out;
}