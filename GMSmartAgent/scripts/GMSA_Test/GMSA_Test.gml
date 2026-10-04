enum gmsa_test_status { PASS, FAIL, ERROR }

function __gmsa_test_state() {
    static _state = {
        suites     : [],
        results    : [],
        current    : undefined,
        suite_name : "",
    };
    return _state;
}

function gmsa_test_suite(_name, _func) {
    array_push(__gmsa_test_state().suites, { name : _name, func : _func });
}

function gmsa_test_case(_name, _func) {
    var _state = __gmsa_test_state();
    var _case = {
        suite    : _state.suite_name,
        name     : _name,
        status   : gmsa_test_status.PASS,
        messages : [],
    };
    _state.current = _case;
    try {
        _func();
    } catch (_e) {
        _case.status = gmsa_test_status.ERROR;
        array_push(_case.messages, "error: " + __gmsa_test_error_text(_e));
    }
    _state.current = undefined;
    array_push(_state.results, _case);
}

function gmsa_test_run(_verbose = false) {
    var _state = __gmsa_test_state();
    _state.results = [];
    var _count = array_length(_state.suites);
    for (var _i = 0; _i < _count; _i++) {
        var _suite = _state.suites[_i];
        _state.suite_name = _suite.name;
        try {
            _suite.func();
        } catch (_e) {
            // an error outside any case marks the whole suite
            array_push(_state.results, {
                suite    : _suite.name,
                name     : "(suite)",
                status   : gmsa_test_status.ERROR,
                messages : ["error: " + __gmsa_test_error_text(_e)],
            });
        }
    }
    _state.suite_name = "";
    return gmsa_test_report(_verbose);
}

function gmsa_test_report(_verbose = false) {
    var _results = __gmsa_test_state().results;
    var _summary = { passed : 0, failed : 0, errors : 0, total : array_length(_results) };
    var _last_suite = undefined;
    for (var _i = 0; _i < _summary.total; _i++) {
        var _case = _results[_i];
        switch (_case.status) {
            case gmsa_test_status.PASS:  _summary.passed++; break;
            case gmsa_test_status.FAIL:  _summary.failed++; break;
            case gmsa_test_status.ERROR: _summary.errors++; break;
        }
        if (!_verbose && _case.status == gmsa_test_status.PASS) continue;
        if (_case.suite != _last_suite) {
            show_debug_message("[GMSA Test] " + _case.suite);
            _last_suite = _case.suite;
        }
        show_debug_message("  " + __gmsa_test_status_text(_case.status) + " " + _case.name);
        for (var _j = 0; _j < array_length(_case.messages); _j++) {
            show_debug_message("       " + _case.messages[_j]);
        }
    }
    show_debug_message("[GMSA Test] " + string(_summary.passed) + " passed, "
        + string(_summary.failed) + " failed, " + string(_summary.errors) + " errors");
    return _summary;
}

function gmsa_test_clear() {
    var _state = __gmsa_test_state();
    _state.suites  = [];
    _state.results = [];
}

// Assertions. Each returns true on pass, false on fail, so a case can return early
function gmsa_test_assert_true(_cond, _msg = "") {
    if (_cond) return true;
    return __gmsa_test_fail("expected true, got " + __gmsa_test_text(_cond), _msg);
}

function gmsa_test_assert_false(_cond, _msg = "") {
    if (!_cond) return true;
    return __gmsa_test_fail("expected false, got " + __gmsa_test_text(_cond), _msg);
}

function gmsa_test_assert_equal(_actual, _expected, _msg = "") {
    if (__gmsa_test_equal(_actual, _expected)) return true;
    return __gmsa_test_fail("expected " + __gmsa_test_text(_expected) + ", got " + __gmsa_test_text(_actual), _msg);
}

function gmsa_test_assert_near(_actual, _expected, _tolerance = 0.0001, _msg = "") {
    if (is_numeric(_actual) && abs(_actual - _expected) <= _tolerance) return true;
    return __gmsa_test_fail("expected " + __gmsa_test_text(_expected) + " +/- " + __gmsa_test_text(_tolerance)
        + ", got " + __gmsa_test_text(_actual), _msg);
}

function gmsa_test_assert_range(_value, _min, _max, _msg = "") {
    if (is_numeric(_value) && _value >= _min && _value <= _max) return true;
    return __gmsa_test_fail("expected within [" + __gmsa_test_text(_min) + ", " + __gmsa_test_text(_max)
        + "], got " + __gmsa_test_text(_value), _msg);
}

function gmsa_test_assert_throws(_func, _msg = "") {
    try {
        _func();
    } catch (_e) {
        return true;
    }
    return __gmsa_test_fail("expected an error, none was thrown", _msg);
}

// Internal helpers
function __gmsa_test_fail(_text, _msg) {
    var _line = (_msg != "") ? (_msg + ": " + _text) : _text;
    var _case = __gmsa_test_state().current;
    if (_case == undefined) {
        show_debug_message("[GMSA Test] assertion outside a case, " + _line);
        return false;
    }
    if (_case.status == gmsa_test_status.PASS) _case.status = gmsa_test_status.FAIL;
    array_push(_case.messages, _line);
    return false;
}

function __gmsa_test_equal(_a, _b) {
    if (is_array(_a) && is_array(_b)) return array_equals(_a, _b);
    if (is_numeric(_a) && is_numeric(_b)) return _a == _b;
    if (typeof(_a) != typeof(_b)) return false;
    return _a == _b;
}

function __gmsa_test_text(_value) {
    if (is_bool(_value)) return _value ? "true" : "false";
    if (is_numeric(_value)) {
        var _s = string_format(_value, 0, 6);
        if (string_pos(".", _s) > 0) {
            while (string_char_at(_s, string_length(_s)) == "0") _s = string_delete(_s, string_length(_s), 1);
            if (string_char_at(_s, string_length(_s)) == ".") _s = string_delete(_s, string_length(_s), 1);
        }
        return _s;
    }
    return string(_value);
}

function __gmsa_test_error_text(_e) {
    if (is_struct(_e) && variable_struct_exists(_e, "message")) return _e.message;
    return string(_e);
}

function __gmsa_test_status_text(_status) {
    switch (_status) {
        case gmsa_test_status.PASS:  return "PASS ";
        case gmsa_test_status.FAIL:  return "FAIL ";
        case gmsa_test_status.ERROR: return "ERROR";
    }
    return "?    ";
}

// stubs and invariant checks. this part depends on Core
function gmsa_test_stub(_value) {
    var _stub = { value : _value, calls : 0, fn : undefined };
    _stub.fn = method(_stub, function(_agent = undefined, _target = undefined) {
        calls++;
        return is_method(value) ? value(_agent, _target) : value;
    });
    return _stub;
}

function gmsa_test_decision_problems(_decision) {
    var _problems  = [];
    var _chooser   = __gmsa_param(_decision, "chooser", gmsa_chooser.AGENT);
    var _observed  = (_chooser == gmsa_chooser.OBSERVED);
    var _evaluated = (_chooser == gmsa_chooser.EVALUATED);
    var _options   = _decision.options;
    var _count     = array_length(_options);
    var _owner_agent = __gmsa_param(_decision, "agent", undefined);
    var _features  = is_struct(_owner_agent) ? _owner_agent.profile.features : undefined;

    if (_count == 0 || _evaluated) {
        if (_decision.chosen != -1) array_push(_problems, "chosen should be -1, got " + string(_decision.chosen));
        if (_count == 0) return _problems;
    }
    var _chosen_ok = !_evaluated && (_decision.chosen >= 0 && _decision.chosen < _count);
    if (!_evaluated && !_chosen_ok) array_push(_problems, "chosen index " + string(_decision.chosen) + " out of range");

    var _sum = 0;
    for (var _i = 0; _i < _count; _i++) {
        var _o = _options[_i];
        var _tag = "option " + string(_i) + " (" + string(_o.action.name) + ") ";
        if (!is_numeric(_o.score) || is_nan(_o.score)) {
            array_push(_problems, _tag + "score is not a number");
        } else if ((_observed || _evaluated) && _o.score < 0) {
            array_push(_problems, _tag + "score must be 0 or more, got " + string(_o.score));
        } else if (!_observed && !_evaluated && _o.score <= 0) {
            array_push(_problems, _tag + "score must be positive, got " + string(_o.score));
        }
        if (!_observed && _i > 0 && _o.score > _options[_i - 1].score) array_push(_problems, _tag + "not ranked high to low");
        if (array_length(_o.features) != array_length(_o.action.considerations)) array_push(_problems, _tag + "features length does not match considerations");
        for (var _f = 0; _f < array_length(_o.features); _f++) {
            if (_o.features[_f] < 0 || _o.features[_f] > 1) array_push(_problems, _tag + "feature " + string(_f) + " outside 0..1");
        }
        if (_features != undefined) {
            if (!is_array(_o.inputs) || array_length(_o.inputs) != array_length(_features)) {
                array_push(_problems, _tag + "inputs length does not match features");
            } else {
                for (var _f = 0; _f < array_length(_o.inputs); _f++) {
                    if (_o.inputs[_f] < 0 || _o.inputs[_f] > 1) array_push(_problems, _tag + "input " + string(_f) + " outside 0..1");
                }
            }
        }
        if (_evaluated) {
            if (_o.probability != 0) array_push(_problems, _tag + "evaluated option has a probability");
        } else if (_o.probability < 0 || _o.probability > 1) {
            array_push(_problems, _tag + "probability outside 0..1");
        }
        _sum += _o.probability;
    }
    if (!_evaluated && abs(_sum - 1) > 0.0001) array_push(_problems, "probabilities sum to " + string(_sum));
    if (_chosen_ok && _options[_decision.chosen].probability <= 0) array_push(_problems, "chosen option has zero probability");
    return _problems;
}

function gmsa_test_assert_decision(_decision, _msg = "") {
    var _problems = gmsa_test_decision_problems(_decision);
    for (var _i = 0; _i < array_length(_problems); _i++) __gmsa_test_fail(_problems[_i], _msg);
    return array_length(_problems) == 0;
}

function gmsa_test_clock(_start = 0, _per_call = 0) {
    var _clock = { now : _start, per_call : _per_call, calls : 0, fn : undefined };
    _clock.fn = method(_clock, function() {
        calls++;
        var _t = now;
        now += per_call;
        return _t;
    });
    return _clock;
}

function gmsa_test_scenario(_profile, _owner, _push, _expected, _msg = "") {
    var _agent = gmsa_agent_create(_profile, _owner);
    var _names = variable_struct_get_names(_push);
    for (var _i = 0; _i < array_length(_names); _i++) {
        gmsa_agent_set_input(_agent, _names[_i], _push[$ _names[_i]]);
    }
    var _decision = gmsa_agent_think(_agent, 0, gmsa_rng_create(1));
    gmsa_test_assert_decision(_decision, _msg);
    var _option = gmsa_decision_get_chosen(_decision);
    gmsa_test_assert_equal((_option == undefined) ? undefined : _option.action.name, _expected, _msg);
    return _decision;
}