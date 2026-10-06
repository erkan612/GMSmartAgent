function test_plan_domain() {
    gmsa_test_suite("Plan domain", function() {

        gmsa_test_case("adding validates", function() {
            gmsa_test_assert_throws(function() { gmsa_plan_domain_create(""); }, "domain name");
            var _d = gmsa_plan_domain_create("t");
            var _ctx = { d : _d };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_fact(d, "", function(_o) { return 0; }); }), "fact name");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_fact(d, "x", "nope"); }), "fact read");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_step(d, ""); }), "step name");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_add_method({}, "m", {}); }), "method needs a task");
        });

        gmsa_test_case("build compiles conditions and effects", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _buy = _d.steps[_d.lookup[$ "buy_key"].index];
            gmsa_test_assert_equal(_buy.requires.count, 1, "one condition");
            gmsa_test_assert_equal(_buy.requires.fact[0], gmsa_plan_fact_index(_d, "gold"), "fact index");
            gmsa_test_assert_equal(_buy.requires.op[0], gmsa_plan_op.GE, "op");
            gmsa_test_assert_equal(_buy.effects.op[0], gmsa_plan_op.SUB, "effect op");
            gmsa_test_assert_equal(_buy.effects.value[1], 1, "bools become 1");
            var _loot = _d.tasks[0];
            gmsa_test_assert_equal(array_length(_loot.methods), 3, "methods");
            gmsa_test_assert_equal(_loot.methods[2].subtasks[0].kind, 0, "subtask is a step");
            gmsa_test_assert_equal(gmsa_plan_fact_index(_d, "nope"), -1, "unknown fact");
            gmsa_test_assert_throws(method({ d : _d }, function() { gmsa_plan_add_step(d, "late"); }), "locked after build");
        });

        gmsa_test_case("build rejects bad domains and changes nothing", function() {
            var _cases = [
                function(_d) { gmsa_plan_add_step(_d, "a", { requires : [["missing", true]] }); },
                function(_d) { gmsa_plan_add_step(_d, "a", { requires : [["has_key", "~", true]] }); },
                function(_d) { gmsa_plan_add_step(_d, "a", { effects : [["gold", ">=", 1]] }); },
                function(_d) { gmsa_plan_add_step(_d, "a", { effects : [["gold", "-", "ten"]] }); },
                function(_d) { gmsa_plan_add_step(_d, "a", { requires : ["has_key"] }); },
                function(_d) { gmsa_plan_add_step(_d, "a", { check : "nope" }); },
                function(_d) { gmsa_plan_add_step(_d, "open_chest"); },
                function(_d) { gmsa_plan_add_task(_d, "empty"); },
                function(_d) { var _t = gmsa_plan_add_task(_d, "x"); gmsa_plan_add_method(_t, "m", { subtasks : ["nowhere"] }); },
                function(_d) { var _t = gmsa_plan_add_task(_d, "x"); gmsa_plan_add_method(_t, "m", { subtasks : [] }); },
                function(_d) { gmsa_plan_add_fact(_d, "gold", function(_o) { return 0; }); },
            ];
            for (var _i = 0; _i < array_length(_cases); _i++) {
                var _d = __test_plan_key_domain();
                _cases[_i](_d);
                gmsa_test_assert_throws(method({ d : _d }, function() { gmsa_plan_domain_build(d); }), "case " + string(_i));
                gmsa_test_assert_false(_d.built, "case " + string(_i) + " not built");
            }
            gmsa_test_assert_throws(function() { gmsa_plan_domain_build(gmsa_plan_domain_create("no steps")); }, "no steps");
        });

        gmsa_test_case("tasks can use themselves", function() {
            var _d = gmsa_plan_domain_create("loop");
            gmsa_plan_add_fact(_d, "coins", function(_o) { return _o.coins; });
            gmsa_plan_add_step(_d, "grab", { effects : [["coins", "-", 1]] });
            var _t = gmsa_plan_add_task(_d, "grab_all");
            gmsa_plan_add_method(_t, "more", { requires : [["coins", ">", 0]], subtasks : ["grab", "grab_all"] });
            gmsa_plan_add_method(_t, "done", { subtasks : ["grab"] });
            gmsa_plan_domain_build(_d);
            gmsa_test_assert_equal(_d.tasks[0].methods[0].subtasks[1].kind, 1, "a task in its own method");
        });

        gmsa_test_case("conditions", function() {
            var _d = gmsa_plan_domain_create("ops");
            gmsa_plan_add_fact(_d, "n", function(_o) { return 0; });
            var _ops = ["==", "!=", "<", "<=", ">", ">="];
            var _expect = [[false, true, false], [true, false, true], [true, false, false], [true, true, false], [false, false, true], [false, true, true]];
            for (var _o = 0; _o < 6; _o++) gmsa_plan_add_step(_d, "s" + string(_o), { requires : [["n", _ops[_o], 5]] });
            gmsa_plan_domain_build(_d);
            var _values = [4, 5, 6];
            for (var _o = 0; _o < 6; _o++) {
                for (var _v = 0; _v < 3; _v++) {
                    gmsa_test_assert_equal(__gmsa_plan_met([_values[_v]], _d.steps[_o].requires), _expect[_o][_v],
                        _ops[_o] + " with " + string(_values[_v]));
                }
            }
        });

        gmsa_test_case("effects apply and undo", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _h = { state : [0, 25], undo_fact : [], undo_value : [], undo_count : 0 }; // has_key, gold
            var _buy = _d.steps[_d.lookup[$ "buy_key"].index];
            var _mark = _h.undo_count;
            __gmsa_plan_apply(_h, _buy.effects);
            gmsa_test_assert_equal(_h.state[1], 15, "gold spent");
            gmsa_test_assert_equal(_h.state[0], 1, "key gained");
            __gmsa_plan_apply(_h, _buy.effects);
            gmsa_test_assert_equal(_h.state[1], 5, "twice");
            __gmsa_plan_undo(_h, _mark);
            gmsa_test_assert_equal(_h.state[1], 25, "gold restored");
            gmsa_test_assert_equal(_h.state[0], 0, "key restored");
            gmsa_test_assert_equal(_h.undo_count, 0, "log emptied");
        });

        gmsa_test_case("reading facts", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _h = { state : [], undo_fact : [], undo_value : [], undo_count : 0 };
            __gmsa_plan_read_facts(_d, { has_key : true, gold : 12 }, _h);
            gmsa_test_assert_equal(_h.state[0], 1, "bool read as 1");
            gmsa_test_assert_equal(_h.state[1], 12, "number");
            gmsa_test_assert_throws(method({ d : _d, h : _h }, function() { __gmsa_plan_read_facts(d, { has_key : "yes", gold : 1 }, h); }), "not a number");
        });
    });
}

function __test_plan_key_domain() {
    var _d = gmsa_plan_domain_create("key test");
    gmsa_plan_add_fact(_d, "has_key", function(_o) { return _o.has_key; });
    gmsa_plan_add_fact(_d, "gold", function(_o) { return _o.gold; });
    gmsa_plan_add_step(_d, "go_to_key");
    gmsa_plan_add_step(_d, "pick_up_key", { effects : [["has_key", true]] });
    gmsa_plan_add_step(_d, "buy_key", { requires : [["gold", ">=", 10]], effects : [["gold", "-", 10], ["has_key", true]] });
    gmsa_plan_add_step(_d, "open_chest", { requires : [["has_key", true]] });
    var _loot = gmsa_plan_add_task(_d, "loot_chest");
    gmsa_plan_add_method(_loot, "have_key", { requires : [["has_key", true]], subtasks : ["open_chest"] });
    gmsa_plan_add_method(_loot, "buy", { subtasks : ["buy_key", "open_chest"] });
    gmsa_plan_add_method(_loot, "fetch", { subtasks : ["go_to_key", "pick_up_key", "open_chest"] });
    return _d;
}