function __gmsa_tests_profile() {
    var _p = gmsa_profile_create("test");
    gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100));
    gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _target) { return 0; }, 0, 512, true));
    var _a = gmsa_profile_add_action(_p, "attack", { targets : function(_agent) { return [0]; } });
    gmsa_action_add_consideration(_a, "dist", gmsa_curve_make(gmsa_curve.LINEAR));
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR));
    gmsa_profile_add_action(_p, "idle", { weight : 0.1 });
    return _p;
}

function gmsa_tests_core() {
    gmsa_test_suite("Core", function() {

        gmsa_test_case("rng deterministic", function() {
            var _a = gmsa_rng_create(42);
            var _b = gmsa_rng_create(42);
            for (var _i = 0; _i < 20; _i++) {
                if (!gmsa_test_assert_equal(gmsa_rng_next(_a), gmsa_rng_next(_b), "step " + string(_i))) return;
            }
        });

        gmsa_test_case("rng seeds differ", function() {
            gmsa_test_assert_false(gmsa_rng_next(gmsa_rng_create(1)) == gmsa_rng_next(gmsa_rng_create(2)));
        });

        gmsa_test_case("rng range", function() {
            var _r = gmsa_rng_create(7);
            for (var _i = 0; _i < 1000; _i++) {
                var _v = gmsa_rng_next(_r);
                if (!gmsa_test_assert_true(_v >= 0 && _v < 1, "value " + string(_v))) return;
            }
        });

        gmsa_test_case("rng mean", function() {
            var _r = gmsa_rng_create(99);
            var _sum = 0;
            for (var _i = 0; _i < 1000; _i++) _sum += gmsa_rng_next(_r);
            gmsa_test_assert_range(_sum / 1000, 0.45, 0.55);
        });

        gmsa_test_case("rng seed zero", function() {
            var _r = gmsa_rng_create(0);
            gmsa_test_assert_false(gmsa_rng_next(_r) == gmsa_rng_next(_r));
        });

        gmsa_test_case("rng leaves global random alone", function() {
            random_set_seed(123);
            var _expected = random(1);
            random_set_seed(123);
            var _r = gmsa_rng_create(5);
            for (var _i = 0; _i < 100; _i++) gmsa_rng_next(_r);
            gmsa_test_assert_equal(random(1), _expected);
        });

        gmsa_test_case("input normalize", function() {
            var _in = gmsa_input_push("hp", 0, 100);
            gmsa_test_assert_near(gmsa_input_normalize(_in, 50),  0.5, GMSA_TEST_EPS, "50");
            gmsa_test_assert_near(gmsa_input_normalize(_in, -10), 0,   GMSA_TEST_EPS, "below min");
            gmsa_test_assert_near(gmsa_input_normalize(_in, 200), 1,   GMSA_TEST_EPS, "above max");
            gmsa_test_assert_near(gmsa_input_normalize(_in, "x"), 0,   GMSA_TEST_EPS, "string");
            gmsa_test_assert_near(gmsa_input_normalize(_in, NaN), 0,   GMSA_TEST_EPS, "NaN");
            var _rev = gmsa_input_push("rev", 100, 0);
            gmsa_test_assert_near(gmsa_input_normalize(_rev, 25), 0.75, GMSA_TEST_EPS, "reversed range");
        });

        gmsa_test_case("input validation", function() {
            gmsa_test_assert_throws(function() { gmsa_input_push("a", 5, 5); }, "min equals max");
            gmsa_test_assert_throws(function() { gmsa_input_pull("a", "nope"); }, "pull not callable");
            gmsa_test_assert_throws(function() { gmsa_input_push(""); }, "empty name");
        });

        gmsa_test_case("build resolves indices", function() {
            var _p = gmsa_profile_build(__gmsa_tests_profile());
            gmsa_test_assert_true(_p.built, "built");
            var _cons = _p.actions[0].considerations;
            gmsa_test_assert_equal(_cons[0].input_index, 1, "dist index");
            gmsa_test_assert_equal(_cons[1].input_index, 0, "hp index");
            gmsa_test_assert_equal(gmsa_profile_input_index(_p, "dist"), 1, "input lookup");
            gmsa_test_assert_equal(gmsa_profile_action_index(_p, "idle"), 1, "action lookup");
            gmsa_test_assert_equal(gmsa_profile_action_index(_p, "nope"), -1, "missing action");
            gmsa_test_assert_equal(_p.actions[1].index, 1, "action index");
        });

        gmsa_test_case("build rejects bad config", function() {
            gmsa_test_assert_throws(function() { gmsa_profile_build(gmsa_profile_create("t")); }, "no actions");
            gmsa_test_assert_throws(function() {
                var _p = __gmsa_tests_profile();
                gmsa_profile_add_input(_p, gmsa_input_push("hp"));
                gmsa_profile_build(_p);
            }, "duplicate input");
            gmsa_test_assert_throws(function() {
                var _p = __gmsa_tests_profile();
                gmsa_profile_add_action(_p, "attack");
                gmsa_profile_build(_p);
            }, "duplicate action");
            gmsa_test_assert_throws(function() {
                var _p = gmsa_profile_create("t");
                var _a = gmsa_profile_add_action(_p, "a");
                gmsa_action_add_consideration(_a, "nope", gmsa_curve_make(gmsa_curve.LINEAR));
                gmsa_profile_build(_p);
            }, "unknown input");
            gmsa_test_assert_throws(function() {
                var _p = gmsa_profile_create("t");
                gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _target) { return 0; }, 0, 1, true));
                var _a = gmsa_profile_add_action(_p, "a");
                gmsa_action_add_consideration(_a, "dist", gmsa_curve_make(gmsa_curve.LINEAR));
                gmsa_profile_build(_p);
            }, "per-target without targets");
            gmsa_test_assert_throws(function() {
                var _p = gmsa_profile_create("t");
                gmsa_profile_add_input(_p, gmsa_input_push("hp"));
                var _a = gmsa_profile_add_action(_p, "a");
                gmsa_action_add_consideration(_a, "hp", undefined);
                gmsa_profile_build(_p);
            }, "missing curve");
            gmsa_test_assert_throws(function() {
                var _p = gmsa_profile_create("t", { top_n : 0 });
                gmsa_profile_add_action(_p, "a");
                gmsa_profile_build(_p);
            }, "top_n 0");
            gmsa_test_assert_throws(function() {
                var _p = gmsa_profile_create("t");
                gmsa_profile_add_action(_p, "a", { weight : -1 });
                gmsa_profile_build(_p);
            }, "negative weight");
        });

        gmsa_test_case("built profile is locked", function() {
            var _p = gmsa_profile_build(__gmsa_tests_profile());
            var _ctx = { p : _p };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_profile_add_input(p, gmsa_input_push("x")); }), "add input");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_profile_add_action(p, "x"); }), "add action");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_action_add_consideration(p.actions[0], "hp", gmsa_curve_make(gmsa_curve.LINEAR)); }), "add consideration");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_profile_build(p); }), "build twice");
        });

        gmsa_test_case("agent needs built profile", function() {
            gmsa_test_assert_throws(function() { gmsa_agent_create(__gmsa_tests_profile()); });
        });

        gmsa_test_case("agent push inputs", function() {
            var _ag = gmsa_agent_create(gmsa_profile_build(__gmsa_tests_profile()));
            gmsa_test_assert_equal(_ag.push[0], 0, "hp default is min");
            gmsa_agent_set_input(_ag, "hp", 40);
            gmsa_test_assert_equal(_ag.push[0], 40, "set by name");
            gmsa_agent_set_input(_ag, 0, 55);
            gmsa_test_assert_equal(_ag.push[0], 55, "set by index");
            var _ctx = { ag : _ag };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_agent_set_input(ag, "dist", 1); }), "pull input");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_agent_set_input(ag, "nope", 1); }), "unknown name");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_agent_set_input(ag, 5, 1); }), "index out of range");
        });

        gmsa_test_case("agent current and consume", function() {
            var _ag = gmsa_agent_create(gmsa_profile_build(__gmsa_tests_profile()));
            gmsa_test_assert_equal(array_length(_ag.cooldowns), 2, "cooldowns per action");
            gmsa_test_assert_equal(_ag.decision.agent, _ag, "decision points to agent");
            gmsa_agent_set_current(_ag, "idle");
            gmsa_test_assert_equal(_ag.current.action, 1, "current by name");
            gmsa_test_assert_equal(_ag.current.target, undefined, "no target");
            gmsa_agent_clear_current(_ag);
            gmsa_test_assert_equal(_ag.current, undefined, "cleared");
            gmsa_test_assert_equal(gmsa_agent_consume(_ag), undefined, "not fresh");
            _ag.decision.fresh = true;
            gmsa_test_assert_equal(gmsa_agent_consume(_ag), _ag.decision, "fresh");
            gmsa_test_assert_equal(gmsa_agent_consume(_ag), undefined, "consumed once");
        });
    });
}