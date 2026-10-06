function test_plan_slice() {
    gmsa_test_suite("Plan slices", function() {

        gmsa_test_case("slices validate", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _ctx = { d : _d };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_planner_create(d, {}, { slice : 0 }); }), "slice 0");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_planner_create(d, {}, { slice : "x" }); }), "slice not a number");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_planner_create(d, {}, { clock : "nope" }); }), "clock");
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_make(_p, "loot_chest");
            gmsa_test_assert_equal(gmsa_plan_work(_p), gmsa_plan_status.RUNNING, "work does nothing unless planning");
        });

        gmsa_test_case("a plan made in slices is the same plan", function() {
            var _d = __test_plan_slice_coins();
            var _whole = gmsa_plan_planner_create(_d, { coins : 30 }, { depth : 64 });
            gmsa_plan_make(_whole, "grab_all");
            var _sliced = gmsa_plan_planner_create(_d, { coins : 30 }, { depth : 64, slice : 1000, clock : __test_plan_clock(100) });
            gmsa_test_assert_equal(gmsa_plan_make(_sliced, "grab_all"), true, "started");
            gmsa_test_assert_equal(gmsa_plan_get_status(_sliced), gmsa_plan_status.PLANNING, "still planning");
            var _calls = 1;
            while (gmsa_plan_get_status(_sliced) == gmsa_plan_status.PLANNING) {
                gmsa_plan_work(_sliced);
                _calls++;
            }
            gmsa_test_assert_true(_calls > 3, "took several calls");
            gmsa_test_assert_equal(gmsa_plan_get_status(_sliced), gmsa_plan_status.RUNNING, "running");
            gmsa_test_assert_equal(__test_plan_names(_sliced), __test_plan_names(_whole), "same plan");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_sliced), gmsa_plan_nodes_used(_whole), "same search");
        });

        gmsa_test_case("pausing while backtracking", function() {
            var _d = __test_plan_slice_backtrack();
            var _whole = gmsa_plan_planner_create(_d, {});
            gmsa_plan_make(_whole, "choose");
            var _sliced = gmsa_plan_planner_create(_d, {}, { slice : 250, clock : __test_plan_clock(100) });
            gmsa_plan_make(_sliced, "choose");
            while (gmsa_plan_get_status(_sliced) == gmsa_plan_status.PLANNING) gmsa_plan_work(_sliced);
            gmsa_test_assert_equal(__test_plan_names(_sliced), "work,finish", "found the right method");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_sliced), gmsa_plan_nodes_used(_whole), "same search");
        });

        gmsa_test_case("while planning", function() {
            var _p = gmsa_plan_planner_create(__test_plan_slice_coins(), { coins : 30 }, { depth : 64, slice : 1000, clock : __test_plan_clock(100) });
            gmsa_plan_make(_p, "grab_all");
            gmsa_test_assert_equal(gmsa_plan_current(_p), undefined, "no step yet");
            gmsa_test_assert_equal(gmsa_plan_length(_p), 0, "no plan yet");
            gmsa_test_assert_equal(gmsa_plan_step_done(_p), gmsa_plan_status.PLANNING, "reports are ignored");
            gmsa_test_assert_true(string_pos("grab_all (planning, ", gmsa_plan_explain(_p)) == 1, "explain says planning");
            gmsa_plan_stop(_p);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.IDLE, "stopped");
            gmsa_test_assert_equal(gmsa_plan_work(_p), gmsa_plan_status.IDLE, "nothing to work on");
            gmsa_plan_make(_p, "grab_all");
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.PLANNING) gmsa_plan_work(_p, 5000);
            gmsa_test_assert_equal(gmsa_plan_length(_p), 31, "made again");
        });

        gmsa_test_case("small plans finish in the first slice", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 }, { slice : 100000, clock : __test_plan_clock(1) });
            gmsa_test_assert_equal(gmsa_plan_make(_p, "loot_chest"), true, "made");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "go_to_key", "running at once");
        });

        gmsa_test_case("facts that changed while planning are checked", function() {
            var _owner = { door_locked : false, has_pick : true };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner, { slice : 150, clock : __test_plan_clock(100) });
            gmsa_plan_make(_p, "heist");
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.PLANNING, "still planning");
            _owner.door_locked = true; // locked while the plan was being made
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.PLANNING) gmsa_plan_work(_p);
            gmsa_test_assert_equal(__test_plan_names(_p), "approach,walk,pick_lock,enter", "repaired before starting");
        });

        gmsa_test_case("the node budget still caps the whole plan", function() {
            var _d = gmsa_plan_domain_create("forever");
            gmsa_plan_add_step(_d, "s");
            var _t = gmsa_plan_add_task(_d, "loop");
            gmsa_plan_add_method(_t, "again", { subtasks : ["loop"] });
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, {}, { depth : 100000, budget : 50, slice : 250, clock : __test_plan_clock(100) });
            gmsa_plan_make(_p, "loop");
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.PLANNING) gmsa_plan_work(_p);
            gmsa_test_assert_equal(gmsa_plan_last_result(_p), gmsa_plan_result.OUT_OF_BUDGET, "out of budget");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_p), 50, "never over");
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.FAILED, "failed");
        });
    });
}

function __test_plan_clock(_step) {
    return method({ t : 0, step : _step }, function() {
        t += step;
        return t;
    });
}

function __test_plan_slice_coins() {
    var _d = gmsa_plan_domain_create("slice coins");
    gmsa_plan_add_fact(_d, "coins", function(_o) { return _o.coins; });
    gmsa_plan_add_step(_d, "grab", { requires : [["coins", ">", 0]], effects : [["coins", "-", 1]] });
    gmsa_plan_add_step(_d, "stop");
    var _t = gmsa_plan_add_task(_d, "grab_all");
    gmsa_plan_add_method(_t, "more", { requires : [["coins", ">", 0]], subtasks : ["grab", "grab_all"] });
    gmsa_plan_add_method(_t, "done", { subtasks : ["stop"] });
    return gmsa_plan_domain_build(_d);
}

function __test_plan_slice_backtrack() {
    var _d = gmsa_plan_domain_create("slice backtrack");
    gmsa_plan_add_fact(_d, "x", function(_o) { return 0; });
    gmsa_plan_add_step(_d, "work", { effects : [["x", "+", 1]] });
    gmsa_plan_add_step(_d, "fail", { requires : [["x", "<", 0]] });
    gmsa_plan_add_step(_d, "finish");
    var _t = gmsa_plan_add_task(_d, "choose");
    for (var _m = 0; _m < 19; _m++) gmsa_plan_add_method(_t, "wrong_" + string(_m), { subtasks : ["work", "work", "work", "fail"] });
    gmsa_plan_add_method(_t, "right", { subtasks : ["work", "finish"] });
    return gmsa_plan_domain_build(_d);
}