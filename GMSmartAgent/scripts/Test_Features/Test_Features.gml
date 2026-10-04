function __gmsa_tests_feature_profile(_danger_fn, _list, _features = true) {
    var _p = gmsa_profile_create("features");
    gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100));
    gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _target) { return _target.d; }, 0, 1, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("danger", _danger_fn));
    var _a = gmsa_profile_add_action(_p, "attack", { targets : method({ list : _list }, function(_agent) { return list; }) });
    gmsa_action_add_consideration(_a, "dist", gmsa_curve_make(gmsa_curve.LINEAR));
    _a = gmsa_profile_add_action(_p, "heal");
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR));
    if (_features == true) _features = ["hp", "dist", "danger"];
    if (is_array(_features)) gmsa_profile_set_features(_p, _features);
    return _p;
}

function __gmsa_tests_find_option(_decision, _action, _d = undefined) {
    var _options = _decision.options;
    for (var _i = 0; _i < array_length(_options); _i++) {
        var _o = _options[_i];
        if (_o.action.name != _action) continue;
        if (_d == undefined || (_o.target != undefined && _o.target.d == _d)) return _o;
    }
    return undefined;
}

function gmsa_tests_features() {
    gmsa_test_suite("Features", function() {

        gmsa_test_case("set features validation", function() {
            var _fn = function(_agent, _target) { return 0; };
            var _ctx = { fn : _fn };
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_profile_build(__gmsa_tests_feature_profile(fn, [], ["hp", "nope"]));
            }), "unknown feature");
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_profile_build(__gmsa_tests_feature_profile(fn, [], ["hp", "hp"]));
            }), "duplicate feature");
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_profile_build(__gmsa_tests_feature_profile(fn, [], []));
            }), "empty features");
            gmsa_test_assert_throws(method(_ctx, function() {
                var _p = gmsa_profile_build(__gmsa_tests_feature_profile(fn, [], false));
                gmsa_profile_set_features(_p, ["hp"]);
            }), "after build");
            var _p = gmsa_profile_build(__gmsa_tests_feature_profile(_fn, []));
            gmsa_test_assert_equal(_p.features, [0, 1, 2], "resolved indices");
        });

        gmsa_test_case("no features, no inputs and no extra calls", function() {
            var _danger = gmsa_test_stub(0.3);
            var _p = gmsa_profile_build(__gmsa_tests_feature_profile(_danger.fn, [{ d : 0.5 }], false));
            gmsa_test_assert_equal(_p.features, undefined, "no features declared");
            var _ag = gmsa_agent_create(_p);
            gmsa_agent_set_input(_ag, "hp", 50);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_equal(_d.options[0].inputs, undefined, "inputs untouched");
            gmsa_test_assert_equal(_danger.calls, 0, "unused input never pulled");
        });

        gmsa_test_case("think fills inputs in feature order", function() {
            var _danger = gmsa_test_stub(0.3);
            var _p = gmsa_profile_build(__gmsa_tests_feature_profile(_danger.fn, [{ d : 0.2 }, { d : 0.7 }]));
            var _ag = gmsa_agent_create(_p);
            gmsa_agent_set_input(_ag, "hp", 50);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d);
            var _far  = __gmsa_tests_find_option(_d, "attack", 0.7);
            var _near = __gmsa_tests_find_option(_d, "attack", 0.2);
            var _heal = __gmsa_tests_find_option(_d, "heal");
            gmsa_test_assert_equal(_far.inputs,  [0.5, 0.7, 0.3], "attack far");
            gmsa_test_assert_equal(_near.inputs, [0.5, 0.2, 0.3], "attack near");
            gmsa_test_assert_equal(_heal.inputs, [0.5, 0,   0.3], "targetless per-target feature is 0");
            gmsa_test_assert_equal(_danger.calls, 1, "unused feature pulled once per think");
        });

        gmsa_test_case("observe fills inputs including vetoed options", function() {
            var _danger = gmsa_test_stub(0.3);
            var _p = gmsa_profile_build(__gmsa_tests_feature_profile(_danger.fn, []));
            var _ag = gmsa_agent_create(_p);
            gmsa_agent_set_input(_ag, "hp", 80);
            var _d = gmsa_observe(_ag, [{ action : "attack", target : { d : 0 } }, "heal"], 1, 0);
            gmsa_test_assert_decision(_d);
            gmsa_test_assert_near(_d.options[0].score, 0, GMSA_TEST_EPS, "attack vetoed");
            gmsa_test_assert_equal(_d.options[0].inputs, [0.8, 0, 0.3], "vetoed option still has inputs");
            gmsa_test_assert_equal(_d.options[1].inputs, [0.8, 0, 0.3], "heal");
        });

        gmsa_test_case("checker flags bad inputs", function() {
            var _p = gmsa_profile_build(__gmsa_tests_feature_profile(function(_agent, _target) { return 0.3; }, []));
            var _ag = gmsa_agent_create(_p);
            gmsa_agent_set_input(_ag, "hp", 50);
            var _d = gmsa_agent_think(_ag, 0);
            gmsa_test_assert_decision(_d, "valid before tampering");
            _d.options[0].inputs = [0.5];
            gmsa_test_assert_true(array_length(gmsa_test_decision_problems(_d)) > 0, "wrong length caught");
        });
    });
}