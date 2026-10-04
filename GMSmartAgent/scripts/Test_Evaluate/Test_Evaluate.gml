function gmsa_tests_evaluate() {
    gmsa_test_suite("Evaluate", function() {

        gmsa_test_case("leaves the agent's decision alone", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"]));
            gmsa_agent_set_input(_ag, "a", 0.3);
            gmsa_agent_set_input(_ag, "b", 0.8);
            var _d = gmsa_agent_think(_ag, 0);
            var _top = _d.options[0];
            gmsa_agent_set_input(_ag, "a", 0.9);
            gmsa_agent_set_input(_ag, "b", 0.1);
            var _e = gmsa_agent_evaluate(_ag, 1);
            gmsa_test_assert_false(_e == _d, "separate struct");
            gmsa_test_assert_true(_d.fresh, "decision still fresh");
            gmsa_test_assert_equal(_d.options[0], _top, "decision options untouched");
            gmsa_test_assert_equal(_top.action.name, "b", "top option unchanged");
            gmsa_test_assert_near(_top.score, 0.8, GMSA_TEST_EPS, "top score unchanged");
            gmsa_test_assert_equal(_e.options[0].action.name, "a", "evaluation sees the new inputs");
        });

        gmsa_test_case("no side effects", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_push("x"));
            var _a = gmsa_profile_add_action(_p, "blast", { cooldown : 1000 });
            gmsa_action_add_consideration(_a, "x", gmsa_curve_make(gmsa_curve.LINEAR));
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_ag, "x", 1);
            _ag.rng = gmsa_rng_create(4);
            var _state = _ag.rng.state;
            gmsa_agent_evaluate(_ag, 0);
            gmsa_test_assert_equal(_ag.cooldowns[0], 0, "no cooldown started");
            gmsa_test_assert_equal(_ag.last_think, undefined, "last think untouched");
            gmsa_test_assert_equal(_ag.current, undefined, "current untouched");
            gmsa_test_assert_false(_ag.decision.fresh, "agent decision not marked fresh");
            gmsa_test_assert_equal(_ag.rng.state, _state, "no random draw");
        });

        gmsa_test_case("keeps vetoed options, ranked last", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"]));
            gmsa_agent_set_input(_ag, "b", 0.6);
            var _e = gmsa_agent_evaluate(_ag, 0);
            gmsa_test_assert_decision(_e);
            gmsa_test_assert_equal(_e.chooser, gmsa_chooser.EVALUATED, "chooser");
            gmsa_test_assert_equal(_e.chosen, -1, "nothing chosen");
            gmsa_test_assert_equal(array_length(_e.options), 2, "vetoed option kept");
            gmsa_test_assert_equal(_e.options[0].action.name, "b", "b first");
            gmsa_test_assert_near(_e.options[1].score, 0, GMSA_TEST_EPS, "a vetoed");
            gmsa_test_assert_equal(_e.options[1].features, [0], "vetoed option has its features");
        });

        gmsa_test_case("respects cooldowns", function() {
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_push("x"));
            var _a = gmsa_profile_add_action(_p, "blast", { cooldown : 1000 });
            gmsa_action_add_consideration(_a, "x", gmsa_curve_make(gmsa_curve.LINEAR));
            gmsa_profile_add_action(_p, "idle", { weight : 0.1 });
            var _ag = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_ag, "x", 1);
            gmsa_agent_think(_ag, 0);
            gmsa_test_assert_equal(array_length(gmsa_agent_evaluate(_ag, 500).options), 1, "blast on cooldown");
            gmsa_test_assert_equal(array_length(gmsa_agent_evaluate(_ag, 1000).options), 2, "blast ready again");
        });

        gmsa_test_case("no commitment bonus", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a"], { commitment : 0.5 }));
            gmsa_agent_set_input(_ag, "a", 0.4);
            gmsa_agent_set_current(_ag, "a");
            gmsa_test_assert_near(gmsa_agent_evaluate(_ag, 0).options[0].score, 0.4, GMSA_TEST_EPS, "raw score");
            gmsa_test_assert_near(gmsa_agent_think(_ag, 0).options[0].score, 0.6, GMSA_TEST_EPS, "think still applies it");
        });

        gmsa_test_case("fills features, including vetoed options", function() {
            var _p = gmsa_profile_build(__gmsa_tests_feature_profile(function(_agent, _target) { return 0.3; }, [{ d : 0 }, { d : 0.6 }]));
            var _ag = gmsa_agent_create(_p);
            gmsa_agent_set_input(_ag, "hp", 50);
            var _e = gmsa_agent_evaluate(_ag, 0);
            gmsa_test_assert_decision(_e);
            gmsa_test_assert_equal(array_length(_e.options), 3, "every option");
            gmsa_test_assert_equal(__gmsa_tests_find_option(_e, "attack", 0).inputs, [0.5, 0, 0.3], "vetoed attack");
            gmsa_test_assert_equal(__gmsa_tests_find_option(_e, "attack", 0.6).inputs, [0.5, 0.6, 0.3], "attack");
        });

        gmsa_test_case("struct and options reused", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a"]));
            gmsa_agent_set_input(_ag, "a", 1);
            var _e1 = gmsa_agent_evaluate(_ag, 0);
            var _o1 = _e1.options[0];
            var _e2 = gmsa_agent_evaluate(_ag, 1);
            gmsa_test_assert_equal(_e1, _e2, "same struct");
            gmsa_test_assert_equal(_e2.options[0], _o1, "option pooled");
        });
    });
}