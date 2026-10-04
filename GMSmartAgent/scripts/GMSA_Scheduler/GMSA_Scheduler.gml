function gmsa_scheduler_create(_budget = 2000, _params = {}) {
    if (!is_numeric(_budget) || _budget < 0) throw "GMSA: scheduler budget must be 0 or more";
    var _clock = __gmsa_param(_params, "clock", get_timer);
    if (!is_callable(_clock)) throw "GMSA: scheduler clock must be callable";
    return {
        budget : _budget,
        clock  : _clock,
        rng    : gmsa_rng_create(__gmsa_param(_params, "seed", 1)),
        tiers  : [], // sorted by priority, highest first
        count  : 0,
        queue  : [], // agents waiting for on_decide
        stats  : { thinks : 0, time : 0, stopped : false }, // last step
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

function gmsa_scheduler_step(_scheduler) {
    var _clock   = _scheduler.clock;
    var _start   = _clock();
    var _now     = _start;
    var _budget  = _scheduler.budget;
    var _thinks  = 0;
    var _stopped = false;
    var _tiers   = _scheduler.tiers;

    for (var _ti = 0; _ti < array_length(_tiers) && !_stopped; _ti++) {
        var _tier = _tiers[_ti];
        var _n = array_length(_tier.agents);
        for (var _k = 0; _k < _n; _k++) {
            if (_tier.cursor >= _n) _tier.cursor = 0;
            var _agent = _tier.agents[_tier.cursor];
            var _due = (_agent.last_think == undefined) || (_now - _agent.last_think >= _agent.interval);
            if (!_due) {
                _tier.cursor++;
                continue;
            }
            if (_thinks > 0 && _clock() - _start >= _budget) {
                _stopped = true;
                break;
            }
            _tier.cursor++;
            gmsa_agent_think(_agent, _now, _scheduler.rng);
            _thinks++;
            if (_agent.on_decide != undefined) array_push(_scheduler.queue, _agent);
        }
    }

    var _stats = _scheduler.stats;
    _stats.thinks  = _thinks;
    _stats.time    = _clock() - _start;
    _stats.stopped = _stopped;

    // callbacks run outside the timed loop
    var _queue = _scheduler.queue;
    var _qn = array_length(_queue);
    for (var _i = 0; _i < _qn; _i++) _queue[_i].on_decide(_queue[_i]);
    array_resize(_queue, 0);

    return _thinks;
}

function gmsa_scheduler_count(_scheduler) {
    return _scheduler.count;
}

function gmsa_scheduler_set_budget(_scheduler, _budget) {
    if (!is_numeric(_budget) || _budget < 0) throw "GMSA: scheduler budget must be 0 or more";
    _scheduler.budget = _budget;
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
    var _tier = { priority : _priority, agents : [], cursor : 0 };
    array_insert(_tiers, _i, _tier);
    return _tier;
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