function gmsa_learn_track(_agent, _params = {}) {
    if (_agent.profile.features == undefined) {
        throw "GMSA: learn track needs a profile with features, declare them with gmsa_profile_set_features before build";
    }
    var _size   = __gmsa_param(_params, "size", 8);
    var _window = __gmsa_param(_params, "window", 3000000);
    var _clock  = __gmsa_param(_params, "clock", get_timer);
    if (!is_numeric(_size) || _size < 1 || _size != floor(_size)) throw "GMSA: learn track size must be a whole number of 1 or more";
    if (!is_numeric(_window) || _window <= 0) throw "GMSA: learn track window must be above 0";
    if (!__gmsa_callable(_clock)) throw "GMSA: learn track clock must be callable";

    var _history = {
        agent   : _agent,
        size    : _size,
        window  : _window,
        clock   : _clock,
        entries : [],         // oldest first
        current : undefined,  // the entry the agent is acting on right now
    };
    _agent.__history = _history;
    _agent.__track = method(_history, __gmsa_learn_track_hook);
    return _agent;
}

function gmsa_learn_untrack(_agent) {
    _agent.__track = undefined;
    _agent.__history = undefined;
}

function gmsa_learn_remember(_agent) {
    var _history = __gmsa_learn_history_of(_agent);
    return _history.current;
}

function gmsa_learn_history(_agent) {
    return __gmsa_learn_history_of(_agent).entries;
}

// Internal
function __gmsa_learn_history_of(_agent) {
    var _history = _agent[$ "__history"];
    if (_history == undefined) throw "GMSA: agent isn't tracked, start with gmsa_learn_track";
    return _history;
}

function __gmsa_learn_track_hook(_option, _same) {
    var _now = clock();
    if (_same && current != undefined) {  // still doing it
        current.last = _now;
        return;
    }
    if (current != undefined) {           // the previous decision ends now
        current.last = _now;
        current.active = false;
        current = undefined;
    }
    if (_option == undefined) return;

    var _decision = agent.decision;
    var _options = _decision.options;
    var _n = array_length(_options);
    var _chosen = -1;
    for (var _i = 0; _i < _n; _i++) {
        if (_options[_i] == _option) { _chosen = _i; break; }
    }
    if (_chosen < 0) return;

    var _copy = array_create(_n, undefined);
    for (var _i = 0; _i < _n; _i++) {
        var _o = _options[_i];
        var _len = array_length(_o.inputs);
        var _inputs = array_create(_len, 0);
        array_copy(_inputs, 0, _o.inputs, 0, _len);
        _copy[_i] = { action : _o.action, inputs : _inputs };
    }
    var _entry = {
        agent       : agent,
        options     : _copy,
        chosen      : _chosen,
        probability : _option.probability,  // the odds of this choice, corrects outcome learning for what was rarely tried
        start       : _now,
        last        : _now,                 // last time the agent was acting on it
        active      : true,
    };
    array_push(entries, _entry);
    if (array_length(entries) > size) array_delete(entries, 0, 1);
    current = _entry;
}