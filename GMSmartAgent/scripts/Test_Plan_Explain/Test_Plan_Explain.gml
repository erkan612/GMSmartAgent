function test_plan_explain() {
    gmsa_test_suite("Plan explain", function() {

        gmsa_test_case("a running plan", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_test_assert_equal(gmsa_plan_explain(_p), "no plan running", "before make");
            gmsa_plan_make(_p, "loot_chest");
            gmsa_plan_step_done(_p);
            var _expect = "loot_chest (running, step 2 of 3)"
                + "\n  loot_chest: fetch"
                + "\n    have_key skipped: has_key is false, needs true"
                + "\n    buy skipped: buy_key: gold is 3, needs at least 10"
                + "\n    go_to_key, done"
                + "\n  > pick_up_key"
                + "\n    open_chest";
            gmsa_test_assert_equal(gmsa_plan_explain(_p), _expect, "text");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "pick_up_key", "explaining changes nothing");
            gmsa_plan_stop(_p);
            gmsa_test_assert_equal(gmsa_plan_explain(_p), "no plan running", "after stop");
        });

        gmsa_test_case("nested tasks and repairs", function() {
            var _owner = { door_locked : false, has_pick : true };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
            gmsa_plan_make(_p, "heist");
            var _expect = "heist (running, step 1 of 3)"
                + "\n  heist: front"
                + "\n  > approach"
                + "\n    get_in: walk_in"
                + "\n      walk"
                + "\n      enter";
            gmsa_test_assert_equal(gmsa_plan_explain(_p), _expect, "nested");
            _owner.door_locked = true;
            gmsa_plan_refresh(_p);
            _expect = "heist (running, step 1 of 4)"
                + "\n  heist: front"
                + "\n  > approach"
                + "\n    get_in: pick"
                + "\n      walk_in skipped: door_locked is true, needs false"
                + "\n      walk"
                + "\n      pick_lock"
                + "\n      enter";
            gmsa_test_assert_equal(gmsa_plan_explain(_p), _expect, "after the repair");
        });

        gmsa_test_case("no plan", function() {
            var _owner = { door_locked : true, has_pick : false };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
            gmsa_plan_make(_p, "get_in");
            var _expect = "get_in (failed, no plan)"
                + "\nget_in has no method that works"
                + "\n  walk_in: door_locked is true, needs false"
                + "\n  pick: pick_lock: has_pick is false, needs true";
            gmsa_test_assert_equal(gmsa_plan_explain(_p), _expect, "task");
            gmsa_plan_make(_p, "enter");
            gmsa_test_assert_equal(gmsa_plan_explain(_p), "enter (failed, no plan)\nenter can't be done: door_locked is true, needs false", "step");
        });

        gmsa_test_case("scores", function() {
            var _d = gmsa_plan_domain_create("scores");
            gmsa_plan_add_step(_d, "low");
            gmsa_plan_add_step(_d, "high");
            var _t = gmsa_plan_add_task(_d, "pick");
            gmsa_plan_add_method(_t, "low", { score : function(_o, _s) { return _o.low; }, subtasks : ["low"] });
            gmsa_plan_add_method(_t, "high", { score : function(_o, _s) { return _o.high; }, subtasks : ["high"] });
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { low : 0, high : 0.8 });
            gmsa_plan_make(_p, "pick");
            var _text = gmsa_plan_explain(_p);
            gmsa_test_assert_true(string_pos("pick: high (score 0.80)", _text) > 0, "score shown");
            gmsa_test_assert_true(string_pos("low ruled out by its score", _text) > 0, "ruled out");
        });
    });
}