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