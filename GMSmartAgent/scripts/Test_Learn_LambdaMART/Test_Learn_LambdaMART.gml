function test_learn_lambdamart() {
    gmsa_test_suite("Learn LambdaMART", function() {

        gmsa_test_case("create validates", function() {
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ trees : 0 }); }, "trees 0");
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ depth : 0 }); }, "depth 0");
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ depth : 9 }); }, "depth 9");
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ learn_rate : 0 }); }, "learn_rate 0");
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ reg : -1 }); }, "negative reg");
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ bins : 1 }); }, "bins 1");
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ min_leaf : 0 }); }, "min_leaf 0");
            gmsa_test_assert_throws(function() { gmsa_learn_lambdamart_create({ buffer : 0 }); }, "buffer 0");
            var _m = gmsa_learn_lambdamart_create();
            gmsa_test_assert_equal(_m.tier, gmsa_learn_tier.LAMBDAMART, "tier");
            gmsa_test_assert_equal(_m.tier_name, "lambdamart", "tier name");
        });

        gmsa_test_case("untrained predicts evenly with no confidence", function() {
            var _m = gmsa_learn_lambdamart_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (10) __test_rn_observe(_m, _agent, 0.5, 0.5, 1);
            gmsa_test_assert_near(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 1 / 3, 0.000001, "observing alone changes nothing");
            var _r = gmsa_learn_predict(_m, gmsa_agent_evaluate(_agent));
            gmsa_test_assert_near(_r.confidence, 0, 0.000001, "no confidence before training");
        });

        gmsa_test_case("learns a habit", function() {
            var _m = gmsa_learn_lambdamart_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            var _rng = gmsa_rng_create(3);
            repeat (20) __test_rn_observe(_m, _agent, gmsa_rng_next(_rng), gmsa_rng_next(_rng), 1);
            gmsa_test_assert_true(gmsa_learn_train(_m), "train finishes without a budget");
            gmsa_test_assert_range(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 0.8, 1, "prefers loot");
            var _r = gmsa_learn_predict(_m, gmsa_agent_evaluate(_agent));
            gmsa_test_assert_true(_r.confidence > 0.2, "confident once trained");
        });

        gmsa_test_case("learns an uneven interaction Linear can't", function() {
            // "same" when hp and danger are both low or both high, "differ" otherwise, corners seen 50/40/30/20 times
            var _lm = gmsa_learn_lambdamart_create();
            var _lin = gmsa_learn_linear_create();
            var _agent = __test_rn_agent(["same", "differ"]);
            var _corners = [[0.1, 0.1, 0, 50], [0.9, 0.9, 0, 40], [0.1, 0.9, 1, 30], [0.9, 0.1, 1, 20]];
            var _rng = gmsa_rng_create(4);
            for (var _round = 0; _round < 50; _round++) {
                for (var _c = 0; _c < 4; _c++) {
                    var _k = _corners[_c];
                    if (_round >= _k[3]) continue;
                    gmsa_agent_set_input(_agent, "hp", _k[0] + gmsa_rng_next(_rng) * 0.1 - 0.05);
                    gmsa_agent_set_input(_agent, "danger", _k[1] + gmsa_rng_next(_rng) * 0.1 - 0.05);
                    var _d = gmsa_observe(_agent, ["same", "differ"], _k[2]);
                    gmsa_learn_observe(_lm, _d);
                    gmsa_learn_observe(_lin, _d);
                }
            }
            gmsa_learn_train(_lm);
            var _lm_worst = 1, _lin_worst = 1;
            for (var _c = 0; _c < 4; _c++) {
                var _k = _corners[_c];
                var _right = (_k[2] == 0) ? "same" : "differ";
                _lm_worst = min(_lm_worst, __test_rn_p(_lm, _agent, _k[0], _k[1], _right));
                _lin_worst = min(_lin_worst, __test_rn_p(_lin, _agent, _k[0], _k[1], _right));
            }
            gmsa_test_assert_range(_lm_worst, 0.75, 1, "lambdamart gets every corner");
            gmsa_test_assert_range(_lin_worst, 0, 0.6, "linear can't");
        });

        gmsa_test_case("budgeted training matches unbudgeted", function() {
            var _a = gmsa_learn_lambdamart_create({ trees : 10 });
            var _b = gmsa_learn_lambdamart_create({ trees : 10 });
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            var _rng = gmsa_rng_create(6);
            repeat (30) {
                gmsa_agent_set_input(_agent, "hp", gmsa_rng_next(_rng));
                gmsa_agent_set_input(_agent, "danger", gmsa_rng_next(_rng));
                var _d = gmsa_observe(_agent, ["drink", "loot", "flee"], floor(gmsa_rng_next(_rng) * 3));
                gmsa_learn_observe(_a, _d);
                gmsa_learn_observe(_b, _d);
            }
            gmsa_learn_train(_a);
            var _calls = 1;
            while (!gmsa_learn_train(_b, 0)) _calls += 1;
            gmsa_test_assert_true(_calls > 10, "spread over many calls");
            gmsa_test_assert_equal(__test_rn_p(_b, _agent, 0.3, 0.7, "drink"), __test_rn_p(_a, _agent, 0.3, 0.7, "drink"), "same result");
        });

        gmsa_test_case("old trees predict until training finishes", function() {
            var _m = gmsa_learn_lambdamart_create({ trees : 10 });
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (20) __test_rn_observe(_m, _agent, 0.5, 0.5, 1);
            gmsa_learn_train(_m);
            var _before = __test_rn_p(_m, _agent, 0.5, 0.5, "loot");
            repeat (40) __test_rn_observe(_m, _agent, 0.5, 0.5, 0);
            gmsa_test_assert_false(gmsa_learn_train(_m, 0), "one unit doesn't finish");
            gmsa_test_assert_equal(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), _before, "unchanged mid training");
            while (!gmsa_learn_train(_m, 0)) {}
            gmsa_test_assert_true(__test_rn_p(_m, _agent, 0.5, 0.5, "drink") > __test_rn_p(_m, _agent, 0.5, 0.5, "loot"), "new habit after");
        });

        gmsa_test_case("buffer keeps the newest", function() {
            var _m = gmsa_learn_lambdamart_create({ buffer : 10 });
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (15) __test_rn_observe(_m, _agent, 0.5, 0.5, 1);
            repeat (10) __test_rn_observe(_m, _agent, 0.5, 0.5, 0);
            gmsa_test_assert_equal(array_length(_m.data.buffer), 10, "bounded");
            gmsa_learn_train(_m);
            gmsa_test_assert_range(__test_rn_p(_m, _agent, 0.5, 0.5, "drink"), 0.8, 1, "only the newest choices count");
        });

        gmsa_test_case("explain", function() {
            var _m = gmsa_learn_lambdamart_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (20) __test_rn_observe(_m, _agent, 0.2, 0.8, 0);
            gmsa_learn_train(_m);
            gmsa_agent_set_input(_agent, "hp", 0.2);
            gmsa_agent_set_input(_agent, "danger", 0.8);
            var _lines = gmsa_learn_explain(_m, gmsa_agent_evaluate(_agent), 0);
            gmsa_test_assert_equal(array_length(_lines), 1, "one line");
            gmsa_test_assert_true(string_pos("score", _lines[0]) > 0, "shows the score");
        });

        gmsa_test_case("save and load keep trees and buffer", function() {
            var _a = gmsa_learn_lambdamart_create({ trees : 20 });
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            var _rng = gmsa_rng_create(8);
            repeat (30) __test_rn_observe(_a, _agent, gmsa_rng_next(_rng), gmsa_rng_next(_rng), 2);
            gmsa_learn_train(_a);
            var _b = gmsa_learn_lambdamart_create({ trees : 20 });
            gmsa_learn_load(_b, gmsa_learn_save(_a));
            gmsa_test_assert_near(__test_rn_p(_b, _agent, 0.4, 0.6, "flee"), __test_rn_p(_a, _agent, 0.4, 0.6, "flee"), 0.000001, "same trees");

            repeat (10) {
                __test_rn_observe(_a, _agent, 0.5, 0.5, 0);
                __test_rn_observe(_b, _agent, 0.5, 0.5, 0);
            }
            gmsa_learn_train(_a);
            gmsa_learn_train(_b);
            gmsa_test_assert_near(__test_rn_p(_b, _agent, 0.4, 0.6, "drink"), __test_rn_p(_a, _agent, 0.4, 0.6, "drink"), 0.000001, "same buffer");
        });

        gmsa_test_case("reset, freeze and other tiers", function() {
            var _m = gmsa_learn_lambdamart_create({ trees : 10 });
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            gmsa_test_assert_true(gmsa_learn_train(_m), "empty buffer finishes at once");
            repeat (20) __test_rn_observe(_m, _agent, 0.5, 0.5, 1);
            gmsa_learn_freeze(_m);
            gmsa_test_assert_true(gmsa_learn_train(_m), "frozen finishes at once");
            gmsa_test_assert_near(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 1 / 3, 0.000001, "frozen doesn't train");
            gmsa_learn_freeze(_m, false);
            gmsa_learn_train(_m);
            gmsa_learn_reset(_m);
            gmsa_test_assert_near(__test_rn_p(_m, _agent, 0.5, 0.5, "loot"), 1 / 3, 0.000001, "reset forgets");
            gmsa_test_assert_equal(array_length(_m.data.buffer), 0, "reset empties the buffer");
            gmsa_test_assert_true(gmsa_learn_train(gmsa_learn_linear_create()), "online tiers return true");
        });
		
        gmsa_test_case("custom models can train", function() {
            var _m = gmsa_learn_custom({
                observe : function(_sample) {},
                predict : function(_sample, _out) {
                    var _n = array_length(_sample.options);
                    for (var _i = 0; _i < _n; _i++) _out.p[_i] = 1 / _n;
                    _out.confidence = 0;
                },
                reset_data : function() { data = { calls : 0 }; },
                train : function(_budget) {
                    data.calls += 1;
                    return data.calls >= 3; // finishes on the third call
                },
            });
            gmsa_test_assert_false(gmsa_learn_train(_m, 100), "first call");
            gmsa_test_assert_false(gmsa_learn_train(_m, 100), "second call");
            gmsa_test_assert_true(gmsa_learn_train(_m, 100), "third call finishes");

            var _lazy = gmsa_learn_custom({
                observe : function(_sample) {},
                predict : function(_sample, _out) { _out.confidence = 0; },
                train : function(_budget) {}, // no return
            });
            gmsa_test_assert_true(gmsa_learn_train(_lazy), "no return counts as finished");
            gmsa_test_assert_throws(function() { gmsa_learn_custom({ observe : function(_s) {}, predict : function(_s, _o) {}, train : "later" }); }, "train must be callable");
        });
    });
}