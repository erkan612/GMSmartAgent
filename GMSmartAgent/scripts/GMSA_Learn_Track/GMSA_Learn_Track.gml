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

function gmsa_learn_outcome(_model, _ticket, _reward, _note = undefined) {
    __gmsa_learn_check_outcome(_model, _reward);
    if (!is_struct(_ticket) || !is_array(_ticket[$ "options"])) throw "GMSA: learn outcome needs a ticket from gmsa_learn_remember";
    if (_model.frozen) return false;
    __gmsa_learn_outcome_one(_model, _ticket, _reward, 1, _note);
    __gmsa_learn_invalidate(_model);
    return true;
}

function gmsa_learn_reward(_model, _agent, _reward, _note = undefined) {
    __gmsa_learn_check_outcome(_model, _reward);
    var _history = __gmsa_learn_history_of(_agent);
    if (_model.frozen) return 0;
    var _now = _history.clock();
    var _window = _history.window;
    var _entries = _history.entries;
    var _count = 0;
    for (var _i = 0; _i < array_length(_entries); _i++) {
        var _entry = _entries[_i];
        var _age = _entry.active ? 0 : _now - _entry.last;
        if (_age >= _window) continue;
        __gmsa_learn_outcome_one(_model, _entry, _reward, 1 - _age / _window, _note);
        _count += 1;
    }
    if (_count > 0) __gmsa_learn_invalidate(_model);
    return _count;
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

function __gmsa_learn_check_outcome(_model, _reward) {
    if (!is_struct(_model) || _model[$ "tier"] == undefined) throw "GMSA: learn outcome needs a model";
    if (_model.learns != gmsa_learn_target.OUTCOMES) {
        throw "GMSA: this model learns from choices, create it with learns : gmsa_learn_target.OUTCOMES to learn from outcomes";
    }
    if (!is_numeric(_reward) || is_nan(_reward)) throw "GMSA: learn outcome reward must be a number";
}

function __gmsa_learn_outcome_one(_model, _entry, _reward, _credit, _note = undefined) {
    var _sample = __gmsa_learn_sample(_model, _entry, _entry.chosen);
    // options the agent rarely picks count more when they are picked, so they aren't misjudged from little data
    var _p = _entry.probability;
    var _odds = (_p * GMSA_LEARN_ODDS_CLIP > 1) ? 1 / _p : GMSA_LEARN_ODDS_CLIP;
    _sample.weight = _credit * _odds;
    _sample.reward = _reward;
    _sample.note = __gmsa_learn_note(_note);
    _model.samples = _model.samples * _model.decay + _credit;
    _model.observe(_sample);
}