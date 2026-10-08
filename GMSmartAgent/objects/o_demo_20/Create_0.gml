randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
names = ["ash", "birch", "cedar", "elm", "fir", "hazel", "oak", "pine"];
// a match's luck, the same amount the rating pool assumes: one side's chance is 1 / (1 + exp(-gap / luck_c))
luck_c = sqrt(2) * 125;
elo_k = 32;
join_at = 200;
shapes = [
    { label : "1 v 1", teams : 2, size : 1 },
    { label : "2 v 2", teams : 2, size : 2 },
    { label : "4 v 4", teams : 2, size : 4 },
    { label : "free for all of 4", teams : 4, size : 1 },
    { label : "3 teams of 2", teams : 3, size : 2 },
];
wl_colour = make_color_rgb(110, 210, 120);
elo_colour = make_color_rgb(90, 140, 230);
lo = 900;
hi = 2400;

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = true;
show_true = false;

shuffled = function(_n) {
    var _a = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) _a[_i] = _i;
    for (var _i = _n - 1; _i > 0; _i--) {
        var _j = irandom(_i);
        var _t = _a[_i];
        _a[_i] = _a[_j];
        _a[_j] = _t;
    }
    return _a;
};

pct = function(_p) { return string(round(_p * 100)) + "%"; };

bot_of = function(_name) {
    for (var _i = 0; _i < array_length(bots); _i++) if (bots[_i].name == _name) return bots[_i];
    return undefined;
};

team_skill = function(_team) {
    var _s = 0;
    for (var _i = 0; _i < array_length(_team); _i++) {
        var _b = bot_of(_team[_i]);
        _s += _b.skill;
    }
    return _s;
};

team_elo = function(_team) {
    var _s = 0;
    for (var _i = 0; _i < array_length(_team); _i++) {
        var _b = bot_of(_team[_i]);
        _s += _b.elo;
    }
    return _s;
};

true_chance = function(_a, _b) { return 1 / (1 + exp(-(_a - _b) / luck_c)); };
elo_chance = function(_a, _b) { return 1 / (1 + power(10, -(_a - _b) / 400)); };

// Elo for teams and free for alls: every pair of sides is a game, a side's rating the sum of its players'
elo_update = function(_teams, _places) {
    var _k = array_length(_teams);
    var _s = array_create(_k, 0);
    for (var _t = 0; _t < _k; _t++) _s[_t] = team_elo(_teams[_t]);
    var _d = array_create(_k, 0);
    for (var _i = 0; _i < _k; _i++) {
        for (var _j = 0; _j < _k; _j++) {
            if (_i == _j) continue;
            var _won = (_places[_i] < _places[_j]) ? 1 : 0;
            _d[_i] += elo_k * (_won - elo_chance(_s[_i], _s[_j])) / (_k - 1);
        }
    }
    for (var _t = 0; _t < _k; _t++) {
        var _team = _teams[_t];
        for (var _i = 0; _i < array_length(_team); _i++) {
            var _b = bot_of(_team[_i]);
            _b.elo += _d[_t];
        }
    }
};

join_names = function(_team) {
    var _s = "";
    for (var _i = 0; _i < array_length(_team); _i++) _s += ((_i > 0) ? " + " : "") + _team[_i];
    return _s;
};

describe = function(_label, _teams, _places) {
    var _k = array_length(_teams);
    if (_k == 2) {
        var _w = (_places[0] == 1) ? 0 : 1;
        return _label + ": " + join_names(_teams[_w]) + " beat " + join_names(_teams[1 - _w]);
    }
    var _words = ["1st", "2nd", "3rd", "4th"];
    var _s = _label + ":";
    for (var _p = 1; _p <= _k; _p++) {
        for (var _t = 0; _t < _k; _t++) if (_places[_t] == _p) _s += ((_p > 1) ? "," : "") + " " + _words[_p - 1] + " " + join_names(_teams[_t]);
    }
    return _s;
};

top_by = function(_use_elo) {
    var _best = 0;
    for (var _i = 1; _i < array_length(bots); _i++) {
        var _a = _use_elo ? bots[_i].elo : gmsa_rating_get(pool, bots[_i].name).rating;
        var _b = _use_elo ? bots[_best].elo : gmsa_rating_get(pool, bots[_best].name).rating;
        if (_a > _b) _best = _i;
    }
    return bots[_best].name;
};

// pairs of bots each system puts in the true order
pairs_right = function(_use_elo) {
    var _ok = 0;
    var _all = 0;
    for (var _i = 0; _i < array_length(bots); _i++) {
        for (var _j = _i + 1; _j < array_length(bots); _j++) {
            var _a = _use_elo ? bots[_i].elo : gmsa_rating_get(pool, bots[_i].name).rating;
            var _b = _use_elo ? bots[_j].elo : gmsa_rating_get(pool, bots[_j].name).rating;
            _all += 1;
            if ((_a - _b) * (bots[_i].skill - bots[_j].skill) > 0) _ok += 1;
        }
    }
    return string(_ok) + " of " + string(_all);
};

avg = function(_list) {
    if (array_length(_list) == 0) return 0;
    var _s = 0;
    for (var _i = 0; _i < array_length(_list); _i++) _s += _list[_i];
    return _s / array_length(_list);
};

join = function() {
    if (joined_at >= 0) return;
    array_push(bots, { name : "rowan", skill : 1950, elo : 1500, newcomer : true });
    joined_at = matches;
    flash_text = "rowan joins, stronger than everyone";
    flash = 60;
};

// a match: teams given, or a random shape from random bots
play = function(_teams = undefined) {
    var _label = "fair teams";
    if (_teams == undefined) {
        var _s = shapes[irandom(array_length(shapes) - 1)];
        var _order = shuffled(array_length(bots));
        _teams = [];
        for (var _t = 0; _t < _s.teams; _t++) {
            var _team = [];
            for (var _i = 0; _i < _s.size; _i++) array_push(_team, bots[_order[_t * _s.size + _i]].name);
            array_push(_teams, _team);
        }
        _label = _s.label;
    }
    // each side's true strength plus luck: the order of those is the result
    var _k = array_length(_teams);
    var _perf = array_create(_k, 0);
    for (var _t = 0; _t < _k; _t++) _perf[_t] = team_skill(_teams[_t]) - luck_c * ln(-ln(random_range(0.000001, 0.999999)));
    var _places = array_create(_k, 0);
    for (var _t = 0; _t < _k; _t++) {
        var _p = 1;
        for (var _u = 0; _u < _k; _u++) if (_perf[_u] > _perf[_t]) _p += 1;
        _places[_t] = _p;
    }
    // two sides: what each system expected, against the truth
    if (_k == 2) {
        var _wl = gmsa_rating_chance(pool, _teams[0], _teams[1]);
        var _el = elo_chance(team_elo(_teams[0]), team_elo(_teams[1]));
        var _tr = true_chance(team_skill(_teams[0]), team_skill(_teams[1]));
        array_push(off_wl, abs(_wl - _tr));
        array_push(off_elo, abs(_el - _tr));
        if (array_length(off_wl) > 40) array_delete(off_wl, 0, 1);
        if (array_length(off_elo) > 40) array_delete(off_elo, 0, 1);
        last_odds = "Before it, " + join_names(_teams[0]) + " to win: Weng-Lin " + pct(_wl) + ", Elo " + pct(_el) + ", the truth " + pct(_tr);
    } else {
        last_odds = "Free for alls and three-way matches aren't scored for chance, only learned from.";
    }

    gmsa_rating_match(pool, { teams : _teams, places : _places });
    elo_update(_teams, _places);
    matches += 1;
    last_text = describe(_label, _teams, _places);
    flash_text = last_text;
    flash = 40;

    if (array_length(off_wl) > 0) {
        array_push(curve_wl, avg(off_wl));
        array_push(curve_elo, avg(off_elo));
        if (array_length(curve_wl) > 300) array_delete(curve_wl, 0, 1);
        if (array_length(curve_elo) > 300) array_delete(curve_elo, 0, 1);
    }
    if (joined_at >= 0) {
        if (top_wl < 0 && top_by(false) == "rowan") top_wl = matches - joined_at;
        if (top_elo < 0 && top_by(true) == "rowan") top_elo = matches - joined_at;
    }
};

next_match = function() {
    timer = 0;
    if (joined_at < 0 && matches >= join_at) join();
    play();
};

// eight bots picked at random, split as evenly as the pool can, and played at once
fair = function() {
    var _order = shuffled(array_length(bots));
    var _names = [];
    for (var _i = 0; _i < 8; _i++) array_push(_names, bots[_order[_i]].name);
    var _t = gmsa_rating_balance(pool, _names, 2);
    var _wl = gmsa_rating_chance(pool, _t[0], _t[1]);
    var _tr = true_chance(team_skill(_t[0]), team_skill(_t[1]));
    fair_text = "Fair teams: " + join_names(_t[0]) + " against " + join_names(_t[1]) + ". Weng-Lin expects " + pct(_wl) + " for the first, the truth is " + pct(_tr) + ".";
    play(_t);
};

tick = function() {
    if (flash > 0) flash -= 1;
    if (!auto) return;
    timer += 1;
    if (timer >= 20) next_match();
};

reset = function() {
    pool = gmsa_rating_pool_create();
    var _skills = [1150, 1250, 1350, 1450, 1550, 1650, 1750, 1850];
    var _order = shuffled(8);
    bots = [];
    for (var _i = 0; _i < 8; _i++) array_push(bots, { name : names[_i], skill : _skills[_order[_i]], elo : 1500, newcomer : false });
    matches = 0;
    joined_at = -1;
    top_wl = -1;
    top_elo = -1;
    off_wl = [];
    off_elo = [];
    curve_wl = [];
    curve_elo = [];
    last_text = "";
    last_odds = "";
    fair_text = "";
    flash = 0;
    flash_text = "";
    timer = 0;
    selected = "";
    row_names = [];
};
reset();