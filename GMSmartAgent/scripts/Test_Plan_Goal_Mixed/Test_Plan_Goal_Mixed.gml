function test_plan_goal_mixed() {
    gmsa_test_suite("Plan goals in recipes", function() {
        gmsa_test_case("a goal inside a recipe: the search fills the gap", function() {
            var _p = gmsa_plan_planner_create(__test_plan_evening(), __test_plan_evening_camper());
            gmsa_test_assert_true(gmsa_plan_make(_p, "dinner"));
            gmsa_test_assert_equal(__test_plan_names(_p), "forage,get_axe,walk_to_tree,chop,build_fire,cook");
        });

        gmsa_test_case("a goal no chain reaches: the recipe backs up to its other method", function() {
            var _p = gmsa_plan_planner_create(__test_plan_evening(["get_axe", "walk_to_tree"]), __test_plan_evening_camper());
            gmsa_test_assert_true(gmsa_plan_make(_p, "dinner"));
            gmsa_test_assert_equal(__test_plan_names(_p), "forage,eat_raw");
        });

        gmsa_test_case("an earlier choice changes: the goal is searched again", function() {
            // sleeping in closes the axe shop, the goal can't be reached, so the planner rises early instead
            var _p = gmsa_plan_planner_create(__test_plan_evening(), __test_plan_evening_camper());
            gmsa_test_assert_true(gmsa_plan_make(_p, "morning"));
            gmsa_test_assert_equal(__test_plan_names(_p), "rise_early,get_axe,walk_to_tree,chop,build_fire");
        });

        gmsa_test_case("a broken step in the chain: the goal is searched again, the rest of the recipe stays", function() {
            var _o = __test_plan_evening_camper();
            var _p = gmsa_plan_planner_create(__test_plan_evening(), _o);
            gmsa_plan_make(_p, "dinner");
            __test_plan_evening_do(_o, "forage");
            gmsa_plan_step_done(_p);
            __test_plan_evening_do(_o, "get_axe");
            gmsa_plan_step_done(_p);
            _o.has_axe = false;
            gmsa_plan_refresh(_p);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "get_axe");
            gmsa_test_assert_equal(__test_plan_names(_p), "forage,get_axe,walk_to_tree,chop,build_fire,cook");
            var _guard = 0;
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING && _guard++ < 20) {
                __test_plan_evening_do(_o, gmsa_plan_current(_p));
                gmsa_plan_step_done(_p);
            }
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.DONE);
            gmsa_test_assert_true(_o.fed);
        });

        gmsa_test_case("reports: the goal succeeds before its recipe, rewards reach only methods", function() {
            var _d = __test_plan_evening();
            var _log = [];
            gmsa_plan_add_listener(_d, method({ log : _log }, function(_r) {
                if (_r.kind == gmsa_plan_report.GOAL_SUCCESS) array_push(log, "goal " + _r.goal_name);
                if (_r.kind == gmsa_plan_report.METHOD_SUCCESS) array_push(log, "method " + _r.task_name);
            }));
            var _o = __test_plan_evening_camper();
            var _p = gmsa_plan_planner_create(_d, _o);
            gmsa_plan_make(_p, "dinner");
            var _guard = 0;
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING && _guard++ < 20) {
                __test_plan_evening_do(_o, gmsa_plan_current(_p));
                gmsa_plan_step_done(_p);
            }
            gmsa_test_assert_equal(_log, ["goal warm", "method dinner"]);
            gmsa_test_assert_equal(gmsa_plan_reward(_p, 1), 1, "dinner's method, not the goal");
        });

        gmsa_test_case("the depth cap applies to goals like tasks", function() {
            var _p = gmsa_plan_planner_create(__test_plan_evening(), __test_plan_evening_camper(), { depth : 1 });
            gmsa_test_assert_true(gmsa_plan_make(_p, "dinner"));
            gmsa_test_assert_equal(__test_plan_names(_p), "forage,eat_raw");
            gmsa_test_assert_true(_p.depth_cut);
        });

        gmsa_test_case("in slices: the same plan, backtracking included", function() {
            var _clock = gmsa_test_clock(0, 1);
            var _p = gmsa_plan_planner_create(__test_plan_evening(), __test_plan_evening_camper(), { slice : 1, clock : _clock.fn });
            gmsa_plan_make(_p, "morning");
            var _calls = 0;
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.PLANNING && _calls < 1000) {
                gmsa_plan_work(_p);
                _calls += 1;
            }
            gmsa_test_assert_equal(__test_plan_names(_p), "rise_early,get_axe,walk_to_tree,chop,build_fire");
        });
    });
}

function __test_plan_evening(_warm_actions = ["get_axe", "walk_to_tree", "chop", "build_fire"]) {
    var _d = gmsa_plan_domain_create("evening");
    gmsa_plan_add_fact(_d, "has_axe", function(_o) { return _o.has_axe; });
    gmsa_plan_add_fact(_d, "at_tree", function(_o) { return _o.at_tree; });
    gmsa_plan_add_fact(_d, "has_wood", function(_o) { return _o.has_wood; });
    gmsa_plan_add_fact(_d, "fire", function(_o) { return _o.fire; });
    gmsa_plan_add_fact(_d, "shop_open", function(_o) { return _o.shop_open; });
    gmsa_plan_add_fact(_d, "has_food", function(_o) { return _o.has_food; });
    gmsa_plan_add_fact(_d, "fed", function(_o) { return _o.fed; });
    gmsa_plan_add_step(_d, "get_axe", { requires : [["shop_open", true]], effects : [["has_axe", true]], cost : 2 });
    gmsa_plan_add_step(_d, "walk_to_tree", { effects : [["at_tree", true]], cost : 4 });
    gmsa_plan_add_step(_d, "chop", { requires : [["has_axe", true], ["at_tree", true]], effects : [["has_wood", true]], cost : 3 });
    gmsa_plan_add_step(_d, "build_fire", { requires : [["has_wood", true]], effects : [["fire", true], ["has_wood", false]] });
    gmsa_plan_add_step(_d, "forage", { effects : [["has_food", true]] });
    gmsa_plan_add_step(_d, "cook", { requires : [["fire", true], ["has_food", true]], effects : [["fed", true], ["has_food", false]] });
    gmsa_plan_add_step(_d, "eat_raw", { requires : [["has_food", true]], effects : [["fed", true], ["has_food", false]] });
    gmsa_plan_add_step(_d, "sleep_in", { effects : [["shop_open", false]] });
    gmsa_plan_add_step(_d, "rise_early", { effects : [["shop_open", true]] });
    gmsa_plan_add_goal(_d, "warm", { conditions : [["fire", true]], actions : _warm_actions });
    var _dinner = gmsa_plan_add_task(_d, "dinner");
    gmsa_plan_add_method(_dinner, "cooked", { subtasks : ["forage", "warm", "cook"] });
    gmsa_plan_add_method(_dinner, "raw", { subtasks : ["forage", "eat_raw"] });
    var _prep = gmsa_plan_add_task(_d, "prep");
    gmsa_plan_add_method(_prep, "sleep_in", { subtasks : ["sleep_in"] });
    gmsa_plan_add_method(_prep, "rise_early", { subtasks : ["rise_early"] });
    var _morning = gmsa_plan_add_task(_d, "morning");
    gmsa_plan_add_method(_morning, "only", { subtasks : ["prep", "warm"] });
    return gmsa_plan_domain_build(_d);
}

function __test_plan_evening_camper() {
    return { has_axe : false, at_tree : false, has_wood : false, fire : false, shop_open : true, has_food : false, fed : false };
}

function __test_plan_evening_do(_o, _step) {
    switch (_step) {
        case "get_axe": _o.has_axe = true; break;
        case "walk_to_tree": _o.at_tree = true; break;
        case "chop": _o.has_wood = true; break;
        case "build_fire": _o.fire = true; _o.has_wood = false; break;
        case "forage": _o.has_food = true; break;
        case "cook":
        case "eat_raw": _o.fed = true; _o.has_food = false; break;
        case "sleep_in": _o.shop_open = false; break;
        case "rise_early": _o.shop_open = true; break;
    }
}