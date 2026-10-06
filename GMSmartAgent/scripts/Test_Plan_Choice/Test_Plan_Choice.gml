function test_plan_choice() {
    gmsa_test_suite("Plan choice", function() {

        gmsa_test_case("tasks and fact ranges validate", function() {
            var _d = gmsa_plan_domain_create("v");
            var _ctx = { d : _d };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_task(d, "t", { select : 99 }); }), "select");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_task(d, "t", { top_n : 0 }); }), "top_n");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_fact(d, "g", function(_o) { return 0; }, { min : 0 }); }), "min alone");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_fact(d, "g", function(_o) { return 0; }, { min : 5, max : 5 }); }), "empty range");
            gmsa_plan_add_fact(_d, "gold", function(_o) { return 0; }, { min : 0, max : 50 });
            gmsa_test_assert_equal(_d.facts[0].max, 50, "range kept");
        });

        gmsa_test_case("weighted tasks explore", function() {
            var _p = gmsa_plan_planner_create(__test_plan_choice_domain(0.5, 0.5, 2), { ok : true }, { seed : 7 });
            var _a = __test_plan_count_a(_p, 200);
            gmsa_test_assert_true(_a > 60 && _a < 140, "both get tried: " + string(_a));
        });

        gmsa_test_case("chances follow scores", function() {
            var _p = gmsa_plan_planner_create(__test_plan_choice_domain(0.8, 0.2, 2), { ok : true }, { seed : 7 });
            var _a = __test_plan_count_a(_p, 200);
            gmsa_test_assert_true(_a > 130 && _a < 190, "about 80%: " + string(_a));
            var _q = gmsa_plan_planner_create(__test_plan_choice_domain(0.8, 0.2, 1), { ok : true }, { seed : 7 });
            gmsa_test_assert_equal(__test_plan_count_a(_q, 50), 50, "top 1 is a fixed order");
        });

        gmsa_test_case("a plan is always found", function() {
            var _p = gmsa_plan_planner_create(__test_plan_choice_domain(0.5, 0.5, 2), { ok : false }, { seed : 7 });
            repeat (50) {
                gmsa_plan_make(_p, "pick");
                gmsa_test_assert_equal(__test_plan_names(_p), "b", "the method that works");
            }
        });

        gmsa_test_case("the chance of the chosen method", function() {
            var _p = gmsa_plan_planner_create(__test_plan_choice_domain(0.5, 0.5, 2), { ok : true }, { seed : 7 });
            repeat (20) {
                gmsa_plan_make(_p, "pick");
                gmsa_test_assert_equal(__gmsa_plan_entry_chance(_p, 0), 0.5, "both possible");
            }
            var _q = gmsa_plan_planner_create(__test_plan_choice_domain(0.5, 0.5, 2), { ok : false }, { seed : 7 });
            var _half = 0;
            var _whole = 0;
            repeat (100) {
                gmsa_plan_make(_q, "pick");
                var _c = __gmsa_plan_entry_chance(_q, 0);
                if (_c == 0.5) _half++;
                else if (_c == 1) _whole++;
            }
            gmsa_test_assert_equal(_half + _whole, 100, "a was tried first (1) or not (0.5), nothing else");
            gmsa_test_assert_true(_half > 0 && _whole > 0, "both happen");
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _r = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_make(_r, "loot_chest");
            gmsa_test_assert_equal(__gmsa_plan_entry_chance(_r, 0), 1, "fixed order");
        });

        gmsa_test_case("same seed, same plans, in slices too", function() {
            var _d = __test_plan_choice_domain(0.5, 0.5, 2);
            var _x = gmsa_plan_planner_create(_d, { ok : true }, { seed : 3 });
            var _y = gmsa_plan_planner_create(_d, { ok : true }, { seed : 3 });
            repeat (20) {
                gmsa_plan_make(_x, "pick");
                gmsa_plan_make(_y, "pick");
                gmsa_test_assert_equal(__test_plan_names(_x), __test_plan_names(_y), "same choices");
            }
            var _w = __test_plan_weighted_backtrack();
            var _whole = gmsa_plan_planner_create(_w, {}, { seed : 5 });
            var _sliced = gmsa_plan_planner_create(_w, {}, { seed : 5, slice : 250, clock : __test_plan_clock(100) });
            repeat (5) {
                gmsa_plan_make(_whole, "choose");
                gmsa_plan_make(_sliced, "choose");
                while (gmsa_plan_get_status(_sliced) == gmsa_plan_status.PLANNING) gmsa_plan_work(_sliced);
                gmsa_test_assert_equal(gmsa_plan_nodes_used(_sliced), gmsa_plan_nodes_used(_whole), "same search");
                gmsa_test_assert_equal(__test_plan_names(_sliced), "work,finish", "found");
            }
        });

        gmsa_test_case("explain shows the chance", function() {
            var _p = gmsa_plan_planner_create(__test_plan_choice_domain(0.5, 0.5, 2), { ok : true });
            gmsa_plan_make(_p, "pick");
            gmsa_test_assert_true(string_pos("(score 0.50, chance 0.50)", gmsa_plan_explain(_p)) > 0, "score and chance");
        });
    });
}

function __test_plan_choice_domain(_score_a, _score_b, _top_n) {
    var _d = gmsa_plan_domain_create("choice");
    gmsa_plan_add_fact(_d, "ok", function(_o) { return _o.ok; });
    gmsa_plan_add_step(_d, "a");
    gmsa_plan_add_step(_d, "b");
    var _t = gmsa_plan_add_task(_d, "pick", { select : gmsa_select.TOP_N_WEIGHTED, top_n : _top_n });
    gmsa_plan_add_method(_t, "a", { requires : [["ok", true]], score : method({ s : _score_a }, function(_o, _st) { return s; }), subtasks : ["a"] });
    gmsa_plan_add_method(_t, "b", { score : method({ s : _score_b }, function(_o, _st) { return s; }), subtasks : ["b"] });
    return gmsa_plan_domain_build(_d);
}

function __test_plan_count_a(_p, _times) {
    var _a = 0;
    repeat (_times) {
        gmsa_plan_make(_p, "pick");
        if (__test_plan_names(_p) == "a") _a++;
    }
    return _a;
}

function __test_plan_weighted_backtrack() {
    var _d = gmsa_plan_domain_create("weighted backtrack");
    gmsa_plan_add_fact(_d, "x", function(_o) { return 0; });
    gmsa_plan_add_step(_d, "work", { effects : [["x", "+", 1]] });
    gmsa_plan_add_step(_d, "fail", { requires : [["x", "<", 0]] });
    gmsa_plan_add_step(_d, "finish");
    var _t = gmsa_plan_add_task(_d, "choose", { select : gmsa_select.TOP_N_WEIGHTED, top_n : 20 });
    for (var _m = 0; _m < 19; _m++) gmsa_plan_add_method(_t, "wrong_" + string(_m), { subtasks : ["work", "work", "work", "fail"] });
    gmsa_plan_add_method(_t, "right", { subtasks : ["work", "finish"] });
    return gmsa_plan_domain_build(_d);
}