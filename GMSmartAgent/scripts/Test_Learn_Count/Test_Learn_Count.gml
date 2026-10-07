function __gmsa_tests_count_profile(_actions, _extra = 0) {
    var _p = gmsa_profile_create("count");
    var _features = ["hp", "danger"];
    gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100));
    gmsa_profile_add_input(_p, gmsa_input_push("danger", 0, 100));
    for (var _i = 0; _i < _extra; _i++) {
        var _name = "extra" + string(_i);
        gmsa_profile_add_input(_p, gmsa_input_push(_name));
        array_push(_features, _name);
    }
    for (var _i = 0; _i < array_length(_actions); _i++) gmsa_profile_add_action(_p, _actions[_i]);
    gmsa_profile_set_features(_p, _features);
    return gmsa_profile_build(_p);
}

function __gmsa_tests_count_choose(_model, _agent, _hp, _danger, _offered, _chosen_name, _times = 1) {
    gmsa_agent_set_input(_agent, "hp", _hp);
    gmsa_agent_set_input(_agent, "danger", _danger);
    var _idx = -1;
    for (var _i = 0; _i < array_length(_offered); _i++) if (_offered[_i] == _chosen_name) _idx = _i;
    repeat (_times) gmsa_learn_observe(_model, gmsa_observe(_agent, _offered, _idx, 0));
}

function __gmsa_tests_count_predict(_model, _agent, _hp, _danger) {
    gmsa_agent_set_input(_agent, "hp", _hp);
    gmsa_agent_set_input(_agent, "danger", _danger);
    var _e = gmsa_agent_evaluate(_agent, 0);
    return { out : gmsa_learn_predict(_model, _e), e : _e };
}

function __gmsa_tests_count_p(_r, _action) {
    for (var _i = 0; _i < array_length(_r.e.options); _i++) {
        if (_r.e.options[_i].action.name == _action) return _r.out.p[_i];
    }
    return -1;
}

function gmsa_tests_learn_count() {
    gmsa_test_suite("Learn count", function() {

        gmsa_test_case("create validation", function() {
            gmsa_test_assert_throws(function() { gmsa_learn_count_create({ bins : 0 }); }, "bins 0");
            gmsa_test_assert_throws(function() { gmsa_learn_count_create({ bins : 1.5 }); }, "fractional bins");
            gmsa_test_assert_throws(function() { gmsa_learn_count_create({ smoothing : 0 }); }, "smoothing 0");
            gmsa_test_assert_throws(function() { gmsa_learn_count_create({ inputs : [] }); }, "empty inputs");
            gmsa_test_assert_throws(function() {
                gmsa_learn_count_create({ inputs : ["a", "b", "c", "d", "e", "f", "g"] });
            }, "too many buckets at creation");
            var _ctx = {
                model : gmsa_learn_count_create(),
                ag    : gmsa_agent_create(__gmsa_tests_count_profile(["drink"], 5)),
            };
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_learn_observe(model, gmsa_observe(ag, ["drink"], 0, 0));
            }), "too many buckets on first use");
        });

        gmsa_test_case("learns a habit per situation", function() {
            var _model = gmsa_learn_count_create();
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot", "flee"]));
            __gmsa_tests_count_choose(_model, _ag, 20, 0, ["drink", "loot"], "drink", 6);
            __gmsa_tests_count_choose(_model, _ag, 20, 0, ["drink", "loot"], "loot", 1);
            __gmsa_tests_count_choose(_model, _ag, 90, 0, ["drink", "loot"], "loot", 5);
            var _low = __gmsa_tests_count_predict(_model, _ag, 20, 0);
            gmsa_test_assert_true(__gmsa_tests_count_p(_low, "drink") > __gmsa_tests_count_p(_low, "loot"), "hurt: drink");
            gmsa_test_assert_true(__gmsa_tests_count_p(_low, "drink") > __gmsa_tests_count_p(_low, "flee"), "hurt: not flee");
            var _high = __gmsa_tests_count_predict(_model, _ag, 90, 0);
            gmsa_test_assert_true(__gmsa_tests_count_p(_high, "loot") > __gmsa_tests_count_p(_high, "drink"), "healthy: loot");
        });

        gmsa_test_case("one sample is not certainty", function() {
            var _model = gmsa_learn_count_create();
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            __gmsa_tests_count_choose(_model, _ag, 20, 0, ["drink", "loot"], "drink");
            var _r = __gmsa_tests_count_predict(_model, _ag, 20, 0);
            gmsa_test_assert_near(__gmsa_tests_count_p(_r, "drink"), 2 / 3, GMSA_TEST_EPS, "smoothed");
        });

        gmsa_test_case("confidence is per bucket", function() {
            var _model = gmsa_learn_count_create();
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            __gmsa_tests_count_choose(_model, _ag, 20, 0, ["drink", "loot"], "drink", 20);
            gmsa_test_assert_true(__gmsa_tests_count_predict(_model, _ag, 20, 0).out.confidence > 0.7, "seen situation");
            gmsa_test_assert_near(__gmsa_tests_count_predict(_model, _ag, 90, 0).out.confidence, 0, GMSA_TEST_EPS, "unseen situation");
        });

        gmsa_test_case("same action options split their share", function() {
            var _model = gmsa_learn_count_create();
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            var _d = gmsa_observe(_ag, ["loot", "loot", "drink"], 0, 0);
            var _out = gmsa_learn_predict(_model, _d);
            gmsa_test_assert_near(_out.p[0], 0.25, GMSA_TEST_EPS, "loot 1");
            gmsa_test_assert_near(_out.p[1], 0.25, GMSA_TEST_EPS, "loot 2");
            gmsa_test_assert_near(_out.p[2], 0.5,  GMSA_TEST_EPS, "drink");
        });

        gmsa_test_case("decay fades old habits", function() {
            var _model = gmsa_learn_count_create({ half_life : 5 });
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            __gmsa_tests_count_choose(_model, _ag, 20, 0, ["drink", "loot"], "drink", 10);
            __gmsa_tests_count_choose(_model, _ag, 20, 0, ["drink", "loot"], "loot", 10);
            var _r = __gmsa_tests_count_predict(_model, _ag, 20, 0);
            gmsa_test_assert_true(__gmsa_tests_count_p(_r, "loot") > __gmsa_tests_count_p(_r, "drink"), "recent habit wins");
        });

        gmsa_test_case("explain", function() {
            var _model = gmsa_learn_count_create({ half_life : 1000000000 });
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            __gmsa_tests_count_choose(_model, _ag, 20, 90, ["drink", "loot"], "drink", 7);
            __gmsa_tests_count_choose(_model, _ag, 20, 90, ["drink", "loot"], "loot", 2);
            var _d = gmsa_observe(_ag, ["drink", "loot"], 0, 0);
            var _line = gmsa_learn_explain(_model, _d, 0)[0];
            gmsa_test_assert_true(string_pos("hp 0-25%", _line) > 0, "hp bin: " + _line);
            gmsa_test_assert_true(string_pos("danger 75-100%", _line) > 0, "danger bin: " + _line);
            gmsa_test_assert_true(string_pos("drink 7.0 of 9.0 (0.73)", _line) > 0, "counts: " + _line);
            gmsa_agent_set_input(_ag, "hp", 90);
            var _fresh = gmsa_learn_explain(_model, gmsa_observe(_ag, ["drink", "loot"], 0, 0), 0)[0];
            gmsa_test_assert_true(string_pos("no data yet", _fresh) > 0, "unseen: " + _fresh);
        });

        gmsa_test_case("save and load", function() {
            var _model = gmsa_learn_count_create();
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            __gmsa_tests_count_choose(_model, _ag, 20, 0, ["drink", "loot"], "drink", 4);
            __gmsa_tests_count_choose(_model, _ag, 90, 0, ["drink", "loot"], "loot", 3);
            var _json = gmsa_learn_save(_model);
            var _copy = gmsa_learn_count_create();
            gmsa_learn_load(_copy, _json);
            var _hps = [20, 90];
            for (var _h = 0; _h < 2; _h++) {
                var _a = __gmsa_tests_count_predict(_model, _ag, _hps[_h], 0);
                var _pa = [__gmsa_tests_count_p(_a, "drink"), _a.out.confidence];
                var _b = __gmsa_tests_count_predict(_copy, _ag, _hps[_h], 0);
                gmsa_test_assert_near(__gmsa_tests_count_p(_b, "drink"), _pa[0], GMSA_TEST_EPS, "p at hp " + string(_hps[_h]));
                gmsa_test_assert_near(_b.out.confidence, _pa[1], GMSA_TEST_EPS, "confidence at hp " + string(_hps[_h]));
            }
            var _ctx = { json : _json };
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_learn_load(gmsa_learn_count_create({ bins : 3 }), json);
            }), "different bins");
        });

        gmsa_test_case("explicit inputs ignore the rest", function() {
            var _only_hp = gmsa_learn_count_create({ inputs : ["hp"] });
            var _all = gmsa_learn_count_create();
            var _ag = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            __gmsa_tests_count_choose(_only_hp, _ag, 20, 90, ["drink", "loot"], "drink", 5);
            __gmsa_tests_count_choose(_all,     _ag, 20, 90, ["drink", "loot"], "drink", 5);
            gmsa_test_assert_true(__gmsa_tests_count_predict(_only_hp, _ag, 20, 10).out.confidence > 0, "danger ignored");
            gmsa_test_assert_near(__gmsa_tests_count_predict(_all, _ag, 20, 10).out.confidence, 0, GMSA_TEST_EPS, "danger matters by default");
        });
		
        gmsa_test_case("no situational inputs: one bucket, no crash", function() {
            var _space = gmsa_learn_space("count no situation", ["potion"], ["price"], { situational : [false] });
            var _m = gmsa_learn_count_create();
            var _offer = [{ action : 0, inputs : [0.2] }, { action : 0, inputs : [0.8] }];
            repeat (3) gmsa_learn_space_observe(_m, _space, _offer, 0);
            gmsa_test_assert_true(variable_struct_exists(_m.data.buckets, "any"), "one bucket");
            gmsa_test_assert_near(gmsa_learn_space_predict(_m, _space, _offer).p[0], 0.5);
        });
    });
}