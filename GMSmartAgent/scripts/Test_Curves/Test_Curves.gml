#macro GMSA_TEST_EPS 0.0001

function gmsa_tests_curves() {
    gmsa_test_suite("Curves", function() {

        gmsa_test_case("linear default", function() {
            var _c = gmsa_curve_make(gmsa_curve.LINEAR);
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0),   0,   GMSA_TEST_EPS, "x=0");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.5), 0.5, GMSA_TEST_EPS, "x=0.5");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 1),   1,   GMSA_TEST_EPS, "x=1");
        });

        gmsa_test_case("input clamped", function() {
            var _c = gmsa_curve_make(gmsa_curve.LINEAR);
            gmsa_test_assert_near(gmsa_curve_eval(_c, -1), 0, GMSA_TEST_EPS, "x=-1");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 2),  1, GMSA_TEST_EPS, "x=2");
        });

        gmsa_test_case("output clamped", function() {
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.LINEAR, { m : 2 }), 0.75), 1, GMSA_TEST_EPS, "above 1");
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.LINEAR, { b : -0.5 }), 0.25), 0, GMSA_TEST_EPS, "below 0");
        });

        gmsa_test_case("linear descending", function() {
            var _c = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0),    1,    GMSA_TEST_EPS, "x=0");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.25), 0.75, GMSA_TEST_EPS, "x=0.25");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 1),    0,    GMSA_TEST_EPS, "x=1");
        });

        gmsa_test_case("invert flag", function() {
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.LINEAR, { invert : true }), 0.25), 0.75, GMSA_TEST_EPS, "linear");
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.STEP, { invert : true }), 0.6), 0, GMSA_TEST_EPS, "step");
        });

        gmsa_test_case("power default", function() {
            var _c = gmsa_curve_make(gmsa_curve.POWER);
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0),   0,    GMSA_TEST_EPS, "x=0");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.5), 0.25, GMSA_TEST_EPS, "x=0.5");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 1),   1,    GMSA_TEST_EPS, "x=1");
        });

        gmsa_test_case("power root", function() {
            var _c = gmsa_curve_make(gmsa_curve.POWER, { k : 0.5 });
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.25), 0.5, GMSA_TEST_EPS, "x=0.25");
        });

        gmsa_test_case("power U shape", function() {
            var _c = gmsa_curve_make(gmsa_curve.POWER, { m : 4, k : 2, c : 0.5 });
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0),   1, GMSA_TEST_EPS, "x=0");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.5), 0, GMSA_TEST_EPS, "x=0.5");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 1),   1, GMSA_TEST_EPS, "x=1");
        });

        gmsa_test_case("logistic default", function() {
            var _c = gmsa_curve_make(gmsa_curve.LOGISTIC);
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0),   0.006693, GMSA_TEST_EPS, "x=0");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.5), 0.5,      GMSA_TEST_EPS, "x=0.5");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 1),   0.993307, GMSA_TEST_EPS, "x=1");
        });

        gmsa_test_case("logistic increasing", function() {
            var _c = gmsa_curve_make(gmsa_curve.LOGISTIC);
            var _prev = gmsa_curve_eval(_c, 0);
            for (var _i = 1; _i <= 10; _i++) {
                var _y = gmsa_curve_eval(_c, _i / 10);
                if (!gmsa_test_assert_true(_y >= _prev, "x=" + string(_i / 10))) return;
                _prev = _y;
            }
        });

        gmsa_test_case("step", function() {
            var _c = gmsa_curve_make(gmsa_curve.STEP);
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.49), 0, GMSA_TEST_EPS, "x=0.49");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.5),  1, GMSA_TEST_EPS, "x=0.5");
            gmsa_test_assert_near(gmsa_curve_eval(_c, 1),    1, GMSA_TEST_EPS, "x=1");
            var _c2 = gmsa_curve_make(gmsa_curve.STEP, { c : 0.2 });
            gmsa_test_assert_near(gmsa_curve_eval(_c2, 0.19), 0, GMSA_TEST_EPS, "c=0.2 x=0.19");
            gmsa_test_assert_near(gmsa_curve_eval(_c2, 0.2),  1, GMSA_TEST_EPS, "c=0.2 x=0.2");
        });

        gmsa_test_case("custom func", function() {
            var _c = gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) { return _x * _x * _x; } });
            gmsa_test_assert_near(gmsa_curve_eval(_c, 0.5), 0.125, GMSA_TEST_EPS, "x=0.5");
        });

        gmsa_test_case("custom clamps and NaN", function() {
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) { return 5; } }), 0.5), 1, GMSA_TEST_EPS, "5");
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) { return -3; } }), 0.5), 0, GMSA_TEST_EPS, "-3");
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) { return NaN; } }), 0.5), 0, GMSA_TEST_EPS, "NaN");
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) { return NaN; }, invert : true }), 0.5), 0, GMSA_TEST_EPS, "NaN inverted");
            gmsa_test_assert_near(gmsa_curve_eval(gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) { return "abc"; } }), 0.5), 0, GMSA_TEST_EPS, "string");
        });

        gmsa_test_case("invalid make throws", function() {
            gmsa_test_assert_throws(function() { gmsa_curve_make(99); }, "unknown type");
            gmsa_test_assert_throws(function() { gmsa_curve_make(gmsa_curve.CUSTOM); }, "custom without func");
            gmsa_test_assert_throws(function() { gmsa_curve_make(gmsa_curve.CUSTOM, { func : "abc" }); }, "custom func not callable");
        });

        gmsa_test_case("outputs always in range", function() {
            var _curves = [
                gmsa_curve_make(gmsa_curve.LINEAR),
                gmsa_curve_make(gmsa_curve.LINEAR, { m : 3, b : -1 }),
                gmsa_curve_make(gmsa_curve.POWER),
                gmsa_curve_make(gmsa_curve.POWER, { k : 0.5, c : 0.5 }),
                gmsa_curve_make(gmsa_curve.LOGISTIC),
                gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -20, m : 2 }),
                gmsa_curve_make(gmsa_curve.STEP, { invert : true }),
            ];
            for (var _i = 0; _i < array_length(_curves); _i++) {
                for (var _x = -0.5; _x <= 1.5; _x += 0.05) {
                    var _y = gmsa_curve_eval(_curves[_i], _x);
                    if (!gmsa_test_assert_range(_y, 0, 1, "curve " + string(_i) + " x=" + string(_x))) return;
                }
            }
        });
    });
}