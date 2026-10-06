function test_learn_space() {
    gmsa_test_suite("Learn space", function() {

        gmsa_test_case("spaces validate", function() {
            gmsa_test_assert_throws(function() { gmsa_learn_space("", ["a"], []); }, "name");
            gmsa_test_assert_throws(function() { gmsa_learn_space("s", [], []); }, "no actions");
            gmsa_test_assert_throws(function() { gmsa_learn_space("s", ["a", "a"], []); }, "duplicate action");
            gmsa_test_assert_throws(function() { gmsa_learn_space("s", ["a"], ["x"], { situational : [true, false] }); }, "situational length");
            var _space = gmsa_learn_space("s", ["a", "b"], ["x"]);
            var _model = gmsa_learn_count_create();
            var _ctx = { m : _model, s : _space };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_space_predict(m, s, [{ action : 2, inputs : [0] }]); }), "action out of range");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_space_predict(m, s, [{ action : 0, inputs : [] }]); }), "inputs length");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_space_observe(m, s, [{ action : 0, inputs : [0] }], 1); }), "chosen");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_space_outcome(m, s, [{ action : 0, inputs : [0] }], 0, 1, 1); }), "a choices model");
        });

        gmsa_test_case("a space learns choices like a profile", function() {
            var _space = gmsa_learn_space("menu", ["soup", "salad", "steak"], ["hunger"]);
            var _model = gmsa_learn_linear_create();
            var _options = [{ action : 0, inputs : [0.5] }, { action : 1, inputs : [0.5] }, { action : 2, inputs : [0.5] }];
            repeat (40) gmsa_learn_space_observe(_model, _space, _options, 1);
            var _out = gmsa_learn_space_predict(_model, _space, _options);
            gmsa_test_assert_true(_out.p[1] > _out.p[0] && _out.p[1] > _out.p[2], "salad");
            gmsa_test_assert_true(_out.confidence > 0, "confident");
        });

        gmsa_test_case("count learns which choice works in which situation", function() {
            var _space = gmsa_learn_space("get_key", ["steal", "buy"], ["guard_awake"]);
            var _model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
            __test_space_train(_model, _space);
            var _asleep = gmsa_learn_space_predict(_model, _space, __test_space_options(0));
            gmsa_test_assert_true(_asleep.p[0] > _asleep.p[1], "steal while the guard sleeps");
            var _awake = gmsa_learn_space_predict(_model, _space, __test_space_options(1));
            gmsa_test_assert_true(_awake.p[1] > _awake.p[0], "buy while he's awake");
        });

        gmsa_test_case("linear learns which choice works in which situation", function() {
            var _space = gmsa_learn_space("get_key", ["steal", "buy"], ["guard_awake"]);
            var _model = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            __test_space_train(_model, _space);
            var _asleep = gmsa_learn_space_predict(_model, _space, __test_space_options(0));
            gmsa_test_assert_true(_asleep.p[0] > _asleep.p[1], "steal while the guard sleeps");
            var _awake = gmsa_learn_space_predict(_model, _space, __test_space_options(1));
            gmsa_test_assert_true(_awake.p[1] > _awake.p[0], "buy while he's awake");
        });

        gmsa_test_case("outcomes weigh like tickets", function() {
            var _space = gmsa_learn_space("s", ["a", "b"], ["x"]);
            var _model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
            var _options = [{ action : 0, inputs : [0] }, { action : 1, inputs : [0] }];
            gmsa_learn_space_outcome(_model, _space, _options, 0, 0.5, 1, 0.5);
            gmsa_test_assert_equal(_model.samples, 0.5, "the credit counts as data");
            gmsa_learn_freeze(_model);
            gmsa_test_assert_equal(gmsa_learn_space_outcome(_model, _space, _options, 0, 0.5, 1), false, "frozen");
            var _ctx = { m : _model, s : _space, o : _options };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_space_outcome(m, s, o, 0, 0, 1); }), "probability 0");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_space_observe(m, s, o, 0); }), "an outcomes model");
        });
    });
}

function __test_space_train(_model, _space) {
    var _rng = gmsa_rng_create(11);
    repeat (400) {
        var _guard = (gmsa_rng_next(_rng) < 0.5) ? 0 : 1;
        var _chosen = (gmsa_rng_next(_rng) < 0.5) ? 0 : 1;
        var _reward = (_chosen == 0) ? ((_guard == 0) ? 1 : -1) : 0.2;
        gmsa_learn_space_outcome(_model, _space, __test_space_options(_guard), _chosen, 0.5, _reward);
    }
}

function __test_space_options(_guard) {
    return [{ action : 0, inputs : [_guard] }, { action : 1, inputs : [_guard] }];
}