function gmsa_tests_debug() {
    gmsa_test_suite("Debug", function() {

        gmsa_test_case("lines mark the chosen option", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b"]));
            gmsa_agent_set_input(_ag, "a", 0.3);
            gmsa_agent_set_input(_ag, "b", 0.9);
            var _lines = gmsa_debug_lines(gmsa_agent_think(_ag, 0));
            gmsa_test_assert_equal(array_length(_lines), 2, "one line per option");
            gmsa_test_assert_equal(string_char_at(_lines[0], 1), ">", "chosen marked");
            gmsa_test_assert_true(string_pos("b", _lines[0]) > 0, "action name");
            gmsa_test_assert_true(string_pos("[b 0.90]", _lines[0]) > 0, "feature shown");
        });

        gmsa_test_case("empty decision and overflow", function() {
            var _ag = gmsa_agent_create(__gmsa_tests_simple_profile(["a"]));
            gmsa_test_assert_equal(gmsa_debug_lines(gmsa_agent_think(_ag, 0)), ["no selectable options"], "empty");
            var _many = gmsa_agent_create(__gmsa_tests_simple_profile(["a", "b", "c"]));
            gmsa_agent_set_input(_many, "a", 0.1);
            gmsa_agent_set_input(_many, "b", 0.2);
            gmsa_agent_set_input(_many, "c", 0.3);
            var _lines = gmsa_debug_lines(gmsa_agent_think(_many, 0), 2);
            gmsa_test_assert_equal(array_length(_lines), 3, "two options plus more line");
            gmsa_test_assert_true(string_pos("1 more", _lines[2]) > 0, "more line");
        });

        gmsa_test_case("target namer", function() {
            var _ctx = { list : [{ name : "orc", v : 0.5 }] };
            var _p = gmsa_profile_create("t");
            gmsa_profile_add_input(_p, gmsa_input_pull("v", function(_agent, _target) { return _target.v; }, 0, 1, true));
            var _a = gmsa_profile_add_action(_p, "attack", { targets : method(_ctx, function(_agent) { return list; }) });
            gmsa_action_add_consideration(_a, "v", gmsa_curve_make(gmsa_curve.LINEAR));
            var _d = gmsa_agent_think(gmsa_agent_create(gmsa_profile_build(_p)), 0);
            gmsa_test_assert_true(string_pos("@ struct", gmsa_debug_lines(_d)[0]) > 0, "default text");
            var _named = gmsa_debug_lines(_d, 8, function(_target) { return _target.name; });
            gmsa_test_assert_true(string_pos("@ orc", _named[0]) > 0, "namer used");
        });
    });
}