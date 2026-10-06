function test_plan_run() {
    gmsa_test_suite("Plan run", function() {

        gmsa_test_case("runs step by step", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _owner = { has_key : false, gold : 3 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.IDLE, "idle at first");
            gmsa_test_assert_equal(gmsa_plan_make(_p, "loot_chest"), true, "started");
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.RUNNING, "running");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "go_to_key", "first step");
            gmsa_test_assert_equal(gmsa_plan_position(_p), 0, "position 0");
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "pick_up_key", "second step");
            gmsa_test_assert_equal(gmsa_plan_position(_p), 1, "position 1");
            _owner.has_key = true; // the game applies the step's effect
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "open_chest", "third step");
            gmsa_test_assert_equal(gmsa_plan_step_done(_p), gmsa_plan_status.DONE, "done");
            gmsa_test_assert_equal(gmsa_plan_current(_p), undefined, "nothing current");
        });

        gmsa_test_case("changed facts that break nothing change nothing", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _owner = { has_key : false, gold : 3 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "loot_chest");
            _owner.gold = 50;
            gmsa_plan_step_done(_p);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "pick_up_key", "keeps fetching");
            gmsa_test_assert_equal(__test_plan_names(_p), "go_to_key,pick_up_key,open_chest", "same plan");
        });

        gmsa_test_case("a failed step replans the smallest task", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_add_step(_d, "escape");
            var _heist = gmsa_plan_add_task(_d, "heist");
            gmsa_plan_add_method(_heist, "only", { subtasks : ["loot_chest", "escape"] });
            gmsa_plan_domain_build(_d);
            var _owner = { has_key : false, gold : 3 };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "heist");
            gmsa_test_assert_equal(__test_plan_names(_p), "go_to_key,pick_up_key,open_chest,escape", "fetch plan");
            gmsa_plan_step_done(_p);
            _owner.gold = 20; // someone took the key, but the goblin found gold
            gmsa_plan_step_failed(_p);
            gmsa_test_assert_equal(gmsa_plan_current(_p), "buy_key", "buys instead");
            gmsa_test_assert_equal(__test_plan_names(_p), "buy_key,open_chest,escape", "escape kept");
            gmsa_test_assert_equal(gmsa_plan_position(_p), 0, "at the new start");
        });

        gmsa_test_case("a broken later task is replanned, the current step stays", function() {
            var _owner = { door_locked : false, has_pick : true };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
            gmsa_plan_make(_p, "heist");
            gmsa_test_assert_equal(__test_plan_names(_p), "approach,walk,enter", "walk in");
            gmsa_plan_refresh(_p);
            gmsa_test_assert_equal(__test_plan_names(_p), "approach,walk,enter", "nothing changed");
            _owner.door_locked = true;
            gmsa_plan_refresh(_p);
            gmsa_test_assert_equal(__test_plan_names(_p), "approach,walk,pick_lock,enter", "picks the lock");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "approach", "still approaching");
        });

        gmsa_test_case("repair climbs to larger tasks", function() {
            var _owner = { door_locked : false, has_pick : false };
            var _p = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
            gmsa_plan_make(_p, "heist");
            _owner.door_locked = true;
            gmsa_plan_refresh(_p);
            gmsa_test_assert_equal(__test_plan_names(_p), "sneak", "the back way");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "sneak", "current");
            _owner.door_locked = false;
            gmsa_plan_make(_p, "heist");
            _owner.door_locked = true;
            _owner.has_pick = false;
            gmsa_plan_step_done(_p); // approached, then found the door locked
            gmsa_test_assert_equal(gmsa_plan_current(_p), "sneak", "repaired on step done too");
        });

        gmsa_test_case("failures retry, then give up", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 }, { retries : 3 });
            gmsa_plan_make(_p, "loot_chest");
            for (var _i = 0; _i < 3; _i++) gmsa_plan_step_failed(_p);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.RUNNING, "three retries");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "go_to_key", "same plan again");
            gmsa_plan_step_done(_p);
            for (var _i = 0; _i < 3; _i++) gmsa_plan_step_failed(_p);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.RUNNING, "a done step resets the count");
            gmsa_test_assert_equal(gmsa_plan_step_failed(_p), gmsa_plan_status.FAILED, "the fourth in a row fails");
            gmsa_test_assert_equal(gmsa_plan_current(_p), undefined, "nothing current");
        });

        gmsa_test_case("targets", function() {
            var _d = gmsa_plan_domain_create("fight");
            gmsa_plan_add_step(_d, "attack", {
                targets : function(_o) { return _o.enemies; },
                score : function(_o, _t) { return _t.threat; },
            });
            gmsa_plan_add_step(_d, "loot", { targets : function(_o) { return _o.items; } });
            gmsa_plan_add_step(_d, "broken", { targets : function(_o) { return 5; } });
            gmsa_plan_domain_build(_d);
            var _strong = { threat : 0.9 };
            var _owner = { enemies : [{ threat : 0.2 }, _strong, { threat : 0 }], items : ["coin", "gem"] };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "attack");
            gmsa_test_assert_equal(gmsa_plan_target(_p), _strong, "highest score");
            gmsa_plan_make(_p, "loot");
            gmsa_test_assert_equal(gmsa_plan_target(_p), "coin", "no score takes the first");
            _owner.enemies = [{ threat : 0 }];
            gmsa_test_assert_equal(gmsa_plan_make(_p, "attack"), false, "all ruled out");
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.FAILED, "failed");
            _owner.enemies = [];
            gmsa_test_assert_equal(gmsa_plan_make(_p, "attack"), false, "none at all");
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_plan_make(p, "broken"); }), "targets must be an array");
        });

        gmsa_test_case("stop", function() {
            var _d = __test_plan_key_domain();
            gmsa_plan_domain_build(_d);
            var _p = gmsa_plan_planner_create(_d, { has_key : false, gold : 3 });
            gmsa_plan_make(_p, "loot_chest");
            gmsa_plan_stop(_p);
            gmsa_test_assert_equal(gmsa_plan_get_status(_p), gmsa_plan_status.IDLE, "idle");
            gmsa_test_assert_equal(gmsa_plan_current(_p), undefined, "nothing current");
            gmsa_test_assert_equal(gmsa_plan_length(_p), 0, "no plan");
            gmsa_test_assert_equal(gmsa_plan_step_done(_p), gmsa_plan_status.IDLE, "late reports are ignored");
        });
    });
}

function __test_plan_door_domain() {
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
    return gmsa_plan_domain_build(_d);
}