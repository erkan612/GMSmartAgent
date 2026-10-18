function gmsa_observe(_agent, _options, _chosen, _now = get_timer()) {
    if (!is_array(_options) || array_length(_options) == 0) throw "GMSA: observe needs at least one offered option";
    var _count = array_length(_options);
    if (!is_numeric(_chosen) || frac(_chosen) != 0 || _chosen < 0 || _chosen >= _count) {
        throw "GMSA: observe chosen index " + string(_chosen) + " is out of range";
    }

    var _profile  = _agent.profile;
    var _decision = _agent.decision;
    var _out      = _decision.options;
    var _cache    = __gmsa_think_begin(_agent);
    array_resize(_out, 0);

    for (var _i = 0; _i < _count; _i++) {
        var _entry  = _options[_i];
        var _key    = _entry;
        var _target = undefined;
        if (is_struct(_entry)) {
            _key    = __gmsa_param(_entry, "action", undefined);
            _target = __gmsa_param(_entry, "target", undefined);
        }
        var _idx = __gmsa_resolve_index(_profile.action_index, _key, array_length(_profile.actions), "action");
        var _action = _profile.actions[_idx];
        if (_action.targets != undefined && _target == undefined) {
            throw "GMSA: observed action '" + _action.name + "' needs a target";
        }
        var _option = __gmsa_option_take(_cache);
        _option.action      = _action;
        _option.target      = _target;
        var _slot = (_target != undefined) ? __gmsa_slots_alloc(_cache, 1, array_length(_profile.inputs)) : -1;
        _option.score       = __gmsa_score_option(_agent, _action, _target, _option, true, _slot);
        if (_profile.features != undefined) __gmsa_option_fill_inputs(_agent, _option, _target, _slot);
        _option.order       = _i;
        _option.probability = (_i == _chosen) ? 1 : 0;
        array_push(_out, _option);
    }

    _decision.chooser = gmsa_chooser.OBSERVED;
    _decision.time    = _now;
    _decision.chosen  = _chosen;
    _decision.fresh   = true;
    return _decision;
}