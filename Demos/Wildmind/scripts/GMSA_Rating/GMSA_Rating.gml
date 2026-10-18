function gmsa_rating_pool_create(_params = {}) {
    var _start = __gmsa_param(_params, "start", 1500);
    if (!is_numeric(_start)) throw "GMSA: rating start must be a number";
    var _unsure = __gmsa_param(_params, "unsure", 250);
    if (!__gmsa_rating_above_zero(_unsure)) throw "GMSA: rating unsure must be above 0";
    var _luck = __gmsa_param(_params, "luck", 125);
    if (!__gmsa_rating_above_zero(_luck)) throw "GMSA: rating luck must be above 0";
    var _drift = __gmsa_param(_params, "drift", 2.5);
    if (!is_numeric(_drift) || _drift < 0) throw "GMSA: rating drift must be a number of 0 or more";
    var _idle = __gmsa_param(_params, "idle", true);
    if (!is_bool(_idle)) throw "GMSA: rating idle must be true or false";
    var _capacity = __gmsa_param(_params, "capacity", undefined);
    if (_capacity != undefined && (!is_numeric(_capacity) || _capacity < 1 || frac(_capacity) != 0)) throw "GMSA: rating capacity must be a whole number of 1 or more";
    var _from = __gmsa_param(_params, "from", undefined);
    if (_from != undefined) __gmsa_rating_check_pool(_from);
    return {
        __gmsa_rating : true,
        start    : _start,
        unsure   : _unsure,     // how unsure a new entry is, in rating points
        luck     : _luck,       // how much one match's result varies around skill
        drift    : _drift,      // uncertainty added each match, so ratings never freeze
        idle     : _idle,       // entries grow less sure while the pool plays without them
        capacity : _capacity,
        from     : _from,       // a pool new entries start from, when they're in it
        entries  : {},
        count    : 0,
        clock    : 0,           // the pool's own time: grows by each match's share of the entries
    };
}

function gmsa_rating_set(_pool, _name, _params) {
    __gmsa_rating_check_pool(_pool);
    __gmsa_rating_check_name(_name);
    if (!is_struct(_params)) throw "GMSA: rating set needs a struct of settings";
    var _from = __gmsa_param(_params, "from", undefined);
    if (_from != undefined) __gmsa_rating_check_pool(_from);
    var _rating = __gmsa_param(_params, "rating", undefined);
    if (_rating != undefined && !is_numeric(_rating)) throw "GMSA: rating set rating must be a number";
    var _unsure = __gmsa_param(_params, "unsure", undefined);
    if (_unsure != undefined && (!is_numeric(_unsure) || _unsure < 0)) throw "GMSA: rating set unsure must be a number of 0 or more";
    var _pinned = __gmsa_param(_params, "pinned", undefined);
    if (_pinned != undefined && !is_bool(_pinned)) throw "GMSA: rating set pinned must be true or false";

    var _e = __gmsa_rating_entry(_pool, _name);
    if (_from != undefined) {
        var _other = _from.entries[$ _name];
        if (_other != undefined) _e.rating = _other.rating;
        _e.variance = sqr(_pool.unsure);
    }
    if (_rating != undefined) _e.rating = _rating;
    if (_pinned != undefined) {
        _e.pinned = _pinned;
        if (_pinned && _unsure == undefined) _e.variance = 0; // pinned: known exactly, unless said otherwise
    }
    if (_unsure != undefined) _e.variance = sqr(_unsure);
    _e.last = _pool.clock;
    __gmsa_rating_trim(_pool);
}

function gmsa_rating_get(_pool, _name) {
    __gmsa_rating_check_pool(_pool);
    __gmsa_rating_check_name(_name);
    var _e = _pool.entries[$ _name];
    var _known = (_e != undefined);
    if (!_known) _e = __gmsa_rating_fresh(_pool, _name);
    return { rating : _e.rating, unsure : sqrt(__gmsa_rating_var(_pool, _e)), matches : _e.matches, pinned : _e.pinned, known : _known };
}

function gmsa_rating_remove(_pool, _name) {
    __gmsa_rating_check_pool(_pool);
    __gmsa_rating_check_name(_name);
    if (!variable_struct_exists(_pool.entries, _name)) return false;
    variable_struct_remove(_pool.entries, _name);
    _pool.count -= 1;
    return true;
}

function gmsa_rating_names(_pool) {
    __gmsa_rating_check_pool(_pool);
    return variable_struct_get_names(_pool.entries);
}

function gmsa_rating_reset(_pool) {
    __gmsa_rating_check_pool(_pool);
    _pool.entries = {};
    _pool.count = 0;
    _pool.clock = 0;
}

// Matches
function gmsa_rating_match(_pool, _match) {
    __gmsa_rating_check_pool(_pool);
    var _m = __gmsa_rating_check_match(_match);
    var _teams = _m.teams;
    var _n = array_length(_teams);
    var _shares = _m.shares;

    // every entry brought to now, plus this match's drift
    for (var _i = 0; _i < _n; _i++) {
        var _t = _teams[_i];
        for (var _j = 0; _j < array_length(_t); _j++) {
            var _e = __gmsa_rating_entry(_pool, _t[_j]);
            var _w = (_shares == undefined) ? 1 : _shares[_i][_j];
            if (_e.pinned || _w <= 0) continue;
            _e.variance = min(__gmsa_rating_var(_pool, _e) + sqr(_pool.drift), max(_e.variance, sqr(_pool.unsure)));
            _e.last = _pool.clock;
        }
    }

    // each team's strength, then each rival pair pulls on both
    var _tm = array_create(_n, 0);
    var _tv = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) {
        var _s = __gmsa_rating_team(_pool, _teams[_i], (_shares == undefined) ? undefined : _shares[_i]);
        _tm[_i] = _s.rating;
        _tv[_i] = _s.variance;
    }
    var _om = array_create(_n, 0);
    var _de = array_create(_n, 0);
    var _pairs = _m.pairs;
    var _l2 = 2 * sqr(_pool.luck);
    for (var _k = 0; _k < array_length(_pairs); _k += 2) {
        for (var _d = 0; _d < 2; _d++) {
            var _a = _pairs[_k + _d];
            var _b = _pairs[_k + 1 - _d];
            var _c = sqrt(_tv[_a] + _tv[_b] + _l2);
            var _p = 1 / (1 + exp(-(_tm[_a] - _tm[_b]) / _c));
            _om[_a] += _tv[_a] / _c * (__gmsa_rating_result(_m, _a, _b) - _p);
            _de[_a] += (sqrt(_tv[_a]) / _c) * _tv[_a] / (_c * _c) * _p * (1 - _p);
        }
    }
    var _entries_in = 0;
    for (var _i = 0; _i < _n; _i++) {
        var _t = _teams[_i];
        var _text = __gmsa_rating_result_text(_m, _i);
        for (var _j = 0; _j < array_length(_t); _j++) {
            var _e = _pool.entries[$ _t[_j]];
            _e.matches += 1;
            _e.text = _text;
            _entries_in += 1;
            var _w = (_shares == undefined) ? 1 : _shares[_i][_j];
            if (_e.pinned || _w <= 0 || _tv[_i] * 1000000000000 <= 0) continue;
            var _r = _w * _e.variance / _tv[_i];
            _e.rating += _r * _om[_i];
            _e.variance *= max(1 - _r * _de[_i], 0.0001);
        }
    }
    _pool.clock += _entries_in / max(1, _pool.count);
    __gmsa_rating_trim(_pool);
}

function gmsa_rating_chance(_pool, _a, _b) {
    __gmsa_rating_check_pool(_pool);
    var _ta = __gmsa_rating_side(_a);
    var _tb = __gmsa_rating_side(_b);
    var _sa = __gmsa_rating_team(_pool, _ta, undefined);
    var _ma = _sa.rating;
    var _va = _sa.variance;
    var _sb = __gmsa_rating_team(_pool, _tb, undefined);
    var _c = sqrt(_va + _sb.variance + 2 * sqr(_pool.luck));
    return 1 / (1 + exp(-(_ma - _sb.rating) / _c));
}

function gmsa_rating_pick(_pool, _side, _candidates, _target = 0.5) {
    __gmsa_rating_check_pool(_pool);
    if (!is_array(_candidates) || array_length(_candidates) == 0) throw "GMSA: rating pick needs a non-empty array of candidates";
    if (!is_numeric(_target) || _target < 0 || _target > 1) throw "GMSA: rating pick target must be between 0 and 1";
    var _best = 0;
    var _gap = infinity;
    for (var _i = 0; _i < array_length(_candidates); _i++) {
        var _g = abs(gmsa_rating_chance(_pool, _side, _candidates[_i]) - _target);
        if (_g < _gap) {
            _gap = _g;
            _best = _i;
        }
    }
    return _best;
}

function gmsa_rating_balance(_pool, _names, _sizes, _budget = 1000) {
    __gmsa_rating_check_pool(_pool);
    if (!is_numeric(_budget) || _budget < 0 || frac(_budget) != 0) throw "GMSA: rating balance budget must be a whole number of 0 or more";
    if (!is_array(_names) || array_length(_names) == 0) throw "GMSA: rating balance needs a non-empty array of names";
    var _n = array_length(_names);
    var _seen = {};
    for (var _i = 0; _i < _n; _i++) {
        __gmsa_rating_check_name(_names[_i]);
        if (variable_struct_exists(_seen, _names[_i])) throw "GMSA: rating balance names '" + _names[_i] + "' twice";
        _seen[$ _names[_i]] = true;
    }
    var _size = [];
    if (is_numeric(_sizes)) {
        if (_sizes < 1 || frac(_sizes) != 0 || _sizes > _n) throw "GMSA: rating balance needs a whole number of teams from 1 to the number of names";
        for (var _k = 0; _k < _sizes; _k++) array_push(_size, floor(_n / _sizes) + ((_k < _n mod _sizes) ? 1 : 0));
    } else if (is_array(_sizes) && array_length(_sizes) > 0) {
        var _total = 0;
        for (var _k = 0; _k < array_length(_sizes); _k++) {
            if (!is_numeric(_sizes[_k]) || _sizes[_k] < 1 || frac(_sizes[_k]) != 0) throw "GMSA: rating balance team sizes must be whole numbers of 1 or more";
            array_push(_size, _sizes[_k]);
            _total += _sizes[_k];
        }
        if (_total != _n) throw "GMSA: rating balance team sizes add up to " + string(_total) + ", there are " + string(_n) + " names";
    } else {
        throw "GMSA: rating balance sizes must be a number of teams or an array of team sizes";
    }
    var _k = array_length(_size);

    // strongest first, each to the weakest team with room
    var _order = array_create(_n, 0);
    for (var _i = 0; _i < _n; _i++) _order[_i] = { name : _names[_i], rating : gmsa_rating_get(_pool, _names[_i]).rating, pos : 0 };
    array_sort(_order, function(_a, _b) { return (_b.rating > _a.rating) ? 1 : ((_b.rating < _a.rating) ? -1 : 0); });
    for (var _i = 0; _i < _n; _i++) _order[_i].pos = _i;
    var _teams = array_create(_k, 0);
    var _sums = array_create(_k, 0);
    for (var _t = 0; _t < _k; _t++) _teams[_t] = [];
    for (var _i = 0; _i < _n; _i++) {
        var _pick = -1;
        for (var _t = 0; _t < _k; _t++) {
            if (array_length(_teams[_t]) >= _size[_t]) continue;
            if (_pick < 0 || _sums[_t] < _sums[_pick]) _pick = _t;
        }
        array_push(_teams[_pick], _order[_i]);
        _sums[_pick] += _order[_i].rating;
    }

    // then the best swap between two teams, again and again, while it narrows the spread
    var _mean = 0;
    for (var _t = 0; _t < _k; _t++) _mean += _sums[_t] / _k;
    var _guard = 0;
    while (_guard < 1000) {
        _guard += 1;
        var _best = 0;
        var _bt = -1;
        var _bu = -1;
        var _bi = -1;
        var _bj = -1;
        for (var _t = 0; _t < _k; _t++) {
            for (var _u = _t + 1; _u < _k; _u++) {
                var _before = sqr(_sums[_t] - _mean) + sqr(_sums[_u] - _mean);
                for (var _i = 0; _i < array_length(_teams[_t]); _i++) {
                    for (var _j = 0; _j < array_length(_teams[_u]); _j++) {
                        var _d = _teams[_u][_j].rating - _teams[_t][_i].rating;
                        var _gain = _before - sqr(_sums[_t] + _d - _mean) - sqr(_sums[_u] - _d - _mean);
                        if (_gain > _best + 0.000001) {
                            _best = _gain;
                            _bt = _t; _bu = _u; _bi = _i; _bj = _j;
                        }
                    }
                }
            }
        }
        if (_bt < 0) break;
        var _x = _teams[_bt][_bi];
        var _y = _teams[_bu][_bj];
        var _ta = _teams[_bt];
        var _tb = _teams[_bu];
        _ta[@ _bi] = _y;
        _tb[@ _bj] = _x;
        _sums[_bt] += _y.rating - _x.rating;
        _sums[_bu] += _x.rating - _y.rating;
    }
    // a search for a split whose strongest and weakest teams are closer to the mean, starting from this one
    var _c = { n : _n, k : _k, size : _size, mean : _mean, budget : _budget, nodes : 0, best : 0,
               v : array_create(_n, 0), at : array_create(_n, 0), best_at : array_create(_n, 0),
               count : array_create(_k, 0), sums : array_create(_k, 0) };
    for (var _i = 0; _i < _n; _i++) _c.v[_i] = _order[_i].rating;
    for (var _t = 0; _t < _k; _t++) {
        _c.best = max(_c.best, abs(_sums[_t] - _mean));
        for (var _i = 0; _i < array_length(_teams[_t]); _i++) _c.best_at[_teams[_t][_i].pos] = _t;
    }
    if (_budget > 0) __gmsa_rating_balance_search(_c, 0);

    var _out = array_create(_k, 0);
    for (var _t = 0; _t < _k; _t++) _out[_t] = [];
    for (var _i = 0; _i < _n; _i++) array_push(_out[_c.best_at[_i]], _order[_i].name);
    return _out;
}

function __gmsa_rating_balance_search(_c, _pos) {
    _c.nodes += 1;
    if (_c.nodes > _c.budget) return;
    if (_pos == _c.n) {
        var _d = 0;
        for (var _t = 0; _t < _c.k; _t++) _d = max(_d, abs(_c.sums[_t] - _c.mean));
        if (_d < _c.best - 0.000001) {
            _c.best = _d;
            array_copy(_c.best_at, 0, _c.at, 0, _c.n);
        }
        return;
    }
    var _v = _c.v[_pos];
    var _next = (_pos + 1 < _c.n) ? _c.v[_pos + 1] : 0;
    var _empty = []; // sizes of the empty teams tried: another empty team of the same size is the same choice
    for (var _t = 0; _t < _c.k; _t++) {
        if (_c.count[_t] >= _c.size[_t]) continue;
        if (_c.count[_t] == 0) {
            var _dup = false;
            for (var _e = 0; _e < array_length(_empty); _e++) if (_empty[_e] == _c.size[_t]) _dup = true;
            if (_dup) continue;
            array_push(_empty, _c.size[_t]);
        }
        var _ns = _c.sums[_t] + _v;
        if (_ns - _c.mean >= _c.best - 0.000001) continue;
        var _ok = true;
        for (var _u = 0; _u < _c.k; _u++) {
            var _room = _c.size[_u] - _c.count[_u] - ((_u == _t) ? 1 : 0);
            var _s = (_u == _t) ? _ns : _c.sums[_u];
            if (((_room > 0) ? _s + _room * _next : _s) < _c.mean - _c.best + 0.000001) {
                _ok = false;
                break;
            }
        }
        if (!_ok) continue;
        _c.count[_t] += 1;
        _c.sums[_t] = _ns;
        _c.at[_pos] = _t;
        __gmsa_rating_balance_search(_c, _pos + 1);
        _c.count[_t] -= 1;
        _c.sums[_t] -= _v;
        if (_c.nodes > _c.budget) return;
    }
}

function gmsa_rating_rest(_pool, _name, _amount) {
    __gmsa_rating_check_pool(_pool);
    __gmsa_rating_check_name(_name);
    if (!is_numeric(_amount) || _amount < 0) throw "GMSA: rating rest amount must be a number of 0 or more";
    var _e = _pool.entries[$ _name];
    if (_e == undefined || _e.pinned) return;
    _e.variance = min(__gmsa_rating_var(_pool, _e) + sqr(_pool.drift) * _amount, max(_e.variance, sqr(_pool.unsure)));
    _e.last = _pool.clock;
}

function gmsa_rating_explain(_pool, _name) {
    __gmsa_rating_check_pool(_pool);
    __gmsa_rating_check_name(_name);
    var _e = _pool.entries[$ _name];
    if (_e == undefined) return _name + ": not rated yet";
    var _sd = sqrt(__gmsa_rating_var(_pool, _e));
    var _sure = _e.pinned ? "pinned" : ((_sd <= 0.25 * _pool.unsure) ? "sure" : ((_sd <= 0.5 * _pool.unsure) ? "fairly sure" : "unsure"));
    var _text = _name + ": " + string(round(_e.rating)) + ", " + _sure + ", " + string(_e.matches) + ((_e.matches == 1) ? " match" : " matches");
    if (_e.text != "") _text += ", last: " + _e.text;
    return _text;
}

function gmsa_rating_input(_pool, _side, _against) {
    __gmsa_rating_check_pool(_pool);
    if (!is_callable(_side)) __gmsa_rating_side(_side);
    if (!is_callable(_against)) __gmsa_rating_side(_against);
    var _ctx = { pool : _pool, side : _side, against : _against };
    return method(_ctx, function(_agent, _target) {
        var _a = is_callable(side) ? side(_agent, _target) : side;
        var _b = is_callable(against) ? against(_agent, _target) : against;
        return gmsa_rating_chance(pool, _a, _b);
    });
}

function gmsa_rating_save(_pool) {
    __gmsa_rating_check_pool(_pool);
    return json_stringify({ format : "gmsa_rating", version : 1, clock : _pool.clock, entries : _pool.entries });
}

function gmsa_rating_load(_pool, _json) {
    __gmsa_rating_check_pool(_pool);
    var _s = json_parse(_json);
    if (!is_struct(_s) || __gmsa_param(_s, "format", "") != "gmsa_rating") throw "GMSA: not a GMSA rating save";
    if (_s.version > 1) throw "GMSA: rating save version " + string(_s.version) + " is newer than this GMSmartAgent";
    if (!is_struct(_s[$ "entries"]) || !is_numeric(_s[$ "clock"])) throw "GMSA: rating save is malformed";
    var _names = variable_struct_get_names(_s.entries);
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _e = _s.entries[$ _names[_i]];
        if (!is_struct(_e) || !is_numeric(_e[$ "rating"]) || !is_numeric(_e[$ "variance"])) throw "GMSA: rating save is malformed";
        _e.pinned = (_e[$ "pinned"] == true);
        if (!is_string(_e[$ "text"])) _e.text = "";
    }
    _pool.entries = _s.entries;
    _pool.count = array_length(_names);
    _pool.clock = _s.clock;
}

// Internal
function __gmsa_rating_above_zero(_v) {
    return is_numeric(_v) && _v * 1000000000000 > 0;
}

function __gmsa_rating_check_pool(_pool) {
    if (!is_struct(_pool) || !variable_struct_exists(_pool, "__gmsa_rating")) throw "GMSA: expected a rating pool from gmsa_rating_pool_create";
}

function __gmsa_rating_check_name(_name) {
    if (!is_string(_name) || _name == "") throw "GMSA: a rating entry's name must be a non-empty string";
}

function __gmsa_rating_side(_side) {
    if (is_string(_side)) {
        __gmsa_rating_check_name(_side);
        return [_side];
    }
    if (!is_array(_side) || array_length(_side) == 0) throw "GMSA: a rating side must be a name or a non-empty array of names";
    for (var _i = 0; _i < array_length(_side); _i++) __gmsa_rating_check_name(_side[_i]);
    return _side;
}

function __gmsa_rating_fresh(_pool, _name) {
    var _rating = _pool.start;
    if (_pool.from != undefined) {
        var _other = _pool.from.entries[$ _name];
        if (_other != undefined) _rating = _other.rating;
    }
    return { rating : _rating, variance : sqr(_pool.unsure), matches : 0, pinned : false, last : _pool.clock, text : "" };
}

function __gmsa_rating_entry(_pool, _name) {
    var _e = _pool.entries[$ _name];
    if (_e == undefined) {
        _e = __gmsa_rating_fresh(_pool, _name);
        _pool.entries[$ _name] = _e;
        _pool.count += 1;
    }
    return _e;
}

function __gmsa_rating_var(_pool, _e) {
    if (_e.pinned || !_pool.idle) return _e.variance;
    return min(_e.variance + sqr(_pool.drift) * max(0, _pool.clock - _e.last), max(_e.variance, sqr(_pool.unsure)));
}

function __gmsa_rating_team(_pool, _team, _shares) {
    static _out = { rating : 0, variance : 0 };
    var _m = 0;
    var _v = 0;
    for (var _j = 0; _j < array_length(_team); _j++) {
        var _e = _pool.entries[$ _team[_j]];
        if (_e == undefined) _e = __gmsa_rating_fresh(_pool, _team[_j]);
        var _w = (_shares == undefined) ? 1 : _shares[_j];
        _m += _w * _e.rating;
        _v += _w * _w * __gmsa_rating_var(_pool, _e);
    }
    _out.rating = _m;
    _out.variance = _v;
    return _out;
}

function __gmsa_rating_result(_m, _a, _b) {
    if (_m.places != undefined) {
        return (_m.places[_a] < _m.places[_b]) ? 1 : ((_m.places[_a] == _m.places[_b]) ? 0.5 : 0);
    }
    return clamp(0.5 + (_m.scores[_a] - _m.scores[_b]) / 2, 0, 1);
}

function __gmsa_rating_result_text(_m, _i) {
    var _rivals = [];
    var _pairs = _m.pairs;
    for (var _k = 0; _k < array_length(_pairs); _k += 2) {
        if (_pairs[_k] == _i) array_push(_rivals, _pairs[_k + 1]);
        else if (_pairs[_k + 1] == _i) array_push(_rivals, _pairs[_k]);
    }
    if (array_length(_rivals) == 0) return "played with no rivals";
    if (array_length(_rivals) == 1) {
        var _q = _rivals[0];
        var _names = "";
        for (var _j = 0; _j < array_length(_m.teams[_q]); _j++) _names += ((_j > 0) ? " and " : "") + _m.teams[_q][_j];
        var _r = __gmsa_rating_result(_m, _i, _q);
        var _verb = (_r > 0.5) ? "beat " : ((_r < 0.5) ? "lost to " : "drew with ");
        return _verb + _names + ((_m.scores != undefined) ? " (" + string_format(_r, 1, 2) + ")" : "");
    }
    if (_m.places != undefined) return "placed " + string(_m.places[_i]) + " of " + string(array_length(_m.teams));
    var _sum = 0;
    for (var _k = 0; _k < array_length(_rivals); _k++) _sum += __gmsa_rating_result(_m, _i, _rivals[_k]);
    return "scored " + string_format(_sum / array_length(_rivals), 1, 2) + " against " + string(array_length(_rivals)) + " rivals";
}

function __gmsa_rating_check_match(_match) {
    if (!is_struct(_match)) throw "GMSA: a rating match must be a struct";
    var _teams = _match[$ "teams"];
    if (!is_array(_teams) || array_length(_teams) < 2) throw "GMSA: a rating match needs at least two teams";
    var _n = array_length(_teams);
    var _seen = {};
    for (var _i = 0; _i < _n; _i++) {
        var _t = _teams[_i];
        if (!is_array(_t) || array_length(_t) == 0) throw "GMSA: rating match team " + string(_i) + " must be a non-empty array of names";
        for (var _j = 0; _j < array_length(_t); _j++) {
            __gmsa_rating_check_name(_t[_j]);
            if (variable_struct_exists(_seen, _t[_j])) throw "GMSA: rating match has '" + _t[_j] + "' in two places";
            _seen[$ _t[_j]] = true;
        }
    }
    var _places = _match[$ "places"];
    var _scores = _match[$ "scores"];
    if ((_places == undefined) == (_scores == undefined)) throw "GMSA: a rating match needs places or scores, one of them";
    var _res = (_places != undefined) ? _places : _scores;
    if (!is_array(_res) || array_length(_res) != _n) throw "GMSA: rating match places or scores need one value per team";
    for (var _i = 0; _i < _n; _i++) {
        if (!is_numeric(_res[_i])) throw "GMSA: rating match places and scores must be numbers";
        if (_scores != undefined && (_res[_i] < 0 || _res[_i] > 1)) throw "GMSA: rating match scores must be between 0 and 1";
    }
    var _shares = _match[$ "shares"];
    if (_shares != undefined) {
        if (!is_array(_shares) || array_length(_shares) != _n) throw "GMSA: rating match shares need one array per team";
        for (var _i = 0; _i < _n; _i++) {
            if (!is_array(_shares[_i]) || array_length(_shares[_i]) != array_length(_teams[_i])) throw "GMSA: rating match shares need one value per entry, team " + string(_i);
            var _any = false;
            for (var _j = 0; _j < array_length(_shares[_i]); _j++) {
                var _w = _shares[_i][_j];
                if (!is_numeric(_w) || _w < 0 || _w > 1) throw "GMSA: rating match shares must be between 0 and 1";
                if (_w * 1000000000000 > 0) _any = true;
            }
            if (!_any) throw "GMSA: rating match team " + string(_i) + " needs someone with a share above 0";
        }
    }
    var _against = _match[$ "against"];
    var _allies = _match[$ "allies"];
    if (_against != undefined && _allies != undefined) throw "GMSA: a rating match takes against or allies, not both";
    var _pairs = [];
    if (_against != undefined) {
        if (!is_array(_against)) throw "GMSA: rating match against must be an array of pairs of team indices";
        for (var _k = 0; _k < array_length(_against); _k++) {
            var _p = _against[_k];
            if (!is_array(_p) || array_length(_p) != 2 || !__gmsa_rating_index(_p[0], _n) || !__gmsa_rating_index(_p[1], _n) || _p[0] == _p[1]) {
                throw "GMSA: rating match against needs pairs of two different team indices";
            }
            array_push(_pairs, _p[0], _p[1]);
        }
    } else {
        var _group = array_create(_n, -1);
        if (_allies != undefined) {
            if (!is_array(_allies)) throw "GMSA: rating match allies must be an array of groups of team indices";
            for (var _g = 0; _g < array_length(_allies); _g++) {
                if (!is_array(_allies[_g])) throw "GMSA: rating match allies must be an array of groups of team indices";
                for (var _k = 0; _k < array_length(_allies[_g]); _k++) {
                    var _t = _allies[_g][_k];
                    if (!__gmsa_rating_index(_t, _n)) throw "GMSA: rating match allies has a team index that doesn't exist";
                    if (_group[_t] >= 0) throw "GMSA: rating match allies puts team " + string(_t) + " in two groups";
                    _group[_t] = _g;
                }
            }
        }
        for (var _i = 0; _i < _n; _i++) {
            for (var _q = _i + 1; _q < _n; _q++) {
                if (_group[_i] >= 0 && _group[_i] == _group[_q]) continue;
                array_push(_pairs, _i, _q);
            }
        }
    }
    return { teams : _teams, places : _places, scores : _scores, shares : _shares, pairs : _pairs };
}

function __gmsa_rating_index(_v, _n) {
    return is_numeric(_v) && frac(_v) == 0 && _v >= 0 && _v < _n;
}

function __gmsa_rating_trim(_pool) {
    if (_pool.capacity == undefined) return;
    while (_pool.count > _pool.capacity) {
        var _names = variable_struct_get_names(_pool.entries);
        var _drop = undefined;
        var _oldest = infinity;
        for (var _i = 0; _i < array_length(_names); _i++) {
            var _e = _pool.entries[$ _names[_i]];
            if (!_e.pinned && _e.last < _oldest) {
                _oldest = _e.last;
                _drop = _names[_i];
            }
        }
        if (_drop == undefined) return;
        variable_struct_remove(_pool.entries, _drop);
        _pool.count -= 1;
    }
}