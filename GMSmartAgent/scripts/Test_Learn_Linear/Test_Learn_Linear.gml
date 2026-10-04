function __gmsa_tests_linear_loot_profile(_ctx) {
    var _p = gmsa_profile_create("loot");
    gmsa_profile_add_input(_p, gmsa_input_pull("value", function(_agent, _target) { return _target.v; }, 0, 1, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("dist",  function(_agent, _target) { return _target.d; }, 0, 1, true));
    gmsa_profile_add_action(_p, "loot", { targets : method(_ctx, function(_agent) { return list; }) });
    gmsa_profile_set_features(_p, ["value", "dist"]);
    return gmsa_profile_build(_p);
}

function __gmsa_tests_linear_train_value(_model, _agent, _n) {
    var _rng = gmsa_rng_create(3);
    repeat (_n) {
        var _options = [];
        var _best = 0, _best_v = -1;
        for (var _i = 0; _i < 3; _i++) {
            var _item = { v : gmsa_rng_next(_rng), d : gmsa_rng_next(_rng) };
            array_push(_options, { action : "loot", target : _item });
            if (_item.v > _best_v) { _best_v = _item.v; _best = _i; }
        }
        gmsa_learn_observe(_model, gmsa_observe(_agent, _options, _best, 0));
    }
}

function __gmsa_tests_argmax(_p) {
    var _best = 0;
    for (var _i = 1; _i < array_length(_p); _i++) if (_p[_i] > _p[_best]) _best = _i;
    return _best;
}

function gmsa_tests_learn_linear() {
    gmsa_test_suite("Learn linear", function() {

        gmsa_test_case("create validation", function() {
            gmsa_test_assert_throws(function() { gmsa_learn_linear_create({ learn_rate : 0 }); }, "learn rate 0");
            gmsa_test_assert_throws(function() { gmsa_learn_linear_create({ learn_rate : -1 }); }, "negative learn rate");
        });

        gmsa_test_case("untrained is even and unsure", function() {
            var _model = gmsa_learn_linear_create();
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b"]));
            var _out = gmsa_learn_predict(_model, gmsa_agent_evaluate(_ag, 0));
            gmsa_test_assert_near(_out.p[0], 0.5, GMSA_TEST_EPS, "even");
            gmsa_test_assert_near(_out.confidence, 0, GMSA_TEST_EPS, "no confidence");
        });

        gmsa_test_case("learns which target", function() {
            var _ctx = { list : [] };
            var _ag = gmsa_agent_create(__gmsa_tests_linear_loot_profile(_ctx));
            var _model = gmsa_learn_linear_create();
            __gmsa_tests_linear_train_value(_model, _ag, 60);
            _ctx.list = [{ v : 0.9, d : 0.8 }, { v : 0.2, d : 0.1 }, { v : 0.5, d : 0.4 }];
            var _e = gmsa_agent_evaluate(_ag, 0);
            var _out = gmsa_learn_predict(_model, _e);
            gmsa_test_assert_near(_e.options[__gmsa_tests_argmax(_out.p)].target.v, 0.9, GMSA_TEST_EPS, "valuable item first, though farthest");
            gmsa_test_assert_true(_model.data.w[0][_model.input_lookup.value] > 0, "value weight positive");
            gmsa_test_assert_true(_out.confidence > 0.6, "confident after 60 samples");
        });

        gmsa_test_case("learns which action per situation", function() {
            var _model = gmsa_learn_linear_create();
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            var _rng = gmsa_rng_create(7);
            repeat (80) {
                var _hp = gmsa_rng_next(_rng) * 100;
                __gmsa_tests_count_choose(_model, _ag, _hp, 0, ["drink", "loot"], (_hp < 50) ? "drink" : "loot");
            }
            var _low = __gmsa_tests_count_predict(_model, _ag, 10, 0);
            gmsa_test_assert_true(__gmsa_tests_count_p(_low, "drink") > __gmsa_tests_count_p(_low, "loot"), "hurt: drink");
            var _high = __gmsa_tests_count_predict(_model, _ag, 90, 0);
            gmsa_test_assert_true(__gmsa_tests_count_p(_high, "loot") > __gmsa_tests_count_p(_high, "drink"), "healthy: loot");
        });

        gmsa_test_case("surprise drives learning", function() {
            var _model = gmsa_learn_linear_create();
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b"]));
            var _p0 = gmsa_learn_predict(_model, gmsa_agent_evaluate(_ag, 0)).p[0];
            gmsa_learn_observe(_model, gmsa_observe(_ag, ["a", "b"], 0, 0));
            var _p1 = gmsa_learn_predict(_model, gmsa_agent_evaluate(_ag, 0)).p[0];
            gmsa_learn_observe(_model, gmsa_observe(_ag, ["a", "b"], 0, 0));
            var _p2 = gmsa_learn_predict(_model, gmsa_agent_evaluate(_ag, 0)).p[0];
            gmsa_test_assert_true(_p1 > _p0, "first choice raises a");
            gmsa_test_assert_true(_p2 - _p1 < _p1 - _p0, "expected choice moves it less");
        });

        gmsa_test_case("decay fades old preferences", function() {
            var _model = gmsa_learn_linear_create({ half_life : 5 });
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b"]));
            repeat (30) gmsa_learn_observe(_model, gmsa_observe(_ag, ["a", "b"], 0, 0));
            repeat (30) gmsa_learn_observe(_model, gmsa_observe(_ag, ["a", "b"], 1, 0));
            var _out = gmsa_learn_predict(_model, gmsa_agent_evaluate(_ag, 0));
            gmsa_test_assert_true(_out.p[1] > _out.p[0], "recent preference wins");
        });

        gmsa_test_case("explain", function() {
            var _ctx = { list : [] };
            var _ag = gmsa_agent_create(__gmsa_tests_linear_loot_profile(_ctx));
            var _model = gmsa_learn_linear_create();
            __gmsa_tests_linear_train_value(_model, _ag, 60);
            _ctx.list = [{ v : 0.9, d : 0.8 }];
            var _line = gmsa_learn_explain(_model, gmsa_agent_evaluate(_ag, 0), 0)[0];
            gmsa_test_assert_true(string_pos("loot: ", _line) == 1, "starts with the action: " + _line);
            gmsa_test_assert_true(string_pos("value +", _line) > 0, "value contributes positively: " + _line);
            gmsa_test_assert_true(string_pos("bias ", _line) > 0, "bias shown: " + _line);
        });

        gmsa_test_case("save and load", function() {
            var _ctx = { list : [] };
            var _ag = gmsa_agent_create(__gmsa_tests_linear_loot_profile(_ctx));
            var _model = gmsa_learn_linear_create();
            __gmsa_tests_linear_train_value(_model, _ag, 40);
            var _json = gmsa_learn_save(_model);
            _ctx.list = [{ v : 0.9, d : 0.8 }, { v : 0.2, d : 0.1 }, { v : 0.5, d : 0.4 }];
            var _e = gmsa_agent_evaluate(_ag, 0);
            var _before = [];
            array_copy(_before, 0, gmsa_learn_predict(_model, _e).p, 0, 3);
            var _copy = gmsa_learn_linear_create();
            gmsa_learn_load(_copy, _json);
            var _after = gmsa_learn_predict(_copy, _e).p;
            for (var _i = 0; _i < 3; _i++) gmsa_test_assert_near(_after[_i], _before[_i], GMSA_TEST_EPS, "p " + string(_i));
        });
    });
}