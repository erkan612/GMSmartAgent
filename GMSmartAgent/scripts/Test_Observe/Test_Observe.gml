function gmsa_tests_observe() {
    gmsa_test_suite("Observe", function() {

        gmsa_test_case("keeps vetoed options", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"]));
            gmsa_agent_set_input(_ag, "a", 0.2);
            var _d = gmsa_observe(_ag, ["a", "b"], 1, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(_d.chooser, gmsa_chooser.OBSERVED, "chooser");
            gmsa_test_assert_equal(array_length(_d.options), 2, "vetoed option kept");
            gmsa_test_assert_near(_d.options[1].score, 0, GMSA_TEST_EPS, "b score");
            gmsa_test_assert_near(_d.options[0].features[0], 0.2, GMSA_TEST_EPS, "a feature");
            gmsa_test_assert_near(_d.options[1].probability, 1, GMSA_TEST_EPS, "chosen probability");
        });

        gmsa_test_case("features continue after veto", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_push("x"));
            gmsa_profile_add_input(_p, gmsa_input_push("y"));
            var _a = gmsa_profile_add_action(_p, "both");
            gmsa_action_add_consideration(_a, "x", gmsa_curve_make(gmsa_curve.LINEAR));
            gmsa_action_add_consideration(_a, "y", gmsa_curve_make(gmsa_curve.LINEAR));
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_ag, "y", 0.7);
            var _d = gmsa_observe(_ag, ["both"], 0, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_near(_d.options[0].features[0], 0,   GMSA_TEST_EPS, "x vetoes");
            gmsa_test_assert_near(_d.options[0].features[1], 0.7, GMSA_TEST_EPS, "y still evaluated");
            gmsa_test_assert_near(_d.options[0].score, 0, GMSA_TEST_EPS, "score");
        });

        gmsa_test_case("keeps caller order", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"]));
            gmsa_agent_set_input(_ag, "a", 0.2);
            gmsa_agent_set_input(_ag, "b", 0.9);
            var _d = gmsa_observe(_ag, ["a", "b"], 0, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(_d.options[0].action.name, "a", "lower score stays first");
            gmsa_test_assert_equal(_d.chosen, 0, "chosen as given");
        });

        gmsa_test_case("targets", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_pull("v", function(_agent, _target) { return _target.v; }, 0, 1, true));
            var _a = gmsa_profile_add_action(_p, "pick", { targets : function(_agent) { return []; } });
            gmsa_action_add_consideration(_a, "v", gmsa_curve_make(gmsa_curve.LINEAR));
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            var _d = gmsa_observe(_ag, [{ action : "pick", target : { v : 0.3 } }, { action : "pick", target : { v : 0.8 } }], 0, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_near(_d.options[0].features[0], 0.3, GMSA_TEST_EPS, "first target");
            gmsa_test_assert_near(_d.options[1].features[0], 0.8, GMSA_TEST_EPS, "second target");
            gmsa_test_assert_throws(method({ ag : _ag }, function() { gmsa_observe(ag, ["pick"], 0, 0); }), "missing target");
        });

        gmsa_test_case("ignores cooldown, commitment and think state", function() {
            var _p = gmsa_profile_create("t", { commitment : 0.5 });
            gmsa_profile_add_input(_p, gmsa_input_push("a"));
            var _a = gmsa_profile_add_action(_p, "blast", { cooldown : 1000 });
            gmsa_action_add_consideration(_a, "a", gmsa_curve_make(gmsa_curve.LINEAR));
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_ag, "a", 0.5);
            gmsa_agent_think(_ag, 0);
            gmsa_test_assert_equal(_ag.cooldowns[0], 1000, "cooldown set by think");
            gmsa_agent_set_current(_ag, "blast");
            var _d = gmsa_observe(_ag, ["blast"], 0, 100);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_near(_d.options[0].score, 0.5, GMSA_TEST_EPS, "no commitment bonus, not blocked by cooldown");
            gmsa_test_assert_equal(_ag.cooldowns[0], 1000, "cooldown untouched");
            gmsa_test_assert_equal(_ag.last_think, 0, "last think untouched");
        });

        gmsa_test_case("validation", function() {
            var _ctx = { ag : gmsa_agent_create(__gmsa_tests_simple_profile(["a"])) };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_observe(ag, [], 0, 0); }), "no options");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_observe(ag, ["a"], 1, 0); }), "chosen out of range");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_observe(ag, ["a"], 0.5, 0); }), "chosen not an integer");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_observe(ag, ["nope"], 0, 0); }), "unknown action");
        });

        gmsa_test_case("consumable", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a"]));
            var _d = gmsa_observe(_ag, ["a"], 0, 321);
            gmsa_test_assert_true(_d.fresh, "fresh");
            gmsa_test_assert_equal(_d.time, 321, "time");
            gmsa_test_assert_equal(gmsa_agent_consume(_ag), _d, "consume");
        });

        gmsa_test_case("scenario helper with push inputs", function() {
            gmsa_test_scenario(__gmsa_tests_simple_profile(["a", "b"]), undefined, { a : 0.3, b : 0.9 }, "b", "b wins");
            gmsa_test_scenario(__gmsa_tests_simple_profile(["a"]), undefined, { a : 0 }, undefined, "nothing selectable");
        });

        gmsa_test_case("scenario helper with a fake owner", function() {
            var _p = gmsa_profile_create("medic");
            gmsa_profile_add_input(_p, gmsa_input_pull("missing", function(_agent, _target) {
                return 1 - _agent.owner.hp / 100;
            }));
            var _a = gmsa_profile_add_action(_p, "heal");
            gmsa_action_add_consideration(_a, "missing", gmsa_curve_make(gmsa_curve.LINEAR));
            gmsa_profile_add_action(_p, "idle", { weight : 0.3 });
            gmsa_profile_build(_p);
            gmsa_test_scenario(_p, { hp : 20 }, {}, "heal", "hurt");
            gmsa_test_scenario(_p, { hp : 90 }, {}, "idle", "healthy");
        });
    });
}