enum gmsa_plan_result { NONE, FOUND, NO_PLAN, OUT_OF_BUDGET }
enum gmsa_plan_status { IDLE, PLANNING, RUNNING, DONE, FAILED }
enum gmsa_plan_report { METHOD_SUCCESS, METHOD_FAILURE, METHOD_REWARD, STEP_SUCCESS, STEP_FAILURE, GOAL_SUCCESS, GOAL_FAILURE }

#macro __GMSA_PLAN_PAUSED -1

function gmsa_plan_planner_create(_domain, _owner, _params = {}) {
    if (!is_struct(_domain) || _domain[$ "built"] == undefined) throw "GMSA: plan planner needs a domain from gmsa_plan_domain_create";
    if (!_domain.built) throw "GMSA: plan domain '" + _domain.name + "' must be built before making planners";
    var _budget = __gmsa_param(_params, "budget", 250);
    var _depth = __gmsa_param(_params, "depth", 32);
    var _retries = __gmsa_param(_params, "retries", 3);
    var _slice = __gmsa_param(_params, "slice", undefined);
    var _clock = __gmsa_param(_params, "clock", get_timer);
    if (!is_numeric(_budget) || _budget < 1) throw "GMSA: plan budget must be at least 1";
    if (!is_numeric(_depth) || _depth < 1) throw "GMSA: plan depth must be at least 1";
    if (!is_numeric(_retries) || _retries < 0) throw "GMSA: plan retries must be 0 or more";
    if (_slice != undefined && (!is_numeric(_slice) || !(_slice * 1000000000000 > 0))) {
        throw "GMSA: plan slice must be more than 0 microseconds, or undefined to plan at once";
    }
    if (!__gmsa_callable(_clock)) throw "GMSA: plan clock must be callable";
    var _facts = array_length(_domain.facts);
	var _p = {
        domain : _domain, owner : _owner, budget : floor(_budget), depth : floor(_depth), retries : floor(_retries),
        slice : _slice, clock : _clock,
        rng : gmsa_rng_create(__gmsa_param(_params, "seed", 1)), // for weighted tasks, never GameMaker's random
        result : gmsa_plan_result.NONE, status : gmsa_plan_status.IDLE, goal : undefined,
        nodes : 0, depth_cut : false, target : undefined, at : 0, failures : 0,
        // imagined state and its undo log, the holder fields __gmsa_plan_apply and __gmsa_plan_undo use
        state : array_create(_facts, 0), undo_fact : [], undo_value : [], undo_count : 0,
        __real : array_create(_facts, 0),          // the facts as last read
        __base : array_create(_facts, 0),          // the state a search starts from
        __fact_bool : array_create(_facts, false), // which facts read as bools, for explain
        // planning in slices: when this call must stop, where the search paused, and whether it's a make (0) or a repair (1)
        __deadline : undefined, __resume_choice : false, __paused_once : false, __mode : 0, __work : undefined, __fresh_from : -1, __fresh_to : -1, __slice_first : false,
        // a repair's climb: the task being replanned, its entries s to e, and how to search it
        __repair_s : 0, __repair_e : 0, __repair_kind : 0, __repair_index : 0, __repair_depth : 0,
        __repair_b : 0, __chain_task : [], __chain_method : [], __chain_aux : [], __chain_goal : [], // what a repair broke, kept for reports
        __report : { kind : 0, planner : undefined, task : -1, task_name : undefined, method : -1, method_name : undefined,
                     step : -1, step_name : undefined, chance : 1, reward : 0, state : undefined, goal : -1, goal_name : undefined },
        // plans are entries: kind 0 a step, 1 a task begins (with its method and a trace record), 2 a task ends
        __out_count : 0, __out_kind : [], __out_index : [], __out_method : [], __out_aux : [],  // search output
        __run_count : 0, __run_kind : [], __run_index : [], __run_method : [], __run_aux : [], __run_steps : 0,  // the running plan
        __spare_count : 0, __spare_kind : [], __spare_index : [], __spare_method : [], __spare_aux : [],  // swapped in while repairing
        // trace records for explain: the search's, and the running plan's (grows with repairs, reset by make)
        __trace_top : 0, __trace : [], __plan_trace_top : 0, __plan_trace : [],
        // to-do list: a linked list in a node pool, head is the next thing to do. kind 0 step, 1 task, 2 end of a task
        __head : -1, __pool : 0, __node_kind : [], __node_index : [], __node_depth : [], __node_next : [],
        // choice points, one per task being broken down
        __frames : 0, __frame_task : [], __frame_rest : [], __frame_pool : [], __frame_undo : [], __frame_out : [],
        __frame_trace : [], __frame_depth : [], __frame_start : [], __frame_count : [], __frame_try : [], __frame_k : [],
        // method order per choice point, best first
        __order_top : 0, __order : [], __order_score : [], __method_score : [],
        // goals: an A* search over imagined states, stored flat and found again through a hash table
        __g_active : false, __g_goal : 0, __g_undo : 0, __g_start : 0, __g_found : -1, __g_expand : -1, __g_next : 0,
        __g_count : 0, __g_state : [], __g_parent : [], __g_action : [], __g_cost : [], __g_depth : [], __g_hash : [], __g_closed : [],
        __g_heap : 0, __g_hf : [], __g_hg : [], __g_hn : [], __g_table_node : [], __g_table_stamp : [], __g_mask : 0, __g_stamp : 0, __g_path : [], __g_vary : [],
    };
    _p.__report.planner = _p;
    _p.__report.state = _p.state; // filled with the facts the report is about, during the call
    return _p;
}

function gmsa_plan_make(_planner, _name) {
    __gmsa_plan_check_planner(_planner);
    var _d = _planner.domain;
    if (!is_string(_name) || !variable_struct_exists(_d.lookup, _name)) {
        throw "GMSA: plan domain '" + _d.name + "' has no step or task named '" + string(_name) + "'";
    }
    var _root = _d.lookup[$ _name];
    _planner.goal = _name;
    _planner.result = gmsa_plan_result.NONE;
    _planner.target = undefined;
    _planner.failures = 0;
    _planner.at = 0;
    _planner.__run_count = 0;
    _planner.__run_steps = 0;
    _planner.__plan_trace_top = 0;
    _planner.__paused_once = false;
    _planner.__fresh_from = -1;
    _planner.__fresh_to = -1;
	_planner.__mode = 0;
    _planner.nodes = 0;
    __gmsa_plan_read_real(_planner);
    __gmsa_plan_base(_planner, 0);
    __gmsa_plan_start_slice(_planner, __gmsa_plan_own_slice(_planner));
    var _r = __gmsa_plan_search_from(_planner, _root.kind, _root.index, 0);
    var _ok = __gmsa_plan_after_search(_planner, _r);
    _planner.__deadline = undefined;
    return _ok;
}

function gmsa_plan_work(_planner, _budget = undefined) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.PLANNING) return _planner.status;
    if (_budget != undefined && (!is_numeric(_budget) || !(_budget * 1000000000000 > 0))) {
        throw "GMSA: plan work budget must be more than 0 microseconds";
    }
    __gmsa_plan_start_slice(_planner, (_budget == undefined) ? _planner.slice : _budget);
    var _r = __gmsa_plan_search(_planner);
    if (_planner.__mode == 0) {
        __gmsa_plan_after_search(_planner, _r);
    } else {
        var _res = __gmsa_plan_repair_result(_planner, _r);
        if (_res == -1) _res = __gmsa_plan_repair_next(_planner);
        __gmsa_plan_after_repair(_planner, _res, true);
    }
    _planner.__deadline = undefined;
    return _planner.status;
}

function gmsa_plan_step_done(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return _planner.status;
    __gmsa_plan_emit_step(_planner, gmsa_plan_report.STEP_SUCCESS);
    _planner.at += 1;
    _planner.failures = 0;
    _planner.__fresh_from = -1;
    _planner.__fresh_to = -1;
    __gmsa_plan_start_slice(_planner, __gmsa_plan_own_slice(_planner));
    __gmsa_plan_settle(_planner, false, true);
    _planner.__deadline = undefined;
    return _planner.status;
}

function gmsa_plan_step_failed(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return _planner.status;
    __gmsa_plan_emit_step(_planner, gmsa_plan_report.STEP_FAILURE);
    __gmsa_plan_start_slice(_planner, __gmsa_plan_own_slice(_planner));
    __gmsa_plan_settle(_planner, true, true);
    _planner.__deadline = undefined;
    return _planner.status;
}

function gmsa_plan_refresh(_planner) {
    __gmsa_plan_check_planner(_planner);
    if (_planner.status != gmsa_plan_status.RUNNING) return _planner.status;
    __gmsa_plan_read_real(_planner);
    var _bad = __gmsa_plan_broken_at(_planner, _planner.at);
    if (_bad == -1) return _planner.status;
    __gmsa_plan_start_slice(_planner, __gmsa_plan_own_slice(_planner));
    __gmsa_plan_after_repair(_planner, __gmsa_plan_repair(_planner, _bad), false);
    _planner.__deadline = undefined;
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
    _planner.__deadline = undefined;
    _planner.__resume_choice = false;
    _planner.__g_active = false;
}

function gmsa_plan_reward(_planner, _reward) {
    __gmsa_plan_check_planner(_planner);
    if (!is_numeric(_reward)) throw "GMSA: plan reward must be a number";
    var _p = _planner;
    if (_p.__run_count == 0) return 0;
    if (_p.status == gmsa_plan_status.DONE) {
        var _n = 0;
        for (var _i = 0; _i < _p.__run_count; _i++) {
            if (_p.__run_kind[_i] != 1) continue;
            __gmsa_plan_emit_entry(_p, gmsa_plan_report.METHOD_REWARD, _i, -1, _reward);
            _n += 1;
        }
        return _n;
    }
    if (_p.status == gmsa_plan_status.RUNNING || _p.status == gmsa_plan_status.PLANNING) {
        return __gmsa_plan_emit_chain(_p, gmsa_plan_report.METHOD_REWARD, _p.at, -1, _reward);
    }
    return 0;
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

function __gmsa_plan_out(_p, _kind, _index, _method, _aux) {
    var _i = _p.__out_count;
    _p.__out_kind[_i] = _kind;
    _p.__out_index[_i] = _index;
    _p.__out_method[_i] = _method;
    _p.__out_aux[_i] = _aux;
    _p.__out_count = _i + 1;
}

function __gmsa_plan_search_from(_p, _kind, _index, _depth) {
    for (var _i = 0; _i < array_length(_p.__base); _i++) _p.state[_i] = _p.__base[_i];
    _p.undo_count = 0;
    _p.__out_count = 0;
    _p.__trace_top = 0;
    _p.__pool = 0;
    _p.__frames = 0;
    _p.__order_top = 0;
    _p.depth_cut = false;
    _p.__resume_choice = false;
    _p.__g_active = false;
    _p.__head = __gmsa_plan_push_node(_p, _kind, _index, _depth, -1);
    return __gmsa_plan_search(_p);
}

function __gmsa_plan_search(_p) {
    var _d = _p.domain;
    if (_p.__resume_choice) {
        // paused while choosing a method: carry on choosing
        _p.__resume_choice = false;
        var _first = __gmsa_plan_choice_result(_p, __gmsa_plan_next_choice(_p));
        if (_first != undefined) return _first;
    }
    while (true) {
        var _n = _p.__head;
        if (_n == -1) return gmsa_plan_result.FOUND;
        var _kind = _p.__node_kind[_n];
        if (_kind == 2) {
            // a task's subtasks are all done, free of budget
            __gmsa_plan_out(_p, 2, _p.__node_index[_n], -1, -1);
            _p.__head = _p.__node_next[_n];
            continue;
        }
        if (_p.nodes >= _p.budget) return gmsa_plan_result.OUT_OF_BUDGET;
        if (__gmsa_plan_time_up(_p)) return __GMSA_PLAN_PAUSED;
        var _r;
        if (_kind == 0) {
            // a step: if it can be done in the imagined state, do it and move on
            _p.nodes += 1;
            var _step = _d.steps[_p.__node_index[_n]];
            if (__gmsa_plan_met(_p.state, _step.requires) && (_step.check == undefined || _step.check(_p.state))) {
                __gmsa_plan_apply(_p, _step.effects);
                __gmsa_plan_out(_p, 0, _step.index, -1, -1);
                _p.__head = _p.__node_next[_n];
                continue;
            }
            _r = __gmsa_plan_next_choice(_p);
        } else if (_p.__node_depth[_n] >= _p.depth) {
            _p.depth_cut = true;
            _r = __gmsa_plan_next_choice(_p);
        } else if (_kind == 3) {
            // a goal: the cheapest chain of steps that reaches it from the imagined state
            if (!_p.__g_active) __gmsa_plan_goal_begin(_p, _p.__node_index[_n]);
            var _g = __gmsa_plan_goal_search(_p);
            if (_g == __GMSA_PLAN_PAUSED) return __GMSA_PLAN_PAUSED;
            __gmsa_plan_goal_end(_p, _g == gmsa_plan_result.FOUND);
            if (_g == gmsa_plan_result.OUT_OF_BUDGET) return _g;
            if (_g == gmsa_plan_result.FOUND) {
                _p.__head = _p.__node_next[_n];
                continue;
            }
            _r = __gmsa_plan_next_choice(_p);  // no chain reaches it: back up, like a step that can't be done
        } else {
            // a task: becomes the newest choice point, and its first method is tried
            __gmsa_plan_push_frame(_p, _n);
            _r = __gmsa_plan_next_choice(_p);
        }
        var _out = __gmsa_plan_choice_result(_p, _r);
        if (_out != undefined) return _out;
    }
}

function __gmsa_plan_choice_result(_p, _r) {
    switch (_r) {
        case 0: return gmsa_plan_result.NO_PLAN;
        case 2: return gmsa_plan_result.OUT_OF_BUDGET;
        case 3:
            _p.__resume_choice = true;
            return __GMSA_PLAN_PAUSED;
    }
    return undefined;
}

function __gmsa_plan_time_up(_p) {
    if (_p.__deadline == undefined) return false;
    if (_p.__slice_first) {
        _p.__slice_first = false;
        return false;
    }
    return _p.clock() >= _p.__deadline;
}

function __gmsa_plan_push_frame(_p, _n) {
    var _f = _p.__frames;
    var _task = _p.domain.tasks[_p.__node_index[_n]];
    _p.__frame_task[_f] = _task.index;
    _p.__frame_rest[_f] = _p.__node_next[_n];
    _p.__frame_pool[_f] = _p.__pool;
    _p.__frame_undo[_f] = _p.undo_count;
    _p.__frame_out[_f] = _p.__out_count;
    _p.__frame_trace[_f] = _p.__trace_top;
    _p.__frame_depth[_f] = _p.__node_depth[_n] + 1;
    _p.__frame_try[_f] = 0;

    // every method's score, 1 without one. The task's adjust may change them all at once, such as learned scores
    var _methods = _task.methods;
    var _nm = array_length(_methods);
    for (var _m = 0; _m < _nm; _m++) {
        var _md = _methods[_m];
        var _s = 1;
        if (_md.score != undefined) {
            _s = _md.score(_p.owner, _p.state);
            if (!is_numeric(_s)) throw "GMSA: plan method '" + _task.name + "." + _md.name + "' score must return a number";
        }
        _p.__method_score[_m] = _s;
    }
    // how likely each method's own steps are to succeed here, when the domain knows
    var _chance = _p.domain.step_chance;
    if (_chance != undefined) {
        for (var _m = 0; _m < _nm; _m++) {
            if (!(_p.__method_score[_m] * 1000000000000 > 0)) continue;
            var _subs = _methods[_m].subtasks;
            for (var _k = 0; _k < array_length(_subs); _k++) {
                if (_subs[_k].kind == 0) _p.__method_score[_m] *= clamp(_chance(_p, _subs[_k].index, _p.state), 0, 1);
            }
        }
    }
    if (_task.adjust != undefined) _task.adjust(_p, _p.state, _p.__method_score);

    // best first, 0 or less rules a method out, ties keep the declared order
    var _start = _p.__order_top;
    var _count = 0;
    for (var _m = 0; _m < _nm; _m++) {
        var _s = _p.__method_score[_m];
        if (!is_numeric(_s)) throw "GMSA: plan task '" + _task.name + "' adjust must leave numbers";
        if (!(_s * 1000000000000 > 0)) continue;
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
	
    // weighted tasks: the top methods in a weighted random order, the rest after them in score order
    var _k = 0;
    if (_task.select == gmsa_select.TOP_N_WEIGHTED) {
        _k = min(_task.top_n, _count);
        for (var _i = 0; _i < _k - 1; _i++) {
            var _total = 0;
            for (var _j = _i; _j < _k; _j++) _total += _p.__order_score[_start + _j];
            var _r = gmsa_rng_next(_p.rng) * _total;
            var _pick = _k - 1;
            for (var _j = _i; _j < _k; _j++) {
                _r -= _p.__order_score[_start + _j];
                if (_r * 1000000000000 < 0) {
                    _pick = _j;
                    break;
                }
            }
            if (_pick != _i) {
                var _m = _p.__order[_start + _i];
                var _s = _p.__order_score[_start + _i];
                _p.__order[_start + _i] = _p.__order[_start + _pick];
                _p.__order_score[_start + _i] = _p.__order_score[_start + _pick];
                _p.__order[_start + _pick] = _m;
                _p.__order_score[_start + _pick] = _s;
            }
        }
    }
    _p.__frame_k[_f] = _k;
    _p.__frame_start[_f] = _start;
    _p.__frame_count[_f] = _count;
    _p.__order_top = _start + _count;
    _p.__frames = _f + 1;
}

function __gmsa_plan_next_choice(_p) {
    var _d = _p.domain;
    while (_p.__frames > 0) {
        var _f = _p.__frames - 1;
        // back to how things were when this task was reached
        __gmsa_plan_undo(_p, _p.__frame_undo[_f]);
        _p.__out_count = _p.__frame_out[_f];
        _p.__trace_top = _p.__frame_trace[_f];
        _p.__pool = _p.__frame_pool[_f];
        _p.__head = _p.__frame_rest[_f];
        var _task = _d.tasks[_p.__frame_task[_f]];
        while (_p.__frame_try[_f] < _p.__frame_count[_f]) {
            if (_p.nodes >= _p.budget) return 2;
            if (__gmsa_plan_time_up(_p)) return 3;
            var _m = _p.__order[_p.__frame_start[_f] + _p.__frame_try[_f]];
            var _method = _task.methods[_m];
            _p.__frame_try[_f] += 1;
            _p.nodes += 1;
            if (!__gmsa_plan_met(_p.state, _method.requires)) continue;
            if (_method.check != undefined && !_method.check(_p.state)) continue;
            // the task begins, its subtasks go in front of the rest of the to-do list, then its end marker
            __gmsa_plan_out(_p, 1, _task.index, _m, __gmsa_plan_record(_p, _f));
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

function __gmsa_plan_record(_p, _f) {
    var _o = _p.__trace_top;
    var _c = _p.__frame_count[_f];
    var _start = _p.__frame_start[_f];
    var _pick = _p.__frame_try[_f] - 1;
    _p.__trace[_o] = _c;
    _p.__trace[_o + 1] = _pick;
    _p.__trace[_o + 2] = __gmsa_plan_chance(_p, _start, _pick, _p.__frame_k[_f]);
    for (var _i = 0; _i < _c; _i++) {
        _p.__trace[_o + 3 + _i * 2] = _p.__order[_start + _i];
        _p.__trace[_o + 4 + _i * 2] = _p.__order_score[_start + _i];
    }
    var _w = _o + 3 + _c * 2;
    var _n = array_length(_p.state);
    for (var _i = 0; _i < _n; _i++) _p.__trace[_w + _i] = _p.state[_i];
    _p.__trace_top = _w + _n;
    return _o;
}

function __gmsa_plan_keep_record(_p, _o) {
    var _len = 3 + _p.__trace[_o] * 2 + array_length(_p.state);
    var _at = _p.__plan_trace_top;
    for (var _i = 0; _i < _len; _i++) _p.__plan_trace[_at + _i] = _p.__trace[_o + _i];
    _p.__plan_trace_top = _at + _len;
    return _at;
}

function __gmsa_plan_chance(_p, _start, _pick, _k) {
    if (_pick >= _k) return 1;
    var _total = 0;
    for (var _j = _pick; _j < _k; _j++) _total += _p.__order_score[_start + _j];
    return _p.__order_score[_start + _pick] / _total;
}

function __gmsa_plan_entry_chance(_p, _i) {
    return _p.__plan_trace[_p.__run_aux[_i] + 2];
}

// Internal: running
function __gmsa_plan_start_slice(_p, _budget) {
    _p.__deadline = (_budget == undefined) ? undefined : _p.clock() + _budget;
    _p.__slice_first = (_budget != undefined && _budget > 0);
}

function __gmsa_plan_own_slice(_p) {
    return (_p.__work != undefined) ? 0 : _p.slice;
}

function __gmsa_plan_after_search(_p, _r) {
    if (_r == __GMSA_PLAN_PAUSED) {
        _p.status = gmsa_plan_status.PLANNING;
        _p.__paused_once = true;
        return true;
    }
    _p.result = _r;
    if (_r != gmsa_plan_result.FOUND) {
        _p.status = gmsa_plan_status.FAILED;
        return false;
    }
    __gmsa_plan_adopt(_p);
    __gmsa_plan_settle(_p, false, _p.__paused_once);
    return _p.status != gmsa_plan_status.FAILED;
}

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
        if (_k == 2 || _k == 4) _level += 1;
        else if (_k == 1 || _k == 3) {
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
        if (_k == 1 || _k == 3) _level += 1;
        else if (_k == 2 || _k == 4) {
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
        if (_k == 1 || _k == 3) _level += 1;
        else if (_k == 2 || _k == 4) _level -= 1;
    }
    return _level;
}

function __gmsa_plan_spare(_p, _w, _kind, _index, _method, _aux) {
    _p.__spare_kind[_w] = _kind;
    _p.__spare_index[_w] = _index;
    _p.__spare_method[_w] = _method;
    _p.__spare_aux[_w] = _aux;
    return _w + 1;
}

function __gmsa_plan_swap(_p) {
    var _a = _p.__run_kind;   _p.__run_kind = _p.__spare_kind;     _p.__spare_kind = _a;
    _a = _p.__run_index;      _p.__run_index = _p.__spare_index;   _p.__spare_index = _a;
    _a = _p.__run_method;     _p.__run_method = _p.__spare_method; _p.__spare_method = _a;
    _a = _p.__run_aux;        _p.__run_aux = _p.__spare_aux;       _p.__spare_aux = _a;
    _a = _p.__run_count;      _p.__run_count = _p.__spare_count;   _p.__spare_count = _a;
}

function __gmsa_plan_splice(_p, _s, _e) {
    var _w = 0;
    for (var _i = 0; _i < _s; _i++) {
        _w = __gmsa_plan_spare(_p, _w, _p.__run_kind[_i], _p.__run_index[_i], _p.__run_method[_i], _p.__run_aux[_i]);
    }
    for (var _i = 0; _i < _p.__out_count; _i++) {
        var _aux = _p.__out_aux[_i];
        if (_p.__out_kind[_i] == 1) _aux = __gmsa_plan_keep_record(_p, _aux);
        _w = __gmsa_plan_spare(_p, _w, _p.__out_kind[_i], _p.__out_index[_i], _p.__out_method[_i], _aux);
    }
    for (var _i = _e + 1; _i < _p.__run_count; _i++) {
        _w = __gmsa_plan_spare(_p, _w, _p.__run_kind[_i], _p.__run_index[_i], _p.__run_method[_i], _p.__run_aux[_i]);
    }
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

function __gmsa_plan_adopt(_p) {
    var _a = _p.__run_kind;   _p.__run_kind = _p.__out_kind;     _p.__out_kind = _a;
    _a = _p.__run_index;      _p.__run_index = _p.__out_index;   _p.__out_index = _a;
    _a = _p.__run_method;     _p.__run_method = _p.__out_method; _p.__out_method = _a;
    _a = _p.__run_aux;        _p.__run_aux = _p.__out_aux;       _p.__out_aux = _a;
    _a = _p.__plan_trace;     _p.__plan_trace = _p.__trace;      _p.__trace = _a;
    _p.__run_count = _p.__out_count;
    _p.__plan_trace_top = _p.__trace_top;
    _p.at = 0;
    _p.__run_steps = 0;
    for (var _i = 0; _i < _p.__run_count; _i++) if (_p.__run_kind[_i] == 0) _p.__run_steps += 1;
}

function __gmsa_plan_repair(_p, _b) {
    _p.nodes = 0;
    __gmsa_plan_read_real(_p);
    _p.__repair_s = _b;
    _p.__repair_b = _b;
    return __gmsa_plan_repair_next(_p);
}

function __gmsa_plan_repair_next(_p) {
    while (true) {
        var _s = __gmsa_plan_enclosing(_p, _p.__repair_s);
        if (_s == -1) {
            var _root = _p.domain.lookup[$ _p.goal];
            if (_root.kind == 1 || _root.kind == 3) {
                _p.result = gmsa_plan_result.NO_PLAN;
                return 0;
            }
            _p.__repair_kind = 0;
            _p.__repair_index = _root.index;
            _p.__repair_s = 0;
            _p.__repair_e = _p.__run_count - 1;
            _p.__repair_depth = 0;
        } else {
            _p.__repair_kind = (_p.__run_kind[_s] == 3) ? 3 : 1; // a goal is repaired by searching it again
            _p.__repair_index = _p.__run_index[_s];
            _p.__repair_s = _s;
            _p.__repair_e = __gmsa_plan_matching_end(_p, _s);
            _p.__repair_depth = __gmsa_plan_depth_at(_p, _s);
        }
        __gmsa_plan_base(_p, _p.__repair_s);
        var _r = __gmsa_plan_search_from(_p, _p.__repair_kind, _p.__repair_index, _p.__repair_depth);
        var _res = __gmsa_plan_repair_result(_p, _r);
        if (_res != -1) return _res;
    }
}

function __gmsa_plan_repair_result(_p, _r) {
    if (_r == __GMSA_PLAN_PAUSED) return 2;
    if (_r == gmsa_plan_result.OUT_OF_BUDGET) {
        _p.result = _r;
        return 0;
    }
    if (_r == gmsa_plan_result.FOUND) {
        var _n = __gmsa_plan_collect_chain(_p, _p.__repair_b, _p.__repair_s);
        if (__gmsa_plan_splice(_p, _p.__repair_s, _p.__repair_e)) {
            _p.result = _r;
            _p.__fresh_from = _p.__repair_s;
            _p.__fresh_to = _p.__repair_s + _p.__out_count;
            for (var _i = 0; _i < _n; _i++) {
                if (_p.__chain_goal[_i]) __gmsa_plan_emit_goal(_p, gmsa_plan_report.METHOD_FAILURE, _p.__chain_task[_i], _p.__chain_aux[_i], -1, 0);
                else __gmsa_plan_emit(_p, gmsa_plan_report.METHOD_FAILURE, _p.__chain_task[_i], _p.__chain_method[_i], _p.__chain_aux[_i], -1, 0);
            }
            return 1;
        }
    }
    if (_p.__repair_kind == 0) {
        _p.result = gmsa_plan_result.NO_PLAN;
        return 0;
    }
    return -1;
}

function __gmsa_plan_after_repair(_p, _res, _check) {
    if (_res == 2) __gmsa_plan_planning(_p);
    else if (_res == 0) __gmsa_plan_fail(_p, _p.__repair_b);
    else __gmsa_plan_settle(_p, false, _check);
}

function __gmsa_plan_planning(_p) {
    _p.status = gmsa_plan_status.PLANNING;
    _p.target = undefined;
    _p.__mode = 1;
    _p.__paused_once = true;
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

function __gmsa_plan_fail(_p, _b) {
    if (_b >= 0 && _b < _p.__run_count) __gmsa_plan_emit_chain(_p, gmsa_plan_report.METHOD_FAILURE, _b, -1, 0);
    _p.status = gmsa_plan_status.FAILED;
    _p.target = undefined;
}

function __gmsa_plan_seek(_p, _from) {
    var _i = _from;
    var _listening = __gmsa_plan_listening(_p);
    while (_i < _p.__run_count && _p.__run_kind[_i] != 0) {
        // passing a task's or a goal's end: everything inside it finished
        var _k = _p.__run_kind[_i];
        if (_listening && (_k == 2 || _k == 4)) {
            __gmsa_plan_emit_entry(_p, gmsa_plan_report.METHOD_SUCCESS, __gmsa_plan_enclosing(_p, _i), -1, 0);
        }
        _i += 1;
    }
    _p.at = _i;
}

function __gmsa_plan_settle(_p, _failed, _check) {
    while (true) {
        var _res = 1;
        var _broken = _p.at;
        if (_failed) {
            _p.failures += 1;
            _res = (_p.failures > _p.retries) ? 0 : __gmsa_plan_repair(_p, _p.at);
        } else if (_check) {
            __gmsa_plan_seek(_p, _p.at);
            if (_p.at < _p.__run_count) {
                __gmsa_plan_read_real(_p);
                var _bad = __gmsa_plan_broken_at(_p, _p.at);
                if (_bad != -1) {
                    _broken = _bad;
                    _res = __gmsa_plan_repair(_p, _bad);
                }
            }
        }
        if (_res == 0) {
            __gmsa_plan_fail(_p, _broken);
            return;
        }
        if (_res == 2) {
            __gmsa_plan_planning(_p);
            return;
        }
        __gmsa_plan_seek(_p, _p.at);
        if (_p.at >= _p.__run_count) {
            _p.status = gmsa_plan_status.DONE;
            _p.target = undefined;
            return;
        }
        _p.status = gmsa_plan_status.RUNNING;
        if (__gmsa_plan_pick_target(_p)) return;
        // no target: the step can't start, same as failing
        __gmsa_plan_emit_step(_p, gmsa_plan_report.STEP_FAILURE);
        _failed = true;
        _check = false;
    }
}

// Internal: reports
function __gmsa_plan_listening(_p) {
    return array_length(_p.domain.listeners) > 0;
}

function __gmsa_plan_emit(_p, _kind, _task, _method, _aux, _step, _reward) {
    var _ls = _p.domain.listeners;
    if (array_length(_ls) == 0) return;
    var _d = _p.domain;
    var _r = _p.__report;
    _r.kind = _kind;
    _r.goal = -1;
    _r.goal_name = undefined;
    _r.reward = _reward;
    _r.step = _step;
    _r.step_name = (_step >= 0) ? _d.steps[_step].name : undefined;
    var _n = array_length(_p.state);
    if (_task >= 0) {
        var _tr = _p.__plan_trace;
        _r.task = _task;
        _r.task_name = _d.tasks[_task].name;
        _r.method = _method;
        _r.method_name = _d.tasks[_task].methods[_method].name;
        _r.chance = (_step >= 0) ? 1 : _tr[_aux + 2];
        var _facts = _aux + 3 + _tr[_aux] * 2;
        for (var _i = 0; _i < _n; _i++) _p.state[_i] = _tr[_facts + _i];
    } else {
        _r.task = -1;
        _r.task_name = undefined;
        _r.method = -1;
        _r.method_name = undefined;
        _r.chance = 1;
        for (var _i = 0; _i < _n; _i++) _p.state[_i] = _p.__real[_i];
    }
    for (var _i = 0; _i < array_length(_ls); _i++) _ls[_i](_r);
}

function __gmsa_plan_emit_entry(_p, _kind, _entry, _step, _reward) {
    if (!__gmsa_plan_listening(_p)) return;
    if (_entry < 0) __gmsa_plan_emit(_p, _kind, -1, -1, -1, _step, _reward);
    else if (_p.__run_kind[_entry] == 3) __gmsa_plan_emit_goal(_p, _kind, _p.__run_index[_entry], _p.__run_aux[_entry], _step, _reward);
    else __gmsa_plan_emit(_p, _kind, _p.__run_index[_entry], _p.__run_method[_entry], _p.__run_aux[_entry], _step, _reward);
}

function __gmsa_plan_emit_step(_p, _kind) {
    if (!__gmsa_plan_listening(_p)) return;
    __gmsa_plan_emit_entry(_p, _kind, __gmsa_plan_enclosing(_p, _p.at), _p.__run_index[_p.at], 0);
}

function __gmsa_plan_emit_chain(_p, _kind, _b, _top, _reward) {
    var _n = 0;
    var _s = _b;
    while (true) {
        _s = __gmsa_plan_enclosing(_p, _s);
        if (_s == -1) break;
        if (_p.__run_kind[_s] == 3 && _kind == gmsa_plan_report.METHOD_REWARD) {
            if (_s == _top) break;
            continue;
        }
        __gmsa_plan_emit_entry(_p, _kind, _s, -1, _reward);
        _n += 1;
        if (_s == _top) break;
    }
    return _n;
}

function __gmsa_plan_collect_chain(_p, _b, _top) {
    if (!__gmsa_plan_listening(_p)) return 0;
    var _n = 0;
    var _s = _b;
    while (true) {
        _s = __gmsa_plan_enclosing(_p, _s);
        if (_s == -1) break;
        _p.__chain_task[_n] = _p.__run_index[_s];
        _p.__chain_method[_n] = _p.__run_method[_s];
        _p.__chain_aux[_n] = _p.__run_aux[_s];
        _p.__chain_goal[_n] = (_p.__run_kind[_s] == 3);
        _n += 1;
        if (_s == _top) break;
    }
    return _n;
}

// Internal: goals, an A* search over imagined states
function __gmsa_plan_goal_begin(_p, _goal) {
    // the hash table holds every state one search can store, with room to spare, sized once per planner
    var _size = 1;
    while (_size < (_p.budget + 2) * 2) _size *= 2;
    if (array_length(_p.__g_table_node) < _size) {
        array_resize(_p.__g_table_node, _size);
        array_resize(_p.__g_table_stamp, _size);
    }
    _p.__g_mask = array_length(_p.__g_table_node) - 1;
    _p.__g_stamp += 1;  // empties the table without clearing it
    _p.__g_active = true;
    _p.__g_goal = _goal;
    _p.__g_undo = _p.undo_count; // a recipe's undo log below this mark stays untouched
    _p.__g_start = _p.nodes;
    _p.__g_found = -1;
    _p.__g_count = 0;
    _p.__g_heap = 0;
    _p.__g_expand = -1;
    _p.__g_next = 0;
    // variety: one cost factor per action for this search, at least 1, so the guess still never overestimates
    var _goal_s = _p.domain.goals[_goal];
    if (_goal_s.variety > 0) {
        for (var _k = 0; _k < array_length(_goal_s.actions); _k++) _p.__g_vary[_k] = 1 + gmsa_rng_next(_p.rng) * _goal_s.variety;
    }
    __gmsa_plan_goal_add(_p, _p.domain.goals[_goal], -1, -1, 0, 0, __gmsa_plan_goal_hash(_p)); // the start: the imagined state as it is now
}

function __gmsa_plan_goal_search(_p) {
    var _d = _p.domain;
    var _goal = _d.goals[_p.__g_goal];
    var _acts = _goal.actions;
    var _na = array_length(_acts);
    var _any = false; // the first action of a call is free of the clock, so every call makes progress
    while (true) {
        if (_p.__g_expand == -1) {
            // the most promising state not expanded yet, stale heap entries are skipped
            var _n = -1;
            while (_p.__g_heap > 0) {
                var _top = __gmsa_plan_heap_pop(_p);
                if (!_p.__g_closed[_top]) {
                    _n = _top;
                    break;
                }
            }
            if (_n == -1) return gmsa_plan_result.NO_PLAN;
            _p.__g_closed[_n] = true;
            __gmsa_plan_goal_load(_p, _n);
            if (__gmsa_plan_met(_p.state, _goal.conditions)) {
                _p.__g_found = _n;
                return gmsa_plan_result.FOUND;
            }
            _p.__g_expand = _n;
            _p.__g_next = 0;
        } else {
            __gmsa_plan_goal_load(_p, _p.__g_expand); // resuming after a pause
        }
        var _from = _p.__g_expand;
        while (_p.__g_next < _na) {
            if (_p.nodes >= _p.budget) return gmsa_plan_result.OUT_OF_BUDGET;
            if (_any && __gmsa_plan_time_up(_p)) return __GMSA_PLAN_PAUSED;
            _any = true;
            var _ai = _p.__g_next;
            var _step = _d.steps[_acts[_ai]];
            _p.__g_next += 1;
            _p.nodes += 1;
            if (!__gmsa_plan_met(_p.state, _step.requires)) continue;
            if (_step.check != undefined && !_step.check(_p.state)) continue;
            var _cost = _step.cost;
            if (_step.cost_fn != undefined) {
                _cost = _step.cost_fn(_p.owner, _p.state);
                if (!is_numeric(_cost)) throw "GMSA: plan step '" + _step.name + "' cost must return a number";
                if (!(_cost * 1000000000000 > 0)) continue; // 0 or less rules the step out
            }
            // a step that works half the time costs twice as much, one that never works is ruled out
            if (_d.step_chance != undefined) {
                var _chance = clamp(_d.step_chance(_p, _step.index, _p.state), 0, 1);
                if (!(_chance * 1000000000000 > 0)) continue;
                _cost /= _chance;
            }
            if (_goal.variety > 0) _cost *= _p.__g_vary[_ai];
            var _g = _p.__g_cost[_from] + _cost;
            var _mark = _p.undo_count;
            __gmsa_plan_apply(_p, _step.effects);
            var _hash = __gmsa_plan_goal_hash(_p);
            var _m = __gmsa_plan_goal_find(_p, _hash);
            if (_m == -1) {
                __gmsa_plan_goal_add(_p, _goal, _from, _step.index, _g, _p.__g_depth[_from] + 1, _hash);
            } else if (!_p.__g_closed[_m] && _g < _p.__g_cost[_m]) {
                // a cheaper way to a state that's still waiting: take it, its old heap entry gets skipped
                _p.__g_parent[_m] = _from;
                _p.__g_action[_m] = _step.index;
                _p.__g_cost[_m] = _g;
                _p.__g_depth[_m] = _p.__g_depth[_from] + 1;
                __gmsa_plan_heap_push(_p, _g + __gmsa_plan_goal_guess(_p, _goal), _g, _m);
            }
            __gmsa_plan_undo(_p, _mark);
        }
        _p.__g_expand = -1;
    }
}

function __gmsa_plan_goal_end(_p, _found) {
    _p.__g_active = false;
    // back to the imagined state the goal started from, with the recipe's undo log as it was
    __gmsa_plan_goal_load(_p, 0);
    _p.undo_count = _p.__g_undo;
    if (!_found) return;
    var _len = _p.__g_depth[_p.__g_found];
    var _n = _p.__g_found;
    for (var _i = _len - 1; _i >= 0; _i--) {
        _p.__g_path[_i] = _p.__g_action[_n];
        _n = _p.__g_parent[_n];
    }
    // the chain goes into the plan between the goal's begin (3) and end (4), its effects into the imagined state
    __gmsa_plan_out(_p, 3, _p.__g_goal, -1, __gmsa_plan_goal_record(_p));
    var _steps = _p.domain.steps;
    for (var _i = 0; _i < _len; _i++) {
        var _s = _p.__g_path[_i];
        __gmsa_plan_apply(_p, _steps[_s].effects);
        __gmsa_plan_out(_p, 0, _s, -1, -1);
    }
    __gmsa_plan_out(_p, 4, _p.__g_goal, -1, -1);
}

function __gmsa_plan_goal_record(_p) {
    var _o = _p.__trace_top;
    _p.__trace[_o] = 1;
    _p.__trace[_o + 1] = _p.nodes - _p.__g_start;
    _p.__trace[_o + 2] = 1;
    _p.__trace[_o + 3] = -1;
    _p.__trace[_o + 4] = _p.__g_cost[_p.__g_found];
    var _nf = array_length(_p.state);
    for (var _i = 0; _i < _nf; _i++) _p.__trace[_o + 5 + _i] = _p.__g_state[_i];
    _p.__trace_top = _o + 5 + _nf;
    return _o;
}

function __gmsa_plan_goal_add(_p, _goal, _parent, _action, _g, _depth, _hash) {
    var _n = _p.__g_count;
    var _nf = array_length(_p.state);
    var _o = _n * _nf;
    for (var _i = 0; _i < _nf; _i++) _p.__g_state[_o + _i] = _p.state[_i];
    _p.__g_parent[_n] = _parent;
    _p.__g_action[_n] = _action;
    _p.__g_cost[_n] = _g;
    _p.__g_depth[_n] = _depth;
    _p.__g_hash[_n] = _hash;
    _p.__g_closed[_n] = false;
    var _slot = _hash & _p.__g_mask;
    while (_p.__g_table_stamp[_slot] == _p.__g_stamp) _slot = (_slot + 1) & _p.__g_mask;
    _p.__g_table_stamp[_slot] = _p.__g_stamp;
    _p.__g_table_node[_slot] = _n;
    _p.__g_count = _n + 1;
    __gmsa_plan_heap_push(_p, _g + __gmsa_plan_goal_guess(_p, _goal), _g, _n);
}

function __gmsa_plan_goal_find(_p, _hash) {
    var _nf = array_length(_p.state);
    var _slot = _hash & _p.__g_mask;
    while (_p.__g_table_stamp[_slot] == _p.__g_stamp) {
        var _m = _p.__g_table_node[_slot];
        if (_p.__g_hash[_m] == _hash) {
            var _o = _m * _nf;
            var _same = true;
            for (var _i = 0; _i < _nf; _i++) {
                if (_p.__g_state[_o + _i] != _p.state[_i]) {
                    _same = false;
                    break;
                }
            }
            if (_same) return _m;
        }
        _slot = (_slot + 1) & _p.__g_mask;
    }
    return -1;
}

function __gmsa_plan_goal_load(_p, _n) {
    var _nf = array_length(_p.state);
    var _o = _n * _nf;
    for (var _i = 0; _i < _nf; _i++) _p.state[_i] = _p.__g_state[_o + _i];
}

function __gmsa_plan_goal_hash(_p) {
    var _h = 17;
    var _s = _p.state;
    for (var _i = 0; _i < array_length(_s); _i++) _h = ((_h * 31) + floor(_s[_i] * 1024)) & 0x3FFFFFFF;
    return _h;
}

function __gmsa_plan_goal_guess(_p, _goal) {
    var _c = _goal.conditions;
    var _unmet = 0;
    for (var _i = 0; _i < _c.count; _i++) if (!__gmsa_plan_met_one(_p.state, _c, _i)) _unmet += 1;
    return ceil(_unmet / _goal.most) * _goal.cheapest;
}

function __gmsa_plan_met_one(_state, _cond, _i) {
    var _a = _state[_cond.fact[_i]];
    var _b = _cond.value[_i];
    switch (_cond.op[_i]) {
        case gmsa_plan_op.EQ: return _a == _b;
        case gmsa_plan_op.NE: return _a != _b;
        case gmsa_plan_op.LT: return _a < _b;
        case gmsa_plan_op.LE: return _a <= _b;
        case gmsa_plan_op.GT: return _a > _b;
        case gmsa_plan_op.GE: return _a >= _b;
    }
    return true;
}

function __gmsa_plan_heap_before(_p, _a, _b) {
    var _fa = _p.__g_hf[_a];
    var _fb = _p.__g_hf[_b];
    if (_fa != _fb) return _fa < _fb;
    var _ga = _p.__g_hg[_a];
    var _gb = _p.__g_hg[_b];
    if (_ga != _gb) return _ga > _gb;
    return _p.__g_hn[_a] < _p.__g_hn[_b];
}

function __gmsa_plan_heap_swap(_p, _a, _b) {
    var _t = _p.__g_hf[_a]; _p.__g_hf[_a] = _p.__g_hf[_b]; _p.__g_hf[_b] = _t;
    _t = _p.__g_hg[_a];     _p.__g_hg[_a] = _p.__g_hg[_b]; _p.__g_hg[_b] = _t;
    _t = _p.__g_hn[_a];     _p.__g_hn[_a] = _p.__g_hn[_b]; _p.__g_hn[_b] = _t;
}

function __gmsa_plan_heap_push(_p, _f, _g, _n) {
    var _i = _p.__g_heap;
    _p.__g_hf[_i] = _f;
    _p.__g_hg[_i] = _g;
    _p.__g_hn[_i] = _n;
    _p.__g_heap = _i + 1;
    while (_i > 0) {
        var _up = (_i - 1) div 2;
        if (!__gmsa_plan_heap_before(_p, _i, _up)) break;
        __gmsa_plan_heap_swap(_p, _i, _up);
        _i = _up;
    }
}

function __gmsa_plan_heap_pop(_p) {
    var _top = _p.__g_hn[0];
    var _last = _p.__g_heap - 1;
    _p.__g_heap = _last;
    if (_last > 0) {
        _p.__g_hf[0] = _p.__g_hf[_last];
        _p.__g_hg[0] = _p.__g_hg[_last];
        _p.__g_hn[0] = _p.__g_hn[_last];
        var _i = 0;
        while (true) {
            var _l = _i * 2 + 1;
            if (_l >= _last) break;
            var _best = _l;
            if (_l + 1 < _last && __gmsa_plan_heap_before(_p, _l + 1, _l)) _best = _l + 1;
            if (!__gmsa_plan_heap_before(_p, _best, _i)) break;
            __gmsa_plan_heap_swap(_p, _i, _best);
            _i = _best;
        }
    }
    return _top;
}

function __gmsa_plan_emit_goal(_p, _kind, _goal, _aux, _step, _reward) {
    var _ls = _p.domain.listeners;
    if (array_length(_ls) == 0) return;
    if (_kind == gmsa_plan_report.METHOD_SUCCESS) _kind = gmsa_plan_report.GOAL_SUCCESS;
    else if (_kind == gmsa_plan_report.METHOD_FAILURE) _kind = gmsa_plan_report.GOAL_FAILURE;
    else if (_kind == gmsa_plan_report.METHOD_REWARD) return;
    var _d = _p.domain;
    var _r = _p.__report;
    _r.kind = _kind;
    _r.reward = _reward;
    _r.step = _step;
    _r.step_name = (_step >= 0) ? _d.steps[_step].name : undefined;
    _r.task = -1;
    _r.task_name = undefined;
    _r.method = -1;
    _r.method_name = undefined;
    _r.chance = 1;
    _r.goal = _goal;
    _r.goal_name = _d.goals[_goal].name;
    var _tr = _p.__plan_trace;
    var _facts = _aux + 3 + _tr[_aux] * 2;
    for (var _i = 0; _i < array_length(_p.state); _i++) _p.state[_i] = _tr[_facts + _i];
    for (var _i = 0; _i < array_length(_ls); _i++) _ls[_i](_r);
}