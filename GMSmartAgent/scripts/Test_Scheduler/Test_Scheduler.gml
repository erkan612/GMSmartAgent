function __gmsa_tests_idle_profile() {
    var _p = gmsa_profile_create("idle");
    gmsa_profile_add_action(_p, "idle");
    return gmsa_profile_build(_p);
}

function __gmsa_tests_counted_agent(_profile, _name, _log, _params = {}) {
    var _owner = { name : _name, count : 0, log : _log };
    _params.on_decide = function(_agent) {
        _agent.owner.count++;
        array_push(_agent.owner.log, _agent.owner.name);
    };
    return gmsa_agent_create(_profile, _owner, _params);
}

function gmsa_tests_scheduler() {
    gmsa_test_suite("Scheduler", function() {

        gmsa_test_case("add assigns rng and rejects doubles", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _ag = gmsa_agent_create(__gmsa_tests_idle_profile());
            gmsa_scheduler_add(_s, _ag);
            gmsa_test_assert_equal(_ag.rng, _s.rng, "rng assigned");
            gmsa_test_assert_equal(gmsa_scheduler_count(_s), 1, "count");
            var _ctx = { s : _s, ag : _ag, second : gmsa_scheduler_create(1000, { clock : _c.fn }) };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_scheduler_add(s, ag); }), "added twice");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_scheduler_add(second, ag); }), "second scheduler");
        });

        gmsa_test_case("remove", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _log = [];
            var _p = __gmsa_tests_idle_profile();
            var _a = __gmsa_tests_counted_agent(_p, "A", _log);
            var _b = __gmsa_tests_counted_agent(_p, "B", _log);
            gmsa_scheduler_add(_s, _a);
            gmsa_scheduler_add(_s, _b);
            gmsa_test_assert_true(gmsa_scheduler_remove(_s, _a), "removed");
            gmsa_test_assert_false(gmsa_scheduler_remove(_s, _a), "not a member anymore");
            gmsa_test_assert_equal(_a.rng, undefined, "rng released");
            gmsa_test_assert_equal(gmsa_scheduler_count(_s), 1, "count");
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_log, ["B"], "only B thinks");
        });

        gmsa_test_case("tiers highest first", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _log = [];
            var _p = __gmsa_tests_idle_profile();
            gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "B", _log));
            gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "A", _log, { priority : 5 }));
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_log, ["A", "B"]);
        });

        gmsa_test_case("interval respected", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _a = __gmsa_tests_counted_agent(__gmsa_tests_idle_profile(), "A", [], { interval : 1000 });
            gmsa_scheduler_add(_s, _a);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 1, "t=0");
            _c.now += 500;
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 1, "t=500 not due");
            _c.now += 500;
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 2, "t=1000 due");
        });

        gmsa_test_case("budget stops the loop", function() {
            var _c = gmsa_test_clock(0, 100);
            var _s = gmsa_scheduler_create(250, { clock : _c.fn });
            var _p = __gmsa_tests_idle_profile();
            for (var _i = 0; _i < 10; _i++) gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, string(_i), []));
            gmsa_test_assert_equal(gmsa_scheduler_step(_s), 3, "thinks");
            gmsa_test_assert_true(_s.stats.stopped, "stopped");
        });

        gmsa_test_case("round-robin fairness", function() {
            var _c = gmsa_test_clock(0, 100);
            var _s = gmsa_scheduler_create(250, { clock : _c.fn });
            var _p = __gmsa_tests_idle_profile();
            var _agents = [];
            for (var _i = 0; _i < 10; _i++) {
                var _ag = __gmsa_tests_counted_agent(_p, string(_i), []);
                array_push(_agents, _ag);
                gmsa_scheduler_add(_s, _ag);
            }
            for (var _i = 0; _i < 10; _i++) gmsa_scheduler_step(_s);
            for (var _i = 0; _i < 10; _i++) {
                if (!gmsa_test_assert_equal(_agents[_i].owner.count, 3, "agent " + string(_i))) return;
            }
        });

        gmsa_test_case("at least one think with zero budget", function() {
            var _c = gmsa_test_clock(0, 100);
            var _s = gmsa_scheduler_create(0, { clock : _c.fn });
            var _p = __gmsa_tests_idle_profile();
            var _agents = [];
            for (var _i = 0; _i < 3; _i++) {
                var _ag = __gmsa_tests_counted_agent(_p, string(_i), []);
                array_push(_agents, _ag);
                gmsa_scheduler_add(_s, _ag);
            }
            for (var _i = 0; _i < 3; _i++) {
                if (!gmsa_test_assert_equal(gmsa_scheduler_step(_s), 1, "step " + string(_i))) return;
            }
            for (var _i = 0; _i < 3; _i++) gmsa_test_assert_equal(_agents[_i].owner.count, 1, "agent " + string(_i));
        });

        gmsa_test_case("low tier starves under tight budget", function() {
            var _c = gmsa_test_clock(0, 100);
            var _s = gmsa_scheduler_create(0, { clock : _c.fn });
            var _p = __gmsa_tests_idle_profile();
            var _a = __gmsa_tests_counted_agent(_p, "A", [], { priority : 5 });
            var _b = __gmsa_tests_counted_agent(_p, "B", []);
            gmsa_scheduler_add(_s, _a);
            gmsa_scheduler_add(_s, _b);
            for (var _i = 0; _i < 5; _i++) gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 5, "high tier");
            gmsa_test_assert_equal(_b.owner.count, 0, "low tier starved");
        });

        gmsa_test_case("callbacks fire after the loop", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _p = __gmsa_tests_idle_profile();
            var _seen = [];
            var _cb = function(_agent) {
                array_push(_agent.owner.seen, _agent.owner.s.stats.thinks);
                if (_agent.owner.remove_self) gmsa_scheduler_remove(_agent.owner.s, _agent);
            };
            var _a = gmsa_agent_create(_p, { s : _s, seen : _seen, remove_self : true },  { on_decide : _cb });
            var _b = gmsa_agent_create(_p, { s : _s, seen : _seen, remove_self : false }, { on_decide : _cb });
            gmsa_scheduler_add(_s, _a);
            gmsa_scheduler_add(_s, _b);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_seen, [2, 2], "both callbacks saw the finished step");
            gmsa_test_assert_equal(gmsa_scheduler_count(_s), 1, "A removed itself");
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_seen, [2, 2, 1], "only B next step");
        });

        gmsa_test_case("decision time uses the clock", function() {
            var _c = gmsa_test_clock(5000);
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _ag = gmsa_agent_create(__gmsa_tests_idle_profile());
            gmsa_scheduler_add(_s, _ag);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_ag.decision.time, 5000, "time");
            gmsa_test_assert_equal(gmsa_agent_consume(_ag), _ag.decision, "consumable");
        });

        gmsa_test_case("seeded schedulers repeat", function() {
            var _c = gmsa_test_clock();
            var _p = __gmsa_tests_simple_profile(["a", "b"], { select : gmsa_select.TOP_N_WEIGHTED, top_n : 2 });
            var _s1 = gmsa_scheduler_create(1000, { clock : _c.fn, seed : 9 });
            var _s2 = gmsa_scheduler_create(1000, { clock : _c.fn, seed : 9 });
            var _x = gmsa_agent_create(_p);
            var _y = gmsa_agent_create(_p);
            gmsa_agent_set_input(_x, "a", 0.5); gmsa_agent_set_input(_x, "b", 0.5);
            gmsa_agent_set_input(_y, "a", 0.5); gmsa_agent_set_input(_y, "b", 0.5);
            gmsa_scheduler_add(_s1, _x);
            gmsa_scheduler_add(_s2, _y);
            for (var _i = 0; _i < 20; _i++) {
                gmsa_scheduler_step(_s1);
                gmsa_scheduler_step(_s2);
                var _nx = gmsa_decision_get_chosen(_x.decision).action.name;
                var _ny = gmsa_decision_get_chosen(_y.decision).action.name;
                if (!gmsa_test_assert_equal(_nx, _ny, "step " + string(_i))) return;
            }
        });

        gmsa_test_case("set seed and clock", function() {
            var _s = gmsa_scheduler_create();
            gmsa_scheduler_set_seed(_s, 9);
            gmsa_test_assert_equal(_s.rng.state, gmsa_rng_create(9).state, "seed");
            var _c = gmsa_test_clock(42);
            gmsa_scheduler_set_clock(_s, _c.fn);
            var _ag = gmsa_agent_create(__gmsa_tests_idle_profile());
            gmsa_scheduler_add(_s, _ag);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_ag.decision.time, 42, "clock used");
            gmsa_test_assert_true(_c.calls > 0, "clock read");
        });
		
		gmsa_test_case("set priority moves tiers", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _log = [];
            var _p = __gmsa_tests_idle_profile();
            var _a = __gmsa_tests_counted_agent(_p, "A", _log);
            var _b = __gmsa_tests_counted_agent(_p, "B", _log);
            gmsa_scheduler_add(_s, _a);
            gmsa_scheduler_add(_s, _b);
            gmsa_test_assert_true(gmsa_scheduler_set_priority(_s, _b, 5), "moved");
            gmsa_test_assert_equal(_b.priority, 5, "field updated");
            gmsa_test_assert_equal(gmsa_scheduler_count(_s), 2, "count unchanged");
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_log, ["B", "A"], "B thinks first");
            var _other = gmsa_scheduler_create(1000, { clock : _c.fn });
            gmsa_test_assert_false(gmsa_scheduler_set_priority(_other, _a, 1), "not a member");
        });
    });
}