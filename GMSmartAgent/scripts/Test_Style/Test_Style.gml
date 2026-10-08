function test_style() {
    gmsa_test_suite("Style", function() {
        gmsa_test_case("a set: nonsense throws", function() {
            var _bad = [[], ["a", "a"], [""], [{ name : "a", min : 1, max : 1 }], "kills", [{ name : "a", min : "x", max : 2 }]];
            for (var _i = 0; _i < array_length(_bad); _i++) {
                gmsa_test_assert_throws(method({ m : _bad[_i] }, function() { gmsa_style_set_create(m); }), "case " + string(_i));
            }
            var _set = gmsa_style_set_create(["kills", { name : "distance", min : 0, max : 2000 }]);
            gmsa_test_assert_equal(_set.measures, ["kills", "distance"]);
        });

        gmsa_test_case("a tracker: counts per tick, averages, shares of choices", function() {
            var _set = gmsa_style_set_create(["kills", "distance", "attack", "block"]);
            var _t = gmsa_style_tracker_create(_set);
            gmsa_style_count(_t, "kills", 3);
            gmsa_style_sample(_t, "distance", 100);
            gmsa_style_sample(_t, "distance", 200);
            gmsa_style_choice(_t, "attack");
            gmsa_style_choice(_t, "attack");
            gmsa_style_choice(_t, "block");
            gmsa_style_choice(_t, "jump"); // not a measure, still a choice
            gmsa_style_tick(_t);
            var _v = gmsa_style_values(_t);
            gmsa_test_assert_near(_v.kills, 3, 0.0001);
            gmsa_test_assert_near(_v.distance, 150, 0.0001);
            gmsa_test_assert_near(_v.attack, 0.5, 0.0001);
            gmsa_test_assert_near(_v.block, 0.25, 0.0001);
            gmsa_test_assert_throws(method({ t : _t }, function() { gmsa_style_sample(t, "kills", 1); }), "counted, then sampled");
            gmsa_test_assert_throws(method({ t : _t }, function() { gmsa_style_count(t, "nope"); }), "unknown measure");
        });

        gmsa_test_case("a tracker: recent play counts more", function() {
            var _set = gmsa_style_set_create(["kills"]);
            var _t = gmsa_style_tracker_create(_set, { half_life : 10 });
            gmsa_style_count(_t, "kills", 10);
            repeat (21) gmsa_style_tick(_t);
            var _rate = gmsa_style_values(_t).kills;
            gmsa_test_assert_true(_rate > 0 && _rate < 0.3, "10 kills long ago, then quiet: " + string(_rate) + " a tick, against 0.48 without fading");
        });

        gmsa_test_case("hand-written styles: typical values, spreads from the ranges", function() {
            var _set = __test_style_set();
            gmsa_style_add(_set, "rusher", { kills : 3, deaths : 8, distance : 150 });
            gmsa_style_add(_set, "sniper", { kills : 1.5, distance : 900, cover : 0.6 });
            var _m = gmsa_style_match(_set, { kills : 2.8, deaths : 7, distance : 200, cover : 0.2 });
            gmsa_test_assert_equal(_m.best_name, "rusher");
            gmsa_test_assert_true(_m.p[0] > 0.9 && _m.confidence == 1, "a struct of values is sure");
            var _l = gmsa_style_list(_set);
            gmsa_test_assert_near(_l[0].spread.kills, 0.15 * 10, 0.0001);
            var _open = gmsa_style_set_create(["kills", "deaths"]);
            gmsa_test_assert_throws(method({ s : _open }, function() { gmsa_style_add(s, "rusher", { kills : 3 }); }), "no range, no spread");
            gmsa_test_assert_throws(method({ s : _set }, function() { gmsa_style_add(s, "rusher", { kills : 3 }); }), "a name twice");
        });

        gmsa_test_case("fitting finds the styles and how many there are", function() {
            var _set = __test_style_set();
            var _rng = gmsa_rng_create(11);
            var _sessions = __test_style_sessions(_rng, 150, 3);
            var _job = gmsa_style_fit(_set, _sessions, { max_styles : 5, restarts : 3 });
            gmsa_test_assert_true(gmsa_style_fit_work(_job));
            gmsa_test_assert_equal(_job.found, 3);
            // every true style has a found one close to it
            var _true = __test_style_true();
            var _l = gmsa_style_list(_set);
            for (var _s = 0; _s < 3; _s++) {
                var _near = false;
                for (var _f = 0; _f < array_length(_l); _f++) {
                    if (abs(_l[_f].typical.kills - _true[_s][0]) < 0.3 && abs(_l[_f].typical.distance - _true[_s][2]) < 60) _near = true;
                }
                gmsa_test_assert_true(_near, "true style " + string(_s));
            }
            // and the sessions go where they belong
            var _map = array_create(3, -1);
            var _right = 0;
            for (var _i = 0; _i < array_length(_sessions); _i++) {
                var _b = gmsa_style_match(_set, _sessions[_i]).best;
                if (_map[_i mod 3] < 0) _map[_i mod 3] = _b;
                if (_map[_i mod 3] == _b) _right += 1;
            }
            gmsa_test_assert_true(_right / array_length(_sessions) > 0.95, "sessions placed right: " + string(_right));
        });

        gmsa_test_case("fitting: a fixed number of styles", function() {
            var _set = __test_style_set();
            var _job = gmsa_style_fit(_set, __test_style_sessions(gmsa_rng_create(12), 90, 3), { styles : 2, restarts : 2 });
            gmsa_style_fit_work(_job);
            gmsa_test_assert_equal(array_length(gmsa_style_list(_set)), 2);
        });

        gmsa_test_case("fitting in slices gives the same styles as at once", function() {
            var _sessions = __test_style_sessions(gmsa_rng_create(13), 90, 3);
            var _once = __test_style_set();
            gmsa_style_fit_work(gmsa_style_fit(_once, _sessions, { max_styles : 4, restarts : 2, seed : 5 }));
            var _sliced = __test_style_set();
            var _job = gmsa_style_fit(_sliced, _sessions, { max_styles : 4, restarts : 2, seed : 5 });
            var _calls = 0;
            while (!gmsa_style_fit_work(_job, 300) && _calls < 100000) _calls += 1;
            gmsa_test_assert_true(_calls > 5, "it took several slices: " + string(_calls));
            var _a = gmsa_style_list(_once);
            var _b = gmsa_style_list(_sliced);
            gmsa_test_assert_equal(array_length(_a), array_length(_b));
            for (var _s = 0; _s < array_length(_a); _s++) gmsa_test_assert_near(_a[_s].typical.kills, _b[_s].typical.kills, 0.000001);
        });

        gmsa_test_case("fitting on a scheduler", function() {
            var _set = __test_style_set();
            var _job = gmsa_style_fit(_set, __test_style_sessions(gmsa_rng_create(14), 150, 3), { max_styles : 5, restarts : 3 });
            var _sch = gmsa_scheduler_create(1000);
            gmsa_style_schedule(_job, _sch);
            var _steps = 0;
            while (!_job.done && _steps < 100000) {
                gmsa_scheduler_step(_sch);
                _steps += 1;
            }
            gmsa_test_assert_true(_job.done && _steps > 1, "steps " + string(_steps));
            gmsa_test_assert_equal(_job.found, 3);
        });

        gmsa_test_case("fitting again keeps the names, a new style comes unnamed", function() {
            var _set = __test_style_fitted();
            var _job = gmsa_style_fit(_set, __test_style_sessions(gmsa_rng_create(15), 200, 4), { max_styles : 5, restarts : 6 });
            gmsa_style_fit_work(_job);
            gmsa_test_assert_equal(_job.found, 4);
            var _l = gmsa_style_list(_set);
            var _names = "";
            var _unnamed = 0;
            for (var _s = 0; _s < array_length(_l); _s++) {
                _names += _l[_s].name + " ";
                if (_l[_s].name == "") _unnamed += 1;
            }
            gmsa_test_assert_true(string_pos("rusher", _names) > 0 && string_pos("sniper", _names) > 0 && string_pos("support", _names) > 0, _names);
            gmsa_test_assert_equal(_unnamed, 1);
        });

        gmsa_test_case("hand-written and found styles in one set", function() {
            var _set = __test_style_set();
            gmsa_style_add(_set, "ghost", { kills : 0, deaths : 0, cover : 0.9 });
            gmsa_style_fit_work(gmsa_style_fit(_set, __test_style_sessions(gmsa_rng_create(16), 150, 3), { max_styles : 5, restarts : 3 }));
            var _l = gmsa_style_list(_set);
            gmsa_test_assert_equal(array_length(_l), 4);
            gmsa_test_assert_true(_l[0].name == "ghost" && _l[0].hand, "the hand-written style stays");
            gmsa_test_assert_equal(gmsa_style_match(_set, { kills : 0, deaths : 0.2, distance : 1000, cover : 0.9 }).best_name, "ghost");
        });

        gmsa_test_case("like none of them: a player far from every style", function() {
            var _set = __test_style_fitted();
            var _odd = { kills : 30, deaths : 60, distance : 9000, cover : 4 };
            gmsa_test_assert_true(gmsa_style_match(_set, _odd).fit < 0.25);
            gmsa_test_assert_true(string_pos("like none of them", gmsa_style_explain(_set, _odd)) > 0);
            gmsa_test_assert_true(gmsa_style_match(_set, { kills : 3, deaths : 8, distance : 150, cover : 0.1 }).fit > 0.6, "a typical rusher");
        });

        gmsa_test_case("not sure yet: confidence grows with what the tracker has seen", function() {
            var _set = __test_style_fitted();
            var _t = gmsa_style_tracker_create(_set);
            __test_style_play(_t, 0, 1);
            var _early = gmsa_style_match(_set, _t);
            gmsa_test_assert_true(_early.confidence < 0.4, "after 1 tick: " + string(_early.confidence));
            gmsa_test_assert_true(string_pos("not sure yet", gmsa_style_explain(_set, _t)) > 0);
            __test_style_play(_t, 0, 30);
            var _late = gmsa_style_match(_set, _t);
            gmsa_test_assert_true(_late.confidence > 0.75 && _late.best_name == "rusher", string(_late.confidence) + " " + _late.best_name);
        });

        gmsa_test_case("the match follows a player who changes style", function() {
            var _set = __test_style_fitted();
            var _t = gmsa_style_tracker_create(_set, { half_life : 5 });
            __test_style_play(_t, 0, 30);
            gmsa_test_assert_equal(gmsa_style_match(_set, _t).best_name, "rusher");
            __test_style_play(_t, 1, 30);
            gmsa_test_assert_equal(gmsa_style_match(_set, _t).best_name, "sniper");
        });

        gmsa_test_case("editing: name, merge, adjust, drop", function() {
            var _set = __test_style_fitted();
            gmsa_test_assert_throws(method({ s : _set }, function() { gmsa_style_name(s, "rusher", "sniper"); }), "a name twice");
            gmsa_test_assert_throws(method({ s : _set }, function() { gmsa_style_drop(s, 7); }), "no style 7");
            gmsa_style_name(_set, "support", "medic");
            gmsa_test_assert_equal(gmsa_style_match(_set, { kills : 0.5, deaths : 2, distance : 500, cover : 0.3 }).best_name, "medic");
            gmsa_style_adjust(_set, "medic", { kills : 0.8 });
            var _list = gmsa_style_list(_set);
            gmsa_test_assert_near(_list[__test_style_find(_set, "medic")].typical.kills, 0.8);
            gmsa_style_merge(_set, "sniper", "medic");
            gmsa_test_assert_equal(array_length(gmsa_style_list(_set)), 2);
            gmsa_test_assert_true(__test_style_find(_set, "sniper") >= 0 && __test_style_find(_set, "medic") < 0);
            gmsa_style_drop(_set, "rusher");
            gmsa_test_assert_equal(array_length(gmsa_style_list(_set)), 1);
        });

        gmsa_test_case("input: a style's share as a pull input, leaning on the fallback while not sure", function() {
            var _set = __test_style_fitted();
            var _t = gmsa_style_tracker_create(_set);
            var _in = gmsa_style_input(_set, _t, "rusher", { fallback : 0.5 });
            gmsa_test_assert_near(_in(undefined, undefined), 0.5, 0.0001);
            __test_style_play(_t, 0, 30);
            gmsa_test_assert_true(_in(undefined, undefined) > 0.75);
            var _per = gmsa_style_input(_set, function(_agent, _target) { return _target.tracker; }, "sniper");
            gmsa_test_assert_true(_per(undefined, { tracker : _t }) < 0.1);
            var _nobody = gmsa_style_input(_set, _t, "nobody");
            gmsa_test_assert_equal(_nobody(undefined, undefined), 0, "no such style: the fallback");
        });

        gmsa_test_case("explain: the shares, how well and how sure, and what sets the style apart", function() {
            var _set = __test_style_fitted();
            var _l = gmsa_style_explain(_set, { kills : 3.1, deaths : 7.5, distance : 160, cover : 0.12 });
            gmsa_test_assert_true(string_pos("rusher 100%", _l) == 1 || string_pos("rusher 99%", _l) == 1, _l);
            gmsa_test_assert_true(string_pos("(fits well, sure): ", _l) > 0 && string_pos(" (rusher ", _l) > 0, _l);
        });

        gmsa_test_case("save and load keep every style", function() {
            var _set = __test_style_fitted();
            var _copy = __test_style_set();
            gmsa_style_load(_copy, gmsa_style_save(_set));
            var _x = { kills : 1.2, deaths : 2.5, distance : 700, cover : 0.5 };
            gmsa_test_assert_near(gmsa_style_match(_copy, _x).p[1], gmsa_style_match(_set, _x).p[1], 0.000001);
            var _other = gmsa_style_set_create(["kills", "deaths"]);
            gmsa_test_assert_throws(method({ o : _other, j : gmsa_style_save(_set) }, function() { gmsa_style_load(o, j); }), "other measures");
        });

        gmsa_test_case("matching needs styles and every measure", function() {
            var _set = __test_style_set();
            gmsa_test_assert_throws(method({ s : _set }, function() { gmsa_style_match(s, { kills : 1, deaths : 1, distance : 1, cover : 1 }); }), "no styles");
            var _fitted = __test_style_fitted();
            gmsa_test_assert_throws(method({ s : _fitted }, function() { gmsa_style_match(s, { kills : 1 }); }), "a measure missing");
            var _foreign = gmsa_style_tracker_create(gmsa_style_set_create(["kills"]));
            gmsa_test_assert_throws(method({ s : _fitted, t : _foreign }, function() { gmsa_style_match(s, t); }), "another set's tracker");
        });
    });
}

function __test_style_set() {
    return gmsa_style_set_create([
        { name : "kills", min : 0, max : 10 }, { name : "deaths", min : 0, max : 20 },
        { name : "distance", min : 0, max : 2000 }, { name : "cover", min : 0, max : 1 },
    ]);
}

function __test_style_true() {
    return [[3.0, 8.0, 150, 0.1], [1.5, 3.0, 900, 0.6], [0.5, 2.0, 500, 0.3], [0.3, 1.0, 1500, 0.8]];
}

function __test_style_spread() {
    return [[0.5, 1.5, 40, 0.05], [0.3, 1.0, 120, 0.1], [0.2, 0.8, 100, 0.08], [0.1, 0.5, 150, 0.08]];
}

function __test_style_gauss(_rng) {
    var _u = max(0.000000001, gmsa_rng_next(_rng));
    return sqrt(-2 * ln(_u)) * cos(2 * pi * gmsa_rng_next(_rng));
}

function __test_style_sessions(_rng, _n, _count) {
    var _t = __test_style_true();
    var _sd = __test_style_spread();
    var _names = ["kills", "deaths", "distance", "cover"];
    var _out = [];
    for (var _i = 0; _i < _n; _i++) {
        var _s = _i mod _count;
        var _v = {};
        for (var _j = 0; _j < 4; _j++) _v[$ _names[_j]] = _t[_s][_j] + _sd[_s][_j] * __test_style_gauss(_rng);
        array_push(_out, _v);
    }
    return _out;
}

function __test_style_fitted() {
    static _json = undefined;
    if (_json == undefined) {
        var _set = __test_style_set();
        gmsa_style_fit_work(gmsa_style_fit(_set, __test_style_sessions(gmsa_rng_create(21), 150, 3), { max_styles : 5, restarts : 3 }));
        var _l = gmsa_style_list(_set);
        for (var _s = 0; _s < array_length(_l); _s++) {
            var _k = _l[_s].typical.kills;
            gmsa_style_name(_set, _s, (_k > 2.2) ? "rusher" : ((_k > 1) ? "sniper" : "support"));
        }
        _json = gmsa_style_save(_set);
    }
    var _copy = __test_style_set();
    gmsa_style_load(_copy, _json);
    return _copy;
}

function __test_style_find(_set, _name) {
    var _l = gmsa_style_list(_set);
    for (var _s = 0; _s < array_length(_l); _s++) if (_l[_s].name == _name) return _s;
    return -1;
}

function __test_style_play(_tracker, _s, _ticks) {
    var _t = __test_style_true();
    repeat (_ticks) {
        gmsa_style_count(_tracker, "kills", _t[_s][0]);
        gmsa_style_count(_tracker, "deaths", _t[_s][1]);
        gmsa_style_sample(_tracker, "distance", _t[_s][2]);
        gmsa_style_sample(_tracker, "cover", _t[_s][3]);
        gmsa_style_tick(_tracker);
    }
}