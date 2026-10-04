function gmsa_tests_selfcheck() {
    gmsa_test_clear();
    gmsa_test_suite("Selfcheck", function() {
        gmsa_test_case("passes", function() {
            gmsa_test_assert_equal(1 + 1, 2);
            gmsa_test_assert_near(0.1 + 0.2, 0.3);
            gmsa_test_assert_range(0.5, 0, 1);
            gmsa_test_assert_throws(function() { var _s = undefined; _s.x = 1; });
        });
        gmsa_test_case("fails on purpose", function() {
            gmsa_test_assert_near(0.5, 0.6, 0.01, "near");
        });
        gmsa_test_case("errors on purpose", function() {
            var _s = undefined;
            _s.x = 1;
        });
    });
    var _summary = gmsa_test_run(true);
    var _ok = (_summary.passed == 1 && _summary.failed == 1 && _summary.errors == 1);
    show_debug_message("[GMSA Test] selfcheck " + (_ok ? "OK" : "BROKEN"));
}