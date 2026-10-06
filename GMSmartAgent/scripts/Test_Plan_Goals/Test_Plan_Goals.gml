function test_plan_goals() {
    gmsa_test_suite("Plan goals", function() {
        gmsa_test_case("a pure GOAP domain builds: facts, steps, goals, no tasks", function() {
            var _d = __test_plan_camp(undefined);
            gmsa_test_assert_equal(array_length(_d.tasks), 0);
            gmsa_test_assert_equal(_d.lookup[$ "warm"].kind, 3);
            gmsa_test_assert_equal(array_length(_d.goals[0].actions), array_length(_d.steps), "every step by default");
        });

        gmsa_test_case("step cost: 1 by default, a number or a function", function() {
            var _d = __test_plan_camp(undefined);
            var _get = _d.steps[_d.lookup[$ "get_axe"].index];
            var _walk = _d.steps[_d.lookup[$ "walk_to_tree"].index];
            var _fire = _d.steps[_d.lookup[$ "build_fire"].index];
            gmsa_test_assert_equal(_get.cost, 2);
            gmsa_test_assert_true(_get.cost_fn == undefined);
            gmsa_test_assert_true(_walk.cost_fn != undefined, "a function is kept");
            gmsa_test_assert_equal(_fire.cost, 1, "default");
        });

        gmsa_test_case("bad costs throw at build", function() {
            var _bad = [0, -1, "two"];
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ c : _bad[_i] }, function() {
                    var _d = gmsa_plan_domain_create("bad cost");
                    gmsa_plan_add_step(_d, "x", { cost : c });
                    gmsa_plan_domain_build(_d);
                }), "cost " + string(_bad[_i]));
            }
        });

        gmsa_test_case("the guess: most conditions per action and the cheapest fixed cost", function() {
            var _d = __test_plan_camp(undefined);
            var _warm = _d.goals[_d.lookup[$ "warm"].index];
            var _ready = _d.goals[_d.lookup[$ "ready"].index];
            gmsa_test_assert_equal(_warm.most, 1);
            gmsa_test_assert_equal(_ready.most, 2, "camp sets both has_axe and at_tree");
            gmsa_test_assert_equal(_warm.cheapest, 1, "walk_to_tree's function cost doesn't count");
        });

        gmsa_test_case("only function costs: the cheapest is 0, the search stays safe", function() {
            var _d = __test_plan_camp(["walk_to_tree"]);
            gmsa_test_assert_equal(_d.goals[_d.lookup[$ "warm"].index].cheapest, 0);
        });

        gmsa_test_case("a goal's actions: a list limits them, pruning drops what can't help", function() {
            var _d = __test_plan_camp(["get_axe"]);
            var _warm = _d.goals[_d.lookup[$ "warm"].index];
            gmsa_test_assert_equal(array_length(_warm.actions), 0, "an axe alone never lights a fire");
            gmsa_test_assert_equal(_warm.pruned, 1);
            gmsa_test_assert_false(_warm.changed[0], "nothing get_axe does lights a fire");
            gmsa_test_assert_equal(_warm.most, 1, "never below 1");
        });

        gmsa_test_case("bad goals throw at build", function() {
            var _cases = [
                { conditions : [] },                               // nothing to reach
                { conditions : [["nope", true]] },                 // unknown fact
                { conditions : [["fire", "~", 1]] },               // bad operator
                { conditions : [["fire", true]], actions : [] },   // empty list
                { conditions : [["fire", true]], actions : ["dance"] },
                { conditions : [["fire", true]], actions : ["stay_warm"] }, // a task isn't an action
                { conditions : [["fire", true]], actions : ["chop", "chop"] },
            ];
            for (var _i = 0; _i < array_length(_cases); _i++) {
                gmsa_test_assert_throws(method({ p : _cases[_i] }, function() {
                    var _d = gmsa_plan_domain_create("bad goal");
                    gmsa_plan_add_fact(_d, "fire", function(_o) { return false; });
                    gmsa_plan_add_step(_d, "chop");
                    var _t = gmsa_plan_add_task(_d, "stay_warm");
                    gmsa_plan_add_method(_t, "only", { subtasks : ["chop"] });
                    gmsa_plan_add_goal(_d, "g", p);
                    gmsa_plan_domain_build(_d);
                }), "case " + string(_i));
            }
        });

        gmsa_test_case("goals share the namespace with steps and tasks", function() {
            gmsa_test_assert_throws(function() {
                var _d = gmsa_plan_domain_create("clash");
                gmsa_plan_add_fact(_d, "fire", function(_o) { return false; });
                gmsa_plan_add_step(_d, "warm", { effects : [["fire", true]] });
                gmsa_plan_add_goal(_d, "warm", { conditions : [["fire", true]] });
                gmsa_plan_domain_build(_d);
            });
        });

        gmsa_test_case("a recipe may use a goal as a subtask", function() {
            var _d = gmsa_plan_domain_create("mixed");
            gmsa_plan_add_fact(_d, "fire", function(_o) { return false; });
            gmsa_plan_add_step(_d, "light", { effects : [["fire", true]] });
            gmsa_plan_add_step(_d, "sit");
            gmsa_plan_add_goal(_d, "warm", { conditions : [["fire", true]] });
            var _t = gmsa_plan_add_task(_d, "rest");
            gmsa_plan_add_method(_t, "by_the_fire", { subtasks : ["warm", "sit"] });
            gmsa_plan_domain_build(_d);
            gmsa_test_assert_equal(_d.tasks[0].methods[0].subtasks[0].kind, 3);
        });

        gmsa_test_case("no goals after build", function() {
            var _d = __test_plan_camp(undefined);
            gmsa_test_assert_throws(method({ d : _d }, function() { gmsa_plan_add_goal(d, "late", { conditions : [["fire", true]] }); }));
        });
		
        gmsa_test_case("pruning keeps every step a chain needs, through requires", function() {
            var _d = __test_plan_camp(undefined);
            gmsa_test_assert_equal(_d.goals[_d.lookup[$ "warm"].index].pruned, 0, "the axe and the walk are needed by chop, chop by the fire");
        });

        gmsa_test_case("pruning drops steps that change nothing the goal needs", function() {
            var _d = __test_plan_distracted(true, false);
            var _goal = _d.goals[_d.lookup[$ "warm"].index];
            gmsa_test_assert_equal(_goal.pruned, 2, "whistle and stretch");
            var _p = gmsa_plan_planner_create(_d, {});
            gmsa_plan_make(_p, "warm");
            gmsa_test_assert_equal(__test_plan_names(_p), "gather,light");
        });

        gmsa_test_case("prune false keeps every step", function() {
            var _d = __test_plan_distracted(false, false);
            gmsa_test_assert_equal(_d.goals[_d.lookup[$ "warm"].index].pruned, 0);
        });

        gmsa_test_case("a relevant step with a check: pruning steps aside for that goal", function() {
            var _d = __test_plan_distracted(true, true);
            gmsa_test_assert_equal(_d.goals[_d.lookup[$ "warm"].index].pruned, 0);
        });

        gmsa_test_case("a step that only lowers costs: pruned by default, used with prune false", function() {
            var _make = function(_prune) {
                var _d = gmsa_plan_domain_create("shoes");
                gmsa_plan_add_fact(_d, "shoes", function(_o) { return false; });
                gmsa_plan_add_fact(_d, "there", function(_o) { return false; });
                gmsa_plan_add_step(_d, "put_on_shoes", { effects : [["shoes", true]], cost : 1 });
                gmsa_plan_add_step(_d, "walk", { effects : [["there", true]], cost : function(_o, _s) { return _s[0] ? 2 : 10; } });
                gmsa_plan_add_goal(_d, "arrive", { conditions : [["there", true]], prune : _prune });
                return gmsa_plan_domain_build(_d);
            };
            var _p = gmsa_plan_planner_create(_make(true), {});
            gmsa_plan_make(_p, "arrive");
            gmsa_test_assert_equal(__test_plan_names(_p), "walk", "the shoes are pruned, walking barefoot costs 10");
            var _q = gmsa_plan_planner_create(_make(false), {});
            gmsa_plan_make(_q, "arrive");
            gmsa_test_assert_equal(__test_plan_names(_q), "put_on_shoes,walk", "1 + 2 beats 10");
        });

        gmsa_test_case("prune must be true or false", function() {
            gmsa_test_assert_throws(function() {
                var _d = gmsa_plan_domain_create("bad prune");
                gmsa_plan_add_fact(_d, "fire", function(_o) { return false; });
                gmsa_plan_add_step(_d, "light", { effects : [["fire", true]] });
                gmsa_plan_add_goal(_d, "warm", { conditions : [["fire", true]], prune : 1 });
                gmsa_plan_domain_build(_d);
            });
        });
    });
}

function __test_plan_camp(_actions) {
    var _d = gmsa_plan_domain_create("camp");
    gmsa_plan_add_fact(_d, "has_axe", function(_o) { return false; });
    gmsa_plan_add_fact(_d, "at_tree", function(_o) { return false; });
    gmsa_plan_add_fact(_d, "has_wood", function(_o) { return false; });
    gmsa_plan_add_fact(_d, "fire", function(_o) { return false; });
    gmsa_plan_add_step(_d, "get_axe", { effects : [["has_axe", true]], cost : 2 });
    gmsa_plan_add_step(_d, "walk_to_tree", { effects : [["at_tree", true]], cost : function(_o, _s) { return 4; } });
    gmsa_plan_add_step(_d, "chop", { requires : [["has_axe", true], ["at_tree", true]], effects : [["has_wood", true]], cost : 3 });
    gmsa_plan_add_step(_d, "build_fire", { requires : [["has_wood", true]], effects : [["fire", true], ["has_wood", false]] });
    gmsa_plan_add_step(_d, "camp", { effects : [["has_axe", true], ["at_tree", true]], cost : 9 });
    var _warm = { conditions : [["fire", true]] };
    if (_actions != undefined) _warm.actions = _actions;
    gmsa_plan_add_goal(_d, "warm", _warm);
    gmsa_plan_add_goal(_d, "ready", { conditions : [["has_axe", true], ["at_tree", true]] });
    return gmsa_plan_domain_build(_d);
}

function __test_plan_distracted(_prune, _check) {
    var _d = gmsa_plan_domain_create("distracted");
    gmsa_plan_add_fact(_d, "wood", function(_o) { return false; });
    gmsa_plan_add_fact(_d, "fire", function(_o) { return false; });
    gmsa_plan_add_fact(_d, "tune", function(_o) { return false; });
    gmsa_plan_add_fact(_d, "limber", function(_o) { return false; });
    gmsa_plan_add_step(_d, "gather", { effects : [["wood", true]] });
    var _light = { requires : [["wood", true]], effects : [["fire", true]] };
    if (_check) _light.check = function(_s) { return true; };
    gmsa_plan_add_step(_d, "light", _light);
    gmsa_plan_add_step(_d, "whistle", { effects : [["tune", true]] });
    gmsa_plan_add_step(_d, "stretch", { effects : [["limber", true]] });
    gmsa_plan_add_goal(_d, "warm", { conditions : [["fire", true]], prune : _prune });
    return gmsa_plan_domain_build(_d);
}