function test_learn_track() {
    gmsa_test_suite("Learn track", function() {

        gmsa_test_case("validation", function() {
            var _plain = gmsa_agent_create(__test_track_profile(false));
            gmsa_test_assert_throws(method({ a : _plain }, function() { gmsa_learn_track(a); }), "needs features");
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_test_assert_throws(method({ a : _agent }, function() { gmsa_learn_track(a, { size : 0 }); }), "size 0");
            gmsa_test_assert_throws(method({ a : _agent }, function() { gmsa_learn_track(a, { window : 0 }); }), "window 0");
            gmsa_test_assert_throws(method({ a : _agent }, function() { gmsa_learn_remember(a); }), "untracked");
            gmsa_learn_track(_agent, { clock : get_timer });
            gmsa_test_assert_true(_agent.__track != undefined, "built-in clock accepted");
            gmsa_learn_untrack(_agent);
        });

        gmsa_test_case("switching records, confirming refreshes", function() {
            var _clock = gmsa_test_clock(1000, 10);
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent, { clock : _clock.fn });

            __test_track_act(_agent, 0.9, 0.1);  // go_a
            gmsa_test_assert_equal(array_length(gmsa_learn_history(_agent)), 1, "first decision");
            var _first = gmsa_learn_remember(_agent);
            gmsa_test_assert_equal(_first.options[_first.chosen].action.name, "go_a", "chosen action");

            __test_track_act(_agent, 0.9, 0.1);  // go_a again
            gmsa_test_assert_equal(array_length(gmsa_learn_history(_agent)), 1, "confirming adds nothing");
            gmsa_test_assert_true(_first.last > _first.start, "confirming refreshes the time");

            __test_track_act(_agent, 0.1, 0.9);  // go_b
            var _history = gmsa_learn_history(_agent);
            gmsa_test_assert_equal(array_length(_history), 2, "switching adds");
            gmsa_test_assert_false(_first.active, "previous decision ended");
            gmsa_test_assert_true(gmsa_learn_remember(_agent).active, "new one is current");
        });

        gmsa_test_case("entries are copies", function() {
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent);
            __test_track_act(_agent, 0.9, 0.1);
            var _entry = gmsa_learn_remember(_agent);
            var _before = _entry.options[0].inputs[0];
            gmsa_agent_set_input(_agent, "a", 0.2);
            gmsa_agent_think(_agent, 5);
            gmsa_test_assert_equal(_entry.options[0].inputs[0], _before, "later thinks don't change it");
            gmsa_test_assert_near(_entry.probability, 1, 0.000001, "BEST picks with probability 1");
        });

        gmsa_test_case("size keeps the newest", function() {
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent, { size : 3 });
            repeat (4) {
                __test_track_act(_agent, 0.9, 0.1);
                __test_track_act(_agent, 0.1, 0.9);
            }
            var _history = gmsa_learn_history(_agent);
            gmsa_test_assert_equal(array_length(_history), 3, "bounded");
            gmsa_test_assert_equal(_history[2], gmsa_learn_remember(_agent), "newest last");
        });

        gmsa_test_case("clearing ends the decision", function() {
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent);
            __test_track_act(_agent, 0.9, 0.1);
            var _entry = gmsa_learn_remember(_agent);
            gmsa_agent_clear_current(_agent);
            gmsa_test_assert_false(_entry.active, "ended");
            gmsa_test_assert_equal(gmsa_learn_remember(_agent), undefined, "nothing current");
            __test_track_act(_agent, 0.9, 0.1);
            gmsa_test_assert_equal(array_length(gmsa_learn_history(_agent)), 2, "same action again is a new decision");
        });

        gmsa_test_case("only the agent's own decisions are recorded", function() {
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent);
            gmsa_agent_set_input(_agent, "a", 0.9);
            var _eval = gmsa_agent_evaluate(_agent, 1);
            gmsa_agent_set_current_option(_agent, _eval.options[0]);
            gmsa_test_assert_equal(array_length(gmsa_learn_history(_agent)), 0, "evaluated option not recorded");
            gmsa_test_assert_equal(_agent.current.action, 0, "but still set as current");
        });

        gmsa_test_case("untracked agents work as before", function() {
            var _agent = gmsa_agent_create(__test_track_profile(true));
            __test_track_act(_agent, 0.9, 0.1);
            gmsa_test_assert_equal(_agent.current.action, 0, "current set");
            gmsa_learn_track(_agent);
            gmsa_learn_untrack(_agent);
            __test_track_act(_agent, 0.1, 0.9);
            gmsa_test_assert_equal(_agent.__track, undefined, "untracked");
        });
    });
}

function __test_track_profile(_features) {
    var _p = gmsa_profile_create("track test");
    gmsa_profile_add_input(_p, gmsa_input_push("a"));
    gmsa_profile_add_input(_p, gmsa_input_push("b"));
    var _act = gmsa_profile_add_action(_p, "go_a");
    gmsa_action_add_consideration(_act, "a", gmsa_curve_make(gmsa_curve.LINEAR));
    _act = gmsa_profile_add_action(_p, "go_b");
    gmsa_action_add_consideration(_act, "b", gmsa_curve_make(gmsa_curve.LINEAR));
    if (_features) gmsa_profile_set_features(_p, ["a", "b"]);
    return gmsa_profile_build(_p);
}

function __test_track_act(_agent, _a, _b) {
    gmsa_agent_set_input(_agent, "a", _a);
    gmsa_agent_set_input(_agent, "b", _b);
    var _option = gmsa_decision_get_chosen(gmsa_agent_think(_agent, 1));
    gmsa_agent_set_current_option(_agent, _option);
}