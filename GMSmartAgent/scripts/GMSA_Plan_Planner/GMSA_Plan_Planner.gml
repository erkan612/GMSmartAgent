enum gmsa_plan_result { NONE, FOUND, NO_PLAN, OUT_OF_BUDGET }
enum gmsa_plan_status { IDLE, RUNNING, DONE, FAILED }

function gmsa_plan_planner_create(_domain, _owner, _params = {}) {
    if (!is_struct(_domain) || _domain[$ "built"] == undefined) throw "GMSA: plan planner needs a domain from gmsa_plan_domain_create";
    if (!_domain.built) throw "GMSA: plan domain '" + _domain.name + "' must be built before making planners";
    var _budget = __gmsa_param(_params, "budget", 2000);
    var _depth = __gmsa_param(_params, "depth", 32);
    var _retries = __gmsa_param(_params, "retries", 3);
    if (!is_numeric(_budget) || _budget < 1) throw "GMSA: plan budget must be at least 1";
    if (!is_numeric(_depth) || _depth < 1) throw "GMSA: plan depth must be at least 1";
    if (!is_numeric(_retries) || _retries < 0) throw "GMSA: plan retries must be 0 or more";
    var _facts = array_length(_domain.facts);
    return {
        domain : _domain, owner : _owner, budget : floor(_budget), depth : floor(_depth), retries : floor(_retries),
        result : gmsa_plan_result.NONE, status : gmsa_plan_status.IDLE, goal : undefined,
        nodes : 0, depth_cut : false, target : undefined, at : 0, failures : 0,
        // imagined state and its undo log, the holder fields __gmsa_plan_apply and __gmsa_plan_undo use
        state : array_create(_facts, 0), undo_fact : [], undo_value : [], undo_count : 0,
        __real : array_create(_facts, 0),  // the facts as last read
        __base : array_create(_facts, 0),  // the state a search starts from
        // plans are entries: kind 0 a step, 1 a task begins (with its method), 2 a task ends
        __out_count : 0, __out_kind : [], __out_index : [], __out_method : [],  // search output
        __run_count : 0, __run_kind : [], __run_index : [], __run_method : [], __run_steps : 0,  // the running plan
        __spare_count : 0, __spare_kind : [], __spare_index : [], __spare_method : [],  // swapped in while repairing
        // to-do list: a linked list in a node pool, head is the next thing to do. kind 0 step, 1 task, 2 end of a task
        __head : -1, __pool : 0, __node_kind : [], __node_index : [], __node_depth : [], __node_next : [],
        // choice points, one per task being broken down
        __frames : 0, __frame_task : [], __frame_rest : [], __frame_pool : [], __frame_undo : [], __frame_out : [],
        __frame_depth : [], __frame_start : [], __frame_count : [], __frame_try : [],
        // method order per choice point, best first
        __order_top : 0, __order : [], __order_score : [],
    };
}

function gmsa_plan_make(_planner, _name) {
    __gmsa_plan_check_planner(_planner);
    var _d = _planner.domain;
    if (!is_string(_name) || !variable_struct_exists(_d.lookup, _name)) {
        throw "GMSA: plan domain '" + _d.name + "' has no step or task named '" + string(_name) + "'";
    }
    var _root = _d.lookup[$ _name];
    _planner.goal = _name;
    _planner.target = undefined;
    _planner.failures = 0;
    _planner.at = 0;
    _planner.__run_count = 0;
    _planner.__run_steps = 0;
    _planner.nodes = 0;
    __gmsa_plan_read_real(_planner);
    __gmsa_plan_base(_planner, 0);
    _planner.result = __gmsa_plan_search_from(_planner, _root.kind, _root.index, 0);
    if (_planner.result != gmsa_plan_result.FOUND) {
        _planner.status = gmsa_plan_status.FAILED;
        return false;
    }
    __gmsa_plan_splice(_planner, 0, -1);
    __gmsa_plan_settle(_planner, false, false);
    return _planner.status != gmsa_plan_status.FAILED;
}

function gmsa_plan_step_done(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return _planner.status;
    _planner.at += 1;
    _planner.failures = 0;
    __gmsa_plan_settle(_planner, false, true);
    return _planner.status;
}

function gmsa_plan_step_failed(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return _planner.status;
    __gmsa_plan_settle(_planner, true, true);
    return _planner.status;
}

function gmsa_plan_refresh(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return _planner.status;
    __gmsa_plan_read_real(_planner);
    var _bad = __gmsa_plan_broken_at(_planner, _planner.at);
    if (_bad == -1) return _planner.status;
    if (__gmsa_plan_repair(_planner, _bad)) __gmsa_plan_settle(_planner, false, false);
    else __gmsa_plan_fail(_planner);
    return _planner.status;
}

function gmsa_plan_stop(_planner) {
    __gmsa_plan_check_planner(_planner);
    _planner.status = gmsa_plan_status.IDLE;
    _planner.target = undefined;
    _planner.at = 0;
    _planner.failures = 0;
    _planner.__run_count = 0;
    _planner.__run_steps = 0;
}

function gmsa_plan_get_status(_planner) {
    __gmsa_plan_check_planner(_planner);
    return _planner.status;
}

function gmsa_plan_last_result(_planner) {
    __gmsa_plan_check_planner(_planner);
    return _planner.result;
}

function gmsa_plan_current(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return undefined;
    return _planner.domain.steps[_planner.__run_index[_planner.at]].name;
}

function gmsa_plan_target(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return undefined;
    return _planner.target;
}

function gmsa_plan_position(_planner) {
    __gmsa_plan_check_planner(_planner);
    var _n = 0;
    for (var _i = 0; _i < min(_planner.at, _planner.__run_count); _i++) if (_planner.__run_kind[_i] == 0) _n += 1;
    return _n;
}

function gmsa_plan_length(_planner) {
    __gmsa_plan_check_planner(_planner);
    return _planner.__run_steps;
}

function gmsa_plan_step_at(_planner, _index) {
    __gmsa_plan_check_planner(_planner);
    if (!is_numeric(_index) || _index < 0 || _index >= _planner.__run_steps) return undefined;
    var _n = 0;
    for (var _i = 0; _i < _planner.__run_count; _i++) {
        if (_planner.__run_kind[_i] != 0) continue;
        if (_n == _index) return _planner.domain.steps[_planner.__run_index[_i]].name;
        _n += 1;
    }
    return undefined;
}

function gmsa_plan_nodes_used(_planner) {
    __gmsa_plan_check_planner(_planner);
    return _planner.nodes;
}

// Internal: searching
function __gmsa_plan_check_planner(_p) {
    if (!is_struct(_p) || _p[$ "__frames"] == undefined) throw "GMSA: plan needs a planner from gmsa_plan_planner_create";
}

function __gmsa_plan_push_node(_p, _kind, _index, _depth, _next) {
    var _n = _p.__pool;
    _p.__node_kind[_n] = _kind;
    _p.__node_index[_n] = _index;
    _p.__node_depth[_n] = _depth;
    _p.__node_next[_n] = _next;
    _p.__pool = _n + 1;
    return _n;
}

function __gmsa_plan_out(_p, _kind, _index, _method) {
    var _i = _p.__out_count;
    _p.__out_kind[_i] = _kind;
    _p.__out_index[_i] = _index;
    _p.__out_method[_i] = _method;
    _p.__out_count = _i + 1;
}

function __gmsa_plan_search_from(_p, _kind, _index, _depth) {
    for (var _i = 0; _i < array_length(_p.__base); _i++) _p.state[_i] = _p.__base[_i];
    _p.undo_count = 0;
    _p.__out_count = 0;
    _p.__pool = 0;
    _p.__frames = 0;
    _p.__order_top = 0;
    _p.depth_cut = false;
    _p.__head = __gmsa_plan_push_node(_p, _kind, _index, _depth, -1);
    return __gmsa_plan_search(_p);
}

function __gmsa_plan_search(_p) {
    var _d = _p.domain;
    while (true) {
        var _n = _p.__head;
        if (_n == -1) return gmsa_plan_result.FOUND;
        if (_p.__node_kind[_n] == 2) {
            __gmsa_plan_out(_p, 2, _p.__node_index[_n], -1);
            _p.__head = _p.__node_next[_n];
            continue;
        }
        if (_p.nodes >= _p.budget) return gmsa_plan_result.OUT_OF_BUDGET;
        var _r;
        if (_p.__node_kind[_n] == 0) {
            _p.nodes += 1;
            var _step = _d.steps[_p.__node_index[_n]];
            if (__gmsa_plan_met(_p.state, _step.requires) && (_step.check == undefined || _step.check(_p.state))) {
                __gmsa_plan_apply(_p, _step.effects);
                __gmsa_plan_out(_p, 0, _step.index, -1);
                _p.__head = _p.__node_next[_n];
                continue;
            }
            _r = __gmsa_plan_next_choice(_p);
        } else if (_p.__node_depth[_n] >= _p.depth) {
            _p.depth_cut = true;
            _r = __gmsa_plan_next_choice(_p);
        } else {
            __gmsa_plan_push_frame(_p, _n);
            _r = __gmsa_plan_next_choice(_p);
        }
        if (_r == 0) return gmsa_plan_result.NO_PLAN;
        if (_r == 2) return gmsa_plan_result.OUT_OF_BUDGET;
    }
}

function __gmsa_plan_push_frame(_p, _n) {
    var _f = _p.__frames;
    var _task = _p.domain.tasks[_p.__node_index[_n]];
    _p.__frame_task[_f] = _task.index;
    _p.__frame_rest[_f] = _p.__node_next[_n];
    _p.__frame_pool[_f] = _p.__pool;
    _p.__frame_undo[_f] = _p.undo_count;
    _p.__frame_out[_f] = _p.__out_count;
    _p.__frame_depth[_f] = _p.__node_depth[_n] + 1;
    _p.__frame_try[_f] = 0;

    var _methods = _task.methods;
    var _start = _p.__order_top;
    var _count = 0;
    for (var _m = 0; _m < array_length(_methods); _m++) {
        var _md = _methods[_m];
        var _s = 1;
        if (_md.score != undefined) {
            _s = _md.score(_p.owner, _p.state);
            if (!is_numeric(_s)) throw "GMSA: plan method '" + _task.name + "." + _md.name + "' score must return a number";
            if (!(_s * 1000000000000 > 0)) continue;
        }
        var _k = _count;
        while (_k > 0 && _p.__order_score[_start + _k - 1] < _s) {
            _p.__order[_start + _k] = _p.__order[_start + _k - 1];
            _p.__order_score[_start + _k] = _p.__order_score[_start + _k - 1];
            _k -= 1;
        }
        _p.__order[_start + _k] = _m;
        _p.__order_score[_start + _k] = _s;
        _count += 1;
    }
    _p.__frame_start[_f] = _start;
    _p.__frame_count[_f] = _count;
    _p.__order_top = _start + _count;
    _p.__frames = _f + 1;
}

function __gmsa_plan_next_choice(_p) {
    var _d = _p.domain;
    while (_p.__frames > 0) {
        var _f = _p.__frames - 1;
        __gmsa_plan_undo(_p, _p.__frame_undo[_f]);
        _p.__out_count = _p.__frame_out[_f];
        _p.__pool = _p.__frame_pool[_f];
        _p.__head = _p.__frame_rest[_f];
        var _task = _d.tasks[_p.__frame_task[_f]];
        while (_p.__frame_try[_f] < _p.__frame_count[_f]) {
            if (_p.nodes >= _p.budget) return 2;
            var _m = _p.__order[_p.__frame_start[_f] + _p.__frame_try[_f]];
            var _method = _task.methods[_m];
            _p.__frame_try[_f] += 1;
            _p.nodes += 1;
            if (!__gmsa_plan_met(_p.state, _method.requires)) continue;
            if (_method.check != undefined && !_method.check(_p.state)) continue;
            __gmsa_plan_out(_p, 1, _task.index, _m);
            var _depth = _p.__frame_depth[_f];
            _p.__head = __gmsa_plan_push_node(_p, 2, _task.index, _depth, _p.__head);
            var _subs = _method.subtasks;
            for (var _k = array_length(_subs) - 1; _k >= 0; _k--) {
                _p.__head = __gmsa_plan_push_node(_p, _subs[_k].kind, _subs[_k].index, _depth, _p.__head);
            }
            return 1;
        }
        _p.__order_top = _p.__frame_start[_f];
        _p.__frames = _f;
    }
    return 0;
}

// Internal: running
function __gmsa_plan_read_real(_p) {
    __gmsa_plan_read_facts(_p.domain, _p.owner, _p);
    for (var _i = 0; _i < array_length(_p.__real); _i++) _p.__real[_i] = _p.state[_i];
}

function __gmsa_plan_base(_p, _s) {
    var _n = array_length(_p.__real);
    for (var _i = 0; _i < _n; _i++) _p.state[_i] = _p.__real[_i];
    _p.undo_count = 0;
    var _steps = _p.domain.steps;
    for (var _i = _p.at; _i < _s; _i++) {
        if (_p.__run_kind[_i] == 0) __gmsa_plan_apply(_p, _steps[_p.__run_index[_i]].effects);
    }
    for (var _i = 0; _i < _n; _i++) _p.__base[_i] = _p.state[_i];
    _p.undo_count = 0;
}

function __gmsa_plan_broken_at(_p, _from) {
    var _steps = _p.domain.steps;
    _p.undo_count = 0;
    var _bad = -1;
    for (var _i = _from; _i < _p.__run_count; _i++) {
        if (_p.__run_kind[_i] != 0) continue;
        var _step = _steps[_p.__run_index[_i]];
        if (!__gmsa_plan_met(_p.state, _step.requires) || (_step.check != undefined && !_step.check(_p.state))) {
            _bad = _i;
            break;
        }
        __gmsa_plan_apply(_p, _step.effects);
    }
    __gmsa_plan_undo(_p, 0);
    return _bad;
}

function __gmsa_plan_enclosing(_p, _pos) {
    var _level = 0;
    for (var _j = _pos - 1; _j >= 0; _j--) {
        var _k = _p.__run_kind[_j];
        if (_k == 2) _level += 1;
        else if (_k == 1) {
            if (_level == 0) return _j;
            _level -= 1;
        }
    }
    return -1;
}

function __gmsa_plan_matching_end(_p, _s) {
    var _level = 0;
    for (var _j = _s + 1; _j < _p.__run_count; _j++) {
        var _k = _p.__run_kind[_j];
        if (_k == 1) _level += 1;
        else if (_k == 2) {
            if (_level == 0) return _j;
            _level -= 1;
        }
    }
    return _p.__run_count - 1;
}

function __gmsa_plan_depth_at(_p, _s) {
    var _level = 0;
    for (var _j = 0; _j < _s; _j++) {
        var _k = _p.__run_kind[_j];
        if (_k == 1) _level += 1;
        else if (_k == 2) _level -= 1;
    }
    return _level;
}

function __gmsa_plan_spare(_p, _w, _kind, _index, _method) {
    _p.__spare_kind[_w] = _kind;
    _p.__spare_index[_w] = _index;
    _p.__spare_method[_w] = _method;
    return _w + 1;
}

function __gmsa_plan_swap(_p) {
    var _a = _p.__run_kind;   _p.__run_kind = _p.__spare_kind;     _p.__spare_kind = _a;
    _a = _p.__run_index;      _p.__run_index = _p.__spare_index;   _p.__spare_index = _a;
    _a = _p.__run_method;     _p.__run_method = _p.__spare_method; _p.__spare_method = _a;
    _a = _p.__run_count;      _p.__run_count = _p.__spare_count;   _p.__spare_count = _a;
}

function __gmsa_plan_splice(_p, _s, _e) {
    var _w = 0;
    for (var _i = 0; _i < _s; _i++) _w = __gmsa_plan_spare(_p, _w, _p.__run_kind[_i], _p.__run_index[_i], _p.__run_method[_i]);
    for (var _i = 0; _i < _p.__out_count; _i++) _w = __gmsa_plan_spare(_p, _w, _p.__out_kind[_i], _p.__out_index[_i], _p.__out_method[_i]);
    for (var _i = _e + 1; _i < _p.__run_count; _i++) _w = __gmsa_plan_spare(_p, _w, _p.__run_kind[_i], _p.__run_index[_i], _p.__run_method[_i]);
    _p.__spare_count = _w;
    __gmsa_plan_swap(_p);
    for (var _i = 0; _i < array_length(_p.__base); _i++) _p.state[_i] = _p.__base[_i];
    if (__gmsa_plan_broken_at(_p, _s) != -1) {
        __gmsa_plan_swap(_p);
        return false;
    }
    if (_s <= _p.at) _p.at = _s;
    _p.__run_steps = 0;
    for (var _i = 0; _i < _p.__run_count; _i++) if (_p.__run_kind[_i] == 0) _p.__run_steps += 1;
    return true;
}

function __gmsa_plan_repair(_p, _b) {
    _p.nodes = 0;
    __gmsa_plan_read_real(_p);
    var _s = _b;
    while (true) {
        _s = __gmsa_plan_enclosing(_p, _s);
        var _kind = 1;
        var _index, _e, _depth;
        if (_s == -1) {
            var _root = _p.domain.lookup[$ _p.goal];
            if (_root.kind == 1) break;
            _kind = 0;
            _index = _root.index;
            _s = 0;
            _e = _p.__run_count - 1;
            _depth = 0;
        } else {
            _index = _p.__run_index[_s];
            _e = __gmsa_plan_matching_end(_p, _s);
            _depth = __gmsa_plan_depth_at(_p, _s);
        }
        __gmsa_plan_base(_p, _s);
        var _r = __gmsa_plan_search_from(_p, _kind, _index, _depth);
        if (_r == gmsa_plan_result.OUT_OF_BUDGET) {
            _p.result = _r;
            return false;
        }
        if (_r == gmsa_plan_result.FOUND && __gmsa_plan_splice(_p, _s, _e)) {
            _p.result = _r;
            return true;
        }
        if (_kind == 0) break;
    }
    _p.result = gmsa_plan_result.NO_PLAN;
    return false;
}

function __gmsa_plan_seek(_p, _from) {
    var _i = _from;
    while (_i < _p.__run_count && _p.__run_kind[_i] != 0) _i += 1;
    _p.at = _i;
}

function __gmsa_plan_pick_target(_p) {
    var _step = _p.domain.steps[_p.__run_index[_p.at]];
    _p.target = undefined;
    if (_step.targets == undefined) return true;
    var _list = _step.targets(_p.owner);
    if (!is_array(_list)) throw "GMSA: plan step '" + _step.name + "' targets must return an array";
    var _found = false;
    var _best = undefined;
    var _best_score = 0;
    for (var _i = 0; _i < array_length(_list); _i++) {
        var _s = 1;
        if (_step.score != undefined) {
            _s = _step.score(_p.owner, _list[_i]);
            if (!is_numeric(_s)) throw "GMSA: plan step '" + _step.name + "' score must return a number";
            if (!(_s * 1000000000000 > 0)) continue;
        }
        if (!_found || _s > _best_score) {
            _found = true;
            _best = _list[_i];
            _best_score = _s;
        }
    }
    if (!_found) return false;
    _p.target = _best;
    return true;
}

function __gmsa_plan_fail(_p) {
    _p.status = gmsa_plan_status.FAILED;
    _p.target = undefined;
}

function __gmsa_plan_settle(_p, _failed, _check) {
    while (true) {
        if (_failed) {
            _p.failures += 1;
            if (_p.failures > _p.retries || !__gmsa_plan_repair(_p, _p.at)) {
                __gmsa_plan_fail(_p);
                return;
            }
        } else if (_check) {
            __gmsa_plan_seek(_p, _p.at);
            if (_p.at < _p.__run_count) {
                __gmsa_plan_read_real(_p);
                var _bad = __gmsa_plan_broken_at(_p, _p.at);
                if (_bad != -1 && !__gmsa_plan_repair(_p, _bad)) {
                    __gmsa_plan_fail(_p);
                    return;
                }
            }
        }
        __gmsa_plan_seek(_p, _p.at);
        if (_p.at >= _p.__run_count) {
            _p.status = gmsa_plan_status.DONE;
            _p.target = undefined;
            return;
        }
        _p.status = gmsa_plan_status.RUNNING;
        if (__gmsa_plan_pick_target(_p)) return;
        _failed = true;
        _check = false;
    }
}