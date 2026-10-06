function gmsa_plan_explain(_planner) {
    __gmsa_plan_check_planner(_planner);
    var _p = _planner;
    if (_p.goal == undefined || _p.status == gmsa_plan_status.IDLE) return "no plan running";
    var _text = _p.goal + " (" + __gmsa_plan_status_text(_p) + ")";
    if (_p.__run_count == 0) return _text + "\n" + __gmsa_plan_explain_failure(_p);
    var _steps = _p.domain.steps;
    var _depth = 0;
    for (var _i = 0; _i < _p.__run_count; _i++) {
        var _kind = _p.__run_kind[_i];
        if (_kind == 2) {
            _depth -= 1;
            continue;
        }
        var _indent = string_repeat("  ", _depth);
        if (_kind == 0) {
            var _line = _steps[_p.__run_index[_i]].name;
            if (_i < _p.at) _line += ", done";
            var _slot = (_i == _p.at && _p.status == gmsa_plan_status.RUNNING) ? "> " : "  ";
            _text += "\n" + _indent + _slot + _line;
            continue;
        }
        _text += "\n" + _indent + "  " + __gmsa_plan_explain_task(_p, _i, _indent + "    ");
        _depth += 1;
    }
    return _text;
}

// Internal
function __gmsa_plan_status_text(_p) {
    switch (_p.status) {
        case gmsa_plan_status.RUNNING: return "running, step " + string(gmsa_plan_position(_p) + 1) + " of " + string(_p.__run_steps);
        case gmsa_plan_status.DONE: return "done";
        case gmsa_plan_status.FAILED:
            if (_p.result == gmsa_plan_result.OUT_OF_BUDGET) return "failed, ran out of budget after " + string(_p.nodes) + " nodes";
            if (_p.failures > _p.retries) return "failed, too many failed steps";
            return "failed, no plan";
    }
    return "idle";
}

function __gmsa_plan_explain_task(_p, _i, _pad) {
    var _task = _p.domain.tasks[_p.__run_index[_i]];
    var _tr = _p.__plan_trace;
    var _o = _p.__run_aux[_i];
    var _count = _tr[_o];
    var _pick = _tr[_o + 1];
    var _line = _task.name + ": " + _task.methods[_p.__run_method[_i]].name;
    if (__gmsa_plan_task_scored(_task)) _line += " (score " + string_format(_tr[_o + 3 + _pick * 2], 0, 2) + ")";

    var _facts = _o + 2 + _count * 2;
    for (var _f = 0; _f < array_length(_p.state); _f++) _p.state[_f] = _tr[_facts + _f];
    for (var _k = 0; _k < _pick; _k++) {
        var _m = _task.methods[_tr[_o + 2 + _k * 2]];
        _line += "\n" + _pad + _m.name + " skipped: " + __gmsa_plan_why_method(_p, _m);
    }
    for (var _m = 0; _m < array_length(_task.methods); _m++) {
        var _listed = false;
        for (var _k = 0; _k < _count; _k++) {
            if (_tr[_o + 2 + _k * 2] == _m) {
                _listed = true;
                break;
            }
        }
        if (!_listed) _line += "\n" + _pad + _task.methods[_m].name + " ruled out by its score";
    }
    return _line;
}

function __gmsa_plan_explain_failure(_p) {
    var _d = _p.domain;
    var _root = _d.lookup[$ _p.goal];
    for (var _f = 0; _f < array_length(_p.state); _f++) _p.state[_f] = _p.__real[_f];
    var _text;
    if (_root.kind == 0) {
        var _step = _d.steps[_root.index];
        var _why = __gmsa_plan_why(_p, _step.requires, _step.check);
        _text = _step.name + ((_why == undefined) ? " can be done, but has no target" : " can't be done: " + _why);
    } else {
        var _task = _d.tasks[_root.index];
        _text = _task.name + " has no method that works";
        for (var _m = 0; _m < array_length(_task.methods); _m++) {
            var _md = _task.methods[_m];
            var _reason;
            if (_md.score != undefined && !(_md.score(_p.owner, _p.state) * 1000000000000 > 0)) _reason = "ruled out by its score";
            else _reason = __gmsa_plan_why_method(_p, _md);
            _text += "\n  " + _md.name + ": " + _reason;
        }
    }
    if (_p.depth_cut) _text += "\nthe depth cap cut some branches";
    return _text;
}

function __gmsa_plan_task_scored(_task) {
    for (var _m = 0; _m < array_length(_task.methods); _m++) if (_task.methods[_m].score != undefined) return true;
    return false;
}

function __gmsa_plan_why_method(_p, _method) {
    var _why = __gmsa_plan_why(_p, _method.requires, _method.check);
    if (_why != undefined) return _why;
    var _d = _p.domain;
    var _result = "the rest of the plan didn't work with it";
    _p.undo_count = 0;
    for (var _k = 0; _k < array_length(_method.subtasks); _k++) {
        var _sub = _method.subtasks[_k];
        if (_sub.kind == 1) {
            _result = _d.tasks[_sub.index].name + " didn't work out";
            break;
        }
        var _step = _d.steps[_sub.index];
        var _w = __gmsa_plan_why(_p, _step.requires, _step.check);
        if (_w != undefined) {
            _result = _step.name + ": " + _w;
            break;
        }
        __gmsa_plan_apply(_p, _step.effects);
    }
    __gmsa_plan_undo(_p, 0);
    return _result;
}

function __gmsa_plan_why(_p, _cond, _check) {
    for (var _i = 0; _i < _cond.count; _i++) {
        var _f = _cond.fact[_i];
        var _a = _p.state[_f];
        var _b = _cond.value[_i];
        var _ok = true;
        var _need = "";
        switch (_cond.op[_i]) {
            case gmsa_plan_op.EQ: _ok = (_a == _b); break;
            case gmsa_plan_op.NE: _ok = (_a != _b); _need = "anything but "; break;
            case gmsa_plan_op.LT: _ok = (_a < _b);  _need = "less than "; break;
            case gmsa_plan_op.LE: _ok = (_a <= _b); _need = "at most "; break;
            case gmsa_plan_op.GT: _ok = (_a > _b);  _need = "more than "; break;
            case gmsa_plan_op.GE: _ok = (_a >= _b); _need = "at least "; break;
        }
        if (!_ok) {
            return _p.domain.facts[_f].name + " is " + __gmsa_plan_value_text(_p, _f, _a)
                + ", needs " + _need + __gmsa_plan_value_text(_p, _f, _b);
        }
    }
    if (_check != undefined && !_check(_p.state)) return "its check failed";
    return undefined;
}

function __gmsa_plan_value_text(_p, _f, _v) {
    if (_p.__fact_bool[_f]) return (_v != 0) ? "true" : "false";
    return string(_v);
}