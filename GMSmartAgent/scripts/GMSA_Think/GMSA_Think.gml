function gmsa_agent_think(_agent, _now = get_timer(), _rng = undefined) {
    var _profile  = _agent.profile;
    var _decision = _agent.decision;
    var _options  = _decision.options;
    if (_rng == undefined) _rng = (_agent.rng != undefined) ? _agent.rng : __gmsa_default_rng();

    var _cache = __gmsa_think_begin(_agent);
    array_resize(_options, 0);

    var _actions      = _profile.actions;
    var _action_count = array_length(_actions);
    var _input_count  = array_length(_profile.inputs);
    var _current      = _agent.current;
    var _order        = 0;

    for (var _a = 0; _a < _action_count; _a++) {
        var _action = _actions[_a];
        if (_now < _agent.cooldowns[_a]) continue;

        var _targets = __gmsa_no_target();
        var _base = -1;
        if (_action.targets != undefined) {
            _targets = _action.targets(_agent);
            if (_targets == undefined) continue;
            if (!is_array(_targets)) throw "GMSA: targets of action '" + _action.name + "' must return an array";
            _base = __gmsa_slots_for_array(_cache, _targets, _input_count);
        }

        var _target_count = array_length(_targets);
        for (var _t = 0; _t < _target_count; _t++) {
            var _target = _targets[_t];
            var _option = __gmsa_option_take(_cache);
            var _score  = __gmsa_score_option(_agent, _action, _target, _option, false, (_base >= 0) ? _base + _t : -1);
            if (_score <= 0) {
                _cache.pool_used--;
                continue;
            }
            if (_current != undefined && _current.action == _a && _current.target == _target) {
                _score *= 1 + _profile.commitment;
            }
            if (_profile.features != undefined) __gmsa_option_fill_inputs(_agent, _option, _target, (_base >= 0) ? _base + _t : -1);
            _option.action = _action;
            _option.target = _target;
            _option.score  = _score;
            _option.order  = _order++;

            // binary search for the ranked position, equal scores keep insertion order
            var _lo = 0;
            var _hi = array_length(_options);
            while (_lo < _hi) {
                var _mid = (_lo + _hi) >> 1;
                if (_options[_mid].score >= _score) _lo = _mid + 1;
                else _hi = _mid;
            }
            array_insert(_options, _lo, _option);
        }
    }

    var _count  = array_length(_options);
    var _chosen = -1;
    if (_count > 0) {
        if (_profile.select == gmsa_select.TOP_N_WEIGHTED && _count > 1) {
            _chosen = __gmsa_select_weighted(_options, _profile.top_n, _rng);
        } else {
            _chosen = 0;
            _options[0].probability = 1;
        }
        var _picked = _options[_chosen].action;
        if (_picked.cooldown > 0) _agent.cooldowns[_picked.index] = _now + _picked.cooldown;
    }

    _decision.chooser = gmsa_chooser.AGENT;
    _decision.time    = _now;
    _decision.chosen  = _chosen;
    _decision.fresh   = true;
    _agent.last_think = _now;
    return _decision;
}

function gmsa_decision_get_chosen(_decision) {
    return (_decision.chosen >= 0) ? _decision.options[_decision.chosen] : undefined;
}

function gmsa_agent_evaluate(_agent, _now = get_timer()) {
    var _eval = _agent.__eval;
    if (_eval == undefined) {
        _eval = {
            pool      : [],
            pool_used : 0,
            decision  : { agent : _agent, chooser : gmsa_chooser.EVALUATED, time : 0, options : [], chosen : -1, fresh : false },
        };
        _agent.__eval = _eval;
    }
    var _profile  = _agent.profile;
    var _decision = _eval.decision;
    var _options  = _decision.options;
    var _cache    = __gmsa_think_begin(_agent);
    _eval.pool_used = 0;
    array_resize(_options, 0);

    var _actions      = _profile.actions;
    var _action_count = array_length(_actions);
    var _input_count  = array_length(_profile.inputs);
    var _order        = 0;

    for (var _a = 0; _a < _action_count; _a++) {
        var _action = _actions[_a];
        if (_now < _agent.cooldowns[_a]) continue;

        var _targets = __gmsa_no_target();
        var _base = -1;
        if (_action.targets != undefined) {
            _targets = _action.targets(_agent);
            if (_targets == undefined) continue;
            if (!is_array(_targets)) throw "GMSA: targets of action '" + _action.name + "' must return an array";
            _base = __gmsa_slots_for_array(_cache, _targets, _input_count);
        }

        var _target_count = array_length(_targets);
        for (var _t = 0; _t < _target_count; _t++) {
            var _target = _targets[_t];
            var _slot   = (_base >= 0) ? _base + _t : -1;
            var _option = __gmsa_option_take(_eval);
            var _score  = __gmsa_score_option(_agent, _action, _target, _option, true, _slot);
            if (_profile.features != undefined) __gmsa_option_fill_inputs(_agent, _option, _target, _slot);
            _option.action = _action;
            _option.target = _target;
            _option.score  = _score;
            _option.order  = _order++;

            // ranked, equal scores keep creation order, vetoed options end up last
            var _lo = 0;
            var _hi = array_length(_options);
            while (_lo < _hi) {
                var _mid = (_lo + _hi) >> 1;
                if (_options[_mid].score >= _score) _lo = _mid + 1;
                else _hi = _mid;
            }
            array_insert(_options, _lo, _option);
        }
    }

    _decision.time   = _now;
    _decision.chosen = -1;
    _decision.fresh  = false;
    return _decision;
}

// Internal
function __gmsa_cache_create(_input_count, _pool_size) {
    var _cache = {
        stamp         : 0,
        values        : array_create(_input_count, 0), // non-target pull inputs, normalized
        stamps        : array_create(_input_count, -1),
        arrays        : [], // targets arrays seen this think
        array_lengths : [],
        array_bases   : [],
        array_count   : 0,
        slot_count    : 0,
        target_values : [], // [slot][input], normalized
        target_stamps : [],
        pool          : [],
        pool_used     : 0,
    };
    repeat (_pool_size) array_push(_cache.pool, __gmsa_option_make());
    return _cache;
}

function __gmsa_think_begin(_agent) {
    var _cache = _agent.__cache;
    _cache.stamp++;
    _cache.array_count = 0;
    _cache.slot_count  = 0;
    _cache.pool_used   = 0;
    return _cache;
}

function __gmsa_slots_for_array(_cache, _array, _input_count) {
    var _len = array_length(_array);
    var _n = _cache.array_count;
    for (var _i = 0; _i < _n; _i++) {
        if (_cache.arrays[_i] == _array && _cache.array_lengths[_i] == _len) return _cache.array_bases[_i];
    }
    var _base = __gmsa_slots_alloc(_cache, _len, _input_count);
    _cache.arrays[_n]        = _array;
    _cache.array_lengths[_n] = _len;
    _cache.array_bases[_n]   = _base;
    _cache.array_count       = _n + 1;
    return _base;
}

function __gmsa_slots_alloc(_cache, _count, _input_count) {
    var _base = _cache.slot_count;
    var _need = _base + _count;
    while (array_length(_cache.target_values) < _need) {
        array_push(_cache.target_values, array_create(_input_count, 0));
        array_push(_cache.target_stamps, array_create(_input_count, -1));
    }
    _cache.slot_count = _need;
    return _base;
}

function __gmsa_score_option(_agent, _action, _target, _option, _full, _slot) {
    var _cons   = _action.considerations;
    var _n      = array_length(_cons);
    var _inputs = _agent.profile.inputs;
    var _cache  = _agent.__cache;
    var _stamp  = _cache.stamp;
    var _score  = 1;
    array_resize(_option.features, _n);

    for (var _c = 0; _c < _n; _c++) {
        var _con   = _cons[_c];
        var _idx   = _con.input_index;
        var _input = _inputs[_idx];
        var _value, _raw;
        if (_input.source == gmsa_source.PUSH) {
            _raw = _agent.push[_idx];
            _value = (is_numeric(_raw) && !is_nan(_raw)) ? clamp((_raw - _input.min) / (_input.max - _input.min), 0, 1) : 0;
        } else if (!_input.per_target) {
            if (_cache.stamps[_idx] != _stamp) {
                _raw = _input.callback(_agent, undefined);
                _cache.values[_idx] = (is_numeric(_raw) && !is_nan(_raw)) ? clamp((_raw - _input.min) / (_input.max - _input.min), 0, 1) : 0;
                _cache.stamps[_idx] = _stamp;
            }
            _value = _cache.values[_idx];
        } else {
            if (_cache.target_stamps[_slot][_idx] != _stamp) {
                _raw = _input.callback(_agent, _target);
                _cache.target_values[_slot][_idx] = (is_numeric(_raw) && !is_nan(_raw)) ? clamp((_raw - _input.min) / (_input.max - _input.min), 0, 1) : 0;
                _cache.target_stamps[_slot][_idx] = _stamp;
            }
            _value = _cache.target_values[_slot][_idx];
        }
        var _y = gmsa_curve_eval(_con.curve, _value);
        _option.features[_c] = _y;
        _score *= _y;
        if (_score <= 0 && !_full) return 0;
    }
    if (_score <= 0) return 0;
    if (_n > 1) {
        var _mod = 1 - 1 / _n;
        _score += (1 - _score) * _mod * _score;
    }
    return _score * _action.weight;
}

function __gmsa_read_input(_agent, _idx, _target, _slot) {
    var _input = _agent.profile.inputs[_idx];
    var _cache = _agent.__cache;
    if (_input.source == gmsa_source.PUSH) return gmsa_input_normalize(_input, _agent.push[_idx]);
    if (!_input.per_target) {
        if (_cache.stamps[_idx] != _cache.stamp) {
            _cache.values[_idx] = gmsa_input_normalize(_input, _input.callback(_agent, undefined));
            _cache.stamps[_idx] = _cache.stamp;
        }
        return _cache.values[_idx];
    }
    if (_slot < 0) return 0;
    if (_cache.target_stamps[_slot][_idx] != _cache.stamp) {
        _cache.target_values[_slot][_idx] = gmsa_input_normalize(_input, _input.callback(_agent, _target));
        _cache.target_stamps[_slot][_idx] = _cache.stamp;
    }
    return _cache.target_values[_slot][_idx];
}

function __gmsa_option_fill_inputs(_agent, _option, _target, _slot) {
    var _features = _agent.profile.features;
    var _n = array_length(_features);
    if (_option.inputs == undefined) _option.inputs = array_create(_n, 0);
    else array_resize(_option.inputs, _n);
    for (var _i = 0; _i < _n; _i++) _option.inputs[_i] = __gmsa_read_input(_agent, _features[_i], _target, _slot);
}

function __gmsa_option_make() {
    return {
        action      : undefined,
        target      : undefined,
        score       : 0,
        features    : [],
        probability : 0,
        order       : 0,
        inputs      : undefined, // reserved for Learn
    };
}

function __gmsa_option_take(_cache) {
    if (_cache.pool_used >= array_length(_cache.pool)) array_push(_cache.pool, __gmsa_option_make());
    var _option = _cache.pool[_cache.pool_used];
    _cache.pool_used++;
    _option.probability = 0;
    return _option;
}

function __gmsa_select_weighted(_options, _top_n, _rng) {
    var _n = min(_top_n, array_length(_options));
    var _sum = 0;
    var _i;
    for (_i = 0; _i < _n; _i++) _sum += _options[_i].score;
    for (_i = 0; _i < _n; _i++) _options[_i].probability = _options[_i].score / _sum;
    var _r = gmsa_rng_next(_rng) * _sum;
    for (_i = 0; _i < _n; _i++) {
        _r -= _options[_i].score;
        if (_r < 0) return _i;
    }
    return _n - 1;
}

function __gmsa_no_target() {
    static _none = [undefined];
    return _none;
}

function __gmsa_input_value(_agent, _index, _target) {
    var _input = _agent.profile.inputs[_index];
    if (_input.source == gmsa_source.PUSH) return gmsa_input_normalize(_input, _agent.push[_index]);

    var _cache = _agent.__cache;
    var _stamp = _cache.stamp;
    if (!_input.per_target) {
        if (_cache.stamps[_index] != _stamp) {
            _cache.values[_index] = gmsa_input_normalize(_input, _input.callback(_agent, undefined));
            _cache.stamps[_index] = _stamp;
        }
        return _cache.values[_index];
    }

    var _slot = __gmsa_target_slot(_cache, _target, array_length(_agent.profile.inputs));
    if (_cache.target_stamps[_slot][_index] != _stamp) {
        _cache.target_values[_slot][_index] = gmsa_input_normalize(_input, _input.callback(_agent, _target));
        _cache.target_stamps[_slot][_index] = _stamp;
    }
    return _cache.target_values[_slot][_index];
}

function __gmsa_target_slot(_cache, _target, _input_count) {
    var _n = _cache.target_count;
    for (var _i = 0; _i < _n; _i++) {
        if (_cache.targets[_i] == _target) return _i;
    }
    if (_n >= array_length(_cache.target_values)) {
        array_push(_cache.target_values, array_create(_input_count, 0));
        array_push(_cache.target_stamps, array_create(_input_count, -1));
    }
    _cache.targets[_n] = _target;
    _cache.target_count = _n + 1;
    return _n;
}