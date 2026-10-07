function test_learn_sure() {
    gmsa_test_suite("Learn sure and best", function() {
        gmsa_test_case("an untrained model: best is the first option, sure is 0", function() {
            var _space = gmsa_learn_space("shop", ["sword", "shield", "potion"], ["hp"]);
            var _model = gmsa_learn_count_create();
            var _out = gmsa_learn_space_predict(_model, _space, __test_sure_options(0.5));
            gmsa_test_assert_equal(_out.best, 0);
            gmsa_test_assert_equal(_out.sure, 0, "no confidence, nothing to be sure about");
        });

        gmsa_test_case("a trained model: best is the habit, sure is confidence times its probability", function() {
            var _space = gmsa_learn_space("shop", ["sword", "shield", "potion"], ["hp"]);
            var _model = gmsa_learn_count_create();
            var _options = __test_sure_options(0.5);
            repeat (20) gmsa_learn_space_observe(_model, _space, _options, 2);  // always the potion
            var _out = gmsa_learn_space_predict(_model, _space, _options);
            gmsa_test_assert_equal(_out.best, 2);
            gmsa_test_assert_near(_out.sure, _out.confidence * _out.p[2]);
            gmsa_test_assert_true(_out.sure > 0.5, "a clear habit, well known");
        });

        gmsa_test_case("sure stays within 0 and 1, and below confidence", function() {
            var _space = gmsa_learn_space("shop", ["sword", "shield", "potion"], ["hp"]);
            var _model = gmsa_learn_linear_create();
            var _options = __test_sure_options(0.2);
            for (var _i = 0; _i < 30; _i++) gmsa_learn_space_observe(_model, _space, _options, _i mod 3);
            var _out = gmsa_learn_space_predict(_model, _space, _options);
            gmsa_test_assert_range(_out.sure, 0, 1);
            gmsa_test_assert_true(_out.sure <= _out.confidence + 0.000001);
        });
    });
}

function __test_sure_options(_hp) {
    var _inputs = [_hp];
    return [{ action : 0, inputs : _inputs }, { action : 1, inputs : _inputs }, { action : 2, inputs : _inputs }];
}