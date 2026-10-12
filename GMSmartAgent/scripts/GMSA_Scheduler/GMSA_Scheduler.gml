function gmsa_scheduler_create(_budget = 2000, _params = {}) {
    if (!is_numeric(_budget) || _budget < 0) throw "GMSA: scheduler budget must be 0 or more";
    var _clock = __gmsa_param(_params, "clock", get_timer);
    if (!is_callable(_clock)) throw "GMSA: scheduler clock must be callable";
    var _share = __gmsa_param(_params, "share", 0.2);
    __gmsa_scheduler_check_share(_share);
    return {
        budget : _budget,
        share  : _share, // what each tier leaves for the tiers below it, of what's left in the step
        clock  : _clock,
        rng    : gmsa_rng_create(__gmsa_param(_params, "seed", 1)),
        tiers  : [], // sorted by priority, highest first
        count  : 0,
        queue  : [], // agents waiting for on_decide
        stats  : { thinks : 0, works : 0, time : 0, stopped : false }, // last step
        __run  : { start : 0, now : 0, thinks : 0, works : 0, stopped : false }, // the step in progress
    };
}

function gmsa_scheduler_add(_scheduler, _agent) {
    if (_agent.__scheduler != undefined) throw "GMSA: agent is already in a scheduler";
    var _tier = __gmsa_scheduler_tier(_scheduler, _agent.priority);
    array_push(_tier.agents, _agent);
    _agent.__scheduler = { scheduler : _scheduler, tier : _tier };
    _agent.rng = _scheduler.rng;
    _scheduler.count++;
    return _agent;
}

function gmsa_scheduler_remove(_scheduler, _agent) {
    var _slot = _agent.__scheduler;
    if (_slot == undefined || _slot.scheduler != _scheduler) return false;
    var _tier = _slot.tier;
    var _n = array_length(_tier.agents);
    for (var _i = 0; _i < _n; _i++) {
        if (_tier.agents[_i] == _agent) {
            array_delete(_tier.agents, _i, 1);
            if (_i < _tier.cursor) _tier.cursor--;
            break;
        }
    }
    _agent.__scheduler = undefined;
    _agent.rng = undefined;
    _scheduler.count--;
    return true;
}

function gmsa_scheduler_add_work(_scheduler, _work, _priority = 0) {
    if (!is_struct(_work) || !__gmsa_callable(_work[$ "work"])) throw "GMSA: scheduler work needs a struct with a work(budget) method";
    if (_work[$ "__scheduler"] != undefined) throw "GMSA: work is already in a scheduler";
    if (!is_numeric(_priority)) throw "GMSA: scheduler work priority must be a number";
    var _tier = __gmsa_scheduler_tier(_scheduler, _priority);
    array_push(_tier.works, _work);
    _work.__scheduler = { scheduler : _scheduler, tier : _tier };
    return _work;
}

function gmsa_scheduler_remove_work(_scheduler, _work) {
    var _slot = _work[$ "__scheduler"];
    if (_slot == undefined || _slot.scheduler != _scheduler) return false;
    var _tier = _slot.tier;
    for (var _i = 0; _i < array_length(_tier.works); _i++) {
        if (_tier.works[_i] == _work) {
            array_delete(_tier.works, _i, 1);
            if (_i < _tier.work_cursor) _tier.work_cursor--;
            break;
        }
    }
    _work.__scheduler = undefined;
    return true;
}

function gmsa_scheduler_step(_scheduler) {
    var _clock  = _scheduler.clock;
    var _run    = _scheduler.__run;
    _run.start   = _clock();
    _run.now     = _run.start;
    _run.thinks  = 0;
    _run.works   = 0;
    _run.stopped = false;
    var _budget = _scheduler.budget;
    var _share  = _scheduler.share;
    var _tiers  = _scheduler.tiers;
    var _nt     = array_length(_tiers);

    // first pass, highest tier first: each tier leaves a share of what's left for the tiers below it
    var _cut = false;
    for (var _ti = 0; _ti < _nt && !_run.stopped; _ti++) {
        var _tier = _tiers[_ti];
        _tier.visited = 0;
        _tier.cut = false;
        _tier.idle = (array_length(_tier.works) == 0); // no work, or a pass found none: skip work for the rest of the step
        var _cap = _budget;
        if (_ti < _nt - 1 && _share * 1000000000000 > 0) {
            var _used = (_run.thinks + _run.works > 0) ? _clock() - _run.start : 0;
            _cap = _used + (1 - _share) * max(0, _budget - _used);
        }
        __gmsa_scheduler_run_tier(_scheduler, _tier, _cap);
        if (_tier.cut) _cut = true;
    }

    // second pass: what the lower tiers left goes back to the tiers that stopped at their share, highest first
    for (var _tj = 0; _tj < _nt && _cut && !_run.stopped; _tj++) {
        var _back = _tiers[_tj];
        if (!_back.cut) continue;
        _back.cut = false;
        __gmsa_scheduler_run_tier(_scheduler, _back, _budget);
    }

    var _stats = _scheduler.stats;
    _stats.thinks  = _run.thinks;
    _stats.works   = _run.works;
    _stats.time    = _clock() - _run.start;
    _stats.stopped = _run.stopped;

    // callbacks run outside the timed loop
    var _queue = _scheduler.queue;
    var _qn = array_length(_queue);
    for (var _i = 0; _i < _qn; _i++) _queue[_i].on_decide(_queue[_i]);
    array_resize(_queue, 0);

    return _run.thinks;
}

function gmsa_scheduler_count(_scheduler) {
    return _scheduler.count;
}

function gmsa_scheduler_set_budget(_scheduler, _budget) {
    if (!is_numeric(_budget) || _budget < 0) throw "GMSA: scheduler budget must be 0 or more";
    _scheduler.budget = _budget;
}

function gmsa_scheduler_set_share(_scheduler, _share) {
    __gmsa_scheduler_check_share(_share);
    _scheduler.share = _share;
}

function __gmsa_scheduler_check_share(_share) {
    if (!is_numeric(_share) || _share < 0 || _share >= 1) throw "GMSA: scheduler share must be 0 or more and below 1";
}

function __gmsa_scheduler_run_tier(_scheduler, _tier, _cap) { // one tier's turn: its agents first, then its work, which they leave a share the way a tier leaves one for the tiers below. What the work doesn't use goes back to the agents
    var _run   = _scheduler.__run;
    var _clock = _scheduler.clock;
    var _share = _scheduler.share;

    // the agents, leaving the tier's work its share of what's left
    var _agents_cap = _cap;
    var _final = true;
    if (!_tier.idle && _share * 1000000000000 > 0) {
        var _used = (_run.thinks + _run.works > 0) ? _clock() - _run.start : 0;
        _agents_cap = _used + (1 - _share) * max(0, _cap - _used);
        _final = false;
    }
    var _waiting = __gmsa_scheduler_run_agents(_scheduler, _tier, _agents_cap, _final);

    // the work, up to the tier's cap
    while (!_run.stopped && !_tier.cut && !_tier.idle) {
        var _now_used = _clock() - _run.start;
        if (_run.thinks + _run.works > 0) {
            if (_now_used >= _scheduler.budget) { _run.stopped = true; break; }
            if (_now_used >= _cap) { _tier.cut = true; break; }
        }
        if (__gmsa_scheduler_work_turn(_tier, max(1, _cap - _now_used))) _run.works++;
        else _tier.idle = true;
    }

    // what the work left goes back to the agents
    if (_waiting && !_run.stopped && !_tier.cut) __gmsa_scheduler_run_agents(_scheduler, _tier, _cap, true);
}

function __gmsa_scheduler_run_agents(_scheduler, _tier, _cap, _final) { // the tier's due agents in turn, until each was looked at, the cap or the budget. Returns true when it stopped at the cap with agents left; at a final cap the tier is cut, to get time back if the lower tiers leave some
    var _run    = _scheduler.__run;
    var _clock  = _scheduler.clock;
    var _start  = _run.start;
    var _now    = _run.now;
    var _budget = _scheduler.budget;
    var _rng    = _scheduler.rng;
    var _queue  = _scheduler.queue;
    var _agents = _tier.agents;
    var _n = array_length(_agents);
    var _k = _tier.visited; // agents already looked at this step, so a tier that gets time back never thinks anyone twice
    var _held = false;

    while (_k < _n) {
        if (_tier.cursor >= _n) _tier.cursor = 0;
        var _agent = _agents[_tier.cursor];
        var _due = _agent.__wake || (_agent.last_think == undefined) || (_now - _agent.last_think >= _agent.interval);
        if (!_due) {
            _tier.cursor++;
            _k++;
            continue;
        }
        if (_run.thinks + _run.works > 0) {
            var _used = _clock() - _start;
            if (_used >= _budget) { _run.stopped = true; break; }
            if (_used >= _cap) {
                if (_final) _tier.cut = true;
                _held = true;
                break;
            }
        }
        _tier.cursor++;
        _k++;
        gmsa_agent_think(_agent, _now, _rng);
        _run.thinks++;
        if (_agent.on_decide != undefined) array_push(_queue, _agent);
    }
    _tier.visited = _k;
    return _held;
}

function gmsa_scheduler_set_seed(_scheduler, _seed) {
    gmsa_rng_seed(_scheduler.rng, _seed);
}

function gmsa_scheduler_set_clock(_scheduler, _clock) {
    if (!is_callable(_clock)) throw "GMSA: scheduler clock must be callable";
    _scheduler.clock = _clock;
}

function __gmsa_scheduler_tier(_scheduler, _priority) {
    var _tiers = _scheduler.tiers;
    var _n = array_length(_tiers);
    var _i = 0;
    for (; _i < _n; _i++) {
        if (_tiers[_i].priority == _priority) return _tiers[_i];
        if (_tiers[_i].priority < _priority) break;
    }
    var _tier = { priority : _priority, agents : [], cursor : 0, works : [], work_cursor : 0, visited : 0, cut : false, idle : true };
    array_insert(_tiers, _i, _tier);
    return _tier;
}

function __gmsa_scheduler_work_turn(_tier, _budget) {
    var _list = _tier.works;
    var _n = array_length(_list);
    for (var _k = 0; _k < _n; _k++) {
        if (_tier.work_cursor >= _n) _tier.work_cursor = 0;
        var _work = _list[_tier.work_cursor];
        _tier.work_cursor++;
        if (_work.work(_budget)) return true;
    }
    return false;
}

function gmsa_scheduler_set_priority(_scheduler, _agent, _priority) {
    var _slot = _agent.__scheduler;
    if (_slot == undefined || _slot.scheduler != _scheduler) return false;
    if (_slot.tier.priority != _priority) {
        gmsa_scheduler_remove(_scheduler, _agent);
        _agent.priority = _priority;
        gmsa_scheduler_add(_scheduler, _agent);
    }
    return true;
}