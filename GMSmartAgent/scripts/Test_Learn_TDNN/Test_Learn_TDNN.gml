function test_learn_tdnn() {
    gmsa_test_suite("Learn TDNN", function() {
        gmsa_test_case("settings: nonsense throws, no upper limits", function() {
            var _bad = [{ length : 0 }, { length : 2.5 }, { layers : [] }, { layers : [0] }, { replay : -1 }, { replay : 1.5 },
                        { memory : 0 }, { remember : "price" }, { remember : [1] }, { familiar_depth : -1 }, { familiar_bins : 0 },
                        { familiar_k : 0 }, { familiar_capacity : 0 }, { learn_rate : 0 }];
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ p : _bad[_i] }, function() { gmsa_learn_tdnn_create(p); }), "case " + string(_i));
            }
            var _big = gmsa_learn_tdnn_create({ length : 50, layers : [256, 128], replay : 64, memory : 100000 });
            gmsa_test_assert_equal(_big.tdnn.layers, [256, 128, 1]);
        });

        gmsa_test_case("untrained: an even split and no confidence", function() {
            var _m = gmsa_learn_tdnn_create();
            var _out = __test_ngram_guess(_m, __test_ngram_shopper(), 50);
            gmsa_test_assert_near(_out.p[0], 1 / 3);
            gmsa_test_assert_equal(_out.confidence, 0);
        });

        gmsa_test_case("learns the order: sword, shield, potion", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_ngram_shopper();
            repeat (30) {
                __test_ngram_buy(_m, _ag, 50, 0);
                __test_ngram_buy(_m, _ag, 50, 1);
                __test_ngram_buy(_m, _ag, 50, 2);
            }
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 50).best, 0, "after a potion: a sword");
            __test_ngram_buy(_m, _ag, 50, 0);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 50).best, 1, "after a sword: a shield");
            __test_ngram_buy(_m, _ag, 50, 1);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 50).best, 2, "after a shield: a potion");
        });

        gmsa_test_case("targets in order: after a sword the cheapest potion, then the priciest", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_tdnn_shop();
            var _rng = gmsa_rng_create(3);
            for (var _i = 0; _i < 300; _i++) {
                var _p = __test_tdnn_potions(_rng);
                var _step = _i mod 3;
                __test_tdnn_shop_buy(_m, _ag, _p, (_step == 0) ? -1 : ((_step == 1) ? __test_tdnn_cheapest(_p) : __test_tdnn_priciest(_p)));
            }
            var _p = [{ price : 50 }, { price : 50 }, { price : 50 }];
            gmsa_test_assert_equal(__test_tdnn_shop_guess(_m, _ag, _p), -1, "after the priciest: a sword");
            __test_tdnn_shop_buy(_m, _ag, _p, -1);
            _p = [{ price : 70 }, { price : 20 }, { price : 50 }];
            gmsa_test_assert_equal(__test_tdnn_shop_guess(_m, _ag, _p), 1, "after a sword: the cheapest");
            __test_tdnn_shop_buy(_m, _ag, _p, 1);
            _p = [{ price : 30 }, { price : 90 }, { price : 60 }];
            gmsa_test_assert_equal(__test_tdnn_shop_guess(_m, _ag, _p), 1, "after a sword and a potion: the priciest");
        });

        gmsa_test_case("remember: after something expensive, the cheapest", function() {
            var _m = gmsa_learn_tdnn_create({ remember : ["price"] });
            var _ag = __test_tdnn_potion_shop();
            var _rng = gmsa_rng_create(5);
            var _last = 0;
            for (var _i = 0; _i < 450; _i++) {
                var _p = __test_tdnn_potions(_rng);
                var _pick = (_last > 50) ? __test_tdnn_cheapest(_p) : __test_tdnn_priciest(_p);
                __test_tdnn_shop_buy(_m, _ag, _p, _pick);
                _last = _p[_pick].price;
            }
            // buy a potion at 90 the way the habit says, then ask
            var _p = (_last > 50) ? [{ price : 90 }, { price : 95 }, { price : 99 }] : [{ price : 10 }, { price : 20 }, { price : 90 }];
            __test_tdnn_shop_buy(_m, _ag, _p, (_last > 50) ? 0 : 2);
            _p = [{ price : 30 }, { price : 80 }, { price : 50 }];
            gmsa_test_assert_equal(__test_tdnn_shop_guess(_m, _ag, _p), 0, "after 90: the cheapest");
            __test_tdnn_shop_buy(_m, _ag, _p, 0);
            gmsa_test_assert_equal(__test_tdnn_shop_guess(_m, _ag, _p), 1, "after 30: the priciest");
        });

        gmsa_test_case("confidence: lower in moments unlike the ones it learned from", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_ngram_shopper();
            repeat (40) {
                __test_ngram_buy(_m, _ag, 90, 0);
                __test_ngram_buy(_m, _ag, 90, 1);
                __test_ngram_buy(_m, _ag, 90, 2);
            }
            __test_ngram_buy(_m, _ag, 90, 0);
            var _known = __test_ngram_guess(_m, _ag, 90).confidence;
            var _new = __test_ngram_guess(_m, _ag, 10).confidence;
            gmsa_test_assert_true(_known > 0.5, "healthy, as always: " + string(_known));
            gmsa_test_assert_true(_new < 0.05, "never seen hurt: " + string(_new));
        });

        gmsa_test_case("a break starts the history over", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_ngram_shopper();
            __test_ngram_buy(_m, _ag, 50, 0);
            __test_ngram_buy(_m, _ag, 50, 1);
            gmsa_learn_tdnn_break(_m, _ag);
            __test_ngram_guess(_m, _ag, 50);
            gmsa_test_assert_equal(_m.__ids, [-1], "only the start");
        });

        gmsa_test_case("learn spaces are refused", function() {
            var _space = gmsa_learn_space("shop", ["sword", "shield", "potion"], ["hp"]);
            var _m = gmsa_learn_tdnn_create();
            gmsa_test_assert_throws(method({ s : _space, m : _m }, function() {
                gmsa_learn_space_observe(m, s, [{ action : 0, inputs : [0.5] }, { action : 1, inputs : [0.5] }], 0);
            }));
        });

        gmsa_test_case("save and load keep what was learned", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_ngram_shopper();
            repeat (20) {
                __test_ngram_buy(_m, _ag, 50, 0);
                __test_ngram_buy(_m, _ag, 50, 1);
                __test_ngram_buy(_m, _ag, 50, 2);
            }
            gmsa_learn_tdnn_break(_m, _ag);
            var _before = __test_ngram_guess(_m, _ag, 50).p[0];
            var _json = gmsa_learn_save(_m);
            var _copy = gmsa_learn_tdnn_create();
            gmsa_learn_load(_copy, _json);
            gmsa_test_assert_near(__test_ngram_guess(_copy, _ag, 50).p[0], _before, 0.0001, "a fresh history in both");
            gmsa_test_assert_throws(method({ j : _json }, function() { gmsa_learn_load(gmsa_learn_tdnn_create({ layers : [8] }), j); }), "other layers");
            gmsa_test_assert_throws(method({ j : _json }, function() { gmsa_learn_load(gmsa_learn_tdnn_create({ remember : ["hp"] }), j); }), "other remember");
        });

        gmsa_test_case("explain names what it leans on", function() {
            var _m = gmsa_learn_tdnn_create();
            var _ag = __test_ngram_shopper();
            repeat (30) {
                __test_ngram_buy(_m, _ag, 50, 0);
                __test_ngram_buy(_m, _ag, 50, 1);
                __test_ngram_buy(_m, _ag, 50, 2);
            }
            __test_ngram_buy(_m, _ag, 50, 0);
            var _lines = gmsa_learn_explain(_m, gmsa_agent_evaluate(_ag), 1);
            gmsa_test_assert_true(string_pos("shield", _lines[0]) == 1, _lines[0]);
            gmsa_test_assert_true(string_pos("1 back: sword", _lines[0]) > 0, _lines[0]);
        });

        gmsa_test_case("outcomes: the boss learns which move pays off after which", function() {
            random_set_seed(7);
            var _m = gmsa_learn_tdnn_create({ learns : gmsa_learn_target.OUTCOMES });
            var _boss = __test_ngram_boss();
            var _names = ["feint", "sweep", "heavy"];
            var _last = ["", ""];
            repeat (300) {
                var _move = _names[irandom(2)];
                var _ticket = __test_ngram_boss_move(_boss, _move);
                var _reward = (_move == "heavy") ? ((_last[0] == "feint" && _last[1] == "sweep") ? 1 : -1) : 0;
                gmsa_learn_outcome(_m, _ticket, _reward);
                _last[0] = _last[1];
                _last[1] = _move;
            }
            __test_ngram_boss_move(_boss, "feint");
            __test_ngram_boss_move(_boss, "sweep");
            gmsa_test_assert_equal(gmsa_learn_predict(_m, gmsa_agent_evaluate(_boss)).best, 2, "feint, sweep: now the heavy attack");
            __test_ngram_boss_move(_boss, "sweep");
            __test_ngram_boss_move(_boss, "sweep");
            gmsa_test_assert_true(gmsa_learn_predict(_m, gmsa_agent_evaluate(_boss)).best != 2, "sweep, sweep: not the heavy attack");
        });

        gmsa_test_case("outcomes: the tracker must keep more than the history length", function() {
            var _m = gmsa_learn_tdnn_create({ learns : gmsa_learn_target.OUTCOMES, length : 5 });
            var _boss = __test_ngram_boss(5);
            gmsa_test_assert_throws(method({ m : _m, b : _boss }, function() {
                gmsa_learn_outcome(m, __test_ngram_boss_move(b, "feint"), 1);
            }));
        });
    });
}

function __test_tdnn_shop() {
    static _profile = undefined;
    if (_profile == undefined) {
        _profile = gmsa_profile_create("tdnn shop");
        gmsa_profile_add_input(_profile, gmsa_input_pull("price", function(_agent, _t) { return _t.price; }, 0, 100, true));
        gmsa_profile_set_features(_profile, ["price"]);
        gmsa_profile_add_action(_profile, "sword", { targets : function(_agent) { return [_agent.sword]; } });
        gmsa_profile_add_action(_profile, "potion", { targets : function(_agent) { return _agent.potions; } });
        gmsa_profile_build(_profile);
    }
    var _ag = gmsa_agent_create(_profile);
    _ag.sword = { price : 0 };
    _ag.potions = [];
    return _ag;
}

function __test_tdnn_potion_shop() {
    static _profile = undefined;
    if (_profile == undefined) {
        _profile = gmsa_profile_create("tdnn potion shop");
        gmsa_profile_add_input(_profile, gmsa_input_pull("price", function(_agent, _t) { return _t.price; }, 0, 100, true));
        gmsa_profile_set_features(_profile, ["price"]);
        gmsa_profile_add_action(_profile, "potion", { targets : function(_agent) { return _agent.potions; } });
        gmsa_profile_build(_profile);
    }
    var _ag = gmsa_agent_create(_profile);
    _ag.sword = undefined;
    _ag.potions = [];
    return _ag;
}

function __test_tdnn_potions(_rng) {
    return [{ price : gmsa_rng_next(_rng) * 100 }, { price : gmsa_rng_next(_rng) * 100 }, { price : gmsa_rng_next(_rng) * 100 }];
}

function __test_tdnn_cheapest(_potions) {
    var _b = 0;
    for (var _i = 1; _i < array_length(_potions); _i++) if (_potions[_i].price < _potions[_b].price) _b = _i;
    return _b;
}

function __test_tdnn_priciest(_potions) {
    var _b = 0;
    for (var _i = 1; _i < array_length(_potions); _i++) if (_potions[_i].price > _potions[_b].price) _b = _i;
    return _b;
}

function __test_tdnn_shop_buy(_model, _agent, _potions, _pick) {
    var _options = [];
    if (_agent.sword != undefined) array_push(_options, { action : "sword", target : _agent.sword });
    for (var _i = 0; _i < array_length(_potions); _i++) array_push(_options, { action : "potion", target : _potions[_i] });
    var _chosen = (_pick < 0) ? 0 : _pick + ((_agent.sword != undefined) ? 1 : 0);
    gmsa_learn_observe(_model, gmsa_observe(_agent, _options, _chosen));
}

function __test_tdnn_shop_guess(_model, _agent, _potions) {
    _agent.potions = _potions;
    var _d = gmsa_agent_evaluate(_agent);
    var _o = _d.options[gmsa_learn_predict(_model, _d).best];
    if (_agent.sword != undefined && _o.target == _agent.sword) return -1;
    for (var _i = 0; _i < array_length(_potions); _i++) if (_o.target == _potions[_i]) return _i;
    return -2;
}