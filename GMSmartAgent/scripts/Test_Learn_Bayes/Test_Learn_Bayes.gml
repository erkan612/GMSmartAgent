function test_learn_bayes() {
    gmsa_test_suite("Learn Naive Bayes", function() {
        gmsa_test_case("settings: nonsense throws, no upper limits", function() {
            var _bad = [{ bins : 0 }, { bins : 2.5 }, { input_bins : "hp" }, { input_bins : { hp : 0 } }, { smoothing : 0 },
                        { temper : 0 }, { temper : "yes" }, { inputs : [] }, { inputs : "hp" }];
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ p : _bad[_i] }, function() { gmsa_learn_bayes_create(p); }), "case " + string(_i));
            }
            var _big = gmsa_learn_bayes_create({ bins : 1024, input_bins : { gold : 4096, flag : 2 } });
            gmsa_test_assert_equal(__gmsa_learn_bayes_levels(_big, "hp"), [2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]);
            gmsa_test_assert_equal(__gmsa_learn_bayes_levels(_big, "flag"), [2]);
        });

        gmsa_test_case("untrained: an even split and no confidence", function() {
            var _m = gmsa_learn_bayes_create();
            var _out = __test_ngram_guess(_m, __test_ngram_shopper(), 50);
            gmsa_test_assert_near(_out.p[0], 1 / 3);
            gmsa_test_assert_equal(_out.confidence, 0);
        });

        gmsa_test_case("learns from an agent's choices", function() {
            var _m = gmsa_learn_bayes_create();
            var _ag = __test_ngram_shopper();
            repeat (30) {
                __test_ngram_buy(_m, _ag, 15, 2);
                __test_ngram_buy(_m, _ag, 85, 0);
            }
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 15).best, 2, "hurt: a potion");
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 85).best, 0, "healthy: a sword");
        });

        gmsa_test_case("each input on its own: six inputs, two matter", function() {
            var _space = gmsa_learn_space("bayes many", ["drink", "loot", "fight"], ["hp", "gold", "a", "b", "c", "d"]);
            var _m = gmsa_learn_bayes_create({ half_life : 200 });
            var _rng = gmsa_rng_create(4);
            repeat (300) {
                var _x = array_create(6, 0);
                for (var _j = 0; _j < 6; _j++) _x[_j] = gmsa_rng_next(_rng);
                var _c = (_x[0] < 0.3) ? 0 : ((_x[1] < 0.3) ? 1 : 2); // hurt: drink, else poor: loot, else fight
                gmsa_learn_space_observe(_m, _space, __test_bayes_options(3, _x), _c);
            }
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(3, [0.1, 0.5, 0.5, 0.5, 0.5, 0.5])), 0, "hurt: drink");
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(3, [0.9, 0.05, 0.5, 0.5, 0.5, 0.5])), 1, "healthy and poor: loot");
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(3, [0.9, 0.9, 0.5, 0.5, 0.5, 0.5])), 2, "healthy and rich: fight");
        });

        gmsa_test_case("not one-directional: drinks at medium hp, flees when low, fights when high", function() {
            var _b = __test_bayes_medium();
            gmsa_test_assert_equal(__test_bayes_best(_b.m, _b.space, __test_bayes_options(3, [0.45, 0.5, 0.5])), 0, "medium: drink");
            gmsa_test_assert_equal(__test_bayes_best(_b.m, _b.space, __test_bayes_options(3, [0.15, 0.5, 0.5])), 1, "low: flee");
            gmsa_test_assert_equal(__test_bayes_best(_b.m, _b.space, __test_bayes_options(3, [0.8, 0.5, 0.5])), 2, "high: fight");
        });

        gmsa_test_case("targets: what was on offer counts, cheap potions are rare and wanted", function() {
            var _space = gmsa_learn_space("bayes potions", ["potion"], ["price"], { situational : [false] });
            var _m = gmsa_learn_bayes_create();
            var _rng = gmsa_rng_create(6);
            repeat (300) {
                var _shelf = __test_bayes_shelf(_rng, 0.15);
                var _c = -1;
                for (var _i = 0; _i < 4; _i++) if (_c < 0 && _shelf[_i].inputs[0] < 0.3) _c = _i;
                if (_c < 0) _c = floor(gmsa_rng_next(_rng) * 4);
                gmsa_learn_space_observe(_m, _space, _shelf, _c);
            }
            var _offer = [{ action : 0, inputs : [0.15] }, { action : 0, inputs : [0.7] }, { action : 0, inputs : [0.8] }, { action : 0, inputs : [0.9] }];
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, _offer), 0, "the cheap one");
        });

        gmsa_test_case("targets: cheap potions common, a player who doesn't care, no preference invented", function() {
            var _space = gmsa_learn_space("bayes common", ["potion"], ["price"], { situational : [false] });
            var _m = gmsa_learn_bayes_create();
            var _rng = gmsa_rng_create(8);
            repeat (300) gmsa_learn_space_observe(_m, _space, __test_bayes_shelf(_rng, 0.8), floor(gmsa_rng_next(_rng) * 4));
            var _offer = [{ action : 0, inputs : [0.15] }, { action : 0, inputs : [0.2] }, { action : 0, inputs : [0.7] }, { action : 0, inputs : [0.9] }];
            var _out = gmsa_learn_space_predict(_m, _space, _offer);
            var _top = 0;
            for (var _i = 0; _i < 4; _i++) _top = max(_top, _out.p[_i]);
            gmsa_test_assert_true(_out.confidence * _top < 0.5, "sure " + string(_out.confidence * _top));
        });

        gmsa_test_case("temper: overlapping inputs are softened, a single useful input isn't", function() {
            var _space = gmsa_learn_space("bayes overlap", ["drink", "fight"], ["hp", "is_hurt", "hp_again"]);
            var _m = gmsa_learn_bayes_create();
            var _rng = gmsa_rng_create(10);
            repeat (300) {
                var _hp = gmsa_rng_next(_rng);
                var _x = [_hp, (_hp < 0.3) ? 1 : 0, _hp];
                var _c = (gmsa_rng_next(_rng) < 0.1) ? floor(gmsa_rng_next(_rng) * 2) : ((_hp < 0.3) ? 0 : 1);
                gmsa_learn_space_observe(_m, _space, __test_bayes_options(2, _x), _c);
            }
            gmsa_test_assert_true(__gmsa_learn_bayes_tau(_m) < 1, "softened to " + string(__gmsa_learn_bayes_tau(_m)));
            var _b = __test_bayes_medium();
            gmsa_test_assert_equal(__gmsa_learn_bayes_tau(_b.m), 1, "one useful input, two useless: no softening");
        });

        gmsa_test_case("outcomes: effects added up", function() {
            var _space = gmsa_learn_space("bayes outcomes", ["drink", "fight", "wait"], ["hp", "danger"]);
            var _m = gmsa_learn_bayes_create({ learns : gmsa_learn_target.OUTCOMES, half_life : 200 });
            var _rng = gmsa_rng_create(12);
            repeat (400) {
                var _x = [gmsa_rng_next(_rng), gmsa_rng_next(_rng)];
                var _a = floor(gmsa_rng_next(_rng) * 3);
                var _reward = (_a == 0) ? ((_x[0] < 0.3) ? 1 : -0.5) : ((_a == 1) ? ((_x[1] < 0.5) ? 0.5 : -1) : 0);
                gmsa_learn_space_outcome(_m, _space, __test_bayes_options(3, _x), _a, 1, _reward);
            }
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(3, [0.1, 0.9])), 0, "hurt: drinking pays");
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(3, [0.9, 0.1])), 1, "healthy and safe: fighting pays");
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(3, [0.9, 0.9])), 2, "healthy in danger: wait");
            var _lines = gmsa_learn_space_explain(_m, _space, __test_bayes_options(3, [0.1, 0.9]), 0);
            gmsa_test_assert_true(string_pos("base", _lines[0]) > 0 && string_pos("hp", _lines[0]) > 0, _lines[0]);
        });

        gmsa_test_case("explain names the inputs and their say", function() {
            var _b = __test_bayes_medium();
            var _lines = gmsa_learn_space_explain(_b.m, _b.space, __test_bayes_options(3, [0.45, 0.5, 0.5]), 0);
            gmsa_test_assert_true(string_pos("drink: picked", _lines[0]) == 1, _lines[0]);
            gmsa_test_assert_true(string_pos("hp ", _lines[0]) > 0 && string_pos(" x", _lines[0]) > 0, _lines[0]);
        });

        gmsa_test_case("save and load keep what was learned", function() {
            var _b = __test_bayes_medium();
            var _offer = __test_bayes_options(3, [0.45, 0.5, 0.5]);
            var _before = gmsa_learn_space_predict(_b.m, _b.space, _offer).p[0];
            var _json = gmsa_learn_save(_b.m);
            var _copy = gmsa_learn_bayes_create();
            gmsa_learn_load(_copy, _json);
            gmsa_test_assert_near(gmsa_learn_space_predict(_copy, _b.space, _offer).p[0], _before, 0.0001);
            gmsa_test_assert_throws(method({ j : _json }, function() { gmsa_learn_load(gmsa_learn_bayes_create({ input_bins : { hp : 16 } }), j); }), "hp cut differently");
        });
    });
}

function __test_bayes_options(_actions, _x) {
    var _o = [];
    for (var _a = 0; _a < _actions; _a++) array_push(_o, { action : _a, inputs : _x });
    return _o;
}

function __test_bayes_best(_model, _space, _options) {
    var _p = gmsa_learn_space_predict(_model, _space, _options).p;
    var _b = 0;
    for (var _i = 1; _i < array_length(_p); _i++) if (_p[_i] > _p[_b]) _b = _i;
    return _b;
}

function __test_bayes_shelf(_rng, _cheap) {
    var _shelf = [];
    repeat (4) {
        var _price = (gmsa_rng_next(_rng) < _cheap) ? 0.1 + gmsa_rng_next(_rng) * 0.15 : 0.5 + gmsa_rng_next(_rng) * 0.45;
        array_push(_shelf, { action : 0, inputs : [_price] });
    }
    return _shelf;
}

function __test_bayes_medium() {
    var _space = gmsa_learn_space("bayes medium", ["drink", "flee", "fight"], ["hp", "a", "b"]);
    var _m = gmsa_learn_bayes_create();
    var _rng = gmsa_rng_create(2);
    repeat (200) {
        var _x = [gmsa_rng_next(_rng), gmsa_rng_next(_rng), gmsa_rng_next(_rng)];
        var _c = (_x[0] < 0.3) ? 1 : ((_x[0] < 0.6) ? 0 : 2);
        gmsa_learn_space_observe(_m, _space, __test_bayes_options(3, _x), _c);
    }
    return { m : _m, space : _space };
}