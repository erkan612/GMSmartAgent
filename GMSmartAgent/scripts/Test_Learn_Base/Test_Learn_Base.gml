function __gmsa_tests_learn_profile(_actions, _features = ["x", "y"]) {
    var _p = gmsa_profile_create("learn");
    gmsa_profile_add_input(_p, gmsa_input_push("x"));
    gmsa_profile_add_input(_p, gmsa_input_push("y"));
    for (var _i = 0; _i < array_length(_actions); _i++) gmsa_profile_add_action(_p, _actions[_i]);
    gmsa_profile_set_features(_p, _features);
    return gmsa_profile_build(_p);
}

function __gmsa_tests_favorite_model(_params = {}) {
    return gmsa_learn_custom({
        observe : function(_sample) {
            var _n = array_length(actions);
            while (array_length(data.counts) < _n) array_push(data.counts, 0);
            for (var _i = 0; _i < _n; _i++) data.counts[_i] *= decay;
            data.counts[_sample.options[_sample.chosen].action] += _sample.weight;
        },
        predict : function(_sample, _out) {
            for (var _i = 0; _i < array_length(_sample.options); _i++) {
                var _id = _sample.options[_i].action;
                _out.p[_i] = ((_id < array_length(data.counts)) ? data.counts[_id] : 0) + 1;
            }
            _out.confidence = gmsa_learn_confidence(self);
        },
        explain    : function(_sample, _i) { return ["seen " + actions[_sample.options[_i].action]]; },
        save_data  : function() { return { counts : data.counts }; },
        load_data  : function(_data) { data.counts = _data.counts; },
        reset_data : function() { data.counts = []; },
    }, _params);
}

function __gmsa_tests_learn_choose(_model, _agent, _offered, _chosen_name) {
    var _chosen = -1;
    for (var _i = 0; _i < array_length(_offered); _i++) if (_offered[_i] == _chosen_name) _chosen = _i;
    gmsa_learn_observe(_model, gmsa_observe(_agent, _offered, _chosen, 0));
}

function gmsa_tests_learn_base() {
    gmsa_test_suite("Learn base", function() {

        gmsa_test_case("custom needs observe and predict", function() {
            gmsa_test_assert_throws(function() { gmsa_learn_custom({ observe : function(_s) {} }); }, "no predict");
            gmsa_test_assert_throws(function() { gmsa_learn_custom({ predict : function(_s, _o) {} }); }, "no observe");
            gmsa_test_assert_throws(function() { gmsa_learn_custom({ observe : 1, predict : "x" }); }, "not callable");
            gmsa_test_assert_throws(function() { __gmsa_tests_favorite_model({ half_life : 0 }); }, "bad half life");
        });

        gmsa_test_case("observe needs features and a choice", function() {
            var _ctx = {
                model : __gmsa_tests_favorite_model(),
                plain : gmsa_agent_create(__gmsa_tests_simple_profile(["a"])),
                ag    : gmsa_agent_create(__gmsa_tests_learn_profile(["a"])),
            };
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_learn_observe(model, gmsa_observe(plain, ["a"], 0, 0));
            }), "profile without features");
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_learn_observe(model, gmsa_agent_evaluate(ag, 0));
            }), "nothing chosen");
        });

        gmsa_test_case("learns from observed choices", function() {
            var _model = __gmsa_tests_favorite_model();
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b", "c"]));
            var _offer = ["a", "b", "c"];
            __gmsa_tests_learn_choose(_model, _ag, _offer, "b");
            __gmsa_tests_learn_choose(_model, _ag, _offer, "b");
            __gmsa_tests_learn_choose(_model, _ag, _offer, "b");
            __gmsa_tests_learn_choose(_model, _ag, _offer, "a");
            var _e = gmsa_agent_evaluate(_ag, 0);
            var _out = gmsa_learn_predict(_model, _e);
            gmsa_test_assert_equal(array_length(_out.p), array_length(_e.options), "one p per option");
            var _sum = 0, _best = 0;
            for (var _i = 0; _i < array_length(_out.p); _i++) {
                _sum += _out.p[_i];
                if (_out.p[_i] > _out.p[_best]) _best = _i;
            }
            gmsa_test_assert_near(_sum, 1, GMSA_TEST_EPS, "sums to 1");
            gmsa_test_assert_equal(_e.options[_best].action.name, "b", "b is the favorite");
            gmsa_test_assert_range(_out.confidence, 0.01, 0.99, "some confidence");
        });

        gmsa_test_case("binds by name across profiles", function() {
            var _model = __gmsa_tests_favorite_model();
            var _player = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b"]));
            repeat (4) __gmsa_tests_learn_choose(_model, _player, ["a", "b"], "b");
            var _pet = gmsa_agent_create(__gmsa_tests_learn_profile(["c", "b", "a"]));
            var _e = gmsa_agent_evaluate(_pet, 0);
            var _out = gmsa_learn_predict(_model, _e);
            var _best = 0;
            for (var _i = 1; _i < array_length(_out.p); _i++) if (_out.p[_i] > _out.p[_best]) _best = _i;
            gmsa_test_assert_equal(_e.options[_best].action.name, "b", "b found by name in another profile");
            gmsa_test_assert_equal(_model.actions, ["a", "b", "c"], "vocabulary grew");
        });

        gmsa_test_case("sample maps inputs by name", function() {
            var _model = gmsa_learn_custom({
                observe : function(_sample) {
                    data.last = [];
                    array_copy(data.last, 0, _sample.options[_sample.chosen].inputs, 0, array_length(_sample.options[_sample.chosen].inputs));
                    data.situation = [];
                    array_copy(data.situation, 0, _sample.situation, 0, array_length(_sample.situation));
                },
                predict : function(_sample, _out) {},
            });
            var _p1 = gmsa_agent_create(__gmsa_tests_learn_profile(["a"], ["x", "y"]));
            gmsa_agent_set_input(_p1, "x", 0.2);
            gmsa_agent_set_input(_p1, "y", 0.9);
            gmsa_learn_observe(_model, gmsa_observe(_p1, ["a"], 0, 0));
            gmsa_test_assert_equal(_model.data.last, [0.2, 0.9], "first profile");
            var _p2 = gmsa_agent_create(__gmsa_tests_learn_profile(["a"], ["y", "x"]));
            gmsa_agent_set_input(_p2, "x", 0.3);
            gmsa_agent_set_input(_p2, "y", 0.7);
            gmsa_learn_observe(_model, gmsa_observe(_p2, ["a"], 0, 0));
            gmsa_test_assert_equal(_model.data.last, [0.3, 0.7], "reversed feature order lands on the same ids");

            var _m2 = gmsa_learn_custom({
                observe : function(_sample) {
                    data.situation = [];
                    array_copy(data.situation, 0, _sample.situation, 0, array_length(_sample.situation));
                },
                predict : function(_sample, _out) {},
            });
            var _fp = gmsa_profile_build(__gmsa_tests_feature_profile(function(_agent, _target) { return 0.3; }, []));
            var _fa = gmsa_agent_create(_fp);
            gmsa_agent_set_input(_fa, "hp", 50);
            gmsa_learn_observe(_m2, gmsa_observe(_fa, [{ action : "attack", target : { d : 0.6 } }], 0, 0));
            gmsa_test_assert_equal(_m2.situational, [true, false, true], "per-target input is not situational");
            gmsa_test_assert_equal(_m2.data.situation, [0.5, 0, 0.3], "situation leaves per-target inputs out");
        });

        gmsa_test_case("frozen model doesn't learn", function() {
            var _model = __gmsa_tests_favorite_model();
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a"]));
            gmsa_learn_freeze(_model);
            gmsa_test_assert_false(gmsa_learn_observe(_model, gmsa_observe(_ag, ["a"], 0, 0)), "returns false");
            gmsa_test_assert_equal(_model.samples, 0, "no samples");
            gmsa_learn_freeze(_model, false);
            gmsa_test_assert_true(gmsa_learn_observe(_model, gmsa_observe(_ag, ["a"], 0, 0)), "learns again");
        });

        gmsa_test_case("samples decay", function() {
            var _model = __gmsa_tests_favorite_model({ half_life : 2 });
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a"]));
            repeat (3) gmsa_learn_observe(_model, gmsa_observe(_ag, ["a"], 0, 0));
            var _d = power(0.5, 1 / 2);
            gmsa_test_assert_near(_model.samples, 1 + _d + _d * _d, GMSA_TEST_EPS, "decayed sum");
            gmsa_test_assert_near(gmsa_learn_confidence(_model, 20), 0.5, GMSA_TEST_EPS, "confidence at k");
        });

        gmsa_test_case("reset forgets", function() {
            var _model = __gmsa_tests_favorite_model();
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b"]));
            repeat (5) __gmsa_tests_learn_choose(_model, _ag, ["a", "b"], "b");
            gmsa_learn_reset(_model);
            gmsa_test_assert_equal(_model.samples, 0, "samples");
            var _out = gmsa_learn_predict(_model, gmsa_agent_evaluate(_ag, 0));
            gmsa_test_assert_near(_out.p[0], 0.5, GMSA_TEST_EPS, "back to even");
            gmsa_test_assert_near(_out.confidence, 0, GMSA_TEST_EPS, "no confidence");
        });

        gmsa_test_case("save and load", function() {
            var _model = __gmsa_tests_favorite_model();
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b", "c"]));
            repeat (3) __gmsa_tests_learn_choose(_model, _ag, ["a", "b", "c"], "c");
            __gmsa_tests_learn_choose(_model, _ag, ["a", "b", "c"], "a");
            var _json = gmsa_learn_save(_model);
            var _e = gmsa_agent_evaluate(_ag, 0);
            var _before = [];
            array_copy(_before, 0, gmsa_learn_predict(_model, _e).p, 0, 3);

            var _copy = __gmsa_tests_favorite_model();
            gmsa_test_assert_true(gmsa_learn_load(_copy, _json), "loaded");
            gmsa_test_assert_near(_copy.samples, _model.samples, GMSA_TEST_EPS, "samples");
            var _after = gmsa_learn_predict(_copy, _e).p;
            for (var _i = 0; _i < 3; _i++) gmsa_test_assert_near(_after[_i], _before[_i], GMSA_TEST_EPS, "p " + string(_i));

            var _ctx = { json : _json };
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_learn_load(__gmsa_tests_favorite_model({ name : "other" }), json);
            }), "other tier");
            gmsa_test_assert_throws(function() {
                gmsa_learn_load(__gmsa_tests_favorite_model(), "{\"format\":\"nope\"}");
            }, "not a save");
        });

        gmsa_test_case("predict sanitizes custom output", function() {
            var _model = gmsa_learn_custom({
                observe : function(_sample) {},
                predict : function(_sample, _out) { _out.p[0] = -1; _out.p[1] = NaN; _out.confidence = 5; },
            });
            var _ag = gmsa_agent_create(__gmsa_tests_learn_profile(["a", "b"]));
            var _out = gmsa_learn_predict(_model, gmsa_agent_evaluate(_ag, 0));
            gmsa_test_assert_near(_out.p[0], 0.5, GMSA_TEST_EPS, "falls back to even");
            gmsa_test_assert_near(_out.p[1], 0.5, GMSA_TEST_EPS, "NaN cleaned");
            gmsa_test_assert_near(_out.confidence, 1, GMSA_TEST_EPS, "confidence clamped");
        });
    });
}