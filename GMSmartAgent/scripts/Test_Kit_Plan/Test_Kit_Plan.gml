function test_kit_plan() {
    gmsa_test_suite("Kit plan", function() {
        gmsa_test_case("an action runs its plan, each step with its own start, step and stop", function() {
            gmsa_kit_profile_forget("kit test raid");
            gmsa_kit_domain_forget("kit test raid");
            var _d = gmsa_kit_domain("kit test raid", {
                facts : {
                    has_key : function(_o) { return _o.keys > 0; },
                    opened  : function(_o) { return _o.opened; },
                },
                steps : {
                    get_key : {
                        effects : { has_key : true },
                        start   : function(_o) { array_push(_o.log, "get_key start"); },
                        step    : function(_o) { _o.keys++; array_push(_o.log, "get_key"); return true; },
                        stop    : function(_o) { array_push(_o.log, "get_key stop"); },
                    },
                    open_chest : {
                        requires : { has_key : true },
                        effects  : { opened : true },
                        step     : function(_o) { _o.opened = 1; _o.keys--; array_push(_o.log, "open"); return true; },
                    },
                },
                tasks : {
                    raid_chest : [
                        { name : "open",  requires : { has_key : true }, subtasks : ["open_chest"] },
                        { name : "fetch", subtasks : ["get_key", "open_chest"] },
                    ],
                },
            });
            var _p = gmsa_kit_profile("kit test raid", {
                inputs  : { opened : gmsa_kit_input_var("opened") },
                actions : {
                    raid : {
                        plan     : "raid_chest",
                        consider : { opened : gmsa_kit_curve_below() },
                        start    : function(_o) { array_push(_o.log, "raid start"); },
                        stop     : function(_o) { array_push(_o.log, "raid stop"); },
                    },
                },
            });
            var _owner = { keys : 0, opened : 0, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner, { domain : _d });
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "raid");
            gmsa_test_assert_equal(gmsa_kit_agent_plan_step(_a), "open_chest", "the key fetched, the chest next");
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["raid start", "get_key start", "get_key", "get_key stop", "open", "raid stop"]);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "", "the chest is open, nothing left to do");
        });

        gmsa_test_case("a domain from one struct: struct conditions, operators, both task forms, the same domain again", function() {
            gmsa_kit_domain_forget("kit test gold");
            var _d = gmsa_kit_domain("kit test gold", {
                facts : { gold : { read : function(_o) { return _o.gold; }, min : 0, max : 100 } },
                steps : {
                    mine  : { effects : { gold : ["+", 5] } },
                    spend : { requires : [["gold", ">=", 10]], effects : { gold : ["-", 10] } },
                },
                tasks : { earn : { methods : [{ name : "dig", subtasks : "mine" }], select : gmsa_select.BEST } },
                goals : { rich : { want : { gold : [">=", 10] } } },
            });
            gmsa_test_assert_true(_d == gmsa_kit_domain("kit test gold"), "asked again");
            var _p = gmsa_plan_planner_create(_d, { gold : 0 });
            gmsa_plan_make(_p, "rich");
            gmsa_test_assert_equal(gmsa_plan_length(_p), 2, "mine twice for 10 gold");
            gmsa_test_assert_equal(gmsa_plan_step_at(_p, 1), "mine");
            gmsa_plan_make(_p, "earn");
            gmsa_test_assert_equal(gmsa_plan_length(_p), 1, "a task given with its settings, subtasks as one name");
        });

        gmsa_test_case("a failed step fails the plan, and the action ends", function() {
            gmsa_kit_profile_forget("kit test fail");
            gmsa_kit_domain_forget("kit test fail");
            var _d = gmsa_kit_domain("kit test fail", {
                facts : { done : function(_o) { return _o.done; } },
                steps : { poke : { effects : { done : true }, start : function(_o) { array_push(_o.log, "poke start"); }, step : function(_o) { return gmsa_kit_step.FAILED; }, stop : function(_o) { array_push(_o.log, "poke stop"); } } },
                tasks : { attempt : [{ name : "once", subtasks : ["poke"] }] },
            });
            var _p = gmsa_kit_profile("kit test fail", { actions : { go : { plan : "attempt", stop : function(_o) { array_push(_o.log, "go stop"); } } } });
            var _owner = { done : 0, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner, { domain : _d, planner : { retries : 0 } });
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["poke start", "poke stop", "go stop"]);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "go", "and it chose to try again");
        });

        gmsa_test_case("a better action stops the plan, and the running step's stop runs", function() {
            gmsa_kit_profile_forget("kit test long");
            gmsa_kit_domain_forget("kit test long");
            var _d = gmsa_kit_domain("kit test long", {
                steps : { long : { start : function(_o) { array_push(_o.log, "long start"); }, step : function(_o) { return false; }, stop : function(_o) { array_push(_o.log, "long stop"); } } },
                tasks : { hold : [{ name : "m", subtasks : "long" }] },
            });
            var _p = gmsa_kit_profile("kit test long", {
                inputs  : { want : gmsa_kit_input_var("want") },
                actions : {
                    raid : { plan : "hold", consider : { want : gmsa_kit_curve_below() }, stop : function(_o) { array_push(_o.log, "raid stop"); } },
                    rest : { consider : { want : gmsa_kit_curve_at_least() }, start : function(_o) { array_push(_o.log, "rest start"); } },
                },
            });
            var _owner = { want : 0, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner, { domain : _d });
            gmsa_kit_agent_update(_a);
            _owner.want = 1;
            gmsa_kit_agent_decide(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["long start", "long stop", "raid stop", "rest start"]);
            gmsa_test_assert_equal(gmsa_plan_get_status(gmsa_kit_agent_planner(_a)), gmsa_plan_status.IDLE, "the plan stopped");
        });

        gmsa_test_case("a step without code is done at once", function() {
            gmsa_kit_profile_forget("kit test instant");
            gmsa_kit_domain_forget("kit test instant");
            var _d = gmsa_kit_domain("kit test instant", {
                steps : { a : {}, b : { step : function(_o) { return false; } } },
                tasks : { seq : [{ name : "m", subtasks : ["a", "b"] }] },
            });
            var _p = gmsa_kit_profile("kit test instant", { actions : { go : { plan : "seq" } } });
            var _a = gmsa_kit_agent_create(_p, {}, { domain : _d });
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_plan_step(_a), "b", "a was done in the same update");
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_plan_step(_a), "b", "b keeps going");
        });

        gmsa_test_case("prepare gets the tasks by name, and a reward reaches the plan's methods", function() {
            gmsa_kit_profile_forget("kit test reward");
            gmsa_kit_domain_forget("kit test reward");
            var _seen = { task : false, rewards : 0 };
            var _d = gmsa_kit_domain("kit test reward", {
                steps   : { work : { step : function(_o) { _o.done = 1; return true; } } },
                tasks   : { job : [{ name : "m", subtasks : "work" }] },
                prepare : method(_seen, function(_domain, _tasks) {
                    task = is_struct(_tasks[$ "job"]);
                    gmsa_plan_add_listener(_domain, method(self, function(_r) { if (_r.kind == gmsa_plan_report.METHOD_REWARD) rewards++; }));
                }),
            });
            var _p = gmsa_kit_profile("kit test reward", {
                inputs  : { done : gmsa_kit_input_var("done") },
                actions : { go : { plan : "job", consider : { done : gmsa_kit_curve_below() } } },
            });
            var _a = gmsa_kit_agent_create(_p, { done : 0 }, { domain : _d });
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_true(_seen.task, "prepare got the job task");
            gmsa_test_assert_equal(gmsa_kit_reward(_a, 1), 1, "one method credited");
            gmsa_test_assert_equal(_seen.rewards, 1);
        });

        gmsa_test_case("a scheduler plans for it", function() {
            gmsa_kit_profile_forget("kit test sched plan");
            gmsa_kit_domain_forget("kit test sched plan");
            var _d = gmsa_kit_domain("kit test sched plan", {
                steps : { work : { step : function(_o) { _o.done = 1; array_push(_o.log, "work"); return true; } } },
                tasks : { job : [{ name : "m", subtasks : "work" }] },
            });
            var _p = gmsa_kit_profile("kit test sched plan", {
                inputs  : { done : gmsa_kit_input_var("done") },
                actions : { go : { plan : "job", consider : { done : gmsa_kit_curve_below() } } },
            });
            var _s = gmsa_scheduler_create(2000, { clock : function() { return 0; } });
            var _owner = { done : 0, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner, { scheduler : _s, domain : _d });
            repeat (4) {
                gmsa_scheduler_step(_s);
                gmsa_kit_agent_update(_a);
            }
            gmsa_test_assert_equal(_owner.log, ["work"]);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "");
            gmsa_kit_agent_destroy(_a);
            gmsa_test_assert_equal(gmsa_scheduler_count(_s), 0, "out of the scheduler");
        });

        gmsa_test_case("planning mistakes are named at once", function() {
            gmsa_test_assert_throws(function() { gmsa_kit_domain("kit test bad d1", { step : {} }); }, "unknown domain field");
            gmsa_test_assert_throws(function() { gmsa_kit_domain("kit test bad d2", { facts : {} }); }, "no steps");
            gmsa_test_assert_throws(function() { gmsa_kit_domain("kit test bad d3", { steps : { a : {} }, tasks : { t : [{ subtasks : ["a"] }] } }); }, "a method without a name");
            gmsa_test_assert_throws(function() { gmsa_kit_domain("kit test bad d4", { steps : { a : { step : 5 } } }); }, "a step's step not a function");
            gmsa_test_assert_throws(function() { gmsa_kit_domain("kit test bad d5", { facts : { f : function(_o) { return 1; } }, steps : { a : { requires : { f : [">="] } } } }); }, "an operator without its value");
            gmsa_test_assert_throws(function() { gmsa_kit_domain("kit test bad d6", { steps : { a : { requires : { nope : true } } } }); }, "an unknown fact");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad p1", { actions : { a : { plan : "t", step : function() { return true; } } } }); }, "both step and plan");

            gmsa_kit_profile_forget("kit test plan mistakes");
            gmsa_kit_profile_forget("kit test plan mistakes plain");
            gmsa_kit_domain_forget("kit test plan mistakes");
            gmsa_kit_domain_forget("kit test plan other");
            var _ctx = {
                p     : gmsa_kit_profile("kit test plan mistakes", { actions : { go : { plan : "t" } } }),
                plain : gmsa_kit_profile("kit test plan mistakes plain", { actions : { a : {} } }),
                d     : gmsa_kit_domain("kit test plan mistakes", { steps : { a : {} }, tasks : { t : [{ name : "m", subtasks : "a" }] } }),
                other : gmsa_kit_domain("kit test plan other", { steps : { a : {} } }),
            };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}); }), "a plan action without a domain");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}, { domain : other }); }), "a plan the domain doesn't have");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(plain, {}, { planner : { budget : 10 } }); }), "planner settings without a domain");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(plain, {}, { thinks : false, domain : d }); }), "a domain for an agent that doesn't think");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}, { domain : gmsa_plan_domain_create("kit test unbuilt") }); }), "a domain not built");
        });
    });
}