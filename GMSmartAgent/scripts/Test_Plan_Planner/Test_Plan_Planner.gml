function test_plan_planner() {
    gmsa_test_suite("Plan planner", function() {

        gmsa_test_case("create and make validate", function() {
            var _open = gmsa_plan_domain_create("open");
            gmsa_plan_add_step(_open, "s");
            gmsa_test_assert_throws(method({ d : _open }, function() { gmsa_plan_planner_create(d, {}); }), "domain not built");
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            gmsa_test_assert_throws(method({ d : _d }, function() { gmsa_plan_planner_create(d, {}, { budget : 0 }); }), "budget");
            gmsa_test_assert_throws(method({ d : _d }, function() { gmsa_plan_planner_create(d, {}, { depth : 0 }); }), "depth");
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 0 });
            gmsa_test_assert_equal(gmsa_plan_last_result(_p), gmsa_plan_result.NONE, "nothing yet");
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_plan_make(p, "nope"); }), "unknown goal");
            gmsa_test_assert_equal(gmsa_plan_step_at(_p, 0), undefined, "no plan yet");
        });

        gmsa_test_case("first method that works wins, facts read each time", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _owner = { has_key : true, gold : 0 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_test_assert_equal(gmsa_plan_make(_p, "loot_chest"), true, "found");
            gmsa_test_assert_equal(__test_plan_names(_p), "open_chest", "has the key");
            _owner.has_key = false;
            _owner.gold = 25;
            gmsa_plan_make(_p, "loot_chest");
            gmsa_test_assert_equal(__test_plan_names(_p), "buy_key,open_chest", "can buy");
            _owner.gold = 3;
            gmsa_plan_make(_p, "loot_chest");
            gmsa_test_assert_equal(__test_plan_names(_p), "go_to_key,pick_up_key,open_chest", "has to fetch");
            gmsa_test_assert_equal(gmsa_plan_last_result(_p), gmsa_plan_result.FOUND, "result");
            gmsa_test_assert_equal(gmsa_plan_make(_p, "open_chest"), false, "a step as the goal");
            gmsa_test_assert_equal(gmsa_plan_last_result(_p), gmsa_plan_result.NO_PLAN, "no plan");
            gmsa_test_assert_equal(gmsa_plan_length(_p), 0, "emptied");
        });

        gmsa_test_case("backtracking undoes effects", function() {
            var _d = gmsa_plan_domain_create("door");
            gmsa_plan_add_fact(_d, "door_open", function(_o) { return _o.door_open; });
            gmsa_plan_add_fact(_d, "gold", function(_o) { return _o.gold; });
            gmsa_plan_add_step(_d, "pay", { requires : [["gold", ">=", 5]], effects : [["gold", "-", 5]] });
            gmsa_plan_add_step(_d, "enter", { requires : [["door_open", true]] });
            gmsa_plan_add_step(_d, "climb");
            var _t = gmsa_plan_add_task(_d, "get_in");
            gmsa_plan_add_method(_t, "walk", { subtasks : ["pay", "enter"] });
            gmsa_plan_add_method(_t, "climb", { subtasks : ["pay", "climb"] });
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { door_open : false, gold : 5 });
            gmsa_plan_make(_p, "get_in");
            gmsa_test_assert_equal(__test_plan_names(_p), "pay,climb", "paid once, not twice");
        });

        gmsa_test_case("backtracking into a finished task", function() {
            var _d = gmsa_plan_domain_create("nested");
            gmsa_plan_add_fact(_d, "x", function(_o) { return 0; });
            gmsa_plan_add_step(_d, "a", { effects : [["x", 1]] });
            gmsa_plan_add_step(_d, "b", { effects : [["x", 2]] });
            gmsa_plan_add_step(_d, "finish", { requires : [["x", 2]] });
            var _inner = gmsa_plan_add_task(_d, "inner");
            gmsa_plan_add_method(_inner, "first", { subtasks : ["a"] });
            gmsa_plan_add_method(_inner, "second", { subtasks : ["b"] });
            var _outer = gmsa_plan_add_task(_d, "outer");
            gmsa_plan_add_method(_outer, "only", { subtasks : ["inner", "finish"] });
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, {});
            gmsa_plan_make(_p, "outer");
            gmsa_test_assert_equal(__test_plan_names(_p), "b,finish", "inner changed its mind");
        });

        gmsa_test_case("recursive tasks", function() {
            var _d = gmsa_plan_domain_create("coins");
            gmsa_plan_add_fact(_d, "coins", function(_o) { return _o.coins; });
            gmsa_plan_add_step(_d, "grab", { requires : [["coins", ">", 0]], effects : [["coins", "-", 1]] });
            gmsa_plan_add_step(_d, "stop");
            var _t = gmsa_plan_add_task(_d, "grab_all");
            gmsa_plan_add_method(_t, "more", { requires : [["coins", ">", 0]], subtasks : ["grab", "grab_all"] });
            gmsa_plan_add_method(_t, "done", { subtasks : ["stop"] });
            gmsa_plan_domain_build(_d);
            var _owner = { coins : 3 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "grab_all");
            gmsa_test_assert_equal(__test_plan_names(_p), "grab,grab,grab,stop", "three coins");
            _owner.coins = 0;
            gmsa_plan_make(_p, "grab_all");
            gmsa_test_assert_equal(__test_plan_names(_p), "stop", "none");
        });

        gmsa_test_case("depth cap and node budget", function() {
            var _d = gmsa_plan_domain_create("forever");
            gmsa_plan_add_step(_d, "s");
            var _t = gmsa_plan_add_task(_d, "loop");
            gmsa_plan_add_method(_t, "again", { subtasks : ["loop"] });
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, {}, { depth : 8 });
            gmsa_test_assert_equal(gmsa_plan_make(_p, "loop"), false, "no plan");
            gmsa_test_assert_equal(gmsa_plan_last_result(_p), gmsa_plan_result.NO_PLAN, "result");
            gmsa_test_assert_equal(_p.depth_cut, true, "cut by depth");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_p), 8, "one node per level");
            var _q = gmsa_plan_planner_create(_d, {}, { depth : 100000, budget : 50 });
            gmsa_test_assert_equal(gmsa_plan_make(_q, "loop"), false, "no plan");
            gmsa_test_assert_equal(gmsa_plan_last_result(_q), gmsa_plan_result.OUT_OF_BUDGET, "budget result");
            gmsa_test_assert_equal(gmsa_plan_nodes_used(_q), 50, "never over budget");
        });

        gmsa_test_case("scored methods", function() {
            var _d = gmsa_plan_domain_create("scores");
            gmsa_plan_add_step(_d, "low");
            gmsa_plan_add_step(_d, "high");
            gmsa_plan_add_step(_d, "plain");
            var _t = gmsa_plan_add_task(_d, "pick");
            gmsa_plan_add_method(_t, "low", { score : function(_o, _s) { return _o.low; }, subtasks : ["low"] });
            gmsa_plan_add_method(_t, "high", { score : function(_o, _s) { return _o.high; }, subtasks : ["high"] });
            var _t2 = gmsa_plan_add_task(_d, "pick_plain");
            gmsa_plan_add_method(_t2, "low", { score : function(_o, _s) { return _o.low; }, subtasks : ["low"] });
            gmsa_plan_add_method(_t2, "plain", { subtasks : ["plain"] });
            var _t3 = gmsa_plan_add_task(_d, "broken");
            gmsa_plan_add_method(_t3, "bad", { score : function(_o, _s) { return "x"; }, subtasks : ["low"] });
            gmsa_plan_domain_build(_d);
            var _owner = { low : 0.2, high : 0.8 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "pick");
            gmsa_test_assert_equal(__test_plan_names(_p), "high", "best first");
            _owner.high = 0;
            gmsa_plan_make(_p, "pick");
            gmsa_test_assert_equal(__test_plan_names(_p), "low", "0 rules out");
            _owner.low = 0;
            gmsa_test_assert_equal(gmsa_plan_make(_p, "pick"), false, "all ruled out");
            _owner.low = 0.5;
            _owner.high = 0.5;
            gmsa_plan_make(_p, "pick");
            gmsa_test_assert_equal(__test_plan_names(_p), "low", "ties keep order");
            gmsa_plan_make(_p, "pick_plain");
            gmsa_test_assert_equal(__test_plan_names(_p), "plain", "no score counts as 1");
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_plan_make(p, "broken"); }), "score must be a number");
        });

        gmsa_test_case("check functions", function() {
            var _d = gmsa_plan_domain_create("check");
            gmsa_plan_add_fact(_d, "a", function(_o) { return _o.a; });
            gmsa_plan_add_fact(_d, "b", function(_o) { return _o.b; });
            gmsa_plan_add_step(_d, "open", { check : function(_s) { return _s[0] + _s[1] >= 10; } }); // a and b are facts 0 and 1
            gmsa_plan_domain_build(_d);
            var _owner = { a : 4, b : 6 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_test_assert_equal(gmsa_plan_make(_p, "open"), true, "10 is enough");
            _owner.b = 5;
            gmsa_test_assert_equal(gmsa_plan_make(_p, "open"), false, "9 is not");
        });

        gmsa_test_case("planning again allocates nothing", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_make(_p, "loot_chest");
            var _nodes = array_length(_p.__node_kind);
            var _undo = array_length(_p.undo_fact);
            var _frames = array_length(_p.__frame_task);
            gmsa_plan_make(_p, "loot_chest");
            gmsa_test_assert_equal(array_length(_p.__node_kind), _nodes, "node pool reused");
            gmsa_test_assert_equal(array_length(_p.undo_fact), _undo, "undo log reused");
            gmsa_test_assert_equal(array_length(_p.__frame_task), _frames, "choice points reused");
        });
    });
}

function __test_plan_names(_p) {
    var _s = "";
    for (var _i = 0; _i < gmsa_plan_length(_p); _i++) _s += (_i > 0 ? "," : "") + gmsa_plan_step_at(_p, _i);
    return _s;
}