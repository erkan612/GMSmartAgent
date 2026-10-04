function __gmsa_tests_rerank_profile(_model = false, _influence = 1, _features = true) {
    var _p = gmsa_profile_create("rerank");
    gmsa_profile_add_input(_p, gmsa_input_push("x"));
    gmsa_profile_add_action(_p, "a", { weight : 0.8 });
    gmsa_profile_add_action(_p, "b", { weight : 0.6 });
    if (_features == true) gmsa_profile_set_features(_p, ["x"]);
    if (is_struct(_model)) gmsa_profile_set_model(_p, _model, _influence);
    return gmsa_profile_build(_p);
}

function __gmsa_tests_trained_favorite(_choice, _n) {
    var _model = __gmsa_tests_favorite_model();
    var _player = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b"]));
    repeat (_n) __gmsa_tests_learn_choose(_model, _player, ["a", "b"], _choice);
    return _model;
}

function __gmsa_tests_chosen_name(_decision) {
    return gmsa_decision_get_chosen(_decision).action.name;
}

function gmsa_tests_learn_rerank() {
    gmsa_test_suite("Learn rerank", function() {

        gmsa_test_case("influence 0 changes nothing", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(__gmsa_tests_trained_favorite("b", 60), 0));
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(_d), "a", "designer choice");
            gmsa_test_assert_near(_d.options[0].score, 0.8, GMSA_TEST_EPS, "score untouched");
            gmsa_test_assert_near(_d.options[0].designer, 0.8, GMSA_TEST_EPS, "designer recorded");
        });

        gmsa_test_case("learned preference reorders", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(__gmsa_tests_trained_favorite("b", 60), 1));
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(_d), "b", "learned choice wins");
            gmsa_test_assert_near(_d.options[0].score, 0.6, GMSA_TEST_EPS, "preferred option keeps its designer score");
            gmsa_test_assert_true(_d.options[1].score < _d.options[1].designer, "the other is pushed down");
        });

        gmsa_test_case("never above the designer score", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(__gmsa_tests_trained_favorite("a", 60), 1));
            var _d = gmsa_agent_think(_ag, 0);
            for (var _i = 0; _i < array_length(_d.options); _i++) {
                gmsa_test_assert_true(_d.options[_i].score <= _d.options[_i].designer + GMSA_TEST_EPS, "option " + string(_i));
                gmsa_test_assert_true(_d.options[_i].score > 0, "option " + string(_i) + " not removed");
            }
        });

        gmsa_test_case("no confidence, no change", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(__gmsa_tests_favorite_model(), 1));
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(_d), "a", "untrained model has no say");
            gmsa_test_assert_near(_d.options[1].score, 0.6, GMSA_TEST_EPS, "scores untouched");
        });

        gmsa_test_case("agent model overrides the profile", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(__gmsa_tests_favorite_model(), 1));
            gmsa_agent_set_model(_ag, __gmsa_tests_trained_favorite("b", 60), 1);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(gmsa_agent_think(_ag, 0)), "b", "agent model used");
            gmsa_agent_set_model(_ag, undefined);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(gmsa_agent_think(_ag, 1)), "a", "back to the profile's model");
        });

        gmsa_test_case("influence changes at runtime", function() {
            var _p = __gmsa_tests_rerank_profile(__gmsa_tests_trained_favorite("b", 60), 1);
            var _ag = gmsa_agent_create(_p);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(gmsa_agent_think(_ag, 0)), "b", "influence 1");
            gmsa_learn_set_influence(_p, 0);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(gmsa_agent_think(_ag, 1)), "a", "influence 0");
        });

        gmsa_test_case("a model brings its own features", function() {
            var _p = __gmsa_tests_rerank_profile(__gmsa_tests_favorite_model(), 1, false);
            gmsa_test_assert_equal(_p.features, [0], "every input became a feature");
        });

        gmsa_test_case("validation", function() {
            gmsa_test_assert_throws(function() {
                __gmsa_tests_rerank_profile(__gmsa_tests_favorite_model(), 1.5);
            }, "influence above 1");
            gmsa_test_assert_throws(function() {
                var _p = gmsa_profile_create("t");
                gmsa_profile_add_action(_p, "a");
                gmsa_profile_set_model(_p, { name : "not a model" }, 0.5);
            }, "not a model");
            gmsa_test_assert_throws(function() {
                var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(false, 1, false));
                gmsa_agent_set_model(_ag, __gmsa_tests_favorite_model(), 0.5);
            }, "agent model on a profile without features");
            gmsa_test_assert_throws(function() {
                gmsa_profile_set_model(__gmsa_tests_rerank_profile(), __gmsa_tests_favorite_model(), 0.5);
            }, "after build");
        });

        gmsa_test_case("evaluate and observe don't re-rank", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(__gmsa_tests_trained_favorite("b", 60), 1));
            var _e = gmsa_agent_evaluate(_ag, 0);
            gmsa_test_assert_equal(_e.options[0].action.name, "a", "evaluate keeps designer order");
            gmsa_test_assert_near(_e.options[0].score, 0.8, GMSA_TEST_EPS, "evaluate keeps designer scores");
            var _o = gmsa_observe(_ag, ["a", "b"], 1, 0);
            gmsa_test_assert_near(_o.options[0].score, 0.8, GMSA_TEST_EPS, "observe keeps designer scores");
        });
		
		gmsa_test_case("debug shows the designer score", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_rerank_profile(__gmsa_tests_trained_favorite("b", 60), 1));
            var _lines = gmsa_debug_lines(gmsa_agent_think(_ag, 0));
            gmsa_test_assert_true(string_pos("designer", _lines[0]) == 0, "untouched option has no note: " + _lines[0]);
            gmsa_test_assert_true(string_pos("(designer 0.800)", _lines[1]) > 0, "pushed-down option shows it: " + _lines[1]);

            var _plain = gmsa_agent_create(__gmsa_tests_rerank_profile());
            var _plain_lines = gmsa_debug_lines(gmsa_agent_think(_plain, 0));
            gmsa_test_assert_true(string_pos("designer", _plain_lines[0] + _plain_lines[1]) == 0, "no model, no notes");
        });
    });
}