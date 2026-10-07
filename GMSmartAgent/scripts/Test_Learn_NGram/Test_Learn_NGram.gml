function test_learn_ngram() {
    gmsa_test_suite("Learn n-gram", function() {
        gmsa_test_case("settings: whole numbers of 1 or more, no upper limits", function() {
            var _bad = [{ length : 0 }, { length : 2.5 }, { bins : 0 }, { capacity : 0 }, { inputs : "hp" }];
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ p : _bad[_i] }, function() { gmsa_learn_ngram_create(p); }), "case " + string(_i));
            }
            var _big = gmsa_learn_ngram_create({ length : 100, bins : 64, capacity : 100000 });
            gmsa_test_assert_equal(_big.ngram.levels, [0, 2, 4, 8, 16, 32, 64]);
        });

        gmsa_test_case("untrained: an even split and no confidence", function() {
            var _m = gmsa_learn_ngram_create();
            var _out = __test_ngram_guess(_m, __test_ngram_shopper(), 50);
            gmsa_test_assert_near(_out.p[0], 1 / 3);
            gmsa_test_assert_equal(_out.confidence, 0);
        });

        gmsa_test_case("learns the order: sword, shield, potion", function() {
            var _m = gmsa_learn_ngram_create();
            var _ag = __test_ngram_shopper();
            repeat (20) {
                __test_ngram_buy(_m, _ag, 50, 0);
                __test_ngram_buy(_m, _ag, 50, 1);
                __test_ngram_buy(_m, _ag, 50, 2);
            }
            __test_ngram_buy(_m, _ag, 50, 0);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 50).best, 1, "after a sword, a shield");
            __test_ngram_buy(_m, _ag, 50, 1);
            var _out = __test_ngram_guess(_m, _ag, 50);
            gmsa_test_assert_equal(_out.best, 2, "after a shield, a potion");
            gmsa_test_assert_true(_out.sure > 0.5);
        });

        gmsa_test_case("learns order and situation together: after a shield, a potion only when hurt", function() {
            var _m = gmsa_learn_ngram_create();
            var _ag = __test_ngram_shopper();
            for (var _i = 0; _i < 40; _i++) {
                var _hp = (_i mod 2 == 0) ? 15 : 85;
                __test_ngram_buy(_m, _ag, _hp, 0);
                __test_ngram_buy(_m, _ag, _hp, 1);
                __test_ngram_buy(_m, _ag, _hp, (_hp < 30) ? 2 : 0);
            }
            __test_ngram_buy(_m, _ag, 15, 0);
            __test_ngram_buy(_m, _ag, 15, 1);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 15).best, 2, "hurt: a potion");
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 85).best, 0, "healthy, same history: a sword");
        });
		
        gmsa_test_case("one model, habits that disagree: hurt means a potion, whatever came before", function() {
            var _m = gmsa_learn_ngram_create();
            var _ag = __test_ngram_shopper();
            var _last = -1;
            // sword then shield, shield then sword, a potion then a sword, but always a potion when hurt
            for (var _i = 0; _i < 300; _i++) {
                var _hp = (_i * 37) mod 100;
                var _item = (_hp < 20) ? 2 : ((_last == 0) ? 1 : 0);
                __test_ngram_buy(_m, _ag, _hp, _item);
                _last = _item;
            }
            __test_ngram_buy(_m, _ag, 10, 2);
            __test_ngram_buy(_m, _ag, 80, 0);
            var _g = __test_ngram_guess(_m, _ag, 10);
            gmsa_test_assert_equal(_g.best, 2, "after a sword, hurt: a potion");
            gmsa_test_assert_true(_g.p[2] > 0.8, "and sure of it: " + string(_g.p[2]));
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 80).best, 1, "after a sword, healthy: a shield");
            __test_ngram_buy(_m, _ag, 80, 1);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 80).best, 0, "after a shield, healthy: a sword");
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 10).best, 2, "after a shield, hurt: a potion");
        });

        gmsa_test_case("a break starts the history over, the first buy is a habit too", function() {
            var _m = gmsa_learn_ngram_create();
            var _ag = __test_ngram_shopper();
            repeat (20) {
                gmsa_learn_ngram_break(_m, _ag);
                __test_ngram_buy(_m, _ag, 50, 1);
                __test_ngram_buy(_m, _ag, 50, 0);
            }
            gmsa_learn_ngram_break(_m, _ag);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 50).best, 1, "first a shield");
            __test_ngram_buy(_m, _ag, 50, 1);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 50).best, 0, "then a sword");
        });

        gmsa_test_case("each agent has its own history", function() {
            var _m = gmsa_learn_ngram_create();
            var _a = __test_ngram_shopper();
            var _b = __test_ngram_shopper();
            repeat (20) {
                __test_ngram_buy(_m, _a, 50, 0);
                __test_ngram_buy(_m, _a, 50, 1);
                __test_ngram_buy(_m, _a, 50, 2);
            }
            __test_ngram_buy(_m, _b, 50, 0);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _b, 50).best, 1, "b just bought a sword");
            __test_ngram_buy(_m, _a, 50, 0);
            __test_ngram_buy(_m, _a, 50, 1);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _a, 50).best, 2, "a just bought a shield");
        });

        gmsa_test_case("long histories learn too", function() {
            var _m = gmsa_learn_ngram_create({ length : 12 });
            var _ag = __test_ngram_shopper();
            var _cycle = [0, 0, 1, 2, 1, 0]; // sword, sword, shield, potion, shield, sword
            repeat (20) for (var _i = 0; _i < array_length(_cycle); _i++) __test_ngram_buy(_m, _ag, 50, _cycle[_i]);
            for (var _i = 0; _i < 3; _i++) __test_ngram_buy(_m, _ag, 50, _cycle[_i]);
            gmsa_test_assert_equal(__test_ngram_guess(_m, _ag, 50).best, 2, "sword, sword, shield: a potion");
        });

        gmsa_test_case("capacity: the oldest contexts are forgotten", function() {
            var _m = gmsa_learn_ngram_create({ capacity : 20 });
            var _ag = __test_ngram_shopper();
            for (var _i = 0; _i < 60; _i++) __test_ngram_buy(_m, _ag, irandom(100), irandom(2));
            gmsa_test_assert_true(_m.data.count <= 20);
            gmsa_test_assert_equal(_m.data.count, array_length(variable_struct_get_names(_m.data.contexts)));
        });

        gmsa_test_case("learn spaces are refused", function() {
            var _space = gmsa_learn_space("shop", ["sword", "shield", "potion"], ["hp"]);
            var _m = gmsa_learn_ngram_create();
            gmsa_test_assert_throws(method({ s : _space, m : _m }, function() {
                gmsa_learn_space_observe(m, s, [{ action : 0, inputs : [0.5] }, { action : 1, inputs : [0.5] }], 0);
            }));
        });

        gmsa_test_case("save and load keep what was learned", function() {
            var _m = gmsa_learn_ngram_create();
            var _ag = __test_ngram_shopper();
            repeat (15) {
                gmsa_learn_ngram_break(_m, _ag);
                __test_ngram_buy(_m, _ag, 20, 2);
                __test_ngram_buy(_m, _ag, 20, 0);
            }
            gmsa_learn_ngram_break(_m, _ag);
            var _before = __test_ngram_guess(_m, _ag, 20).p[2];
            var _copy = gmsa_learn_ngram_create();
            gmsa_learn_load(_copy, gmsa_learn_save(_m));
            gmsa_test_assert_near(__test_ngram_guess(_copy, _ag, 20).p[2], _before, 0.0001, "a fresh history in both");
            var _other = gmsa_learn_ngram_create({ bins : 4 });
            gmsa_test_assert_throws(method({ o : _other, j : gmsa_learn_save(_m) }, function() { gmsa_learn_load(o, j); }));
        });

        gmsa_test_case("explain names the context it leans on", function() {
            var _m = gmsa_learn_ngram_create();
            var _ag = __test_ngram_shopper();
            repeat (20) {
                __test_ngram_buy(_m, _ag, 10, 0);
                __test_ngram_buy(_m, _ag, 10, 2);
            }
            __test_ngram_buy(_m, _ag, 10, 0);
            //gmsa_gmsa_dummy = 0;
            var _lines = gmsa_learn_explain(_m, gmsa_agent_evaluate(_ag), 2);
            gmsa_test_assert_true(string_pos("potion", _lines[0]) > 0, _lines[0]);
            gmsa_test_assert_true(string_pos("after sword", _lines[0]) > 0 || string_pos("hp", _lines[0]) > 0, _lines[0]);
        });
		
        gmsa_test_case("outcomes: the boss learns which move pays off after which", function() {
            random_set_seed(7);
            var _m = gmsa_learn_ngram_create({ learns : gmsa_learn_target.OUTCOMES });
            var _boss = __test_ngram_boss();
            var _names = ["feint", "sweep", "heavy"];
            var _last = ["", ""];
            repeat (300) {
                var _move = _names[irandom(2)];
                var _ticket = __test_ngram_boss_move(_boss, _move);
                // a heavy attack only lands right after a feint and a sweep
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
            var _m = gmsa_learn_ngram_create({ learns : gmsa_learn_target.OUTCOMES, length : 5 });
            var _boss = __test_ngram_boss(5);
            gmsa_test_assert_throws(method({ m : _m, b : _boss }, function() {
                gmsa_learn_outcome(m, __test_ngram_boss_move(b, "feint"), 1);
            }));
        });

        gmsa_test_case("outcomes: a break leaves earlier decisions out of the history", function() {
            var _m = gmsa_learn_ngram_create({ learns : gmsa_learn_target.OUTCOMES });
            var _boss = __test_ngram_boss();
            __test_ngram_boss_move(_boss, "feint");
            gmsa_learn_ngram_break(_m, _boss);
            gmsa_learn_predict(_m, gmsa_agent_evaluate(_boss));
            gmsa_test_assert_equal(_m.__ids, [-1], "only the start");
        });
    });
}

function __test_ngram_shopper() {
    static _profile = undefined;
    if (_profile == undefined) {
        _profile = gmsa_profile_create("ngram shopper");
        gmsa_profile_add_input(_profile, gmsa_input_push("hp", 0, 100, 100));
        gmsa_profile_set_features(_profile, ["hp"]);
        gmsa_profile_add_action(_profile, "sword");
        gmsa_profile_add_action(_profile, "shield");
        gmsa_profile_add_action(_profile, "potion");
        gmsa_profile_build(_profile);
    }
    return gmsa_agent_create(_profile);
}

function __test_ngram_buy(_model, _agent, _hp, _item) {
    gmsa_agent_set_input(_agent, "hp", _hp);
    gmsa_learn_observe(_model, gmsa_observe(_agent, ["sword", "shield", "potion"], _item));
}

function __test_ngram_guess(_model, _agent, _hp) {
    gmsa_agent_set_input(_agent, "hp", _hp);
    return gmsa_learn_predict(_model, gmsa_agent_evaluate(_agent));
}

function __test_ngram_boss(_size = 8) {
    static _profile = undefined;
    if (_profile == undefined) {
        _profile = gmsa_profile_create("ngram boss");
        gmsa_profile_add_input(_profile, gmsa_input_push("distance", 0, 1, 0.5));
        gmsa_profile_set_features(_profile, ["distance"]);
        gmsa_profile_add_action(_profile, "feint");
        gmsa_profile_add_action(_profile, "sweep");
        gmsa_profile_add_action(_profile, "heavy");
        gmsa_profile_build(_profile);
    }
    var _boss = gmsa_agent_create(_profile);
    gmsa_learn_track(_boss, { size : _size });
    return _boss;
}

function __test_ngram_boss_move(_boss, _name) {
    var _d = gmsa_agent_think(_boss);
    var _option = undefined;
    for (var _i = 0; _i < array_length(_d.options); _i++) if (_d.options[_i].action.name == _name) _option = _d.options[_i];
    gmsa_agent_set_current_option(_boss, _option);
    var _ticket = gmsa_learn_remember(_boss);
    gmsa_agent_clear_current(_boss);
    return _ticket;
}