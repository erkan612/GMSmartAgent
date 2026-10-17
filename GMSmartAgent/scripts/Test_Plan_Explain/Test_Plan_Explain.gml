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

        gmsa_test_case("a skipped method names the part that failed", function() {
            var _p = gmsa_plan_planner_create(__test_plan_two_goals(), { a : false, b : false, c : false });
            gmsa_plan_make(_p, "job");
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "job (running, step 1 of 1)\n  job: other\n    direct skipped: get_b didn't work out\n  > finish", "the second goal, not the first");
            gmsa_plan_make(_p, "step_after");
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "step_after (running, step 1 of 1)\n  step_after: other\n    direct skipped: need_c couldn't be done after get_a\n  > finish", "a step after a goal");
            gmsa_plan_make(_p, "only");
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "only (failed, no plan)\nonly has no method that works\n  direct: get_b didn't work out", "a failed plan too");
        });

        gmsa_test_case("a make cut off by the budget says what it didn't get to", function() {
            var _p = gmsa_plan_planner_create(__test_plan_two_goals(), { a : false, b : false, c : false }, { budget : 1 });
            gmsa_plan_make(_p, "job");
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "job (failed, ran out of budget after 1 nodes)\njob: the search ran out of budget before finding a method that works"
                + "\n  direct: the budget ran out before it was finished\n  other: not tried before the budget ran out");
        });
		
        gmsa_test_case("a running plan that breaks for good says where and why", function() {
            var _o = { key_there : true, has_key : false };
            var _p = gmsa_plan_planner_create(__test_plan_door(), _o);
            gmsa_plan_make(_p, "escape");
            _o.key_there = false;   // someone else took it
            gmsa_plan_refresh(_p);
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "escape (failed, no plan)\n  escape: by_key\n  ! take_key can't be done: key_there is false, needs true\n    leave"
                + "\nno repair worked:\nescape has no method that works\n  by_key: take_key: key_there is false, needs true");
        });

        gmsa_test_case("a step that keeps failing says how often", function() {
            var _o = { key_there : true, has_key : false };
            var _p = gmsa_plan_planner_create(__test_plan_door(), _o);
            gmsa_plan_make(_p, "escape");
            repeat (4) gmsa_plan_step_failed(_p);   // stuck, and no fact says why
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "escape (failed, too many failed steps)\n  escape: by_key\n  ! take_key failed 4 times in a row\n    leave");
        });
    });
}

function __test_plan_two_goals() { // recipes whose first goal works and whose later part doesn't
    var _d = gmsa_plan_domain_create("two goals");
    gmsa_plan_add_fact(_d, "a", function(_o) { return _o.a; });
    gmsa_plan_add_fact(_d, "b", function(_o) { return _o.b; });
    gmsa_plan_add_fact(_d, "c", function(_o) { return _o.c; });
    gmsa_plan_add_step(_d, "start");
    gmsa_plan_add_step(_d, "make_a", { effects : [["a", true]] });
    gmsa_plan_add_step(_d, "make_b", { requires : [["c", true]], effects : [["b", true]] });
    gmsa_plan_add_step(_d, "need_c", { requires : [["c", true]] });
    gmsa_plan_add_step(_d, "finish");
    gmsa_plan_add_goal(_d, "get_a", { conditions : [["a", true]], actions : ["make_a"] });
    gmsa_plan_add_goal(_d, "get_b", { conditions : [["b", true]], actions : ["make_b"] });
    var _job = gmsa_plan_add_task(_d, "job");
    gmsa_plan_add_method(_job, "direct", { subtasks : ["start", "get_a", "finish", "get_b"] });
    gmsa_plan_add_method(_job, "other", { subtasks : ["finish"] });
    var _after = gmsa_plan_add_task(_d, "step_after");
    gmsa_plan_add_method(_after, "direct", { subtasks : ["get_a", "need_c"] });
    gmsa_plan_add_method(_after, "other", { subtasks : ["finish"] });
    var _only = gmsa_plan_add_task(_d, "only");
    gmsa_plan_add_method(_only, "direct", { subtasks : ["get_a", "get_b"] });
    return gmsa_plan_domain_build(_d);
}

function __test_plan_door() { // take the key, then leave: nothing else works
    var _d = gmsa_plan_domain_create("door");
    gmsa_plan_add_fact(_d, "key_there", function(_o) { return _o.key_there; });
    gmsa_plan_add_fact(_d, "has_key", function(_o) { return _o.has_key; });
    gmsa_plan_add_step(_d, "take_key", { requires : [["key_there", true]], effects : [["has_key", true]] });
    gmsa_plan_add_step(_d, "leave", { requires : [["has_key", true]] });
    var _escape = gmsa_plan_add_task(_d, "escape");
    gmsa_plan_add_method(_escape, "by_key", { subtasks : ["take_key", "leave"] });
    return gmsa_plan_domain_build(_d);
}