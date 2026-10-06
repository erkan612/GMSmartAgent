function test_plan_lines() {
    gmsa_test_suite("Plan lines", function() {

        gmsa_test_case("kinds and depths", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_make(_p, "loot_chest");
            gmsa_plan_step_done(_p);
            var _lines = gmsa_plan_lines(_p);
            var _kinds = ["title", "task", "skipped", "skipped", "done", "current", "step"];
            var _depths = [0, 0, 1, 1, 1, 1, 1];
            gmsa_test_assert_equal(array_length(_lines), 7, "line count");
            for (var _i = 0; _i < 7; _i++) {
                gmsa_test_assert_equal(_lines[_i].kind, _kinds[_i], "kind " + string(_i));
                gmsa_test_assert_equal(_lines[_i].depth, _depths[_i], "depth " + string(_i));
            }
            gmsa_test_assert_equal(_lines[4].text, "go_to_key", "plain name, no decoration");
            gmsa_test_assert_equal(_lines[0].progress, undefined, "no progress while running");
        });

        gmsa_test_case("repaired parts are marked until the next step", function() {
            var _owner = { door_locked : false, has_pick : true };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
            gmsa_plan_make(_p, "heist");
            var _lines = gmsa_plan_lines(_p);
            for (var _i = 0; _i < array_length(_lines); _i++) gmsa_test_assert_false(_lines[_i].repaired, "nothing repaired yet " + string(_i));
            _owner.door_locked = true;
            gmsa_plan_refresh(_p);
            _lines = gmsa_plan_lines(_p);
            // title, heist: front, approach, get_in: pick, walk_in skipped, walk, pick_lock, enter
            var _expect = [false, false, false, true, true, true, true, true];
            gmsa_test_assert_equal(array_length(_lines), 8, "line count");
            for (var _i = 0; _i < 8; _i++) gmsa_test_assert_equal(_lines[_i].repaired, _expect[_i], "repaired " + string(_i));
            gmsa_plan_step_done(_p);
            _lines = gmsa_plan_lines(_p);
            for (var _i = 0; _i < array_length(_lines); _i++) gmsa_test_assert_false(_lines[_i].repaired, "cleared by the next step " + string(_i));
        });

        gmsa_test_case("progress while planning", function() {
            var _p = gmsa_plan_planner_create(__test_plan_slice_coins(), { coins : 30 }, { depth : 64, slice : 1000, clock : __test_plan_clock(100) });
            gmsa_plan_make(_p, "grab_all");
            var _lines = gmsa_plan_lines(_p);
            gmsa_test_assert_equal(array_length(_lines), 1, "only the title");
            gmsa_test_assert_true(_lines[0].progress > 0 && _lines[0].progress < 1, "part way");
        });

        gmsa_test_case("idle and no plan", function() {
            var _owner = { door_locked : true, has_pick : false };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
            var _lines = gmsa_plan_lines(_p);
            gmsa_test_assert_equal(_lines[0].kind, "note", "idle is a note");
            gmsa_plan_make(_p, "get_in");
            _lines = gmsa_plan_lines(_p);
            var _kinds = ["title", "note", "reason", "reason"];
            gmsa_test_assert_equal(array_length(_lines), 4, "line count");
            for (var _i = 0; _i < 4; _i++) gmsa_test_assert_equal(_lines[_i].kind, _kinds[_i], "kind " + string(_i));
        });
		
        gmsa_test_case("Debug draws the same text as explain", function() {
            var _owner = { door_locked : false, has_pick : true };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
            gmsa_plan_make(_p, "heist");
            _owner.door_locked = true;
            gmsa_plan_refresh(_p);
            var _lines = gmsa_plan_lines(_p);
            var _text = "";
            for (var _i = 0; _i < array_length(_lines); _i++) _text += ((_i > 0) ? "\n" : "") + __gmsa_debug_tree_text(_lines[_i]);
            gmsa_test_assert_equal(_text, gmsa_plan_explain(_p), "same text");
        });
    });
}