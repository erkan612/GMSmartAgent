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

        gmsa_test_case("agents and work take turns", function() {
            var _s = gmsa_scheduler_create(1000, { clock : __test_plan_clock(100) });
            var _p = __test_work_profile();
            repeat (20) gmsa_scheduler_add(_s, gmsa_agent_create(_p, {}));
            gmsa_scheduler_add_work(_s, __test_work_item(1000));
            gmsa_scheduler_step(_s);
            gmsa_test_assert_true(_s.stats.thinks > 0, "agents thought");
            gmsa_test_assert_true(_s.stats.works > 0, "work worked");
            gmsa_test_assert_true(abs(_s.stats.thinks - _s.stats.works) <= 1, "one each");
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