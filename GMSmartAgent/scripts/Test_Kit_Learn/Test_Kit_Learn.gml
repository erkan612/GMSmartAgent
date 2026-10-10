function test_kit_learn() {
    gmsa_test_suite("Kit learn", function() {
        gmsa_test_case("observe_pick offers everything the player could choose, and records the pick", function() {
            gmsa_kit_profile_forget("kit test player");
            var _coins = [{ x : 50, y : 0 }, { x : 200, y : 0 }];
            var _p = gmsa_kit_profile("kit test player", {
                inputs  : { distance : gmsa_kit_input_distance(300) },
                learn   : ["distance"],
                actions : {
                    take : { targets : gmsa_kit_targets_all(_coins), consider : { distance : gmsa_kit_curve_near() } },
                    wait : {},
                },
            });
            var _player = gmsa_kit_agent_create(_p, { x : 0, y : 0 }, { thinks : false });
            var _m = __test_kit_recorder();
            gmsa_test_assert_true(gmsa_kit_observe_pick(_m, _player, _coins[1]), "recorded");
            gmsa_test_assert_equal(_m.data.last.action, "take");
            gmsa_test_assert_equal(_m.data.last.offered, 3, "both coins and waiting were on offer");
            gmsa_test_assert_true(_m.data.last.target == _coins[1], "the far coin, though the agent would take the near one");
            gmsa_kit_observe_pick(_m, _player, undefined);
            gmsa_test_assert_equal(_m.data.last.action, "wait", "an action without targets");
            gmsa_test_assert_equal(_m.data.count, 2);
            gmsa_kit_agent_update(_player);
            gmsa_test_assert_equal(gmsa_kit_agent_doing(_player), "", "the player's agent never thinks or acts");
        });

        gmsa_test_case("observe_pick asks for the action when a target has several", function() {
            gmsa_kit_profile_forget("kit test player two");
            var _coins = [{ x : 50, y : 0 }];
            var _p = gmsa_kit_profile("kit test player two", {
                inputs  : { distance : gmsa_kit_input_distance(300) },
                learn   : ["distance"],
                actions : { take : { targets : gmsa_kit_targets_all(_coins) }, kick : { targets : gmsa_kit_targets_all(_coins) } },
            });
            var _ctx = { player : gmsa_kit_agent_create(_p, { x : 0, y : 0 }, { thinks : false }), m : __test_kit_recorder(), coin : _coins[0] };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_observe_pick(m, player, coin); }), "take or kick");
            gmsa_kit_observe_pick(_ctx.m, _ctx.player, _ctx.coin, "kick");
            gmsa_test_assert_equal(_ctx.m.data.last.action, "kick");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_observe_pick(m, player, { x : 9, y : 9 }); }), "a target not on offer");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_observe_pick(m, player, coin, "dance"); }), "an action not on offer");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_observe_pick(__test_kit_recorder(gmsa_learn_target.OUTCOMES), player, coin, "take"); }), "a model that learns outcomes");
        });

        gmsa_test_case("a model that learns outcomes: a ticket per action, outcome and reward", function() {
            gmsa_kit_profile_forget("kit test outcomes");
            var _p = gmsa_kit_profile("kit test outcomes", {
                inputs  : { hp : gmsa_kit_input_var("hp", 0, 100) },
                learn   : ["hp"],
                actions : { fight : {}, flee : { weight : 0.5 } },
            });
            var _m = __test_kit_recorder(gmsa_learn_target.OUTCOMES);
            var _a = gmsa_kit_agent_create(_p, { hp : 50 }, { model : _m });
            gmsa_test_assert_true(_a.model == _m && _a.influence == 1, "attached, influence 1");
            gmsa_kit_agent_update(_a);
            gmsa_kit_outcome(_a, 1);
            gmsa_test_assert_equal(_m.data.last.action, "fight");
            gmsa_test_assert_equal(_m.data.last.reward, 1);
            gmsa_kit_agent_done(_a);
            gmsa_kit_outcome(_a, 0.5);
            gmsa_test_assert_equal(_m.data.last.reward, 0.5, "while idle, the last action");
            gmsa_test_assert_true(gmsa_kit_reward(_a, 2) >= 1, "recent decisions credited");
            gmsa_test_assert_equal(_m.data.last.reward, 2);
        });

        gmsa_test_case("a model set on the profile counts too", function() {
            gmsa_kit_profile_forget("kit test profile model");
            var _m = __test_kit_recorder(gmsa_learn_target.OUTCOMES);
            var _p = gmsa_kit_profile("kit test profile model", {
                inputs  : { hp : gmsa_kit_input_var("hp", 0, 100) },
                learn   : ["hp"],
                prepare : method({ m : _m }, function(_profile) { gmsa_profile_set_model(_profile, m, 0.5); }),
                actions : { fight : {} },
            });
            var _a = gmsa_kit_agent_create(_p, { hp : 50 });
            gmsa_kit_agent_update(_a);
            gmsa_kit_outcome(_a, 1);
            gmsa_test_assert_equal(_m.data.count, 1);
        });

        gmsa_test_case("learning mistakes are named at once", function() {
            gmsa_kit_profile_forget("kit test learn mistakes");
            gmsa_kit_profile_forget("kit test learn plain");
            var _ctx = {
                p     : gmsa_kit_profile("kit test learn mistakes", { inputs : { hp : gmsa_kit_input_var("hp", 0, 100) }, learn : ["hp"], actions : { a : {} } }),
                plain : gmsa_kit_profile("kit test learn plain", { actions : { a : {} } }),
                out   : __test_kit_recorder(gmsa_learn_target.OUTCOMES),
                pick  : __test_kit_recorder(),
            };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, { hp : 1 }, { thinks : false, scheduler : gmsa_scheduler_create() }); }), "a scheduler for an agent that doesn't think");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, { hp : 1 }, { thinks : false, model : out }); }), "a model for an agent that doesn't think");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, { hp : 1 }, { thinks : "no" }); }), "thinks not true or false");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, { hp : 1 }, { influence : 0.5 }); }), "influence without a model");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(p, { hp : 1 }, { model : out, influence : 2 }); }), "influence above 1");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_agent_create(plain, {}, { model : out }); }), "a model, but nothing to learn from");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_outcome(gmsa_kit_agent_create(p, { hp : 1 }), 1); }), "an outcome without a model");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_outcome(gmsa_kit_agent_create(p, { hp : 1 }, { model : pick }), 1); }), "an outcome to a model that learns choices");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_outcome(gmsa_kit_agent_create(p, { hp : 1 }, { model : out }), 1); }), "an outcome before any action");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_kit_reward(gmsa_kit_agent_create(p, { hp : 1 }, { model : pick }), 1); }), "a reward to a model that learns choices");
        });
    });
}

function __test_kit_recorder(_learns = gmsa_learn_target.CHOICES) { // a model that only remembers the last sample it was given
    return gmsa_learn_custom({
        reset_data : function() { data = { count : 0, last : undefined }; },
        observe    : function(_s) {
            var _o = _s.from.options[_s.chosen];
            data.count++;
            data.last = { action : actions[_s.options[_s.chosen].action], offered : array_length(_s.options), target : _o[$ "target"], reward : _s.reward };
        },
        predict    : function(_s, _out) {},
    }, { learns : _learns });
}