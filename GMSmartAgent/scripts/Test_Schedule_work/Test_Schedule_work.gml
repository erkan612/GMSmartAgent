function test_scheduler_work() {
    gmsa_test_suite("Scheduler work", function() {

        gmsa_test_case("work uses what the agents leave", function() {
            var _s = gmsa_scheduler_create(1000, { clock : __test_plan_clock(100) });
            var _w = __test_work_item(50);
            gmsa_scheduler_add_work(_s, _w);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_true(_w.done > 0, "worked");
            gmsa_test_assert_true(_w.done < 50, "stopped at the budget");
            gmsa_test_assert_equal(_s.stats.works, _w.done, "counted");
            var _guard = 0;
            while (_w.left > 0 && _guard < 100) {
                gmsa_scheduler_step(_s);
                _guard++;
            }
            gmsa_test_assert_equal(_w.done, 50, "all done over several steps");
        });

        gmsa_test_case("a job that uses its whole budget leaves its tier's agents most of the step", function() {
            var _clock = __test_plan_clock(100);
            var _s = gmsa_scheduler_create(1000, { clock : _clock });
            var _p = __test_work_profile();
            repeat (20) gmsa_scheduler_add(_s, gmsa_agent_create(_p, {}));
            gmsa_scheduler_add_work(_s, __test_greedy_work(_clock));
            repeat (3) {
                gmsa_scheduler_step(_s);
                gmsa_test_assert_true(_s.stats.thinks >= 7, "agents thought: " + string(_s.stats.thinks));
                gmsa_test_assert_true(_s.stats.works >= 1, "the job still got a turn");
            }
        });

        gmsa_test_case("a tier's work gets what its agents leave", function() {
            var _clock = __test_plan_clock(100);
            var _s = gmsa_scheduler_create(1000, { clock : _clock });
            var _p = __test_work_profile();
            repeat (2) gmsa_scheduler_add(_s, gmsa_agent_create(_p, {}));
            var _w = __test_greedy_work(_clock);
            gmsa_scheduler_add_work(_s, _w);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_s.stats.thinks, 2, "both agents");
            gmsa_test_assert_true(_w.given >= 600, "the job got the rest: " + string(_w.given));
        });

        gmsa_test_case("with share 0, work waits for a busy tier", function() {
            var _clock = __test_plan_clock(100);
            var _s = gmsa_scheduler_create(1000, { clock : _clock, share : 0 });
            var _p = __test_work_profile();
            repeat (20) gmsa_scheduler_add(_s, gmsa_agent_create(_p, {}));
            gmsa_scheduler_add_work(_s, __test_greedy_work(_clock));
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_s.stats.works, 0, "no turn for the work");
            gmsa_test_assert_true(_s.stats.thinks >= 9, "the agents had it all: " + string(_s.stats.thinks));
        });

        gmsa_test_case("idle work costs one check a step", function() {
            var _s = gmsa_scheduler_create(1000, { clock : __test_plan_clock(100) });
            var _p = __test_work_profile();
            repeat (20) gmsa_scheduler_add(_s, gmsa_agent_create(_p, {}));
            var _w = __test_work_item(0);
            gmsa_scheduler_add_work(_s, _w);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_w.checks, 1, "checked once");
            gmsa_test_assert_equal(_s.stats.works, 0, "no work done");
            gmsa_test_assert_true(_s.stats.thinks > 0, "agents unaffected");
        });

        gmsa_test_case("adding and removing work", function() {
            var _s = gmsa_scheduler_create(1000);
            var _ctx = { s : _s };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_scheduler_add_work(s, {}); }), "no work method");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_scheduler_add_work(s, { work : "x" }); }), "not callable");
            var _w = __test_work_item(10);
            gmsa_scheduler_add_work(_s, _w);
            _ctx.w = _w;
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_scheduler_add_work(s, w); }), "added twice");
            gmsa_test_assert_equal(gmsa_scheduler_remove_work(_s, _w), true, "removed");
            gmsa_test_assert_equal(gmsa_scheduler_remove_work(_s, _w), false, "already gone");
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_w.checks, 0, "never called after removal");
        });
    });
}

function __test_work_item(_left) {
    return {
        left : _left, done : 0, checks : 0,
        work : function(_budget) {
            checks++;
            if (left <= 0) return false;
            left--;
            done++;
            return true;
        },
    };
}

function __test_work_profile() {
    var _p = gmsa_profile_create("work test");
    gmsa_profile_add_action(_p, "idle");
    return gmsa_profile_build(_p);
}

function __test_greedy_work(_clock) { // a job that uses every microsecond it's given, like model training
    return {
        clock : _clock, turns : 0, given : 0,
        work : function(_budget) {
            turns++;
            given += _budget;
            var _t0 = clock();
            while (clock() - _t0 < _budget) {}
            return true;
        },
    };
}