function test_plan_schedule() {
    gmsa_test_suite("Plan schedule", function() {

        gmsa_test_case("scheduled planners plan inside the scheduler", function() {
            var _whole = gmsa_plan_planner_create(__test_plan_slice_coins(), { coins : 30 }, { depth : 64 });
            gmsa_plan_make(_whole, "grab_all");
            var _clock = __test_plan_clock(10);
            var _s = gmsa_scheduler_create(500, { clock : _clock });
            var _p = gmsa_plan_planner_create(__test_plan_slice_coins(), { coins : 30 }, { depth : 64, clock : _clock });
            gmsa_plan_schedule(_p, _s);
            gmsa_test_assert_equal(gmsa_plan_make(_p, "grab_all"), true, "started");
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.PLANNING, "left to the scheduler");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_p), 0, "nothing searched in the call");
            var _steps = 0;
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.PLANNING && _steps < 1000) {
                gmsa_scheduler_step(_s);
                _steps++;
            }
            gmsa_test_assert_true(_steps > 1, "over several steps");
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.RUNNING, "running");
            gmsa_test_assert_equal(__test_plan_names(_p), __test_plan_names(_whole), "same plan");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_p), gmsa_plan_nodes_used(_whole), "same search");
        });

        gmsa_test_case("scheduled repairs", function() {
            var _clock = __test_plan_clock(10);
            var _s = gmsa_scheduler_create(500, { clock : _clock });
            var _owner = { ready : true };
            var _p = gmsa_plan_planner_create(__test_plan_vault(true), _owner, { clock : _clock });
            gmsa_plan_schedule(_p, _s);
            gmsa_plan_make(_p, "heist");
            repeat (100) gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(__test_plan_names(_p), "prepare,work,finish", "planned");
            _owner.ready = false;
            gmsa_test_assert_equal(gmsa_plan_refresh(_p), gmsa_plan_status.PLANNING, "repair left to the scheduler");
            repeat (100) gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(__test_plan_names(_p), "prepare,wait", "repaired");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "prepare", "carrying on");
        });

        gmsa_test_case("scheduled planners share turns", function() {
            var _clock = __test_plan_clock(10);
            var _s = gmsa_scheduler_create(300, { clock : _clock });
            var _a = gmsa_plan_planner_create(__test_plan_slice_coins(), { coins : 30 }, { depth : 64, slice : 100, clock : _clock });
            var _b = gmsa_plan_planner_create(__test_plan_slice_coins(), { coins : 30 }, { depth : 64, slice : 100, clock : _clock });
            gmsa_plan_schedule(_a, _s);
            gmsa_plan_schedule(_b, _s);
            gmsa_plan_make(_a, "grab_all");
            gmsa_plan_make(_b, "grab_all");
            gmsa_scheduler_step(_s);
            gmsa_test_assert_true(gmsa_plan_nodes_used(_a) > 0, "the first got a turn");
            gmsa_test_assert_true(gmsa_plan_nodes_used(_b) > 0, "so did the second");
        });

        gmsa_test_case("schedule and unschedule", function() {
            var _s = gmsa_scheduler_create(500);
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_schedule(_p, _s);
            gmsa_test_assert_throws(method({ p : _p, s : _s }, function() { gmsa_plan_schedule(p, s); }), "scheduled twice");
            gmsa_test_assert_equal(gmsa_plan_unschedule(_p), true, "unscheduled");
            gmsa_test_assert_equal(gmsa_plan_unschedule(_p), false, "already");
            gmsa_test_assert_equal(gmsa_plan_make(_p, "loot_chest"), true, "made");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "go_to_key", "planned in the call again");
        });
    });
}