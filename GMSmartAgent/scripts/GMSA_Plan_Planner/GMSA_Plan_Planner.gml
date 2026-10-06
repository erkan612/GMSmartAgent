enum gmsa_plan_result { NONE, FOUND, NO_PLAN, OUT_OF_BUDGET }

function gmsa_plan_planner_create(_domain, _owner, _params = {}) {
    if (!is_struct(_domain) || _domain[$ "built"] == undefined) throw "GMSA: plan planner needs a domain from gmsa_plan_domain_create";
    if (!_domain.built) throw "GMSA: plan domain '" + _domain.name + "' must be built before making planners";
    var _budget = __gmsa_param(_params, "budget", 2000);
    var _depth = __gmsa_param(_params, "depth", 32);
    if (!is_numeric(_budget) || _budget < 1) throw "GMSA: plan budget must be at least 1";
    if (!is_numeric(_depth) || _depth < 1) throw "GMSA: plan depth must be at least 1";
    return {
        domain : _domain, owner : _owner, budget : floor(_budget), depth : floor(_depth),
        result : gmsa_plan_result.NONE, goal : undefined, nodes : 0, depth_cut : false,
        plan : [], plan_count : 0,
        // imagined state and its undo log, the holder fields __gmsa_plan_apply and __gmsa_plan_undo use
        state : array_create(array_length(_domain.facts), 0), undo_fact : [], undo_value : [], undo_count : 0,
        // to-do list: a linked list in a node pool, head is the next thing to do
        __head : -1, __pool : 0, __node_kind : [], __node_index : [], __node_depth : [], __node_next : [],
        // choice points, one per task being broken down
        __frames : 0, __frame_task : [], __frame_rest : [], __frame_pool : [], __frame_undo : [], __frame_plan : [],
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
    _planner.plan_count = 0;
    _planner.undo_count = 0;
    _planner.nodes = 0;
    _planner.depth_cut = false;
    _planner.__pool = 0;
    _planner.__frames = 0;
    _planner.__order_top = 0;
    __gmsa_plan_read_facts(_d, _planner.owner, _planner);
    _planner.__head = __gmsa_plan_push_node(_planner, _root.kind, _root.index, 0, -1);
    _planner.result = __gmsa_plan_search(_planner);
    if (_planner.result != gmsa_plan_result.FOUND) _planner.plan_count = 0;
    return _planner.result == gmsa_plan_result.FOUND;
}

function gmsa_plan_last_result(_planner) {
    __gmsa_plan_check_planner(_planner);
    return _planner.result;
}

function gmsa_plan_length(_planner) {
    __gmsa_plan_check_planner(_planner);
    return _planner.plan_count;
}

function gmsa_plan_step_at(_planner, _index) {
    __gmsa_plan_check_planner(_planner);
    if (!is_numeric(_index) || _index < 0 || _index >= _planner.plan_count) return undefined;
    return _planner.domain.steps[_planner.plan[_index]].name;
}

function gmsa_plan_nodes_used(_planner) {
    __gmsa_plan_check_planner(_planner);
    return _planner.nodes;
}

// Internal
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

function __gmsa_plan_search(_p) {
    var _d = _p.domain;
    while (true) {
        var _n = _p.__head;
        if (_n == -1) return gmsa_plan_result.FOUND;
        if (_p.nodes >= _p.budget) return gmsa_plan_result.OUT_OF_BUDGET;
        var _r;
        if (_p.__node_kind[_n] == 0) {
            _p.nodes += 1;
            var _step = _d.steps[_p.__node_index[_n]];
            if (__gmsa_plan_met(_p.state, _step.requires) && (_step.check == undefined || _step.check(_p.state))) {
                __gmsa_plan_apply(_p, _step.effects);
                _p.plan[_p.plan_count] = _step.index;
                _p.plan_count += 1;
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
    _p.__frame_plan[_f] = _p.plan_count;
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
        _p.plan_count = _p.__frame_plan[_f];
        _p.__pool = _p.__frame_pool[_f];
        _p.__head = _p.__frame_rest[_f];
        var _task = _d.tasks[_p.__frame_task[_f]];
        while (_p.__frame_try[_f] < _p.__frame_count[_f]) {
            if (_p.nodes >= _p.budget) return 2;
            var _method = _task.methods[_p.__order[_p.__frame_start[_f] + _p.__frame_try[_f]]];
            _p.__frame_try[_f] += 1;
            _p.nodes += 1;
            if (!__gmsa_plan_met(_p.state, _method.requires)) continue;
            if (_method.check != undefined && !_method.check(_p.state)) continue;
            var _subs = _method.subtasks;
            var _depth = _p.__frame_depth[_f];
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