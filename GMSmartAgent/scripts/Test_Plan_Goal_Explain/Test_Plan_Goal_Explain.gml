function test_plan_goal_explain() {
    gmsa_test_suite("Plan goal explain", function() {
        gmsa_test_case("a running goal: its chain, cost and search", function() {
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), __test_plan_camper());
            gmsa_plan_make(_p, "warm");
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "warm (running, step 1 of 4)\n  warm: 4 steps, cost 10, searched 25 nodes\n  > get_axe\n    walk_to_tree\n    chop\n    build_fire");
            var _lines = gmsa_plan_lines(_p);
            gmsa_test_assert_equal(_lines[1].kind, "goal");
            gmsa_test_assert_equal(_lines[2].depth, 1, "the chain nests under its goal");
        });

        gmsa_test_case("a goal already met", function() {
            var _o = __test_plan_camper();
            _o.fire = true;
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), _o);
            gmsa_plan_make(_p, "warm");
            gmsa_test_assert_equal(gmsa_plan_explain(_p), "warm (done)\n  warm: already met");
        });

        gmsa_test_case("no chain: a condition nothing changes, and the closest it came", function() {
            var _d = gmsa_plan_domain_create("abc");
            gmsa_plan_add_fact(_d, "a", function(_o) { return _o.a; });
            gmsa_plan_add_fact(_d, "b", function(_o) { return _o.b; });
            gmsa_plan_add_fact(_d, "c", function(_o) { return _o.c; });
            gmsa_plan_add_step(_d, "make_a", { effects : [["a", true]] });
            gmsa_plan_add_step(_d, "make_b", { requires : [["a", true]], effects : [["b", true]] });
            gmsa_plan_add_goal(_d, "all", { conditions : [["a", true], ["b", true], ["c", true]] });
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { a : false, b : false, c : false });
            gmsa_test_assert_false(gmsa_plan_make(_p, "all"));
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "all (failed, no plan)\nall: no chain of steps reaches it\n  c is false, needs true, and none of the goal's steps changes it\n  closest it came: after make_a, make_b\n  still c is false, needs true");
        });

        gmsa_test_case("a goal inside a recipe that didn't work out", function() {
            var _d = gmsa_plan_domain_create("night");
            gmsa_plan_add_fact(_d, "fire", function(_o) { return false; });
            gmsa_plan_add_step(_d, "rest");
            gmsa_plan_add_goal(_d, "warm", { conditions : [["fire", true]], actions : ["rest"] });
            var _t = gmsa_plan_add_task(_d, "night");
            gmsa_plan_add_method(_t, "cozy", { subtasks : ["warm", "rest"] });
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, {});
            gmsa_plan_make(_p, "night");
            gmsa_test_assert_equal(gmsa_plan_explain(_p), "night (failed, no plan)\nnight has no method that works\n  cozy: warm didn't work out");
        });

        gmsa_test_case("a goal in a recipe shows nested in the tree", function() {
            var _p = gmsa_plan_planner_create(__test_plan_evening(), __test_plan_evening_camper());
            gmsa_plan_make(_p, "dinner");
            gmsa_test_assert_equal(gmsa_plan_explain(_p),
                "dinner (running, step 1 of 6)\n  dinner: cooked\n  > forage\n    warm: 4 steps, cost 10, searched "
                + string(_p.__plan_trace[_p.__run_aux[2] + 1]) + " nodes\n      get_axe\n      walk_to_tree\n      chop\n      build_fire\n    cook");
        });
    });
}