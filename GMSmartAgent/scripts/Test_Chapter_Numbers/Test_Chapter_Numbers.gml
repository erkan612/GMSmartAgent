function test_chapter_numbers() {
    gmsa_test_suite("Chapter numbers", function() {

        // Testing_Whole_Behaviors.md
        gmsa_test_case("guard, no fix: 9 switches, twitching until 10.50, home at 13.5", function() {
            var _run = __chk_guard_sim(30, [{ frame : 60, x : 200, y : 0 }], 0);
            gmsa_test_assert_equal(array_length(_run.trace) - 1, 9, "switches");
            gmsa_test_assert_equal(_run.trace[array_length(_run.trace) - 1].time, 10.5, "last switch");
            gmsa_test_assert_near(_run.home, 13.5, 0.001, "home");
        });
        gmsa_test_case("guard, first fix: the golden trace, home at 12", function() {
            var _run = __chk_guard_sim(30, [{ frame : 60, x : 200, y : 0 }], 1);
            gmsa_test_assert_equal(__chk_trace_text(_run.trace), "guard_post 0.00, investigate 1.00, search 4.00, guard_post 9.00");
            gmsa_test_assert_near(_run.home, 12, 0.001, "home");
        });
        gmsa_test_case("guard, first fix: a second noise is dropped", function() {
            var _run = __chk_guard_sim(30, [{ frame : 60, x : 200, y : 0 }, { frame : 360, x : -150, y : 0 }], 1);
            gmsa_test_assert_equal(__chk_trace_text(_run.trace), "guard_post 0.00, investigate 1.00, search 4.00, investigate 6.00, guard_post 6.25");
        });
        gmsa_test_case("guard, second fix: both noises searched", function() {
            var _run = __chk_guard_sim(30, [{ frame : 60, x : 200, y : 0 }, { frame : 360, x : -150, y : 0 }], 2);
            gmsa_test_assert_equal(__chk_trace_text(_run.trace), "guard_post 0.00, investigate 1.00, search 4.00, investigate 6.00, search 11.25, guard_post 15.25");
            gmsa_test_assert_near(_run.guard.x, 0, 1, "back at his post");
        });
        gmsa_test_case("guard, second fix: idle for a minute", function() {
            var _run = __chk_guard_sim(60, [], 2);
            gmsa_test_assert_equal(__chk_trace_text(_run.trace), "guard_post 0.00");
        });
        gmsa_test_case("guard, second fix: ten minutes of random noises", function() {
            var _g = __chk_guard_create();
            var _rng = gmsa_rng_create(1);
            var _events = gmsa_rng_create(7);
            var _far = 0;
            var _long = 0;
            for (var _f = 0; _f < 10 * 60 * 60; _f++) {
                if (gmsa_rng_next(_events) < 1 / 600) {
                    var _x = gmsa_rng_next(_events) * 500 - 250;
                    __chk_guard_hear(_g, _x, gmsa_rng_next(_events) * 500 - 250);
                }
                if (_f mod 15 == 0) {
                    var _d = gmsa_agent_think(_g.agent, _f * 16667, _rng);
                    if (array_length(gmsa_test_decision_problems(_d)) > 0) { gmsa_test_assert_true(false, "problems at frame " + string(_f)); return; }
                    __chk_guard_choose(_g, gmsa_decision_get_chosen(_d), 2);
                }
                __chk_guard_act(_g, 1 / 60);
                _far = max(_far, point_distance(_g.x, _g.y, 0, 0));
                if (_g.job == "search") _long = max(_long, _g.search_time);
            }
            gmsa_test_assert_near(_far, 300, 0.01, "farthest from post");
            gmsa_test_assert_near(_long, 6.0167, 0.001, "longest search");
        });

        // Learning_From_The_Player.md
        gmsa_test_case("thief: the designer scores the silver 0.645 and the painting 0.443", function() {
            var _thief = {
                x : 0, y : 0, bag : 0, bag_size : 5,
                loot : [{ x : 80, y : 0, value : 30 }, { x : 260, y : 0, value : 90 }],
                find_loot : function() { return loot; },
                guard_distance : function(_target) { return 400; },
            };
            var _agent = gmsa_agent_create(__chk_thief_profile(), _thief);
            var _e = gmsa_agent_evaluate(_agent);
            for (var _i = 0; _i < array_length(_e.options); _i++) {
                var _o = _e.options[_i];
                if (_o.target == _thief.loot[0]) gmsa_test_assert_near(_o.score, 0.6448, 0.0005, "silver");
                if (_o.target == _thief.loot[1]) gmsa_test_assert_near(_o.score, 0.4435, 0.0005, "painting");
            }
        });

        // A_Decision_That_Looks_Wrong.md
        gmsa_test_case("miner: 0.479 with light as a factor, 0.584 with light as a gate", function() {
            var _agent = gmsa_agent_create(__chk_miner_profile(false));
            __chk_miner_set(_agent, 0.75);
            gmsa_test_assert_near(gmsa_agent_evaluate(_agent).options[0].score, 0.479, 0.0005, "factor");
            _agent = gmsa_agent_create(__chk_miner_profile(true));
            __chk_miner_set(_agent, 1);
            gmsa_test_assert_near(gmsa_agent_evaluate(_agent).options[0].score, 0.5845, 0.0005, "gate");
        });
    });
}

// the guard, as in Testing_Whole_Behaviors.md
function __chk_guard_profile() {
    static _profile = __chk_guard_profile_build();
    return _profile;
}

function __chk_guard_profile_build() {
    var _p = gmsa_profile_create("chk_guard", { commitment : 0.15 });
    gmsa_profile_add_input(_p, gmsa_input_pull("alert", function(_agent, _target) { return _agent.owner.alert; }));
    gmsa_profile_add_input(_p, gmsa_input_pull("noise_distance", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, 300, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("searched", function(_agent, _target) { return _agent.owner.search_time; }, 0, 8));
    var _noises = function(_agent) { return _agent.owner.noises; };
    var _post = gmsa_profile_add_action(_p, "guard_post");
    gmsa_action_add_consideration(_post, "alert", gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 }));
    var _investigate = gmsa_profile_add_action(_p, "investigate", { targets : _noises });
    gmsa_action_add_consideration(_investigate, "alert", gmsa_curve_make(gmsa_curve.LINEAR, { m : 1, b : 0 }));
    gmsa_action_add_consideration(_investigate, "noise_distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.1 }));
    var _search = gmsa_profile_add_action(_p, "search", { targets : _noises });
    gmsa_action_add_consideration(_search, "alert", gmsa_curve_make(gmsa_curve.LINEAR, { m : 1, b : 0 }));
    gmsa_action_add_consideration(_search, "noise_distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.1, invert : true }));
    gmsa_action_add_consideration(_search, "searched", gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 }));
    return gmsa_profile_build(_p);
}

function __chk_guard_create() {
    var _g = { x : 0, y : 0, post : { x : 0, y : 0 }, noises : [], alert : 0, search_time : 0, job : undefined, job_target : undefined };
    _g.agent = gmsa_agent_create(__chk_guard_profile(), _g);
    return _g;
}

function __chk_guard_hear(_g, _x, _y) {
    _g.noises = [{ x : _x, y : _y }];
    _g.alert = 1;
    _g.search_time = 0;
}

function __chk_guard_choose(_g, _option, _fix) { // 0: the chapter's first version, 1: forget every noise, 2: forget the searched one
    var _job = (_option == undefined) ? undefined : _option.action.name;
    if (_fix > 0 && _g.job == "search" && _job != "search") {
        if (_fix == 1) _g.noises = [];
        else {
            for (var _i = array_length(_g.noises) - 1; _i >= 0; _i--) {
                if (_g.noises[_i] == _g.job_target) array_delete(_g.noises, _i, 1);
            }
        }
    }
    _g.job = _job;
    _g.job_target = (_option == undefined) ? undefined : _option.target;
    gmsa_agent_set_current_option(_g.agent, _option);
}

function __chk_guard_act(_g, _dt) {
    _g.alert = max(0, _g.alert - 0.05 * _dt);
    switch (_g.job) {
        case "investigate": __chk_guard_move(_g, _g.job_target.x, _g.job_target.y, _dt); break;
        case "search":      _g.search_time += _dt; break;
        case "guard_post":  __chk_guard_move(_g, _g.post.x, _g.post.y, _dt); break;
    }
}

function __chk_guard_move(_g, _tx, _ty, _dt) {
    var _d = point_distance(_g.x, _g.y, _tx, _ty);
    var _step = 60 * _dt;
    if (_d <= _step) {
        _g.x = _tx;
        _g.y = _ty;
    } else {
        _g.x += (_tx - _g.x) / _d * _step;
        _g.y += (_ty - _g.y) / _d * _step;
    }
}

function __chk_guard_sim(_seconds, _events, _fix) {
    var _g = __chk_guard_create();
    var _rng = gmsa_rng_create(1);
    var _trace = [];
    var _home = -1;
    for (var _f = 0; _f < _seconds * 60; _f++) {
        for (var _e = 0; _e < array_length(_events); _e++) {
            if (_events[_e].frame == _f) __chk_guard_hear(_g, _events[_e].x, _events[_e].y);
        }
        if (_f mod 15 == 0) {
            var _d = gmsa_agent_think(_g.agent, _f * 16667, _rng);
            __chk_guard_choose(_g, gmsa_decision_get_chosen(_d), _fix);
        }
        __chk_guard_act(_g, 1 / 60);
        if (_f > 120 && _home < 0 && _g.x == 0 && _g.y == 0) _home = (_f + 1) / 60;
        var _n = array_length(_trace);
        if (_n == 0 || _trace[_n - 1].job != _g.job) array_push(_trace, { job : _g.job, time : _f / 60 });
    }
    return { guard : _g, trace : _trace, home : _home };
}

function __chk_trace_text(_trace) {
    var _s = "";
    for (var _i = 0; _i < array_length(_trace); _i++) {
        if (_i > 0) _s += ", ";
        _s += string(_trace[_i].job) + " " + string_format(_trace[_i].time, 1, 2);
    }
    return _s;
}

// the thief, as in Learning_From_The_Player.md
function __chk_thief_profile() {
    static _profile = __chk_thief_profile_build();
    return _profile;
}

function __chk_thief_profile_build() {
    var _p = gmsa_profile_create("chk_thief", { commitment : 0.15 });
    gmsa_profile_add_input(_p, gmsa_input_pull("value", function(_agent, _target) { return _target.value; }, 0, 100, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("distance", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, 400, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("guard_distance", function(_agent, _target) { return _agent.owner.guard_distance(_target); }, 0, 400, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("bag", function(_agent, _target) { var _o = _agent.owner; return _o.bag / _o.bag_size; }));
    var _grab = gmsa_profile_add_action(_p, "grab", { targets : function(_agent) { return _agent.owner.find_loot(); } });
    gmsa_action_add_consideration(_grab, "value", gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.5, b : 0.5 }));
    gmsa_action_add_consideration(_grab, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 }));
    gmsa_action_add_consideration(_grab, "guard_distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.15 }));
    var _leave = gmsa_profile_add_action(_p, "leave");
    gmsa_action_add_consideration(_leave, "bag", gmsa_curve_make(gmsa_curve.POWER, { k : 2 }));
    gmsa_profile_set_features(_p, ["value", "distance", "guard_distance", "bag"]);
    return gmsa_profile_build(_p);
}

// the miner's four considerations, as in A_Decision_That_Looks_Wrong.md
function __chk_miner_profile(_light_is_gate) {
    var _p = gmsa_profile_create(_light_is_gate ? "chk_miner_gate" : "chk_miner");
    var _names = ["distance", "richness", "fatigue", "light"];
    for (var _i = 0; _i < 4; _i++) gmsa_profile_add_input(_p, gmsa_input_push(_names[_i], 0, 1));
    var _mine = gmsa_profile_add_action(_p, "mine");
    for (var _i = 0; _i < 3; _i++) gmsa_action_add_consideration(_mine, _names[_i], gmsa_curve_make(gmsa_curve.LINEAR));
    gmsa_action_add_consideration(_mine, "light", _light_is_gate ? gmsa_curve_make(gmsa_curve.STEP, { c : 0.5 }) : gmsa_curve_make(gmsa_curve.LINEAR));
    return gmsa_profile_build(_p);
}

function __chk_miner_set(_agent, _light) {
    gmsa_agent_set_input(_agent, "distance", 0.75);
    gmsa_agent_set_input(_agent, "richness", 0.75);
    gmsa_agent_set_input(_agent, "fatigue", 0.75);
    gmsa_agent_set_input(_agent, "light", _light);
}