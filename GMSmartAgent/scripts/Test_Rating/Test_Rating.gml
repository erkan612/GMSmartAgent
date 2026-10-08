function test_rating() {
    gmsa_test_suite("Rating", function() {
        gmsa_test_case("settings: nonsense throws, no upper limits", function() {
            var _bad = [{ start : "x" }, { unsure : 0 }, { luck : 0 }, { drift : -1 }, { idle : "yes" }, { capacity : 0 }, { capacity : 1.5 }, { from : {} }];
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ p : _bad[_i] }, function() { gmsa_rating_pool_create(p); }), "case " + string(_i));
            }
            var _big = gmsa_rating_pool_create({ start : 100000, unsure : 100000, luck : 100000, drift : 1000, capacity : 1000000 });
            gmsa_test_assert_equal(gmsa_rating_get(_big, "a").rating, 100000);
        });

        gmsa_test_case("a new entry: the start, unsure, an even chance", function() {
            var _p = gmsa_rating_pool_create();
            var _g = gmsa_rating_get(_p, "erkan");
            gmsa_test_assert_equal(_g.rating, 1500);
            gmsa_test_assert_near(_g.unsure, 250);
            gmsa_test_assert_false(_g.known);
            gmsa_test_assert_near(gmsa_rating_chance(_p, "erkan", "ogre"), 0.5);
            gmsa_test_assert_equal(array_length(gmsa_rating_names(_p)), 0, "reading doesn't create");
        });

        gmsa_test_case("a win moves the winner up and the loser down, by the same amount when equally sure", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_match(_p, { teams : [["a"], ["b"]], places : [1, 2] });
            var _a = gmsa_rating_get(_p, "a").rating;
            var _b = gmsa_rating_get(_p, "b").rating;
            gmsa_test_assert_true(_a > 1500 && _b < 1500, string(_a) + " " + string(_b));
            gmsa_test_assert_near(_a - 1500, 1500 - _b, 0.001);
            gmsa_test_assert_true(gmsa_rating_get(_p, "a").unsure < 250, "surer after a match");
        });

        gmsa_test_case("a sure entry moves less than an unsure one", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_set(_p, "veteran", { unsure : 50 });
            gmsa_rating_match(_p, { teams : [["newcomer"], ["veteran"]], places : [1, 2] });
            var _gain = gmsa_rating_get(_p, "newcomer").rating - 1500;
            var _loss = 1500 - gmsa_rating_get(_p, "veteran").rating;
            gmsa_test_assert_true(_gain > 5 * _loss, "gain " + string(_gain) + ", loss " + string(_loss));
        });

        gmsa_test_case("places: equal places are ties", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_match(_p, { teams : [["a"], ["b"], ["c"]], places : [1, 1, 3] });
            gmsa_test_assert_near(gmsa_rating_get(_p, "a").rating, gmsa_rating_get(_p, "b").rating, 0.001);
            gmsa_test_assert_true(gmsa_rating_get(_p, "a").rating > 1500 && gmsa_rating_get(_p, "c").rating < 1500);
        });

        gmsa_test_case("scores: a narrow win moves less than a crushing one", function() {
            var _crush = gmsa_rating_pool_create();
            gmsa_rating_match(_crush, { teams : [["player"], ["ogre"]], scores : [1, 0] });
            var _narrow = gmsa_rating_pool_create();
            gmsa_rating_match(_narrow, { teams : [["player"], ["ogre"]], scores : [0.6, 0.4] });
            var _c = gmsa_rating_get(_crush, "player").rating - 1500;
            var _n = gmsa_rating_get(_narrow, "player").rating - 1500;
            gmsa_test_assert_true(_c > _n && _n > 0, "crushing " + string(_c) + ", narrow " + string(_n));
        });

        gmsa_test_case("allies aren't compared with each other", function() {
            var _with = gmsa_rating_pool_create();
            gmsa_rating_match(_with, { teams : [["a"], ["b"], ["c"]], places : [1, 2, 3], allies : [[0, 1]] });
            var _without = gmsa_rating_pool_create();
            gmsa_rating_match(_without, { teams : [["a"], ["b"], ["c"]], places : [1, 2, 3] });
            var _b_with = gmsa_rating_get(_with, "b").rating;
            var _b_without = gmsa_rating_get(_without, "b").rating;
            gmsa_test_assert_true(_b_with > 1500, "b beat its only rival: " + string(_b_with));
            gmsa_test_assert_true(_b_with > _b_without + 1, "against a and c: " + string(_b_without));
        });

        gmsa_test_case("against: only the listed pairs are rivals", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_match(_p, { teams : [["a"], ["b"], ["c"], ["d"]], places : [1, 2, 3, 4], against : [[0, 1]] });
            gmsa_test_assert_true(gmsa_rating_get(_p, "a").rating > 1500);
            gmsa_test_assert_equal(gmsa_rating_get(_p, "c").rating, 1500);
            gmsa_test_assert_equal(gmsa_rating_get(_p, "d").rating, 1500);
            gmsa_test_assert_equal(gmsa_rating_explain(_p, "c"), "c: 1500, unsure, 1 match, last: played with no rivals");
        });

        gmsa_test_case("shares: someone who played a tenth of the match takes a smaller part of the loss", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_match(_p, { teams : [["full", "late"], ["c", "d"]], places : [2, 1], shares : [[1, 0.1], [1, 1]] });
            var _full = 1500 - gmsa_rating_get(_p, "full").rating;
            var _late = 1500 - gmsa_rating_get(_p, "late").rating;
            gmsa_test_assert_true(_full > 0 && _late > 0 && _late < _full * 0.2, "full " + string(_full) + ", late " + string(_late));
        });

        gmsa_test_case("pinned: never moves, others learn against it", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_set(_p, "ogre", { rating : 1800, pinned : true });
            repeat (3) gmsa_rating_match(_p, { teams : [["player"], ["ogre"]], places : [1, 2] });
            gmsa_test_assert_equal(gmsa_rating_get(_p, "ogre").rating, 1800);
            gmsa_test_assert_equal(gmsa_rating_get(_p, "ogre").unsure, 0);
            gmsa_test_assert_true(gmsa_rating_get(_p, "player").rating > 1600);
            gmsa_test_assert_true(string_pos("pinned", gmsa_rating_explain(_p, "ogre")) > 0);
        });

        gmsa_test_case("from: a new entry starts from its rating in another pool, unsure", function() {
            var _mixed = gmsa_rating_pool_create();
            gmsa_rating_set(_mixed, "erkan", { rating : 1800, unsure : 40 });
            var _knife = gmsa_rating_pool_create({ from : _mixed });
            var _g = gmsa_rating_get(_knife, "erkan");
            gmsa_test_assert_equal(_g.rating, 1800);
            gmsa_test_assert_near(_g.unsure, 250);
            gmsa_test_assert_equal(gmsa_rating_get(_knife, "stranger").rating, 1500);
            var _pistol = gmsa_rating_pool_create();
            gmsa_rating_set(_pistol, "erkan", { from : _mixed });
            gmsa_test_assert_equal(gmsa_rating_get(_pistol, "erkan").rating, 1800);
        });

        gmsa_test_case("learns the true order: one against one", function() {
            var _p = gmsa_rating_pool_create();
            var _rng = gmsa_rng_create(3);
            var _skill = __test_rating_skills(12);
            repeat (400) {
                var _a = floor(gmsa_rng_next(_rng) * 12);
                var _b = (_a + 1 + floor(gmsa_rng_next(_rng) * 11)) mod 12;
                var _pa = _skill[_a] + __test_rating_gauss(_rng);
                var _pb = _skill[_b] + __test_rating_gauss(_rng);
                gmsa_rating_match(_p, { teams : [["p" + string(_a)], ["p" + string(_b)]], places : (_pa > _pb) ? [1, 2] : [2, 1] });
            }
            __test_rating_order(_p, _skill);
        });

        gmsa_test_case("learns the true order: free-for-alls of 8", function() {
            var _p = gmsa_rating_pool_create();
            var _rng = gmsa_rng_create(5);
            var _skill = __test_rating_skills(12);
            repeat (80) {
                var _ids = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];
                for (var _i = 11; _i > 0; _i--) {
                    var _j = floor(gmsa_rng_next(_rng) * (_i + 1));
                    var _t = _ids[_i];
                    _ids[_i] = _ids[_j];
                    _ids[_j] = _t;
                }
                var _teams = [];
                var _perf = [];
                for (var _i = 0; _i < 8; _i++) {
                    array_push(_teams, ["p" + string(_ids[_i])]);
                    array_push(_perf, _skill[_ids[_i]] + __test_rating_gauss(_rng));
                }
                var _places = array_create(8, 1);
                for (var _i = 0; _i < 8; _i++) for (var _q = 0; _q < 8; _q++) if (_perf[_q] > _perf[_i]) _places[_i] += 1;
                gmsa_rating_match(_p, { teams : _teams, places : _places });
            }
            __test_rating_order(_p, _skill);
        });

        gmsa_test_case("chance: two sides add up to 1, a team is its members together", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_set(_p, "a", { rating : 1700 });
            gmsa_test_assert_near(gmsa_rating_chance(_p, "a", "b") + gmsa_rating_chance(_p, "b", "a"), 1);
            gmsa_test_assert_true(gmsa_rating_chance(_p, "a", "b") > 0.6);
            gmsa_test_assert_true(gmsa_rating_chance(_p, ["b", "c"], "d") > 0.9, "two against one");
        });

        gmsa_test_case("pick: the candidate closest to the target chance", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_set(_p, "player", { rating : 1500, unsure : 30 });
            gmsa_rating_set(_p, "imp", { rating : 1300, pinned : true });
            gmsa_rating_set(_p, "orc", { rating : 1500, pinned : true });
            gmsa_rating_set(_p, "ogre", { rating : 1700, pinned : true });
            gmsa_test_assert_equal(gmsa_rating_pick(_p, "player", ["imp", "orc", "ogre"]), 1, "an even fight");
            gmsa_test_assert_equal(gmsa_rating_pick(_p, "player", ["imp", "orc", "ogre"], 0.8), 0, "an easy one");
            gmsa_test_assert_equal(gmsa_rating_pick(_p, "player", ["imp", "orc", "ogre"], 0.2), 2, "a hard one");
        });

        gmsa_test_case("balance: the best split for small lobbies, any sizes", function() {
            var _p = gmsa_rating_pool_create();
            var _r = [2000, 1900, 1700, 1600, 1100, 1000];
            var _names = [];
            for (var _i = 0; _i < 6; _i++) {
                gmsa_rating_set(_p, "p" + string(_i), { rating : _r[_i], pinned : true });
                array_push(_names, "p" + string(_i));
            }
            var _t = gmsa_rating_balance(_p, _names, 2);
            gmsa_test_assert_equal(abs(__test_rating_sum(_p, _t[0]) - __test_rating_sum(_p, _t[1])), 100, "the best possible");
            var _rng = gmsa_rng_create(7);
            var _many = [];
            for (var _i = 0; _i < 8; _i++) {
                gmsa_rating_set(_p, "q" + string(_i), { rating : 1000 + floor(gmsa_rng_next(_rng) * 1000), pinned : true });
                array_push(_many, "q" + string(_i));
            }
            var _b = gmsa_rating_balance(_p, _many, [4, 4]);
            gmsa_test_assert_near(abs(__test_rating_sum(_p, _b[0]) - __test_rating_sum(_p, _b[1])), __test_rating_best_split(_p, _many), 0.001);
            var _odd = gmsa_rating_balance(_p, ["p0", "p1", "p2", "p3", "p4", "p5", "q0"], [3, 2, 2]);
            gmsa_test_assert_equal([array_length(_odd[0]), array_length(_odd[1]), array_length(_odd[2])], [3, 2, 2]);
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_rating_balance(p, ["a", "b", "c"], [2, 2]); }), "sizes don't add up");
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_rating_balance(p, ["a", "a"], 2); }), "a name twice");
        });

        gmsa_test_case("time away: rest and the pool's clock make an entry less sure", function() {
            var _p = gmsa_rating_pool_create();
            repeat (20) gmsa_rating_match(_p, { teams : [["a"], ["b"]], places : [1, 2] });
            var _before = gmsa_rating_get(_p, "a").unsure;
            gmsa_rating_rest(_p, "a", 2000);
            gmsa_test_assert_true(gmsa_rating_get(_p, "a").unsure > _before + 10, string(_before) + " to " + string(gmsa_rating_get(_p, "a").unsure));
            var _c = gmsa_rating_get(_p, "b").unsure;
            repeat (200) gmsa_rating_match(_p, { teams : [["x"], ["y"]], places : [1, 2] });
            gmsa_test_assert_true(gmsa_rating_get(_p, "b").unsure > _c, "b sat out");
            var _still = gmsa_rating_pool_create({ idle : false });
            repeat (5) gmsa_rating_match(_still, { teams : [["a"], ["b"]], places : [1, 2] });
            var _s = gmsa_rating_get(_still, "a").unsure;
            repeat (100) gmsa_rating_match(_still, { teams : [["x"], ["y"]], places : [1, 2] });
            gmsa_test_assert_equal(gmsa_rating_get(_still, "a").unsure, _s, "idle off");
        });

        gmsa_test_case("capacity: the entry idle longest goes, pinned ones stay", function() {
            var _p = gmsa_rating_pool_create({ capacity : 3 });
            gmsa_rating_set(_p, "boss", { rating : 2000, pinned : true });
            gmsa_rating_match(_p, { teams : [["a"], ["b"]], places : [1, 2] });
            gmsa_rating_match(_p, { teams : [["b"], ["c"]], places : [1, 2] });
            gmsa_test_assert_true(gmsa_rating_get(_p, "boss").known, "pinned stays");
            gmsa_test_assert_false(gmsa_rating_get(_p, "a").known, "a sat out longest");
            gmsa_test_assert_true(gmsa_rating_get(_p, "b").known && gmsa_rating_get(_p, "c").known);
        });

        gmsa_test_case("explain says how good, how sure, how many matches and the last one", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_test_assert_equal(gmsa_rating_explain(_p, "erkan"), "erkan: not rated yet");
            gmsa_rating_match(_p, { teams : [["erkan"], ["the ogre"]], scores : [0.85, 0.15] });
            var _l = gmsa_rating_explain(_p, "erkan");
            gmsa_test_assert_true(string_pos("erkan: 15", _l) == 1 && string_pos(", 1 match, last: beat the ogre (0.85)", _l) > 0, _l);
            gmsa_rating_match(_p, { teams : [["erkan"], ["b"], ["c"], ["d"]], places : [2, 1, 3, 4] });
            _l = gmsa_rating_explain(_p, "erkan");
            gmsa_test_assert_true(string_pos("2 matches, last: placed 2 of 4", _l) > 0, _l);
        });

        gmsa_test_case("save and load keep every entry", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_set(_p, "ogre", { rating : 1800, pinned : true });
            gmsa_rating_match(_p, { teams : [["erkan"], ["ogre"]], places : [1, 2] });
            var _json = gmsa_rating_save(_p);
            var _copy = gmsa_rating_pool_create();
            gmsa_rating_load(_copy, _json);
            gmsa_test_assert_near(gmsa_rating_get(_copy, "erkan").rating, gmsa_rating_get(_p, "erkan").rating, 0.0001);
            gmsa_test_assert_near(gmsa_rating_get(_copy, "erkan").unsure, gmsa_rating_get(_p, "erkan").unsure, 0.0001);
            gmsa_test_assert_true(gmsa_rating_get(_copy, "ogre").pinned);
            gmsa_test_assert_equal(gmsa_rating_explain(_copy, "erkan"), gmsa_rating_explain(_p, "erkan"));
            gmsa_test_assert_throws(method({ c : _copy }, function() { gmsa_rating_load(c, "{\"format\":\"gmsa_learn\"}"); }), "not a rating save");
        });

        gmsa_test_case("input: the chance as a pull input, sides fixed or per target", function() {
            var _p = gmsa_rating_pool_create();
            gmsa_rating_set(_p, "player", { rating : 1700 });
            var _fixed = gmsa_rating_input(_p, "player", "goblins");
            gmsa_test_assert_near(_fixed(undefined, undefined), gmsa_rating_chance(_p, "player", "goblins"));
            var _per = gmsa_rating_input(_p, function(_agent, _target) { return _target.pack; }, "player");
            gmsa_test_assert_near(_per(undefined, { pack : ["g1", "g2"] }), gmsa_rating_chance(_p, ["g1", "g2"], "player"));
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_rating_input(p, "", "x"); }), "empty name");
        });

        gmsa_test_case("a match that doesn't make sense throws", function() {
            var _bad = [
                { teams : [["a"]], places : [1] },
                { teams : [["a"], ["a"]], places : [1, 2] },
                { teams : [["a"], []], places : [1, 2] },
                { teams : [["a"], ["b"]] },
                { teams : [["a"], ["b"]], places : [1, 2], scores : [1, 0] },
                { teams : [["a"], ["b"]], places : [1] },
                { teams : [["a"], ["b"]], scores : [1.5, 0] },
                { teams : [["a"], ["b"]], places : [1, 2], against : [[0, 0]] },
                { teams : [["a"], ["b"]], places : [1, 2], against : [[0, 2]] },
                { teams : [["a"], ["b"], ["c"]], places : [1, 2, 3], allies : [[0, 1], [1, 2]] },
                { teams : [["a"], ["b"]], places : [1, 2], against : [[0, 1]], allies : [[0]] },
                { teams : [["a"], ["b"]], places : [1, 2], shares : [[0], [1]] },
                { teams : [["a"], ["b"]], places : [1, 2], shares : [[1, 1], [1]] },
            ];
            var _p = gmsa_rating_pool_create();
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ p : _p, m : _bad[_i] }, function() { gmsa_rating_match(p, m); }), "case " + string(_i));
            }
            gmsa_test_assert_equal(array_length(gmsa_rating_names(_p)), 0, "nothing was rated");
        });
    });
}

function __test_rating_skills(_n) {
    var _s = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) _s[_i] = -1.5 + 3 * _i / (_n - 1);
    return _s;
}

function __test_rating_gauss(_rng) {
    var _u = max(0.000000001, gmsa_rng_next(_rng));
    return sqrt(-2 * ln(_u)) * cos(2 * pi * gmsa_rng_next(_rng));
}

function __test_rating_order(_pool, _skill) {
    var _n = array_length(_skill);
    var _est = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) _est[_i] = gmsa_rating_get(_pool, "p" + string(_i)).rating;
    var _rank = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) for (var _j = 0; _j < _n; _j++) if (_est[_j] < _est[_i]) _rank[_i] += 1;
    var _m = (_n - 1) / 2;
    var _cov = 0;
    var _va = 0;
    var _vb = 0;
    for (var _i = 0; _i < _n; _i++) {
        _cov += (_rank[_i] - _m) * (_i - _m);
        _va += sqr(_rank[_i] - _m);
        _vb += sqr(_i - _m);
    }
    var _corr = _cov / sqrt(_va * _vb);
    gmsa_test_assert_true(_corr > 0.7, "rank correlation " + string(_corr));
    var _top = min(_est[_n - 1], _est[_n - 2], _est[_n - 3]);
    var _bottom = max(_est[0], _est[1], _est[2]);
    gmsa_test_assert_true(_top > _bottom, "best three above the worst three");
}

function __test_rating_sum(_pool, _team) {
    var _s = 0;
    for (var _i = 0; _i < array_length(_team); _i++) _s += gmsa_rating_get(_pool, _team[_i]).rating;
    return _s;
}

function __test_rating_best_split(_pool, _names) {
    var _best = infinity;
    var _total = __test_rating_sum(_pool, _names);
    for (var _mask = 0; _mask < 256; _mask++) {
        var _count = 0;
        var _s = 0;
        for (var _i = 0; _i < 8; _i++) {
            if ((_mask >> _i) & 1) {
                _count += 1;
                _s += gmsa_rating_get(_pool, _names[_i]).rating;
            }
        }
        if (_count == 4) _best = min(_best, abs(2 * _s - _total));
    }
    return _best;
}