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

function __gmsa_tests_total(_agents) {
    var _sum = 0;
    for (var _i = 0; _i < array_length(_agents); _i++) _sum += _agents[_i].owner.count;
    return _sum;
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
		
        gmsa_test_case("an agent's interval can change", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _a = __gmsa_tests_counted_agent(__gmsa_tests_idle_profile(), "A", [], { interval : 1000 });
            gmsa_scheduler_add(_s, _a);
            gmsa_scheduler_step(_s);
            _c.now += 200;
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 1, "not due at 200");
            gmsa_agent_set_interval(_a, 100);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 2, "a shorter interval: due at once");
            gmsa_agent_set_interval(_a, infinity);
            _c.now += 1000000;
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 2, "infinity: not again");
            gmsa_test_assert_throws(method({ a : _a }, function() { gmsa_agent_set_interval(a, -1); }), "negative");
            gmsa_test_assert_throws(method({ a : _a }, function() { gmsa_agent_set_interval(a, "1"); }), "not a number");
            gmsa_test_assert_throws(function() { gmsa_agent_create(__gmsa_tests_idle_profile(), {}, { interval : -5 }); }, "checked at create too");
        });
		
        gmsa_test_case("a woken agent thinks at the next step, once", function() {
            var _c = gmsa_test_clock();
            var _s = gmsa_scheduler_create(1000, { clock : _c.fn });
            var _a = __gmsa_tests_counted_agent(__gmsa_tests_idle_profile(), "A", [], { interval : 1000000 });
            gmsa_scheduler_add(_s, _a);
            gmsa_scheduler_step(_s);
            _c.now += 100;
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 1, "not due on its own");
            gmsa_agent_wake(_a);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 2, "woken: thought at the next step");
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 2, "the think used the wake up");
        });
		
        gmsa_test_case("a busy agent doesn't think until it's free", function() {
            var _s = gmsa_scheduler_create(1000000);
            var _a = __gmsa_tests_counted_agent(__gmsa_tests_idle_profile(), "A", []);
            gmsa_scheduler_add(_s, _a);
            gmsa_agent_set_busy(_a, true);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 0, "busy: not due");
            gmsa_agent_wake(_a);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 0, "a wake waits");
            gmsa_agent_set_busy(_a, false);
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_a.owner.count, 1, "free: thinks at the next step");
            gmsa_agent_set_busy(_a, true);
            gmsa_test_assert_true(gmsa_agent_think(_a, 0).fresh, "a direct think still runs");
        });

        gmsa_test_case("woken agents still respect the budget", function() {
            var _c = gmsa_test_clock(0, 100);
            var _s = gmsa_scheduler_create(0, { clock : _c.fn });   // a budget of 0: one think per step
            var _p = __gmsa_tests_idle_profile();
            var _agents = [];
            repeat (10) {
                var _a = __gmsa_tests_counted_agent(_p, "x", [], { interval : 1000000000 });
                gmsa_agent_think(_a, 0);                            // thought once, so not due on its own
                gmsa_scheduler_add(_s, _a);
                array_push(_agents, _a);
            }
            for (var _i = 0; _i < 10; _i++) gmsa_agent_wake(_agents[_i]);
            repeat (5) gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(__gmsa_tests_total(_agents), 5, "one per step");
            repeat (6) gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(__gmsa_tests_total(_agents), 10, "each woken agent once, none twice");
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
		
        gmsa_test_case("each tier leaves a share for the tiers below", function() {
            var _c = gmsa_test_clock(0, 100); // each read of the clock costs 100
            var _s = gmsa_scheduler_create(2000, { clock : _c.fn }); // share 0.2 by default
            var _p = __gmsa_tests_idle_profile();
            var _high = [], _low = [];
            repeat (30) array_push(_high, gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "H", [], { priority : 1 })));
            repeat (10) array_push(_low, gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "L", [])));
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(__gmsa_tests_total(_high), 16, "the high tier stops at its 80%");
            gmsa_test_assert_equal(__gmsa_tests_total(_low), 3, "the low tier thinks too");

            gmsa_scheduler_set_share(_s, 0);
            _c.now += 16667;
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(__gmsa_tests_total(_high), 16 + 20, "share 0: strict priority, the high tier takes it all");
            gmsa_test_assert_equal(__gmsa_tests_total(_low), 3, "and the low tier waits");

            gmsa_test_assert_throws(method({ s : _s }, function() { gmsa_scheduler_set_share(s, 1); }), "share 1");
            gmsa_test_assert_throws(function() { gmsa_scheduler_create(2000, { share : -0.5 }); }, "negative share");
        });

        gmsa_test_case("what the lower tiers leave goes back up", function() {
            var _c = gmsa_test_clock(0, 100);
            var _s = gmsa_scheduler_create(2000, { clock : _c.fn });
            var _p = __gmsa_tests_idle_profile();
            var _high = [];
            repeat (30) array_push(_high, gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "H", [], { priority : 1 })));
            var _low = gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "L", [], { interval : 1000000000 }));
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_low.owner.count, 1, "the low agent thinks once");
            gmsa_test_assert_equal(__gmsa_tests_total(_high), 18, "the high tier gets the rest back");
            _c.now += 16667;
            gmsa_scheduler_step(_s);
            gmsa_test_assert_equal(_low.owner.count, 1, "nothing due below");
            gmsa_test_assert_equal(__gmsa_tests_total(_high), 18 + 19, "so the high tier uses the whole budget");
        });

        gmsa_test_case("a tier that gets time back never thinks anyone twice", function() {
            var _c = gmsa_test_clock(0, 100);
            var _s = gmsa_scheduler_create(2000, { clock : _c.fn });
            var _p = __gmsa_tests_idle_profile();
            var _high = [];
            repeat (17) array_push(_high, gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "H", [], { priority : 1 })));
            gmsa_scheduler_add(_s, __gmsa_tests_counted_agent(_p, "L", [], { interval : 1000000000 }));
            gmsa_scheduler_step(_s);
            for (var _i = 0; _i < 17; _i++) {
                if (!gmsa_test_assert_equal(_high[_i].owner.count, 1, "high agent " + string(_i))) return;
            }
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