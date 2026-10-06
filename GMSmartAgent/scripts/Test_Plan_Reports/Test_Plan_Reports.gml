function test_plan_reports() {
    gmsa_test_suite("Plan reports", function() {

        gmsa_test_case("a finished plan reports its steps and methods", function() {
            var _d = __test_plan_key_domain();
            var _log = __test_plan_log(_d);
            gmsa_plan_domain_build(_d);
            var _owner = { has_key : false, gold : 3 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "loot_chest");
            gmsa_plan_step_done(_p);
            _owner.has_key = true;
            gmsa_plan_step_done(_p);
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(__test_plan_log_text(_log),
                "step success go_to_key|step success pick_up_key|step success open_chest|method success loot_chest.fetch", "in order");
        });

        gmsa_test_case("methods with nothing to do succeed at once", function() {
            var _d = __test_plan_key_domain();
            var _t = gmsa_plan_add_task(_d, "ensure_key");
            gmsa_plan_add_method(_t, "have_it", { requires : [["has_key", true]], subtasks : [] });
            gmsa_plan_add_method(_t, "fetch", { subtasks : ["go_to_key", "pick_up_key"] });
            var _log = __test_plan_log(_d);
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : true, gold : 0 });
            gmsa_plan_make(_p, "ensure_key");
            gmsa_test_assert_equal(__test_plan_log_text(_log), "method success ensure_key.have_it", "at once");
        });

        gmsa_test_case("a repair fails the methods around the break", function() {
            var _owner = { door_locked : false, has_pick : true };
            var _d = __test_plan_door_domain_open();
            var _log = __test_plan_log(_d);
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "heist");
            _owner.door_locked = true;
            gmsa_plan_refresh(_p);
            gmsa_test_assert_equal(__test_plan_log_text(_log), "method failure get_in.walk_in", "only get_in's method");

            var _owner2 = { door_locked : false, has_pick : false };
            var _d2 = __test_plan_door_domain_open();
            var _log2 = __test_plan_log(_d2);
            gmsa_plan_domain_build(_d2);
            var _q = gmsa_plan_planner_create(_d2, _owner2);
            gmsa_plan_make(_q, "heist");
            _owner2.door_locked = true;
            gmsa_plan_refresh(_q);
            gmsa_test_assert_equal(__test_plan_log_text(_log2), "method failure get_in.walk_in|method failure heist.front",
                "a repair that climbs fails every level it replaced");
        });

        gmsa_test_case("failed steps and given up plans", function() {
            var _d = __test_plan_key_domain();
            var _log = __test_plan_log(_d);
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_make(_p, "loot_chest");
            gmsa_plan_step_failed(_p);
            gmsa_test_assert_equal(__test_plan_log_text(_log), "step failure go_to_key|method failure loot_chest.fetch", "repaired");
            _log.lines = [];
            var _q = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 }, { retries : 0 });
            gmsa_plan_make(_q, "loot_chest");
            gmsa_plan_step_failed(_q);
            gmsa_test_assert_equal(__test_plan_log_text(_log), "step failure go_to_key|method failure loot_chest.fetch", "given up");
            gmsa_test_assert_equal(gmsa_plan_get_status(_q), gmsa_plan_status.FAILED, "failed");
        });

        gmsa_test_case("interruptions report nothing", function() {
            var _d = __test_plan_key_domain();
            var _log = __test_plan_log(_d);
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_make(_p, "loot_chest");
            gmsa_plan_step_done(_p);
            gmsa_plan_stop(_p);
            gmsa_plan_make(_p, "loot_chest");
            gmsa_plan_make(_p, "loot_chest");
            gmsa_test_assert_equal(__test_plan_log_text(_log), "step success go_to_key", "only the step that was done");
        });

        gmsa_test_case("rewards", function() {
            var _d = __test_plan_door_domain_open();
            var _log = __test_plan_log(_d);
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { door_locked : false, has_pick : true });
            gmsa_test_assert_equal(gmsa_plan_reward(_p, 1), 0, "nothing running");
            gmsa_plan_make(_p, "heist");
            gmsa_test_assert_equal(gmsa_plan_reward(_p, 0.5), 1, "approach is in heist only");
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(gmsa_plan_reward(_p, 0.25), 2, "walk is in get_in and heist");
            gmsa_plan_step_done(_p);
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.DONE, "done");
            _log.lines = [];
            gmsa_test_assert_equal(gmsa_plan_reward(_p, 1), 2, "every method of the plan");
            gmsa_test_assert_equal(__test_plan_log_text(_log), "method reward heist.front 1|method reward get_in.walk_in 1", "both");
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_plan_reward(p, "lots"); }), "a number");
        });

        gmsa_test_case("reports carry the facts as planned and the chance", function() {
            var _d = __test_plan_key_domain();
            var _seen = { gold : -1, chance : -1 };
            gmsa_plan_add_listener(_d, method(_seen, function(_r) {
                if (_r.kind == gmsa_plan_report.METHOD_SUCCESS) {
                    gold = _r.state[1];
                    chance = _r.chance;
                }
            }));
            gmsa_plan_domain_build(_d);
            var _owner = { has_key : false, gold : 3 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "loot_chest");
            _owner.gold = 40;
            gmsa_plan_step_done(_p);
            _owner.has_key = true;
            gmsa_plan_step_done(_p);
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(_seen.gold, 3, "gold when planned");
            gmsa_test_assert_equal(_seen.chance, 1, "fixed order");
        });
    });
}

function __test_plan_log(_d) {
    var _log = { lines : [] };
    gmsa_plan_add_listener(_d, method(_log, function(_r) {
        var _kinds = ["method success", "method failure", "method reward", "step success", "step failure"];
        var _what = (_r.step >= 0) ? _r.step_name : (_r.task_name + "." + _r.method_name);
        var _line = _kinds[_r.kind] + " " + _what;
        if (_r.kind == gmsa_plan_report.METHOD_REWARD) _line += " " + string(_r.reward);
        array_push(lines, _line);
    }));
    return _log;
}

function __test_plan_log_text(_log) {
    var _s = "";
    for (var _i = 0; _i < array_length(_log.lines); _i++) _s += ((_i > 0) ? "|" : "") + _log.lines[_i];
    return _s;
}

function __test_plan_door_domain_open() {
    var _d = gmsa_plan_domain_create("door test");
    gmsa_plan_add_fact(_d, "door_locked", function(_o) { return _o.door_locked; });
    gmsa_plan_add_fact(_d, "has_pick", function(_o) { return _o.has_pick; });
    gmsa_plan_add_step(_d, "approach");
    gmsa_plan_add_step(_d, "walk");
    gmsa_plan_add_step(_d, "enter", { requires : [["door_locked", false]] });
    gmsa_plan_add_step(_d, "pick_lock", { requires : [["has_pick", true]], effects : [["door_locked", false]] });
    gmsa_plan_add_step(_d, "sneak");
    var _get_in = gmsa_plan_add_task(_d, "get_in");
    gmsa_plan_add_method(_get_in, "walk_in", { requires : [["door_locked", false]], subtasks : ["walk", "enter"] });
    gmsa_plan_add_method(_get_in, "pick", { subtasks : ["walk", "pick_lock", "enter"] });
    var _heist = gmsa_plan_add_task(_d, "heist");
    gmsa_plan_add_method(_heist, "front", { subtasks : ["approach", "get_in"] });
    gmsa_plan_add_method(_heist, "back", { subtasks : ["sneak"] });
    return _d;
}