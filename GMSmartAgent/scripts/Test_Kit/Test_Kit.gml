function test_kit() {
    gmsa_test_suite("Kit", function() {
        gmsa_test_case("a profile from one struct, and the same one when asked again", function() {
            gmsa_kit_profile_forget("kit test goblin");
            var _p = gmsa_kit_profile("kit test goblin", {
                inputs  : { hp : gmsa_kit_input_var("hp", 0, 100) },
                actions : {
                    drink : { consider : { hp : gmsa_kit_curve_low(0.4) } },
                    loot  : { weight : 0.5 },
                },
            });
            gmsa_test_assert_true(_p == gmsa_kit_profile("kit test goblin"), "asked again");
            gmsa_test_assert_near(_p.commitment, 0.15, 0.000001, "Kit's commitment");
            gmsa_test_assert_equal(__test_kit_best(_p, { hp : 20 }), "drink");
            gmsa_test_assert_equal(__test_kit_best(_p, { hp : 90 }), "loot");
        });

        gmsa_test_case("actions are added in name order, the same every run", function() {
            gmsa_kit_profile_forget("kit test order");
            var _p = gmsa_kit_profile("kit test order", { actions : { zeta : {}, alpha : {}, mid : {} } });
            gmsa_test_assert_equal([_p.actions[0].name, _p.actions[1].name, _p.actions[2].name], ["alpha", "mid", "zeta"]);
        });

        gmsa_test_case("mistakes are named at once", function() {
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test never defined"); }, "no definition");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad 1", { action : { a : {} } }); }, "unknown profile field");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad 2", { inputs : {} }); }, "no actions");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad 3", { actions : { a : { consdier : {} } } }); }, "unknown action field");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad 4", { inputs : { hp : gmsa_kit_input_var("hp") }, actions : { a : { consider : [["hp"]] } } }); }, "a pair without its curve");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad 5", { actions : { a : { step : 5 } } }); }, "step not a function");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad 6", { inputs : { hp : gmsa_input_pull("health", function(_a, _t) { return 1; }) }, actions : { a : {} } }); }, "names differ");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad 7", { inputs : { hp : 5 }, actions : { a : {} } }); }, "not an input");
        });

        gmsa_test_case("inputs read the owner and the targets", function() {
            gmsa_kit_profile_forget("kit test inputs");
            var _gold = [{ x : 100, y : 0, gold : 5 }, { x : 400, y : 0, gold : 9 }];
            var _linear = gmsa_curve_make(gmsa_curve.LINEAR);
            var _p = gmsa_kit_profile("kit test inputs", {
                inputs : {
                    hp       : gmsa_kit_input_var("hp", 0, 100),
                    distance : gmsa_kit_input_distance(300),
                    gold     : gmsa_kit_input_target_var("gold", 0, 10),
                    crowd    : gmsa_kit_input_count(_gold, 150, 4),
                },
                actions : {
                    pick : { targets : gmsa_kit_targets_all(_gold), consider : { distance : _linear, gold : _linear } },
                    rest : { consider : { crowd : _linear, hp : _linear } },
                },
            });
            var _d = gmsa_agent_evaluate(gmsa_agent_create(_p, { x : 0, y : 0, hp : 30 }));
            var _near = __test_kit_option(_d, "pick", _gold[0]);
            var _far = __test_kit_option(_d, "pick", _gold[1]);
            var _rest = __test_kit_option(_d, "rest", undefined);
            gmsa_test_assert_near(_near.features[0], 100 / 300, 0.0001, "distance");
            gmsa_test_assert_near(_near.features[1], 0.5, 0.0001, "the target's gold");
            gmsa_test_assert_near(_far.features[0], 1, 0.0001, "past the max reads 1");
            gmsa_test_assert_near(_far.features[1], 0.9, 0.0001);
            gmsa_test_assert_near(_rest.features[0], 0.25, 0.0001, "one of four within 150");
            gmsa_test_assert_near(_rest.features[1], 0.3, 0.0001, "the owner's hp");
        });

        gmsa_test_case("targets: near, nearest, all, your own, and never the owner", function() {
            var _me = { x : 0, y : 0 };
            var _things = [_me, { x : 50, y : 0, n : 1 }, { x : 120, y : 0, n : 2 }, { x : 300, y : 0, n : 3 }];
            var _agent = { owner : _me };
            var _near = gmsa_kit_targets_near(_things, 150);
            var _r = _near(_agent);
            gmsa_test_assert_equal(array_length(_r), 2, "near");
            var _nearest = gmsa_kit_targets_nearest(_things, 1);
            _r = _nearest(_agent);
            gmsa_test_assert_true(array_length(_r) == 1 && _r[0].n == 1, "nearest");
            var _all = gmsa_kit_targets_all(_things);
            _r = _all(_agent);
            gmsa_test_assert_equal(array_length(_r), 3, "all but the owner");
            var _from = gmsa_kit_targets_from(function(_owner) { return [_owner]; });
            _r = _from(_agent);
            gmsa_test_assert_true(_r[0] == _me, "your own list, from the owner");
        });

        gmsa_test_case("curves keep their promises", function() {
            var _soft = gmsa_kit_curve_soft(gmsa_kit_curve_at_least());
            var _cases = [
                [gmsa_kit_curve_near(), 0, 1], [gmsa_kit_curve_near(), 1, 0], [gmsa_kit_curve_near(0.5), 0.25, 0.5], [gmsa_kit_curve_near(0.5), 0.6, 0],
                [gmsa_kit_curve_far(), 0.25, 0.25],
                [gmsa_kit_curve_near_only(), 0, 0.9526], [gmsa_kit_curve_near_only(), 0.25, 0.1192],
                [gmsa_kit_curve_more(2), 0.5, 0.25], [gmsa_kit_curve_less(2), 0.5, 0.75],
                [gmsa_kit_curve_low(), 0.4, 0.5], [gmsa_kit_curve_low(), 0.2, 0.8808],
                [gmsa_kit_curve_high(), 0.6, 0.5], [gmsa_kit_curve_high(), 0.8, 0.8808],
                [gmsa_kit_curve_at_least(), 0.49, 0], [gmsa_kit_curve_at_least(), 0.5, 1],
                [gmsa_kit_curve_below(), 0.49, 1], [gmsa_kit_curve_below(), 0.5, 0],
                [gmsa_kit_curve_peak(), 0.5, 1], [gmsa_kit_curve_peak(), 0.7, 0.3679],
                [gmsa_kit_curve_band(), 0.5, 1], [gmsa_kit_curve_band(), 0.2, 0],
                [gmsa_kit_curve_band(0.3, 0.7, 0.2), 0.2, 0.5], [gmsa_kit_curve_band(0.3, 0.7, 0.2), 0.05, 0],
                [gmsa_kit_curve_valley(), 0.5, 0], [gmsa_kit_curve_valley(), 0.25, 0.25], [gmsa_kit_curve_valley(), 0, 1],
                [gmsa_kit_curve_ease(), 0.25, 0.15625],
                [_soft, 0, 0.2], [_soft, 1, 1],
            ];
            for (var _i = 0; _i < array_length(_cases); _i++) {
                var _c = _cases[_i];
                gmsa_test_assert_near(gmsa_curve_eval(_c[0], _c[1]), _c[2], 0.001, "case " + string(_i));
            }
            gmsa_test_assert_throws(function() { gmsa_kit_curve_near(0); }, "reach 0");
            gmsa_test_assert_throws(function() { gmsa_kit_curve_more(-1); }, "a negative shape");
            gmsa_test_assert_throws(function() { gmsa_kit_curve_band(0.7, 0.3); }, "from above to");
            gmsa_test_assert_throws(function() { gmsa_kit_curve_soft(undefined); }, "nothing to soften");
            gmsa_test_assert_throws(function() { gmsa_kit_curve_soft(gmsa_kit_curve_near(), 2); }, "a floor above 1");
            gmsa_test_assert_throws(function() { gmsa_kit_curve_low("a"); }, "a threshold that isn't a number");
        });

        gmsa_test_case("plain inputs, functions, learn and prepare all fit in", function() {
            gmsa_kit_profile_forget("kit test hooks");
            var _seen = { prepared : false };
            var _linear = gmsa_curve_make(gmsa_curve.LINEAR);
            var _p = gmsa_kit_profile("kit test hooks", {
                inputs : {
                    hp   : gmsa_input_pull("hp", function(_agent, _target) { return 25; }, 0, 100),
                    mood : function(_agent, _target) { return 0.7; },
                },
                learn   : ["hp"],
                prepare : method(_seen, function(_profile) { prepared = true; }),
                actions : { sulk : { consider : { hp : _linear, mood : _linear } } },
            });
            gmsa_test_assert_true(_seen.prepared, "prepare ran");
            gmsa_test_assert_true(is_array(_p.features), "learn set the features");
            var _d = gmsa_agent_evaluate(gmsa_agent_create(_p, {}));
            var _o = __test_kit_option(_d, "sulk", undefined);
            gmsa_test_assert_near(_o.features[0], 0.25, 0.0001, "a plain input");
            gmsa_test_assert_near(_o.features[1], 0.7, 0.0001, "a function");
        });

        gmsa_test_case("the code for each action is kept with it", function() {
            gmsa_kit_profile_forget("kit test handlers");
            var _p = gmsa_kit_profile("kit test handlers", {
                actions : {
                    drink : {},
                    loot  : { step : function(_owner, _target) { return true; } },
                    raid  : { plan : "raid_chest" },
                    wait  : { step : __test_kit_step },
                },
            });
            gmsa_test_assert_true(is_callable(_p.kit.handlers.loot.step), "loot's step");
            gmsa_test_assert_true(_p.kit.handlers.drink.step == undefined, "drink has none");
            gmsa_test_assert_equal(_p.kit.handlers.raid.plan, "raid_chest");
            gmsa_test_assert_true(_p.kit.handlers.wait.step == __test_kit_step, "a script function by name");
        });
		

        gmsa_test_case("an agent thinks at once, then every think_every updates", function() {
            gmsa_kit_profile_forget("kit test pace");
            var _p = gmsa_kit_profile("kit test pace", {
                actions : { idle : { targets : gmsa_kit_targets_from(function(_owner) { _owner.thinks++; return [_owner]; }) } },
            });
            var _owner = { thinks : 0 };
            var _a = gmsa_kit_agent_create(_p, _owner, { think_every : 3 });
            repeat (7) gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.thinks, 3, "updates 1, 4 and 7");
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "idle");
            gmsa_test_assert_true(gmsa_kit_agent_target(_a) == _owner, "its target");
        });

        gmsa_test_case("start, step and stop run in order, and done decides again at once", function() {
            gmsa_kit_profile_forget("kit test cycle");
            var _p = gmsa_kit_profile("kit test cycle", {
                actions : {
                    work : {
                        start : function(_o) { array_push(_o.log, "start"); },
                        step  : function(_o) { _o.steps++; array_push(_o.log, "step"); return _o.steps % 2 == 0; },
                        stop  : function(_o) { array_push(_o.log, "stop"); },
                    },
                },
            });
            var _owner = { log : [], steps : 0 };
            var _a = gmsa_kit_agent_create(_p, _owner);
            gmsa_kit_agent_update(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["start", "step", "step", "stop", "start"]);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "work");
        });

        gmsa_test_case("a better action takes over: the old one stops, the new one starts", function() {
            gmsa_kit_profile_forget("kit test switch");
            var _p = gmsa_kit_profile("kit test switch", {
                inputs  : { want : gmsa_kit_input_var("want") },
                actions : {
                    a : { consider : { want : gmsa_kit_curve_below() }, start : function(_o) { array_push(_o.log, "a start"); }, stop : function(_o) { array_push(_o.log, "a stop"); } },
                    b : { consider : { want : gmsa_kit_curve_at_least() }, start : function(_o) { array_push(_o.log, "b start"); }, stop : function(_o) { array_push(_o.log, "b stop"); } },
                },
            });
            var _owner = { want : 0, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner);
            gmsa_kit_agent_update(_a);
            _owner.want = 1;
            gmsa_kit_agent_decide(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["a start", "a stop", "b start"]);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "b");
            gmsa_test_assert_equal(_a.current.action, gmsa_profile_action_index(_p, "b"), "the agent's current option, for commitment");
        });

        gmsa_test_case("the same action on the same target changes nothing", function() {
            gmsa_kit_profile_forget("kit test same");
            var _p = gmsa_kit_profile("kit test same", {
                actions : { stay : { targets : gmsa_kit_targets_from(function(_owner) { return [_owner.spot]; }), start : function(_o) { array_push(_o.log, "start"); } } },
            });
            var _owner = { spot : {}, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner);
            repeat (3) {
                gmsa_kit_agent_decide(_a);
                gmsa_kit_agent_update(_a);
            }
            gmsa_test_assert_equal(_owner.log, ["start"]);
        });

        gmsa_test_case("nothing worth doing: the current action stops and the agent idles", function() {
            gmsa_kit_profile_forget("kit test nothing");
            var _p = gmsa_kit_profile("kit test nothing", {
                inputs  : { want : gmsa_kit_input_var("want") },
                actions : { a : { consider : { want : gmsa_kit_curve_at_least() }, stop : function(_o) { array_push(_o.log, "stop"); } } },
            });
            var _owner = { want : 1, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "a");
            _owner.want = 0;
            gmsa_kit_agent_decide(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "", "idle");
            gmsa_test_assert_equal(_owner.log, ["stop"]);
            gmsa_test_assert_true(_a.current == undefined, "the agent's current option cleared");
        });

        gmsa_test_case("step results: false, RUNNING and nothing keep going, true, DONE and FAILED end it", function() {
            gmsa_kit_profile_forget("kit test results");
            var _p = gmsa_kit_profile("kit test results", {
                actions : { work : { step : function(_o) { return _o.result; }, stop : function(_o) { array_push(_o.log, "stop"); } } },
            });
            var _owner = { result : false, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner);
            var _keep = [false, gmsa_kit_step.RUNNING, undefined];
            for (var _i = 0; _i < 3; _i++) {
                _owner.result = _keep[_i];
                gmsa_kit_agent_update(_a);
            }
            gmsa_test_assert_equal(_owner.log, [], "still working");
            var _end = [true, gmsa_kit_step.DONE, gmsa_kit_step.FAILED];
            for (var _i = 0; _i < 3; _i++) {
                _owner.result = _end[_i];
                gmsa_kit_agent_update(_a);
            }
            gmsa_test_assert_equal(_owner.log, ["stop", "stop", "stop"], "each ended it, and it chose work again at once");
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "work");
            _owner.result = "yes";
            gmsa_test_assert_throws(method({ a : _a }, function() { gmsa_kit_agent_update(a); }), "a step result that means nothing");
        });

        gmsa_test_case("done, decide and stop from outside", function() {
            gmsa_kit_profile_forget("kit test outside");
            var _p = gmsa_kit_profile("kit test outside", {
                actions : { work : { start : function(_o) { array_push(_o.log, "start"); }, stop : function(_o) { array_push(_o.log, "stop"); } } },
            });
            var _owner = { log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner);
            gmsa_kit_agent_update(_a);
            gmsa_kit_agent_done(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "", "done ends it");
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "work", "and it decides again at the next update");
            gmsa_kit_agent_stop(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "", "stop idles until the next think");
            gmsa_kit_agent_decide(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "work", "decide brings that think now");
            gmsa_test_assert_equal(_owner.log, ["start", "stop", "start", "stop", "start"]);
        });

        gmsa_test_case("a target instance that's gone fails the action", function() {
            gmsa_kit_profile_forget("kit test gone");
            var _p = gmsa_kit_profile("kit test gone", {
                actions : { grab : { targets : gmsa_kit_targets_from(function(_owner) { return _owner.items; }), stop : function(_o) { array_push(_o.log, "stop"); } } },
            });
            var _item = instance_create_depth(0, 0, 0, o_demo1_item);
            var _owner = { items : [_item], log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_true(gmsa_kit_agent_target(_a) == _item, "grabbing the item");
            instance_destroy(_item);
            _owner.items = [];
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["stop"], "it stopped");
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "", "and found nothing else to do");
        });

        gmsa_test_case("a scheduler thinks for it, and destroy takes it out", function() {
            gmsa_kit_profile_forget("kit test scheduler");
            var _p = gmsa_kit_profile("kit test scheduler", { actions : { work : {} } });
            var _s = gmsa_scheduler_create(2000, { clock : function() { return 0; } });
            var _a = gmsa_kit_agent_create(_p, {}, { scheduler : _s });
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "", "waits for the scheduler");
            gmsa_scheduler_step(_s);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "work");
            gmsa_kit_agent_destroy(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "");
            gmsa_test_assert_equal(gmsa_scheduler_count(_s), 0, "out of the scheduler");
        });

        gmsa_test_case("a plain profile runs too, its actions without code", function() {
            var _plain = gmsa_profile_create("kit test plain");
            gmsa_profile_add_action(_plain, "rest");
            _plain = gmsa_profile_build(_plain);
            var _a = gmsa_kit_agent_create(_plain, {});
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "rest");
        });

        gmsa_test_case("agent mistakes are named at once", function() {
            gmsa_kit_profile_forget("kit test agent mistakes");
            var _p = gmsa_kit_profile("kit test agent mistakes", { actions : { a : {} } });
            var _ctx = { p : _p };
            gmsa_test_assert_throws(function() { gmsa_kit_agent_create(gmsa_profile_create("kit test unbuilt")); }, "a profile not built");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}, { think_evry : 5 }); }), "unknown field");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}, { think_every : 0 }); }), "think_every 0");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}, { interval : 100 }); }), "interval without a scheduler");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}, { scheduler : gmsa_scheduler_create(), think_every : 5 }); }), "think_every with a scheduler");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, {}, { scheduler : 5 }); }), "not a scheduler");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_update(gmsa_agent_create(p, {})); }), "a plain agent");
        });
		
        gmsa_test_case("an action that can't be interrupted finishes first", function() {
            gmsa_kit_profile_forget("kit test swing");
            var _p = gmsa_kit_profile("kit test swing", {
                inputs  : { want : gmsa_kit_input_var("want") },
                actions : {
                    swing : {
                        interruptible : false,
                        consider : { want : gmsa_kit_curve_below() },
                        start    : function(_o) { array_push(_o.log, "swing start"); },
                        step     : function(_o) { return _o.landed; },
                        stop     : function(_o) { array_push(_o.log, "swing stop"); },
                    },
                    block : { consider : { want : gmsa_kit_curve_at_least() }, start : function(_o) { array_push(_o.log, "block start"); } },
                },
            });
            var _owner = { want : 0, landed : false, log : [] };
            var _a = gmsa_kit_agent_create(_p, _owner);
            gmsa_kit_agent_update(_a);
            _owner.want = 1;
            gmsa_kit_agent_decide(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "swing", "block wins, but the swing goes on");
            _owner.landed = true;
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["swing start", "swing stop", "block start"], "then it ends by itself, and block takes over at once");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad swing 1", { actions : { a : { interruptible : false } } }); }, "nothing to end it");
            gmsa_test_assert_throws(function() { gmsa_kit_profile("kit test bad swing 2", { actions : { a : { interruptible : "no", step : function() { return true; } } } }); }, "not true or false");
        });
		
        gmsa_test_case("an action that can't be interrupted doesn't think, so nothing else is spent", function() {
            gmsa_kit_profile_forget("kit test busy nap");
            var _p = gmsa_kit_profile("kit test busy nap", {
                inputs  : { tired : gmsa_kit_input_var("tired") },
                actions : {
                    nap : {
                        interruptible : false,
                        consider : { tired : gmsa_kit_curve_more() },
                        start    : function(_o) { _o.left = 30; },
                        step     : function(_o) { _o.left--; return _o.left <= 0; },
                    },
                    taunt : { weight : 0.5, cooldown : 5000000 },
                },
            });
            var _owner = { tired : 1, left : 0 };
            var _a = gmsa_kit_agent_create(_p, _owner, { think_every : 1 });
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "nap", "napping");
            _owner.tired = 0.1; // the taunt would win now
            var _last = _a.last_think;
            repeat (10) gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "nap", "still napping");
            gmsa_test_assert_equal(_a.last_think, _last, "no thinks while napping");
            gmsa_test_assert_equal(_a.cooldowns[gmsa_profile_action_index(_a.profile, "taunt")], 0, "the taunt was never spent");
        });
		
        gmsa_test_case("think_every can change", function() {
            gmsa_kit_profile_forget("kit test every");
            var _p = gmsa_kit_profile("kit test every", { actions : { idle : {} } });
            var _ag = gmsa_kit_agent_create(_p, {}, { think_every : 10 });
            gmsa_kit_agent_update(_ag);               // the first update thinks, then 9 to wait
            gmsa_kit_agent_set_think_every(_ag, 3);
            gmsa_test_assert_equal(_ag.kit.timer, 3, "a shorter wait takes effect now");
            repeat (4) gmsa_kit_agent_update(_ag);    // 3 waits, then a think that sets 3 and counts one down
            gmsa_test_assert_equal(_ag.kit.timer, 2, "thought again on the new pace");
            var _ctx = { p : _p };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_set_think_every(gmsa_kit_agent_create(p, {}, { scheduler : gmsa_scheduler_create() }), 3); }), "with a scheduler");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_set_think_every(gmsa_kit_agent_create(p, {}, { thinks : false }), 3); }), "doesn't think");
            gmsa_test_assert_throws(method({ a : _ag }, function() { gmsa_kit_agent_set_think_every(a, 0); }), "zero");
            gmsa_test_assert_throws(method({ a : _ag }, function() { gmsa_kit_agent_set_think_every(a, 2.5); }), "not whole");
        });
		
        gmsa_test_case("a Kit agent's profile can change, its action stops first", function() {
            gmsa_kit_profile_forget("kit test near");
            gmsa_kit_profile_forget("kit test far");
            var _near = gmsa_kit_profile("kit test near", {
                actions : { guard : { start : function(_o) { array_push(_o.log, "guard start"); }, stop : function(_o) { array_push(_o.log, "guard stop"); } } },
            });
            var _far = gmsa_kit_profile("kit test far", {
                actions : { wander : { start : function(_o) { array_push(_o.log, "wander start"); } } },
            });
            var _owner = { log : [] };
            var _a = gmsa_kit_agent_create(_near, _owner);
            gmsa_kit_agent_update(_a);
            gmsa_kit_agent_set_profile(_a, _far);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_a), "", "idle after the swap");
            gmsa_kit_agent_decide(_a);
            gmsa_kit_agent_update(_a);
            gmsa_test_assert_equal(_owner.log, ["guard start", "guard stop", "wander start"]);
            gmsa_test_assert_throws(method({ a : _a, p : _near }, function() { gmsa_agent_set_profile(a, p); }), "the core call refuses a Kit agent");
        });
    });
}

function __test_kit_best(_profile, _owner) {
    var _d = gmsa_agent_evaluate(gmsa_agent_create(_profile, _owner));
    var _o = _d.options[0];
    return _o.action.name;
}

function __test_kit_option(_decision, _action, _target) {
    for (var _i = 0; _i < array_length(_decision.options); _i++) {
        var _o = _decision.options[_i];
        if (_o.action.name == _action && _o.target == _target) return _o;
    }
    return undefined;
}

function __test_kit_step(_owner, _target) {
    return true;
}