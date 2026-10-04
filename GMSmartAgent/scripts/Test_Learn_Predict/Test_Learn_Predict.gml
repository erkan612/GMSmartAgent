function __gmsa_tests_habit_model(_player) {
    var _model = gmsa_learn_count_create();
    __gmsa_tests_count_choose(_model, _player, 90, 0, ["drink", "loot"], "loot", 10);
    __gmsa_tests_count_choose(_model, _player, 20, 0, ["drink", "loot"], "drink", 10);
    return _model;
}

function gmsa_tests_learn_predict() {
    gmsa_test_suite("Learn predict", function() {

        gmsa_test_case("reads the habit", function() {
            var _player = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            var _will_drink = gmsa_learn_input(__gmsa_tests_habit_model(_player), _player, "drink", { refresh : 0 });
            gmsa_agent_set_input(_player, "hp", 20);
            gmsa_test_assert_true(_will_drink(undefined, undefined) > 0.4, "hurt: likely to drink");
            gmsa_agent_set_input(_player, "hp", 90);
            gmsa_test_assert_true(_will_drink(undefined, undefined) < 0.2, "healthy: unlikely to drink");
        });

        gmsa_test_case("untrained reads the fallback", function() {
            var _player = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            var _model = gmsa_learn_count_create();
            gmsa_test_assert_near(gmsa_learn_input(_model, _player, "drink")(undefined, undefined), 0, GMSA_TEST_EPS, "default 0");
            gmsa_test_assert_near(gmsa_learn_input(_model, _player, "drink", { fallback : 0.5 })(undefined, undefined), 0.5, GMSA_TEST_EPS, "fallback");
        });

        gmsa_test_case("action not on offer reads 0", function() {
            var _p = gmsa_profile_create("cd");
            gmsa_profile_add_input(_p, gmsa_input_push("x"));
            var _a = gmsa_profile_add_action(_p, "drink", { cooldown : 1000 });
            gmsa_action_add_consideration(_a, "x", gmsa_curve_make(gmsa_curve.LINEAR));
            gmsa_profile_add_action(_p, "loot", { weight : 0.1 });
            gmsa_profile_set_features(_p, ["x"]);
            var _player = gmsa_agent_create(gmsa_profile_build(_p));
            gmsa_agent_set_input(_player, "x", 1);
            var _model = __gmsa_tests_favorite_model();
            repeat (30) gmsa_learn_observe(_model, gmsa_observe(_player, ["drink", "loot"], 0, 0));
            gmsa_agent_think(_player, 0); // drink chosen, on cooldown until 1000
            var _clock = gmsa_test_clock(500);
            var _read = gmsa_learn_input(_model, _player, "drink", { refresh : 0, clock : _clock.fn });
            gmsa_test_assert_near(_read(undefined, undefined), 0, GMSA_TEST_EPS, "on cooldown");
            _clock.now = 1000;
            gmsa_test_assert_true(_read(undefined, undefined) > 0, "available again");
        });

        gmsa_test_case("cached within refresh", function() {
            var _player = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            var _clock = gmsa_test_clock(0);
            var _read = gmsa_learn_input(__gmsa_tests_habit_model(_player), _player, "drink", { refresh : 1000, clock : _clock.fn });
            gmsa_agent_set_input(_player, "hp", 20);
            var _v1 = _read(undefined, undefined);
            gmsa_agent_set_input(_player, "hp", 90);
            gmsa_test_assert_near(_read(undefined, undefined), _v1, GMSA_TEST_EPS, "reused within the window");
            _clock.now = 1000;
            gmsa_test_assert_true(_read(undefined, undefined) < _v1, "recomputed after the window");
        });

        gmsa_test_case("learning invalidates the cache", function() {
            var _player = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            var _model = __gmsa_tests_habit_model(_player);
            var _clock = gmsa_test_clock(0);
            var _read = gmsa_learn_input(_model, _player, "drink", { refresh : 1000000, clock : _clock.fn });
            gmsa_agent_set_input(_player, "hp", 90);
            var _before = _read(undefined, undefined);
            __gmsa_tests_count_choose(_model, _player, 90, 0, ["drink", "loot"], "drink", 10);
            gmsa_test_assert_true(_read(undefined, undefined) > _before, "new habit seen at once");
        });

        gmsa_test_case("used as a pull input", function() {
            var _player = gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"]));
            var _model = __gmsa_tests_habit_model(_player);
            var _ui = gmsa_profile_create("ui");
            gmsa_profile_add_input(_ui, gmsa_input_pull("will_drink", gmsa_learn_input(_model, _player, "drink", { refresh : 0 })));
            var _a = gmsa_profile_add_action(_ui, "remind");
            gmsa_action_add_consideration(_a, "will_drink", gmsa_curve_make(gmsa_curve.STEP, { c : 0.5 }));
            gmsa_profile_add_action(_ui, "idle", { weight : 0.1 });
            var _helper = gmsa_agent_create(gmsa_profile_build(_ui));
            gmsa_agent_set_input(_player, "hp", 20);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(gmsa_agent_think(_helper, 0)), "remind", "hurt player gets a reminder");
            gmsa_agent_set_input(_player, "hp", 90);
            gmsa_test_assert_equal(__gmsa_tests_chosen_name(gmsa_agent_think(_helper, 1)), "idle", "healthy player doesn't");
        });

        gmsa_test_case("validation", function() {
            var _ctx = {
                model  : gmsa_learn_count_create(),
                player : gmsa_agent_create(__gmsa_tests_count_profile(["drink", "loot"])),
                plain  : gmsa_agent_create(__gmsa_tests_simple_profile(["drink"])),
            };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_input(model, player, "nope"); }), "unknown action");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_input(model, plain, "drink"); }), "no features");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_input(model, player, "drink", { fallback : 2 }); }), "bad fallback");
            gmsa_test_assert_throws(method(_ctx, function() {
                var _read = gmsa_learn_input(model, player, "drink");
                _read(player, undefined);
            }), "read by the observed agent");
        });
    });
}