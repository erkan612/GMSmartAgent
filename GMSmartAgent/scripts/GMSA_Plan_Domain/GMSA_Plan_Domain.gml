enum gmsa_plan_op { EQ, NE, LT, LE, GT, GE, SET, ADD, SUB }

function gmsa_plan_domain_create(_name) {
    if (!is_string(_name) || _name == "") throw "GMSA: plan domain needs a name";
    return { name : _name, facts : [], steps : [], tasks : [], built : false, fact_lookup : {}, lookup : {} };
}

function gmsa_plan_add_fact(_domain, _name, _read) {
    __gmsa_plan_check_open(_domain);
    if (!is_string(_name) || _name == "") throw "GMSA: plan fact needs a name";
    if (!__gmsa_callable(_read)) throw "GMSA: plan fact '" + _name + "' needs a read function";
    array_push(_domain.facts, { name : _name, read : _read });
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
    };
    array_push(_domain.steps, _step);
    return _step;
}

function gmsa_plan_add_task(_domain, _name) {
    __gmsa_plan_check_open(_domain);
    if (!is_string(_name) || _name == "") throw "GMSA: plan task needs a name";
    var _task = { name : _name, domain : _domain, methods : [] };
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

    // compile into new structures, the domain is only changed once all of it is valid
    var _steps = array_create(array_length(_domain.steps), undefined);
    for (var _i = 0; _i < array_length(_domain.steps); _i++) {
        var _s = _domain.steps[_i];
        var _at = "step '" + _s.name + "'";
        __gmsa_plan_check_callable(_s.check, _at + " check");
        __gmsa_plan_check_callable(_s.targets, _at + " targets");
        __gmsa_plan_check_callable(_s.score, _at + " score");
        _steps[_i] = {
            name : _s.name, index : _i,
            requires : __gmsa_plan_compile(_facts, _s.requires, false, _at + " requires"),
            effects  : __gmsa_plan_compile(_facts, _s.effects, true, _at + " effects"),
            check : _s.check, targets : _s.targets, score : _s.score,
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
            if (!is_array(_md.subtasks) || array_length(_md.subtasks) == 0) throw "GMSA: plan " + _at + " has no subtasks";
            var _subs = array_create(array_length(_md.subtasks), undefined);
            for (var _k = 0; _k < array_length(_md.subtasks); _k++) {
                var _sub = _md.subtasks[_k];
                if (!is_string(_sub) || !variable_struct_exists(_names, _sub)) throw "GMSA: plan " + _at + " uses unknown step or task '" + string(_sub) + "'";
                _subs[_k] = _names[$ _sub];  // { kind : 0 step or 1 task, index }
            }
            _methods[_m] = {
                name : _md.name, task : _i, index : _m, subtasks : _subs,
                requires : __gmsa_plan_compile(_facts, _md.requires, false, _at + " requires"),
                check : _md.check, score : _md.score,
            };
        }
        _tasks[_i] = { name : _t.name, index : _i, methods : _methods };
    }

    _domain.fact_lookup = _facts;
    _domain.lookup = _names;
    _domain.steps = _steps;
    _domain.tasks = _tasks;
    _domain.built = true;
    return _domain;
}

function gmsa_plan_fact_index(_domain, _name) {
    return variable_struct_exists(_domain.fact_lookup, _name) ? _domain.fact_lookup[$ _name] : -1;
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
    for (var _i = 0; _i < array_length(_facts); _i++) {
        var _v = _facts[_i].read(_owner);
        if (is_bool(_v)) _v = _v ? 1 : 0;
        if (!is_numeric(_v)) throw "GMSA: plan fact '" + _facts[_i].name + "' must read a number or a bool";
        _holder.state[_i] = _v;
    }
}