function test_learn_ranknet() {
    gmsa_test_suite("Learn RankNet", function() {

        gmsa_test_case("create validates", function() {
            gmsa_test_assert_throws(function() { gmsa_learn_ranknet_create({ hidden : 8 }); }, "hidden not an array");
            gmsa_test_assert_throws(function() { gmsa_learn_ranknet_create({ hidden : [0] }); }, "hidden size 0");
            gmsa_test_assert_throws(function() { gmsa_learn_ranknet_create({ learn_rate : 0 }); }, "learn_rate 0");
            gmsa_test_assert_throws(function() { gmsa_learn_ranknet_create({ activation : 9 }); }, "bad activation");
            gmsa_test_assert_throws(function() { gmsa_learn_ranknet_create({ optimizer : 9 }); }, "bad optimizer");
            var _m = gmsa_learn_ranknet_create();
            gmsa_test_assert_equal(_m.tier, gmsa_learn_tier.RANKNET, "tier");
            gmsa_test_assert_equal(_m.tier_name, "ranknet", "tier name");
        });

        gmsa_test_case("untrained predicts evenly with no confidence", function() {
            var _m = gmsa_learn_ranknet_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            gmsa_test_assert_near(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 1 / 3, 0.000001, "even");
            gmsa_test_assert_near(gmsa_learn_confidence(_m), 0, 0.000001, "no confidence");
        });

        gmsa_test_case("learns a habit", function() {
            var _m = gmsa_learn_ranknet_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            var _rng = gmsa_rng_create(3);
            repeat (40) __test_rn_observe(_m, _agent, gmsa_rng_next(_rng), gmsa_rng_next(_rng), 1);
            gmsa_test_assert_range(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 0.8, 1, "prefers loot");
            gmsa_test_assert_true(gmsa_learn_confidence(_m) > 0.3, "gains confidence");
        });

        gmsa_test_case("learns an interaction Linear can't", function() {
            // "same" when hp and danger are both low or both high, "differ" otherwise (XOR)
            var _rn = gmsa_learn_ranknet_create();
            var _lin = gmsa_learn_linear_create();
            var _agent = __test_rn_agent(["same", "differ"]);
            var _corners = [[0.1, 0.1, 0], [0.9, 0.9, 0], [0.1, 0.9, 1], [0.9, 0.1, 1]];
            repeat (300) {
                for (var _c = 0; _c < 4; _c++) {
                    var _k = _corners[_c];
                    gmsa_agent_set_input(_agent, "hp", _k[0]);
                    gmsa_agent_set_input(_agent, "danger", _k[1]);
                    var _d = gmsa_observe(_agent, ["same", "differ"], _k[2]);
                    gmsa_learn_observe(_rn, _d);
                    gmsa_learn_observe(_lin, _d);
                }
            }
            var _rn_worst = 1, _lin_worst = 1;
            for (var _c = 0; _c < 4; _c++) {
                var _k = _corners[_c];
                var _right = (_k[2] == 0) ? "same" : "differ";
                _rn_worst = min(_rn_worst, __test_rn_p(_rn, _agent, _k[0], _k[1], _right));
                _lin_worst = min(_lin_worst, __test_rn_p(_lin, _agent, _k[0], _k[1], _right));
            }
            gmsa_test_assert_range(_rn_worst, 0.75, 1, "ranknet gets every corner");
            gmsa_test_assert_range(_lin_worst, 0, 0.65, "linear can't");
        });

        gmsa_test_case("same seed, same model", function() {
            var _a = gmsa_learn_ranknet_create({ seed : 5 });
            var _b = gmsa_learn_ranknet_create({ seed : 5 });
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            for (var _i = 0; _i < 20; _i++) {
                gmsa_agent_set_input(_agent, "hp", (_i mod 5) / 5);
                gmsa_agent_set_input(_agent, "danger", (_i mod 3) / 3);
                var _d = gmsa_observe(_agent, ["drink", "loot", "flee"], _i mod 3);
                gmsa_learn_observe(_a, _d);
                gmsa_learn_observe(_b, _d);
            }
            gmsa_test_assert_equal(__test_rn_p(_a, _agent, 0.3, 0.7, "drink"), __test_rn_p(_b, _agent, 0.3, 0.7, "drink"));
        });

        gmsa_test_case("a single option teaches nothing", function() {
            var _m = gmsa_learn_ranknet_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (10) {
                gmsa_agent_set_input(_agent, "hp", 0.5);
                gmsa_learn_observe(_m, gmsa_observe(_agent, ["loot"], 0));
            }
            gmsa_test_assert_near(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 1 / 3, 0.000001);
        });

        gmsa_test_case("new actions keep what was learned", function() {
            var _m = gmsa_learn_ranknet_create();
            var _small = __test_rn_agent(["drink", "loot"]);
            repeat (40) __test_rn_observe(_m, _small, 0.5, 0.5, 1);
            var _big = __test_rn_agent(["flee", "drink", "loot"]);
            var _loot = __test_rn_p(_m, _big, 0.5, 0.5, "loot");
            gmsa_test_assert_true(_loot > __test_rn_p(_m, _big, 0.5, 0.5, "drink"), "loot above drink");
            gmsa_test_assert_true(_loot > __test_rn_p(_m, _big, 0.5, 0.5, "flee"), "loot above the new action");
        });

        gmsa_test_case("explain", function() {
            var _m = gmsa_learn_ranknet_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (20) __test_rn_observe(_m, _agent, 0.2, 0.8, 0);
            gmsa_agent_set_input(_agent, "hp", 0.2);
            gmsa_agent_set_input(_agent, "danger", 0.8);
            var _lines = gmsa_learn_explain(_m, gmsa_agent_evaluate(_agent), 0);
            gmsa_test_assert_equal(array_length(_lines), 1, "one line");
            gmsa_test_assert_true(string_pos("score", _lines[0]) > 0, "shows the score");
        });

        gmsa_test_case("save and load", function() {
            var _a = gmsa_learn_ranknet_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            var _rng = gmsa_rng_create(8);
            repeat (30) __test_rn_observe(_a, _agent, gmsa_rng_next(_rng), gmsa_rng_next(_rng), 2);
            var _json = gmsa_learn_save(_a);

            var _b = gmsa_learn_ranknet_create({ seed : 77 });
            gmsa_learn_load(_b, _json);
            gmsa_test_assert_near(__test_rn_p(_b, _agent, 0.4, 0.6, "flee"), __test_rn_p(_a, _agent, 0.4, 0.6, "flee"), 0.000001, "same predictions");

            var _fresh = gmsa_learn_ranknet_create();
            gmsa_learn_load(_fresh, gmsa_learn_save(gmsa_learn_ranknet_create()));
            gmsa_test_assert_near(__test_rn_p(_fresh, _agent, 0.4, 0.6, "flee"), 1 / 3, 0.000001, "untrained save loads");

            gmsa_test_assert_throws(method({ json : _json }, function() {
                gmsa_learn_load(gmsa_learn_ranknet_create({ hidden : [4] }), json);
            }), "different hidden layers");
        });

        gmsa_test_case("reset forgets", function() {
            var _m = gmsa_learn_ranknet_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (30) __test_rn_observe(_m, _agent, 0.5, 0.5, 1);
            gmsa_learn_reset(_m);
            gmsa_test_assert_near(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 1 / 3, 0.000001);
        });
    });
}

function __test_rn_agent(_actions) {
    var _p = gmsa_profile_create("ranknet test");
    gmsa_profile_add_input(_p, gmsa_input_push("hp"));
    gmsa_profile_add_input(_p, gmsa_input_push("danger"));
    for (var _i = 0; _i < array_length(_actions); _i++) gmsa_profile_add_action(_p, _actions[_i]);
    gmsa_profile_set_features(_p, ["hp", "danger"]);
    return gmsa_agent_create(gmsa_profile_build(_p), {});
}

function __test_rn_observe(_model, _agent, _hp, _danger, _chosen) {
    gmsa_agent_set_input(_agent, "hp", _hp);
    gmsa_agent_set_input(_agent, "danger", _danger);
    var _actions = _agent.profile.actions;
    var _names = array_create(array_length(_actions), "");
    for (var _i = 0; _i < array_length(_actions); _i++) _names[_i] = _actions[_i].name;
    gmsa_learn_observe(_model, gmsa_observe(_agent, _names, _chosen));
}

function __test_rn_p(_model, _agent, _hp, _danger, _action) {
    gmsa_agent_set_input(_agent, "hp", _hp);
    gmsa_agent_set_input(_agent, "danger", _danger);
    var _d = gmsa_agent_evaluate(_agent);
    var _r = gmsa_learn_predict(_model, _d);
    for (var _i = 0; _i < array_length(_d.options); _i++) {
        if (_d.options[_i].action.name == _action) return _r.p[_i];
    }
    return -1;
}