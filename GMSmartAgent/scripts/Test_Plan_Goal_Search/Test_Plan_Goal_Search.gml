function test_plan_goal_search() {
    gmsa_test_suite("Plan goal search", function() {
        gmsa_test_case("a goal as the root: the cheapest chain", function() {
            var _o = __test_plan_camper();
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), _o);
            gmsa_test_assert_true(gmsa_plan_make(_p, "warm"));
            gmsa_test_assert_equal(gmsa_plan_last_result(_p), gmsa_plan_result.FOUND);
            gmsa_test_assert_equal(__test_plan_names(_p), "get_axe,walk_to_tree,chop,build_fire", "2 + 4 + 3 + 1 beats camp's 9 + 3 + 1");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_p), 25, "five states expanded, five actions each");
        });

        gmsa_test_case("cost functions change the plan", function() {
            var _o = __test_plan_camper();
            _o.walk_cost = 20;
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), _o);
            gmsa_plan_make(_p, "warm");
            gmsa_test_assert_equal(__test_plan_names(_p), "camp,chop,build_fire", "the far tree makes camping cheaper");
        });

        gmsa_test_case("a cost of 0 rules a step out, a cost that isn't a number throws", function() {
            var _o = __test_plan_camper();
            _o.walk_cost = 0;
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), _o);
            gmsa_plan_make(_p, "warm");
            gmsa_test_assert_equal(__test_plan_names(_p), "camp,chop,build_fire");
            _o.walk_cost = "far";
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_plan_make(p, "warm"); }));
        });

        gmsa_test_case("a goal already met: an empty plan, done at once", function() {
            var _o = __test_plan_camper();
            _o.fire = true;
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), _o);
            gmsa_test_assert_true(gmsa_plan_make(_p, "warm"));
            gmsa_test_assert_equal(gmsa_plan_length(_p), 0);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.DONE);
        });

        gmsa_test_case("no chain reaches it, or the budget runs out", function() {
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(["get_axe", "walk_to_tree"]), __test_plan_camper());
            gmsa_test_assert_false(gmsa_plan_make(_p, "warm"));
            gmsa_test_assert_equal(gmsa_plan_last_result(_p), gmsa_plan_result.NO_PLAN);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.FAILED);
            var _q = gmsa_plan_planner_create(__test_plan_camp_live(), __test_plan_camper(), { budget : 6 });
            gmsa_test_assert_false(gmsa_plan_make(_q, "warm"));
            gmsa_test_assert_equal(gmsa_plan_last_result(_q), gmsa_plan_result.OUT_OF_BUDGET);
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_q), 6);
        });

        gmsa_test_case("running the chain to the end", function() {
            var _o = __test_plan_camper();
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), _o);
            gmsa_plan_make(_p, "warm");
            var _guard = 0;
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING && _guard++ < 20) {
                __test_plan_camp_do(_o, gmsa_plan_current(_p));
                gmsa_plan_step_done(_p);
            }
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.DONE);
            gmsa_test_assert_true(_o.fire);
        });

        gmsa_test_case("a broken chain is searched again from the real facts", function() {
            var _o = __test_plan_camper();
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), _o);
            gmsa_plan_make(_p, "warm");
            __test_plan_camp_do(_o, "get_axe");
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "walk_to_tree");
            _o.has_axe = false; // someone took it
            gmsa_test_assert_equal(gmsa_plan_refresh(_p), gmsa_plan_status.RUNNING);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "get_axe", "fetch it again");
            gmsa_test_assert_equal(gmsa_plan_length(_p), 4);
        });

        gmsa_test_case("planning in slices gives the same plan", function() {
            var _clock = gmsa_test_clock(0, 1);
            var _p = gmsa_plan_planner_create(__test_plan_camp_live(), __test_plan_camper(), { slice : 1, clock : _clock.fn });
            gmsa_test_assert_true(gmsa_plan_make(_p, "warm"));
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.PLANNING);
            var _calls = 0;
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.PLANNING && _calls < 500) {
                gmsa_plan_work(_p);
                _calls += 1;
            }
            gmsa_test_assert_true(_calls > 5, "it really was spread out");
            gmsa_test_assert_equal(__test_plan_names(_p), "get_axe,walk_to_tree,chop,build_fire");
        });

        gmsa_test_case("reports: steps carry the goal, the goal succeeds and fails", function() {
            var _d = __test_plan_camp_live();
            var _log = [];
            gmsa_plan_add_listener(_d, method({ log : _log }, function(_r) {
                array_push(log, string(_r.kind) + ":" + string(_r.goal_name) + ":" + string(_r.step_name));
            }));
            var _o = __test_plan_camper();
            var _p = gmsa_plan_planner_create(_d, _o);
            gmsa_plan_make(_p, "warm");
            __test_plan_camp_do(_o, "get_axe");
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(_log[0], string(gmsa_plan_report.STEP_SUCCESS) + ":warm:get_axe");
            gmsa_test_assert_equal(gmsa_plan_reward(_p, 1), 0, "a goal has no method to reward");
            var _guard = 0;
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING && _guard++ < 20) {
                __test_plan_camp_do(_o, gmsa_plan_current(_p));
                gmsa_plan_step_done(_p);
            }
            gmsa_test_assert_equal(_log[array_length(_log) - 1], string(gmsa_plan_report.GOAL_SUCCESS) + ":warm:undefined");

            // failing until the retries run out
            array_resize(_log, 0);
            var _q = gmsa_plan_planner_create(_d, __test_plan_camper());
            gmsa_plan_make(_q, "warm");
            _guard = 0;
            while (gmsa_plan_get_status(_q) == gmsa_plan_status.RUNNING && _guard++ < 20) gmsa_plan_step_failed(_q);
            gmsa_test_assert_equal(gmsa_plan_get_status(_q), gmsa_plan_status.FAILED);
            gmsa_test_assert_true(array_contains(_log, string(gmsa_plan_report.GOAL_FAILURE) + ":warm:undefined"));
        });
		
        gmsa_test_case("a step chance raises the cost: 10% axe luck makes camping cheaper", function() {
            var _d = __test_plan_camp_live();
            gmsa_plan_set_step_chance(_d, function(_planner, _step, _state) {
                return (_planner.domain.steps[_step].name == "get_axe") ? 0.1 : 1;
            });
            var _p = gmsa_plan_planner_create(_d, __test_plan_camper());
            gmsa_plan_make(_p, "warm");
            gmsa_test_assert_equal(__test_plan_names(_p), "camp,chop,build_fire", "20 + 4 + 3 + 1 against 9 + 3 + 1");
        });

        gmsa_test_case("a chance of 0 rules a step out", function() {
            var _d = __test_plan_camp_live();
            gmsa_plan_set_step_chance(_d, function(_planner, _step, _state) {
                return (_planner.domain.steps[_step].name == "camp") ? 0 : 1;
            });
            var _o = __test_plan_camper();
            _o.walk_cost = 20; // camping would win, but it never works
            var _p = gmsa_plan_planner_create(_d, _o);
            gmsa_plan_make(_p, "warm");
            gmsa_test_assert_equal(__test_plan_names(_p), "get_axe,walk_to_tree,chop,build_fire");
        });

        gmsa_test_case("learned reliability: the repair turns to camping within the same plan", function() {
            var _d = gmsa_plan_domain_create("unlucky camp");
            gmsa_plan_add_fact(_d, "has_axe", function(_o) { return _o.has_axe; });
            gmsa_plan_add_fact(_d, "at_tree", function(_o) { return _o.at_tree; });
            gmsa_plan_add_fact(_d, "has_wood", function(_o) { return _o.has_wood; });
            gmsa_plan_add_fact(_d, "fire", function(_o) { return _o.fire; });
            gmsa_plan_add_step(_d, "get_axe", { effects : [["has_axe", true]], cost : 2 });
            gmsa_plan_add_step(_d, "walk_to_tree", { effects : [["at_tree", true]], cost : 4.5 });
            gmsa_plan_add_step(_d, "chop", { requires : [["has_axe", true], ["at_tree", true]], effects : [["has_wood", true]], cost : 3 });
            gmsa_plan_add_step(_d, "build_fire", { requires : [["has_wood", true]], effects : [["fire", true], ["has_wood", false]] });
            gmsa_plan_add_step(_d, "camp", { effects : [["has_axe", true], ["at_tree", true]], cost : 9 });
            gmsa_plan_add_goal(_d, "warm", { conditions : [["fire", true]] });
            gmsa_plan_learn_steps(_d);
            gmsa_plan_domain_build(_d);

            // the axe route costs 2 / chance + 8.5, camping 13: after three failures get_axe's chance is 2 / 5, 5 + 8.5 > 13
            var _p = gmsa_plan_planner_create(_d, __test_plan_camper());
            gmsa_plan_make(_p, "warm");
            var _failures = 0;
            while (gmsa_plan_current(_p) == "get_axe" && _failures < 10) {
                gmsa_plan_step_failed(_p);
                _failures += 1;
            }
            gmsa_test_assert_equal(_failures, 3);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.RUNNING);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "camp");
        });
    });
}

function __test_plan_camp_live(_actions = undefined) {
    var _d = gmsa_plan_domain_create("live camp");
    gmsa_plan_add_fact(_d, "has_axe", function(_o) { return _o.has_axe; });
    gmsa_plan_add_fact(_d, "at_tree", function(_o) { return _o.at_tree; });
    gmsa_plan_add_fact(_d, "has_wood", function(_o) { return _o.has_wood; });
    gmsa_plan_add_fact(_d, "fire", function(_o) { return _o.fire; });
    gmsa_plan_add_step(_d, "get_axe", { effects : [["has_axe", true]], cost : 2 });
    gmsa_plan_add_step(_d, "walk_to_tree", { effects : [["at_tree", true]], cost : function(_o, _s) { return _o.walk_cost; } });
    gmsa_plan_add_step(_d, "chop", { requires : [["has_axe", true], ["at_tree", true]], effects : [["has_wood", true]], cost : 3 });
    gmsa_plan_add_step(_d, "build_fire", { requires : [["has_wood", true]], effects : [["fire", true], ["has_wood", false]] });
    gmsa_plan_add_step(_d, "camp", { effects : [["has_axe", true], ["at_tree", true]], cost : 9 });
    var _warm = { conditions : [["fire", true]] };
    if (_actions != undefined) _warm.actions = _actions;
    gmsa_plan_add_goal(_d, "warm", _warm);
    return gmsa_plan_domain_build(_d);
}

function __test_plan_camper() {
    return { has_axe : false, at_tree : false, has_wood : false, fire : false, walk_cost : 4 };
}

function __test_plan_camp_do(_o, _step) {
    switch (_step) {
        case "get_axe": _o.has_axe = true; break;
        case "walk_to_tree": _o.at_tree = true; break;
        case "chop": _o.has_wood = true; break;
        case "build_fire": _o.fire = true; _o.has_wood = false; break;
        case "camp": _o.has_axe = true; _o.at_tree = true; break;
    }
}