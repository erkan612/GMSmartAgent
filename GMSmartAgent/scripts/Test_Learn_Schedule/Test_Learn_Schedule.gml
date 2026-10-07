function test_learn_schedule() {
    gmsa_test_suite("Learn schedule", function() {
        gmsa_test_case("a TDNN's replays wait for training", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_ngram_shopper();
            for (var _i = 0; _i < 5; _i++) __test_sched_buy(_m, _ag, _i mod 3);
            gmsa_test_assert_true(_m.waiting(), "replays waiting");
            gmsa_test_assert_true(gmsa_learn_train(_m), "all trained in one call without a budget");
            gmsa_test_assert_true(!_m.waiting(), "none left");
        });

        gmsa_test_case("scheduled: training runs inside the scheduler's budget", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_ngram_shopper();
            var _s = gmsa_scheduler_create(2000);
            gmsa_learn_schedule(_m, _s);
            for (var _i = 0; _i < 20; _i++) __test_sched_buy(_m, _ag, _i mod 3);
            var _steps = 0;
            while (_m.waiting() && _steps < 100) {
                gmsa_scheduler_step(_s);
                _steps += 1;
            }
            gmsa_test_assert_true(!_m.waiting(), "trained within " + string(_steps) + " steps");
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_s.stats.works, 0, "nothing waiting: no turns");
        });

        gmsa_test_case("scheduled: LambdaMART retrains when new choices come in", function() {
            var _m = gmsa_learn_lambdamart_create({ trees : 5 });
            var _ag = __test_ngram_shopper();
            var _s = gmsa_scheduler_create(2000);
            gmsa_learn_schedule(_m, _s);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_s.stats.works, 0, "no choices yet: no turns");
            for (var _i = 0; _i < 30; _i++) __test_sched_buy(_m, _ag, _i mod 3);
            var _steps = 0;
            while (_m.waiting() && _steps < 200) {
                gmsa_scheduler_step(_s);
                _steps += 1;
            }
            gmsa_test_assert_equal(_m.data.tree_count, 5, "trained");
            __test_sched_buy(_m, _ag, 0);
            gmsa_test_assert_true(_m.waiting(), "a new choice: training again");
        });

        gmsa_test_case("models that learn as they observe never take a turn", function() {
            var _m = gmsa_learn_ngram_create();
            var _ag = __test_ngram_shopper();
            var _s = gmsa_scheduler_create(2000);
            gmsa_learn_schedule(_m, _s);
            __test_sched_buy(_m, _ag, 0);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_s.stats.works, 0);
        });

        gmsa_test_case("schedule once, unschedule, custom models need waiting", function() {
            var _m = gmsa_learn_tdnn_create();
            var _s = gmsa_scheduler_create();
            gmsa_learn_schedule(_m, _s);
            gmsa_test_assert_throws(method({ m : _m, s : _s }, function() { gmsa_learn_schedule(m, s); }), "twice");
            gmsa_test_assert_true(gmsa_learn_unschedule(_m));
            gmsa_test_assert_true(!gmsa_learn_unschedule(_m), "already off");
            var _custom = gmsa_learn_custom({ observe : function(_x) {}, predict : function(_x, _o) {}, train : function(_b) { return true; } });
            gmsa_test_assert_throws(method({ c : _custom, s : _s }, function() { gmsa_learn_schedule(c, s); }), "train without waiting");
        });
    });
}

function __test_sched_buy(_model, _agent, _item) {
    gmsa_agent_set_input(_agent, "hp", 50);
    gmsa_learn_observe(_model, gmsa_observe(_agent, ["sword", "shield", "potion"], _item));
}