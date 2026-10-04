function __gmsa_tests_simple_profile(_names, _params = {}) {
    var _p = gmsa_profile_create("simple", _params);
    for (var _i = 0; _i < array_length(_names); _i++) {
        gmsa_profile_add_input(_p, gmsa_input_push(_names[_i]));
        var _a = gmsa_profile_add_action(_p, _names[_i]);
        gmsa_action_add_consideration(_a, _names[_i], gmsa_curve_make(gmsa_curve.LINEAR));
    }
    return gmsa_profile_build(_p);
}

function gmsa_tests_think() {
    gmsa_test_suite("Think", function() {

        gmsa_test_case("stub counts calls", function() {
            var _s = gmsa_test_stub(3);
            gmsa_test_assert_equal(_s.fn(), 3, "value");
            _s.fn();
            gmsa_test_assert_equal(_s.calls, 2, "calls");
            var _f = gmsa_test_stub(function(_agent, _target) { return _target * 2; });
            gmsa_test_assert_equal(_f.fn(undefined, 4), 8, "callable value");
        });

        gmsa_test_case("checker catches problems", function() {
            var _bad = {
                options : [{ action : { name : "x", considerations : [] }, score : -1, features : [0.5], probability : 0.5 }],
                chosen  : 3,
            };
            gmsa_test_assert_true(array_length(gmsa_test_decision_problems(_bad)) >= 4);
        });

        gmsa_test_case("zero considerations score is weight", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_action(_p, "idle", { weight : 0.4 });
            var _d = gmsa_agent_think(gmsa_agent_create(gmsa_profile_build(_p)), 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(_d.chosen, 0, "chosen");
            gmsa_test_assert_near(_d.options[0].score, 0.4, GMSA_TEST_EPS, "score");
        });

        gmsa_test_case("push input through curve", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["hp"]));
            gmsa_agent_set_input(_ag, "hp", 0.5);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_near(_d.options[0].score, 0.5, GMSA_TEST_EPS);
        });

        gmsa_test_case("veto drops option", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_push("hp"));
            var _a = gmsa_profile_add_action(_p, "heal");
            gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR));
            gmsa_profile_add_action(_p, "idle", { weight : 0.1 });
            var _d = gmsa_agent_think(gmsa_agent_create(gmsa_profile_build(_p)), 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(array_length(_d.options), 1, "one option left");
            gmsa_test_assert_equal(_d.options[0].action.name, "idle", "idle remains");

            var _solo = gmsa_agent_think(gmsa_agent_create(__gmsa_tests_simple_profile(["hp"])), 0);
            gmsa_test_assert_decision(_solo);
            gmsa_test_assert_equal(array_length(_solo.options), 0, "no options");
            gmsa_test_assert_equal(_solo.chosen, -1, "nothing chosen");
        });

        gmsa_test_case("compensation", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_push("x"));
            gmsa_profile_add_input(_p, gmsa_input_push("y"));
            var _a = gmsa_profile_add_action(_p, "both");
            gmsa_action_add_consideration(_a, "x", gmsa_curve_make(gmsa_curve.LINEAR));
            gmsa_action_add_consideration(_a, "y", gmsa_curve_make(gmsa_curve.LINEAR));
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_ag, "x", 0.5);
            gmsa_agent_set_input(_ag, "y", 0.5);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            // raw 0.25, mod 0.5, 0.25 + 0.75 * 0.5 * 0.25
            gmsa_test_assert_near(_d.options[0].score, 0.34375, GMSA_TEST_EPS);
        });

        gmsa_test_case("weight multiplies", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_push("hp"));
            var _a = gmsa_profile_add_action(_p, "a", { weight : 2 });
            gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR));
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_ag, "hp", 0.5);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_near(_d.options[0].score, 1, GMSA_TEST_EPS);
        });

        gmsa_test_case("ranking and best", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"]));
            gmsa_agent_set_input(_ag, "a", 0.3);
            gmsa_agent_set_input(_ag, "b", 0.8);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(_d.options[0].action.name, "b", "b ranked first");
            gmsa_test_assert_equal(_d.chosen, 0, "best chosen");
            gmsa_test_assert_near(_d.options[0].probability, 1, GMSA_TEST_EPS, "prob best");
            gmsa_test_assert_near(_d.options[1].probability, 0, GMSA_TEST_EPS, "prob other");
        });

        gmsa_test_case("targets become options", function() {
            var _ctx = { list : [{ v : 0.2 }, { v : 0.9 }, { v : 0.5 }] };
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_pull("v", function(_agent, _target) { return _target.v; }, 0, 1, true));
            var _a = gmsa_profile_add_action(_p, "attack", { targets : method(_ctx, function(_agent) { return list; }) });
            gmsa_action_add_consideration(_a, "v", gmsa_curve_make(gmsa_curve.LINEAR));
            var _d = gmsa_agent_think(gmsa_agent_create(gmsa_profile_build(_p)), 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(array_length(_d.options), 3, "one option per target");
            gmsa_test_assert_near(_d.options[0].target.v, 0.9, GMSA_TEST_EPS, "best target");
            gmsa_test_assert_near(_d.options[2].target.v, 0.2, GMSA_TEST_EPS, "worst target");
        });

        gmsa_test_case("pull inputs cached per think", function() {
            var _dist = gmsa_test_stub(function(_agent, _target) { return _target.v; });
            var _glob = gmsa_test_stub(0.5);
            var _ctx  = { list : [{ v : 0.3 }, { v : 0.7 }] };
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_pull("dist", _dist.fn, 0, 1, true));
            gmsa_profile_add_input(_p, gmsa_input_pull("glob", _glob.fn, 0, 1, false));
            var _targets = method(_ctx, function(_agent) { return list; });
            var _names = ["attack", "chase"];
            for (var _i = 0; _i < 2; _i++) {
                var _a = gmsa_profile_add_action(_p, _names[_i], { targets : _targets });
                gmsa_action_add_consideration(_a, "dist", gmsa_curve_make(gmsa_curve.LINEAR));
                gmsa_action_add_consideration(_a, "glob", gmsa_curve_make(gmsa_curve.LINEAR));
            }
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_test_assert_decision(gmsa_agent_think(_ag, 0));
            gmsa_test_assert_equal(_dist.calls, 2, "per-target once per target");
            gmsa_test_assert_equal(_glob.calls, 1, "global once");
            gmsa_agent_think(_ag, 1);
            gmsa_test_assert_equal(_dist.calls, 4, "per-target next think");
            gmsa_test_assert_equal(_glob.calls, 2, "global next think");
        });

        gmsa_test_case("cooldown", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_push("hp"));
            var _a = gmsa_profile_add_action(_p, "blast", { cooldown : 1000 });
            gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR));
            gmsa_profile_add_action(_p, "idle", { weight : 0.1 });
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_ag, "hp", 1);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_equal(gmsa_decision_get_chosen(_d).action.name, "blast", "t=0");
            _d = gmsa_agent_think(_ag, 500);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(array_length(_d.options), 1, "t=500 blast unavailable");
            gmsa_test_assert_equal(gmsa_decision_get_chosen(_d).action.name, "idle", "t=500 idle");
            _d = gmsa_agent_think(_ag, 1000);
            gmsa_test_assert_equal(gmsa_decision_get_chosen(_d).action.name, "blast", "t=1000");
        });

        gmsa_test_case("commitment breaks ties", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"], { commitment : 0.2 }));
            gmsa_agent_set_input(_ag, "a", 0.5);
            gmsa_agent_set_input(_ag, "b", 0.5);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_equal(gmsa_decision_get_chosen(_d).action.name, "a", "tie goes to first");
            gmsa_agent_set_current(_ag, "b");
            _d = gmsa_agent_think(_ag, 1);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(gmsa_decision_get_chosen(_d).action.name, "b", "current wins");
            gmsa_test_assert_near(gmsa_decision_get_chosen(_d).score, 0.6, GMSA_TEST_EPS, "bonus applied");
        });

        gmsa_test_case("weighted selection", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b", "c"], { select : gmsa_select.TOP_N_WEIGHTED, top_n : 2 }));
            _ag.rng = gmsa_rng_create(11);
            gmsa_agent_set_input(_ag, "a", 0.6);
            gmsa_agent_set_input(_ag, "b", 0.3);
            gmsa_agent_set_input(_ag, "c", 0.1);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_near(_d.options[0].probability, 2 / 3, GMSA_TEST_EPS, "prob a");
            gmsa_test_assert_near(_d.options[1].probability, 1 / 3, GMSA_TEST_EPS, "prob b");
            gmsa_test_assert_near(_d.options[2].probability, 0, GMSA_TEST_EPS, "prob c");
            var _count_a = 0;
            for (var _i = 1; _i <= 300; _i++) {
                var _name = gmsa_decision_get_chosen(gmsa_agent_think(_ag, _i)).action.name;
                if (!gmsa_test_assert_false(_name == "c", "c is outside top 2")) return;
                if (_name == "a") _count_a++;
            }
            gmsa_test_assert_range(_count_a / 300, 0.55, 0.78, "a share");
        });

        gmsa_test_case("weighted is repeatable", function() {
            var _p = __gmsa_tests_simple_profile(["a", "b"], { select : gmsa_select.TOP_N_WEIGHTED, top_n : 2 });
            var _x = gmsa_agent_create(_p);
            var _y = gmsa_agent_create(_p);
            _x.rng = gmsa_rng_create(5);
            _y.rng = gmsa_rng_create(5);
            gmsa_agent_set_input(_x, "a", 0.5); gmsa_agent_set_input(_x, "b", 0.5);
            gmsa_agent_set_input(_y, "a", 0.5); gmsa_agent_set_input(_y, "b", 0.5);
            for (var _i = 0; _i < 20; _i++) {
                var _nx = gmsa_decision_get_chosen(gmsa_agent_think(_x, _i)).action.name;
                var _ny = gmsa_decision_get_chosen(gmsa_agent_think(_y, _i)).action.name;
                if (!gmsa_test_assert_equal(_nx, _ny, "think " + string(_i))) return;
            }
        });

        gmsa_test_case("decision struct reused", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a"]));
            gmsa_agent_set_input(_ag, "a", 1);
            var _d1 = gmsa_agent_think(_ag, 0);
            var _o1 = _d1.options[0];
            var _d2 = gmsa_agent_think(_ag, 1);
            gmsa_test_assert_equal(_d1, _d2, "same decision");
            gmsa_test_assert_equal(_d2.options[0], _o1, "option pooled");
        });

        gmsa_test_case("fresh and time", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a"]));
            gmsa_agent_set_input(_ag, "a", 1);
            var _d = gmsa_agent_think(_ag, 777);
            gmsa_test_assert_true(_d.fresh, "fresh");
            gmsa_test_assert_equal(_d.time, 777, "time");
            gmsa_test_assert_equal(_ag.last_think, 777, "last think");
            gmsa_test_assert_equal(gmsa_agent_consume(_ag), _d, "consume");
            gmsa_test_assert_false(_d.fresh, "consumed");
        });
		
		gmsa_test_case("set current from option", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"], { commitment : 0.2 }));
            gmsa_agent_set_input(_ag, "a", 0.5);
            gmsa_agent_set_input(_ag, "b", 0.5);
            gmsa_agent_set_current_option(_ag, gmsa_decision_get_chosen(gmsa_agent_think(_ag, 0)));
            gmsa_test_assert_equal(_ag.current.action, 0, "current set from option");
            gmsa_agent_set_input(_ag, "b", 0.55);
            var _d = gmsa_agent_think(_ag, 1);
            gmsa_test_assert_equal(gmsa_decision_get_chosen(_d).action.name, "a", "commitment survives the pooled option");
            gmsa_agent_set_current_option(_ag, undefined);
            gmsa_test_assert_equal(_ag.current, undefined, "cleared");

            var _other = gmsa_agent_create(__gmsa_tests_simple_profile(["x"]));
            gmsa_agent_set_input(_other, "x", 1);
            var _ctx = { ag : _ag, foreign : gmsa_decision_get_chosen(gmsa_agent_think(_other, 0)) };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_agent_set_current_option(ag, foreign); }), "foreign option");
        });
    });
}