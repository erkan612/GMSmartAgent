function test_learn_neighbor() {
    gmsa_test_suite("Learn Nearest neighbor", function() {
        gmsa_test_case("settings: nonsense throws, no upper limits", function() {
            var _bad = [{ capacity : 0 }, { capacity : 1.5 }, { k : 0 }, { candidates : 0 }, { weights : "hp" }, { weights : { hp : -1 } },
                        { learn_weights : "yes" }, { importance : -1 }, { merge : "no" }, { similar : 0 }, { reach : 0 }, { inputs : [] }];
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ p : _bad[_i] }, function() { gmsa_learn_neighbor_create(p); }), "case " + string(_i));
            }
            var _big = gmsa_learn_neighbor_create({ capacity : 1000000, k : 1000, candidates : 5000, weights : { hp : 1000, gold : 0 } });
            gmsa_test_assert_equal(_big.neighbor.capacity, 1000000);
        });

        gmsa_test_case("untrained: an even split and no confidence", function() {
            var _m = gmsa_learn_neighbor_create();
            var _out = __test_ngram_guess(_m, __test_ngram_shopper(), 50);
            gmsa_test_assert_near(_out.p[0], 1 / 3);
            gmsa_test_assert_equal(_out.confidence, 0);
            var _space = gmsa_learn_space("neighbor empty", ["drink", "fight"], ["hp"]);
            var _lines = gmsa_learn_space_explain(_m, _space, __test_bayes_options(2, [0.5]), 0);
            gmsa_test_assert_equal(_lines[0], "drink: no data yet");
        });

        gmsa_test_case("learns from an agent's choices", function() {
            var _m = gmsa_learn_neighbor_create();
            var _ag = __test_ngram_shopper();
            repeat (30) {
                __test_ngram_buy(_m, _ag, 15, 2);
                __test_ngram_buy(_m, _ag, 85, 0);
            }
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 15).best, 2, "hurt: a potion");
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 85).best, 0, "healthy: a sword");
        });

        gmsa_test_case("combinations: one action when exactly one input is high", function() {
            var _space = gmsa_learn_space("neighbor xor", ["dodge", "block"], ["left", "right"]);
            var _m = gmsa_learn_neighbor_create();
            var _rng = gmsa_rng_create(4);
            repeat (400) {
                var _x = [gmsa_rng_next(_rng), gmsa_rng_next(_rng)];
                var _c = ((_x[0] > 0.5) != (_x[1] > 0.5)) ? 0 : 1;
                if (gmsa_rng_next(_rng) < 0.05) _c = floor(gmsa_rng_next(_rng) * 2);
                gmsa_learn_space_observe(_m, _space, __test_bayes_options(2, _x), _c);
            }
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(2, [0.2, 0.8])), 0, "one high: dodge");
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(2, [0.8, 0.2])), 0, "the other high: dodge");
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(2, [0.2, 0.2])), 1, "both low: block");
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, __test_bayes_options(2, [0.8, 0.8])), 1, "both high: block");
        });

        gmsa_test_case("not one-directional: drinks at medium hp, flees when low, fights when high", function() {
            var _b = __test_neighbor_medium(2, 200, {}, false);
            gmsa_test_assert_equal(__test_bayes_best(_b.m, _b.space, __test_bayes_options(3, [0.45, 0.5, 0.5])), 0, "medium: drink");
            gmsa_test_assert_equal(__test_bayes_best(_b.m, _b.space, __test_bayes_options(3, [0.15, 0.5, 0.5])), 1, "low: flee");
            gmsa_test_assert_equal(__test_bayes_best(_b.m, _b.space, __test_bayes_options(3, [0.8, 0.5, 0.5])), 2, "high: fight");
        });

        gmsa_test_case("learned weights: the input that matters gains on five that don't", function() {
            var _b = __test_neighbor_medium(5, 300, {}, false);
            var _lw = _b.m.data.lw;
            for (var _j = 1; _j < 6; _j++) gmsa_test_assert_true(_lw[0] > _lw[_j], "hp " + string(_lw[0]) + " against " + _b.m.data.sk[_j] + " " + string(_lw[_j]));
        });

        gmsa_test_case("your weights: 0 ignores an input", function() {
            var _b = __test_neighbor_medium(2, 200, { weights : { u1 : 0, u2 : 0 } }, false);
            gmsa_test_assert_equal(__test_bayes_best(_b.m, _b.space, __test_bayes_options(3, [0.45, 1, 0])), 0, "far off in ignored inputs, still drink");
        });
		
        gmsa_test_case("learned weights, outcomes: the inputs rewards depend on gain on four that don't", function() {
            var _space = gmsa_learn_space("neighbor outcome weights", ["drink", "fight", "wait"], ["hp", "danger", "u1", "u2", "u3", "u4"]);
            var _m = gmsa_learn_neighbor_create({ learns : gmsa_learn_target.OUTCOMES });
            var _rng = gmsa_rng_create(18);
            repeat (400) {
                var _x = array_create(6, 0);
                for (var _j = 0; _j < 6; _j++) _x[_j] = gmsa_rng_next(_rng);
                var _a = floor(gmsa_rng_next(_rng) * 3);
                var _reward = (_a == 0) ? ((_x[0] < 0.3) ? 1 : -0.5) : ((_a == 1) ? ((_x[1] < 0.5) ? 0.5 : -1) : 0);
                gmsa_learn_space_outcome(_m, _space, __test_bayes_options(3, _x), _a, 1, _reward);
            }
            var _lw = _m.data.lw;
            for (var _j = 2; _j < 6; _j++) {
                gmsa_test_assert_true(min(_lw[0], _lw[1]) > _lw[_j], "hp " + string(_lw[0]) + ", danger " + string(_lw[1]) + " against " + _m.data.sk[_j] + " " + string(_lw[_j]));
            }
        });

        gmsa_test_case("targets: what was on offer counts, cheap potions are rare and wanted", function() {
            var _space = gmsa_learn_space("neighbor potions", ["potion"], ["price"], { situational : [false] });
            var _m = gmsa_learn_neighbor_create();
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
            var _space = gmsa_learn_space("neighbor common", ["potion"], ["price"], { situational : [false] });
            var _m = gmsa_learn_neighbor_create();
            var _rng = gmsa_rng_create(8);
            repeat (300) gmsa_learn_space_observe(_m, _space, __test_bayes_shelf(_rng, 0.8), floor(gmsa_rng_next(_rng) * 4));
            var _offer = [{ action : 0, inputs : [0.15] }, { action : 0, inputs : [0.2] }, { action : 0, inputs : [0.7] }, { action : 0, inputs : [0.9] }];
            var _out = gmsa_learn_space_predict(_m, _space, _offer);
            var _top = 0;
            for (var _i = 0; _i < 4; _i++) _top = max(_top, _out.p[_i]);
            gmsa_test_assert_true(_out.confidence * _top < 0.5, "sure " + string(_out.confidence * _top));
        });

        gmsa_test_case("memory: a surprising moment outlasts ordinary ones, unless importance is 0", function() {
            gmsa_test_assert_true(__test_neighbor_ambush(1), "importance 1: the ambush is still remembered");
            gmsa_test_assert_true(!__test_neighbor_ambush(0), "importance 0: the oldest goes first, the ambush too");
        });

        gmsa_test_case("memory: the same moment merges into one", function() {
            var _space = gmsa_learn_space("neighbor merge", ["drink", "fight"], ["hp"]);
            var _m = gmsa_learn_neighbor_create();
            repeat (5) gmsa_learn_space_observe(_m, _space, __test_bayes_options(2, [0.3]), 0);
            gmsa_test_assert_equal(array_length(_m.data.mem), 1);
            gmsa_test_assert_true(_m.data.mem[0].n > 4.9, "count " + string(_m.data.mem[0].n));
            var _apart = gmsa_learn_neighbor_create({ merge : false });
            repeat (5) gmsa_learn_space_observe(_apart, _space, __test_bayes_options(2, [0.3]), 0);
            gmsa_test_assert_equal(array_length(_apart.data.mem), 5);
        });

        gmsa_test_case("outcomes: the rewards of the nearest tries", function() {
            var _space = gmsa_learn_space("neighbor outcomes", ["drink", "fight", "wait"], ["hp", "danger"]);
            var _m = gmsa_learn_neighbor_create({ learns : gmsa_learn_target.OUTCOMES });
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
            gmsa_test_assert_true(string_pos("drink: like", _lines[0]) == 1 && string_pos("outcomes ago", _lines[0]) > 0 && string_pos("expected +", _lines[0]) > 0, _lines[0]);
        });

        gmsa_test_case("outcomes: targets, by the option's own inputs", function() {
            var _space = gmsa_learn_space("neighbor potion outcomes", ["potion"], ["price"], { situational : [false] });
            var _m = gmsa_learn_neighbor_create({ learns : gmsa_learn_target.OUTCOMES });
            var _rng = gmsa_rng_create(14);
            repeat (300) {
                var _shelf = __test_bayes_shelf(_rng, 0.15);
                var _c = floor(gmsa_rng_next(_rng) * 4);
                gmsa_learn_space_outcome(_m, _space, _shelf, _c, 0.25, (_shelf[_c].inputs[0] < 0.3) ? 1 : -0.5);
            }
            var _offer = [{ action : 0, inputs : [0.8] }, { action : 0, inputs : [0.15] }, { action : 0, inputs : [0.7] }, { action : 0, inputs : [0.9] }];
            gmsa_test_assert_equal(__test_bayes_best(_m, _space, _offer), 1, "the cheap one pays");
        });

        gmsa_test_case("explain names a moment: how long ago, its note, what it was like", function() {
            var _b = __test_neighbor_medium(2, 200, {}, true);
            var _lines = gmsa_learn_space_explain(_b.m, _b.space, __test_bayes_options(3, [0.45, 0.5, 0.5]), 0);
            var _l = _lines[0];
            gmsa_test_assert_true(string_pos("drink: like ", _l) == 1, _l);
            gmsa_test_assert_true(string_pos("choices ago, round ", _l) > 0 || string_pos("choice ago, round ", _l) > 0, _l);
            gmsa_test_assert_true(string_pos("hp ", _l) > 0 && string_pos("similar moments agree (p ", _l) > 0, _l);
        });

        gmsa_test_case("save and load keep moments and notes, other learners ignore notes", function() {
            var _b = __test_neighbor_medium(2, 200, {}, true);
            var _offer = __test_bayes_options(3, [0.45, 0.5, 0.5]);
            var _before = gmsa_learn_space_predict(_b.m, _b.space, _offer).p[0];
            var _copy = gmsa_learn_neighbor_create();
            gmsa_learn_load(_copy, gmsa_learn_save(_b.m));
            gmsa_test_assert_near(gmsa_learn_space_predict(_copy, _b.space, _offer).p[0], _before, 0.0001);
            gmsa_test_assert_equal(_copy.data.mem[0].note, _b.m.data.mem[0].note);
            var _bayes = gmsa_learn_bayes_create();
            gmsa_test_assert_true(gmsa_learn_space_observe(_bayes, _b.space, _offer, 0, "at the bridge"), "bayes takes a note");
        });
    });
}

function __test_neighbor_medium(_useless, _rounds, _params, _notes) {
    var _inputs = ["hp"];
    for (var _j = 1; _j <= _useless; _j++) array_push(_inputs, "u" + string(_j));
    var _space = gmsa_learn_space("neighbor medium " + string(_useless), ["drink", "flee", "fight"], _inputs);
    var _m = gmsa_learn_neighbor_create(_params);
    var _rng = gmsa_rng_create(2);
    for (var _r = 1; _r <= _rounds; _r++) {
        var _x = array_create(_useless + 1, 0);
        for (var _j = 0; _j <= _useless; _j++) _x[_j] = gmsa_rng_next(_rng);
        var _c = (_x[0] < 0.3) ? 1 : ((_x[0] < 0.6) ? 0 : 2);
        gmsa_learn_space_observe(_m, _space, __test_bayes_options(3, _x), _c, _notes ? ("round " + string(_r)) : undefined);
    }
    return { m : _m, space : _space };
}

function __test_neighbor_ambush(_importance) {
    var _space = gmsa_learn_space("neighbor ambush", ["drink", "fight"], ["hp", "danger"]);
    var _m = gmsa_learn_neighbor_create({ capacity : 16, importance : _importance });
    var _rng = gmsa_rng_create(16);
    for (var _r = 0; _r < 81; _r++) {
        if (_r == 50) {
            gmsa_learn_space_observe(_m, _space, __test_bayes_options(2, [0.1, 0.9]), 1, "ambush");
            continue;
        }
        var _x = [gmsa_rng_next(_rng), gmsa_rng_next(_rng)];
        gmsa_learn_space_observe(_m, _space, __test_bayes_options(2, _x), (_x[0] < 0.5) ? 0 : 1);
    }
    for (var _i = 0; _i < array_length(_m.data.mem); _i++) if (_m.data.mem[_i].note == "ambush") return true;
    return false;
}