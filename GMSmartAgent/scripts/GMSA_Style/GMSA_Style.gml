function gmsa_style_set_create(_measures) {
    if (!is_array(_measures) || array_length(_measures) == 0) throw "GMSA: a style set needs a non-empty array of measures";
    var _set = { __gmsa_style : true, measures : [], lookup : {}, lo : [], hi : [], styles : [] };
    for (var _i = 0; _i < array_length(_measures); _i++) {
        var _m = _measures[_i];
        var _name = is_struct(_m) ? _m[$ "name"] : _m;
        if (!is_string(_name) || _name == "") throw "GMSA: style measure names must be non-empty strings";
        if (variable_struct_exists(_set.lookup, _name)) throw "GMSA: style measure '" + _name + "' is declared twice";
        var _lo = undefined;
        var _hi = undefined;
        if (is_struct(_m) && (_m[$ "min"] != undefined || _m[$ "max"] != undefined)) {
            _lo = _m[$ "min"];
            _hi = _m[$ "max"];
            if (!is_numeric(_lo) || !is_numeric(_hi) || _lo >= _hi) throw "GMSA: style measure '" + _name + "' needs a min below its max";
        }
        _set.lookup[$ _name] = _i;
        array_push(_set.measures, _name);
        array_push(_set.lo, _lo);
        array_push(_set.hi, _hi);
    }
    return _set;
}

function gmsa_style_add(_set, _name, _typical, _params = {}) {
    __gmsa_style_check_set(_set);
    __gmsa_style_check_new_name(_set, _name);
    if (!is_struct(_typical)) throw "GMSA: style add needs a struct of typical values";
    var _spread = __gmsa_param(_params, "spread", {});
    if (!is_struct(_spread)) throw "GMSA: style add spread must be a struct of values per measure";
    var _weight = __gmsa_param(_params, "weight", undefined);
    if (_weight != undefined && !__gmsa_style_above_zero(_weight)) throw "GMSA: style add weight must be above 0";
    var _d = array_length(_set.measures);
    var _mean = array_create(_d, 0);
    var _var = array_create(_d, 0);
    var _names = variable_struct_get_names(_typical);
    for (var _k = 0; _k < array_length(_names); _k++) {
        if (!variable_struct_exists(_set.lookup, _names[_k])) throw "GMSA: style add names an unknown measure '" + _names[_k] + "'";
    }
    for (var _j = 0; _j < _d; _j++) {
        var _name_j = _set.measures[_j];
        var _range = (_set.lo[_j] != undefined) ? _set.hi[_j] - _set.lo[_j] : undefined;
        var _t = _typical[$ _name_j];
        var _s = _spread[$ _name_j];
        if (_s != undefined && !__gmsa_style_above_zero(_s)) throw "GMSA: style add spread of '" + _name_j + "' must be above 0";
        if (_t == undefined) {
            // doesn't matter to this style: the middle of the range, spread over it
            if (_range == undefined) throw "GMSA: style '" + _name + "' leaves out '" + _name_j + "', which needs a range to do that";
            _mean[_j] = (_set.lo[_j] + _set.hi[_j]) / 2;
            _var[_j] = sqr(_range / 2);
            continue;
        }
        if (!is_numeric(_t)) throw "GMSA: style add typical value of '" + _name_j + "' must be a number";
        if (_s == undefined) {
            if (_range == undefined) throw "GMSA: style '" + _name + "' needs a spread for '" + _name_j + "', or a range declared for it";
            _s = 0.15 * _range;
        }
        _mean[_j] = _t;
        _var[_j] = sqr(_s);
    }
    if (_weight == undefined) _weight = 1;
    array_push(_set.styles, { name : _name, weight : _weight, mean : _mean, variance : _var, hand : true });
}

function gmsa_style_fit(_set, _sessions, _params = {}) {
    __gmsa_style_check_set(_set);
    if (!is_array(_sessions) || array_length(_sessions) == 0) throw "GMSA: style fit needs a non-empty array of sessions";
    var _fixed = __gmsa_param(_params, "styles", undefined);
    if (_fixed != undefined && !__gmsa_style_whole(_fixed, 1)) throw "GMSA: style fit styles must be a whole number of 1 or more";
    var _max = __gmsa_param(_params, "max_styles", 8);
    if (!__gmsa_style_whole(_max, 1)) throw "GMSA: style fit max_styles must be a whole number of 1 or more";
    var _restarts = __gmsa_param(_params, "restarts", 20);
    if (!__gmsa_style_whole(_restarts, 1)) throw "GMSA: style fit restarts must be a whole number of 1 or more";
    var _iterations = __gmsa_param(_params, "iterations", 100);
    if (!__gmsa_style_whole(_iterations, 1)) throw "GMSA: style fit iterations must be a whole number of 1 or more";
    var _keep = __gmsa_param(_params, "keep", 1);
    if (!is_numeric(_keep) || _keep < 0) throw "GMSA: style fit keep must be a number of 0 or more";
    var _patience = __gmsa_param(_params, "patience", 2);
    if (!__gmsa_style_whole(_patience, 1)) throw "GMSA: style fit patience must be a whole number of 1 or more";
    var _seed = __gmsa_param(_params, "seed", 1);
    var _n = array_length(_sessions);
    var _d = array_length(_set.measures);
    var _kmin = (_fixed != undefined) ? _fixed : 1;
    var _kmax = (_fixed != undefined) ? _fixed : min(_max, _n);
    if (_kmin > _n) throw "GMSA: style fit can't find " + string(_kmin) + " styles in " + string(_n) + " sessions";

    // every measure rescaled to mean 0 and spread 1, so none counts more for its units
    var _x = array_create(_n * _d, 0);
    for (var _i = 0; _i < _n; _i++) {
        var _v = __gmsa_style_values_of(_set, _sessions[_i]);
        for (var _j = 0; _j < _d; _j++) _x[_i * _d + _j] = _v[_j];
    }
    var _centre = array_create(_d, 0);
    var _scale = array_create(_d, 1);
    for (var _j = 0; _j < _d; _j++) {
        var _s = 0;
        for (var _i = 0; _i < _n; _i++) _s += _x[_i * _d + _j];
        _centre[_j] = _s / _n;
        var _q = 0;
        for (var _i = 0; _i < _n; _i++) _q += sqr(_x[_i * _d + _j] - _centre[_j]);
        _scale[_j] = (_q * 1000000000000 > 0) ? sqrt(_q / _n) : 1;
        for (var _i = 0; _i < _n; _i++) _x[_i * _d + _j] = (_x[_i * _d + _j] - _centre[_j]) / _scale[_j];
    }

    var _job = {
        __gmsa_style_job : true, set : _set, n : _n, d : _d, x : _x, centre : _centre, scale : _scale,
        kmin : _kmin, kmax : _kmax, restarts : _restarts, iterations : _iterations, keep : _keep, patience : _patience, worse : 0,
        rng : gmsa_rng_create(_seed), done : false,
        k : _kmin, r : 0, phase : 0, cursor : 0, iter : 0, prev : -infinity,
        seeds : [], dmin : array_create(_n, infinity), newest : 0, total : 0, pick : 0,
        w : [], mu : [], va : [], lp : [], norm : [], iv : [],
        nk : [], s1 : [], s2 : [], ll : 0,
        best_ll : -infinity, best_w : [], best_mu : [], best_va : [], // the best restart at this number of styles
        top_bic : infinity, top_k : 0, top_w : [], top_mu : [], top_va : [], top_ll : 0,
        found : 0, bic : 0,
    };
    _job.work = method(_job, function(_budget) {
        if (done) return false;
        gmsa_style_fit_work(self, _budget);
        return true;
    });
    return _job;
}

function gmsa_style_fit_work(_job, _budget = undefined) {
    if (!is_struct(_job) || !variable_struct_exists(_job, "__gmsa_style_job")) throw "GMSA: expected a job from gmsa_style_fit";
    if (_job.done) return true;
    var _deadline = (_budget == undefined) ? infinity : get_timer() + _budget;
    var _first = true;
    while (!_job.done && (_first || get_timer() < _deadline)) {
        _first = false;
        __gmsa_style_fit_chunk(_job);
    }
    return _job.done;
}

function gmsa_style_schedule(_job, _scheduler, _priority = 0) {
    if (!is_struct(_job) || !variable_struct_exists(_job, "__gmsa_style_job")) throw "GMSA: expected a job from gmsa_style_fit";
    gmsa_scheduler_add_work(_scheduler, _job, _priority);
    return _job;
}

// Editing styles: by index, or by name
function gmsa_style_list(_set) {
    __gmsa_style_check_set(_set);
    var _out = [];
    var _d = array_length(_set.measures);
    var _total = __gmsa_style_total_weight(_set);
    for (var _s = 0; _s < array_length(_set.styles); _s++) {
        var _st = _set.styles[_s];
        var _typical = {};
        var _spread = {};
        for (var _j = 0; _j < _d; _j++) {
            _typical[$ _set.measures[_j]] = _st.mean[_j];
            _spread[$ _set.measures[_j]] = sqrt(_st.variance[_j]);
        }
        array_push(_out, { name : _st.name, label : __gmsa_style_label(_set, _s), share : _st.weight / _total, typical : _typical, spread : _spread, hand : _st.hand });
    }
    return _out;
}

function gmsa_style_name(_set, _which, _name) {
    __gmsa_style_check_set(_set);
    var _s = __gmsa_style_index(_set, _which);
    if (_set.styles[_s].name != _name) __gmsa_style_check_new_name(_set, _name);
    _set.styles[_s].name = _name;
}

function gmsa_style_drop(_set, _which) {
    __gmsa_style_check_set(_set);
    array_delete(_set.styles, __gmsa_style_index(_set, _which), 1);
}

function gmsa_style_merge(_set, _a, _b) {
    __gmsa_style_check_set(_set);
    var _ia = __gmsa_style_index(_set, _a);
    var _ib = __gmsa_style_index(_set, _b);
    if (_ia == _ib) throw "GMSA: style merge needs two different styles";
    var _x = _set.styles[_ia];
    var _y = _set.styles[_ib];
    var _w = _x.weight + _y.weight;
    var _d = array_length(_set.measures);
    var _mean = array_create(_d, 0);
    var _var = array_create(_d, 0);
    for (var _j = 0; _j < _d; _j++) {
        _mean[_j] = (_x.weight * _x.mean[_j] + _y.weight * _y.mean[_j]) / _w;
        var _m2 = (_x.weight * (_x.variance[_j] + sqr(_x.mean[_j])) + _y.weight * (_y.variance[_j] + sqr(_y.mean[_j]))) / _w;
        _var[_j] = max(_m2 - sqr(_mean[_j]), min(_x.variance[_j], _y.variance[_j]));
    }
    var _merged = { name : (_x.name != "") ? _x.name : _y.name, weight : _w, mean : _mean, variance : _var, hand : _x.hand && _y.hand };
    _set.styles[_ia] = _merged;
    array_delete(_set.styles, _ib, 1);
}

function gmsa_style_adjust(_set, _which, _typical) {
    __gmsa_style_check_set(_set);
    var _st = _set.styles[__gmsa_style_index(_set, _which)];
    if (!is_struct(_typical)) throw "GMSA: style adjust needs a struct of typical values";
    var _names = variable_struct_get_names(_typical);
    for (var _k = 0; _k < array_length(_names); _k++) {
        var _j = _set.lookup[$ _names[_k]];
        if (_j == undefined) throw "GMSA: style adjust names an unknown measure '" + _names[_k] + "'";
        if (!is_numeric(_typical[$ _names[_k]])) throw "GMSA: style adjust values must be numbers";
        _st.mean[_j] = _typical[$ _names[_k]];
    }
}

function gmsa_style_tracker_create(_set, _params = {}) {
    __gmsa_style_check_set(_set);
    var _half = __gmsa_param(_params, "half_life", 10);
    if (!__gmsa_style_above_zero(_half)) throw "GMSA: style tracker half_life must be above 0";
    var _k = __gmsa_param(_params, "confidence_k", 3);
    if (!__gmsa_style_above_zero(_k)) throw "GMSA: style tracker confidence_k must be above 0";
    var _d = array_length(_set.measures);
    return { __gmsa_style_tracker : true, set : _set, decay : power(0.5, 1 / _half), confidence_k : _k,
             kind : array_create(_d, 0), sum : array_create(_d, 0), weight : array_create(_d, 0), ticks : 0, choices : 0 };
}

function gmsa_style_count(_tracker, _measure, _amount = 1) {
    var _j = __gmsa_style_tracker_measure(_tracker, _measure, 1);
    if (!is_numeric(_amount)) throw "GMSA: style count amount must be a number";
    _tracker.sum[_j] += _amount;
}

function gmsa_style_sample(_tracker, _measure, _value) {
    var _j = __gmsa_style_tracker_measure(_tracker, _measure, 2);
    if (!is_numeric(_value)) throw "GMSA: style sample value must be a number";
    _tracker.sum[_j] += _value;
    _tracker.weight[_j] += 1;
}

function gmsa_style_choice(_tracker, _name) {
    __gmsa_style_check_tracker(_tracker);
    if (!is_string(_name) || _name == "") throw "GMSA: style choice needs a name";
    _tracker.choices += 1;
    if (!variable_struct_exists(_tracker.set.lookup, _name)) return;
    var _j = __gmsa_style_tracker_measure(_tracker, _name, 3);
    _tracker.sum[_j] += 1;
}

function gmsa_style_tick(_tracker, _amount = 1) {
    __gmsa_style_check_tracker(_tracker);
    if (!is_numeric(_amount) || _amount < 0) throw "GMSA: style tick amount must be a number of 0 or more";
    // the ticks that passed join what happened in them, then everything fades together
    var _f = power(_tracker.decay, _amount);
    for (var _j = 0; _j < array_length(_tracker.sum); _j++) {
        _tracker.sum[_j] *= _f;
        _tracker.weight[_j] *= _f;
    }
    _tracker.choices *= _f;
    _tracker.ticks = (_tracker.ticks + _amount) * _f;
}

function gmsa_style_values(_tracker) {
    __gmsa_style_check_tracker(_tracker);
    var _out = {};
    var _set = _tracker.set;
    for (var _j = 0; _j < array_length(_set.measures); _j++) _out[$ _set.measures[_j]] = __gmsa_style_tracker_value(_tracker, _j);
    return _out;
}

function gmsa_style_tracker_reset(_tracker) {
    __gmsa_style_check_tracker(_tracker);
    for (var _j = 0; _j < array_length(_tracker.sum); _j++) {
        _tracker.sum[_j] = 0;
        _tracker.weight[_j] = 0;
    }
    _tracker.ticks = 0;
    _tracker.choices = 0;
}

function gmsa_style_match(_set, _source) {
    __gmsa_style_check_set(_set);
    var _ns = array_length(_set.styles);
    if (_ns == 0) throw "GMSA: the style set has no styles yet, fit or add some";
    var _x = __gmsa_style_values_of(_set, _source);
    var _confidence = 1;
    if (is_struct(_source) && variable_struct_exists(_source, "__gmsa_style_tracker")) {
        _confidence = _source.ticks / (_source.ticks + _source.confidence_k);
    }
    var _d = array_length(_set.measures);
    var _total = __gmsa_style_total_weight(_set);
    var _lp = array_create(_ns, 0);
    var _top = -infinity;
    for (var _s = 0; _s < _ns; _s++) {
        _lp[_s] = __gmsa_style_logp(_set.styles[_s], _x, _d) + ln(_set.styles[_s].weight / _total);
        _top = max(_top, _lp[_s]);
    }
    var _sum = 0;
    for (var _s = 0; _s < _ns; _s++) {
        _lp[_s] = exp(_lp[_s] - _top);
        _sum += _lp[_s];
    }
    var _names = array_create(_ns, "");
    var _best = 0;
    for (var _s = 0; _s < _ns; _s++) {
        _lp[_s] /= _sum;
        _names[_s] = __gmsa_style_label(_set, _s);
        if (_lp[_s] > _lp[_best]) _best = _s;
    }
    // how typical: a session from the style is about 1 per measure away in its spreads, further is less like it
    var _st = _set.styles[_best];
    var _z2 = 0;
    for (var _j = 0; _j < _d; _j++) _z2 += sqr(_x[_j] - _st.mean[_j]) / _st.variance[_j];
    var _fit = exp(-max(0, _z2 / _d - 1) / 2);
    return { names : _names, p : _lp, best : _best, best_name : _names[_best], fit : _fit, confidence : _confidence, sure : _confidence * _lp[_best] };
}

function gmsa_style_input(_set, _source, _style, _params = {}) {
    __gmsa_style_check_set(_set);
    if (!is_string(_style) || _style == "") throw "GMSA: style input needs a style name";
    var _fallback = __gmsa_param(_params, "fallback", 0);
    if (!is_numeric(_fallback) || _fallback < 0 || _fallback > 1) throw "GMSA: style input fallback must be between 0 and 1";
    if (!is_callable(_source) && !is_struct(_source)) throw "GMSA: style input needs a tracker, a struct of values or a function";
    var _ctx = { set : _set, source : _source, style : _style, fallback : _fallback };
    return method(_ctx, function(_agent, _target) {
        var _src = is_callable(source) ? source(_agent, _target) : source;
        if (array_length(set.styles) == 0) return fallback;
        var _m = gmsa_style_match(set, _src);
        for (var _s = 0; _s < array_length(_m.names); _s++) {
            if (_m.names[_s] == style) return _m.p[_s] * _m.confidence + fallback * (1 - _m.confidence);
        }
        return fallback;
    });
}

function gmsa_style_explain(_set, _source) {
    var _m = gmsa_style_match(_set, _source);
    var _x = __gmsa_style_values_of(_set, _source);
    var _ns = array_length(_m.p);
    // the shares, largest first, up to three
    var _order = array_create(_ns, 0);
    for (var _s = 0; _s < _ns; _s++) _order[_s] = _s;
    array_sort(_order, method({ p : _m.p }, function(_a, _b) { return (p[_b] > p[_a]) ? 1 : ((p[_b] < p[_a]) ? -1 : 0); }));
    var _text = "";
    for (var _k = 0; _k < min(3, _ns); _k++) {
        var _s = _order[_k];
        if (_k > 0 && _m.p[_s] < 0.05) break;
        _text += ((_k > 0) ? ", " : "") + _m.names[_s] + " " + string(round(_m.p[_s] * 100)) + "%";
    }
    var _fit = (_m.fit >= 0.6) ? "fits well" : ((_m.fit >= 0.25) ? "fits loosely" : "like none of them");
    var _sure = (_m.confidence >= 0.75) ? "sure" : ((_m.confidence >= 0.4) ? "fairly sure" : "not sure yet");
    _text += " (" + _fit + ", " + _sure + ")";
    // the measures that set the best style apart from the runner-up, with the player's value and the style's typical one
    var _b = _set.styles[_m.best];
    var _r = (_ns > 1) ? _set.styles[_order[1]] : undefined;
    var _d = array_length(_set.measures);
    var _gap = array_create(_d, 0);
    for (var _j = 0; _j < _d; _j++) _gap[_j] = (_r == undefined) ? 0 : abs(_b.mean[_j] - _r.mean[_j]) / sqrt(_b.variance[_j]);
    var _used = array_create(_d, false);
    for (var _k = 0; _k < min(3, _d); _k++) {
        var _top = -1;
        for (var _j = 0; _j < _d; _j++) if (!_used[_j] && (_top < 0 || _gap[_j] > _gap[_top])) _top = _j;
        _used[_top] = true;
        _text += ((_k == 0) ? ": " : ", ") + _set.measures[_top] + " " + __gmsa_style_number(_x[_top]) + " (" + _m.best_name + " " + __gmsa_style_number(_b.mean[_top]) + ")";
    }
    return _text;
}

function gmsa_style_save(_set) {
    __gmsa_style_check_set(_set);
    return json_stringify({ format : "gmsa_style", version : 1, measures : _set.measures, styles : _set.styles });
}

function gmsa_style_load(_set, _json) {
    __gmsa_style_check_set(_set);
    var _s = json_parse(_json);
    if (!is_struct(_s) || __gmsa_param(_s, "format", "") != "gmsa_style") throw "GMSA: not a GMSA style save";
    if (_s.version > 1) throw "GMSA: style save version " + string(_s.version) + " is newer than this GMSmartAgent";
    if (!is_array(_s[$ "measures"]) || !is_array(_s[$ "styles"])) throw "GMSA: style save is malformed";
    if (array_length(_s.measures) != array_length(_set.measures)) throw "GMSA: style save has different measures than the set";
    for (var _j = 0; _j < array_length(_set.measures); _j++) {
        if (_s.measures[_j] != _set.measures[_j]) throw "GMSA: style save measures '" + string(_s.measures[_j]) + "' where the set has '" + _set.measures[_j] + "'";
    }
    var _d = array_length(_set.measures);
    for (var _i = 0; _i < array_length(_s.styles); _i++) {
        var _st = _s.styles[_i];
        if (!is_struct(_st) || !is_array(_st[$ "mean"]) || !is_array(_st[$ "variance"]) || array_length(_st.mean) != _d || array_length(_st.variance) != _d) throw "GMSA: style save is malformed";
        if (!is_string(_st[$ "name"])) _st.name = "";
        _st.hand = (_st[$ "hand"] == true);
    }
    _set.styles = _s.styles;
}

// Internal
function __gmsa_style_above_zero(_v) {
    return is_numeric(_v) && _v * 1000000000000 > 0;
}

function __gmsa_style_whole(_v, _min) {
    return is_numeric(_v) && frac(_v) == 0 && _v >= _min;
}

function __gmsa_style_check_set(_set) {
    if (!is_struct(_set) || !variable_struct_exists(_set, "__gmsa_style")) throw "GMSA: expected a style set from gmsa_style_set_create";
}

function __gmsa_style_check_tracker(_tracker) {
    if (!is_struct(_tracker) || !variable_struct_exists(_tracker, "__gmsa_style_tracker")) throw "GMSA: expected a style tracker from gmsa_style_tracker_create";
}

function __gmsa_style_check_new_name(_set, _name) {
    if (!is_string(_name) || _name == "") throw "GMSA: a style's name must be a non-empty string";
    for (var _s = 0; _s < array_length(_set.styles); _s++) if (_set.styles[_s].name == _name) throw "GMSA: there is already a style named '" + _name + "'";
}

function __gmsa_style_index(_set, _which) {
    if (is_string(_which)) {
        for (var _s = 0; _s < array_length(_set.styles); _s++) if (_set.styles[_s].name == _which) return _s;
        throw "GMSA: no style named '" + _which + "'";
    }
    if (!__gmsa_style_whole(_which, 0) || _which >= array_length(_set.styles)) throw "GMSA: no style " + string(_which);
    return _which;
}

function __gmsa_style_label(_set, _s) {
    var _name = _set.styles[_s].name;
    return (_name != "") ? _name : "style " + string(_s + 1);
}

function __gmsa_style_total_weight(_set) {
    var _t = 0;
    for (var _s = 0; _s < array_length(_set.styles); _s++) _t += _set.styles[_s].weight;
    return _t;
}

function __gmsa_style_number(_v) {
    return (abs(_v) >= 100) ? string(round(_v)) : string_format(_v, 1, 2);
}

function __gmsa_style_values_of(_set, _source) {
    var _d = array_length(_set.measures);
    var _x = array_create(_d, 0);
    if (is_struct(_source) && variable_struct_exists(_source, "__gmsa_style_tracker")) {
        if (_source.set != _set) throw "GMSA: that style tracker belongs to another style set";
        for (var _j = 0; _j < _d; _j++) _x[_j] = __gmsa_style_tracker_value(_source, _j);
        return _x;
    }
    if (!is_struct(_source)) throw "GMSA: style values must be a tracker or a struct with a value per measure";
    for (var _j = 0; _j < _d; _j++) {
        var _v = _source[$ _set.measures[_j]];
        if (!is_numeric(_v)) throw "GMSA: style values have no number for '" + _set.measures[_j] + "'";
        _x[_j] = _v;
    }
    return _x;
}

function __gmsa_style_tracker_measure(_tracker, _measure, _kind) {
    static _words = ["", "counted", "sampled", "a choice share"];
    __gmsa_style_check_tracker(_tracker);
    var _j = _tracker.set.lookup[$ _measure];
    if (_j == undefined) throw "GMSA: style tracker has no measure '" + string(_measure) + "'";
    var _was = _tracker.kind[_j];
    if (_was != 0 && _was != _kind) {
        throw "GMSA: style measure '" + _measure + "' is " + _words[_was] + ", it can't also be " + _words[_kind];
    }
    _tracker.kind[_j] = _kind;
    return _j;
}

function __gmsa_style_tracker_value(_tracker, _j) {
    switch (_tracker.kind[_j]) {
        case 1: return (_tracker.ticks * 1000000000000 > 0) ? _tracker.sum[_j] / _tracker.ticks : 0;
        case 2: return (_tracker.weight[_j] * 1000000000000 > 0) ? _tracker.sum[_j] / _tracker.weight[_j] : 0;
        case 3: return (_tracker.choices * 1000000000000 > 0) ? _tracker.sum[_j] / _tracker.choices : 0;
    }
    return 0;
}

function __gmsa_style_logp(_st, _x, _d) {
    var _l = 0;
    for (var _j = 0; _j < _d; _j++) _l -= 0.5 * (ln(2 * pi * _st.variance[_j]) + sqr(_x[_j] - _st.mean[_j]) / _st.variance[_j]);
    return _l;
}

function __gmsa_style_fit_chunk(_job) {
    var _n = _job.n;
    var _d = _job.d;
    var _k = _job.k;
    var _x = _job.x;

    if (_job.phase == 0) {
        if (array_length(_job.seeds) == 0) {
            // a new restart: the first starting point at random, the rest far from the ones chosen (k-means++)
            var _i0 = min(_n - 1, floor(gmsa_rng_next(_job.rng) * _n));
            array_push(_job.seeds, _i0);
            _job.newest = _i0;
            var _dmin = _job.dmin;
            for (var _i = 0; _i < _n; _i++) _dmin[@ _i] = infinity;
            _job.cursor = 0;
        }
        if (array_length(_job.seeds) < _k) {
            if (_job.cursor == 0) {
                _job.total = 0;
                _job.pick = min(_n - 1, floor(gmsa_rng_next(_job.rng) * _n));  // kept only when every session sits on a starting point
            }
            var _end = min(_n, _job.cursor + max(1, floor(256 / _d)));
            var _nb = _job.newest * _d;
            var _dist = _job.dmin;
            var _rng = _job.rng;
            var _total = _job.total;
            var _pick = _job.pick;
            for (var _i = _job.cursor; _i < _end; _i++) {
                var _s = 0;
                var _b = _i * _d;
                for (var _j = 0; _j < _d; _j++) _s += sqr(_x[_b + _j] - _x[_nb + _j]);
                if (_s < _dist[_i]) _dist[@ _i] = _s;
                // each session becomes the pick with its share of the distance so far: a pick in proportion to distance, in one pass
                var _di = _dist[_i];
                if (_di > 0) {
                    _total += _di;
                    if (gmsa_rng_next(_rng) * _total < _di) _pick = _i;
                }
            }
            _job.total = _total;
            _job.pick = _pick;
            _job.cursor = _end;
            if (_end < _n) return;
            array_push(_job.seeds, _pick);
            _job.newest = _pick;
            _job.cursor = 0;
            return;
        }
        // starting points chosen: equal weights, every spread the data's own divided among the styles
        _job.w = array_create(_k, 1 / _k);
        _job.mu = array_create(_k * _d, 0);
        _job.va = array_create(_k * _d, 1 / _k + 0.001);
        for (var _c = 0; _c < _k; _c++) for (var _j = 0; _j < _d; _j++) _job.mu[_c * _d + _j] = _x[_job.seeds[_c] * _d + _j];
        __gmsa_style_fit_begin_pass(_job);
        _job.iter = 0;
        _job.prev = -infinity;
        _job.phase = 1;
        return;
    }

    // expectation: each session's share in each style, added up for the maximization at the end of the pass
    var _end2 = min(_n, _job.cursor + max(1, floor(256 / (_k * _d))));
    var _lp = _job.lp;
    var _mu = _job.mu;
    var _iv = _job.iv;
    var _norm = _job.norm;
    var _nk = _job.nk;
    var _s1 = _job.s1;
    var _s2 = _job.s2;
    var _ll = 0;
    for (var _i = _job.cursor; _i < _end2; _i++) {
        var _xb = _i * _d;
        var _top = -infinity;
        for (var _c = 0; _c < _k; _c++) {
            var _l = _norm[_c];
            var _cb = _c * _d;
            for (var _j = 0; _j < _d; _j++) _l -= 0.5 * sqr(_x[_xb + _j] - _mu[_cb + _j]) * _iv[_cb + _j];
            _lp[@ _c] = _l;
            if (_l > _top) _top = _l;
        }
        var _sum = 0;
        for (var _c = 0; _c < _k; _c++) {
            var _e = exp(_lp[_c] - _top);
            _lp[@ _c] = _e;
            _sum += _e;
        }
        _ll += _top + ln(_sum);
        for (var _c = 0; _c < _k; _c++) {
            var _r = _lp[_c] / _sum;
            if (_r < 0.000001) continue;  // a session this far from a style adds nothing to it worth the time
            _nk[@ _c] += _r;
            var _ab = _c * _d;
            for (var _j = 0; _j < _d; _j++) {
                var _v = _x[_xb + _j];
                _s1[@ _ab + _j] += _r * _v;
                _s2[@ _ab + _j] += _r * _v * _v;
            }
        }
    }
    _job.ll += _ll;
    _job.cursor = _end2;
    if (_end2 < _n) return;

    // maximization: new weights, typical values and spreads
    for (var _c = 0; _c < _k; _c++) {
        var _nc = _nk[_c];
        if (_nc < 0.000000001) continue;  // a style nobody belongs to keeps what it had
        _job.w[_c] = _nc / _n;
        for (var _j = 0; _j < _d; _j++) {
            var _m = _s1[_c * _d + _j] / _nc;
            _job.mu[_c * _d + _j] = _m;
            _job.va[_c * _d + _j] = max(_s2[_c * _d + _j] / _nc - _m * _m, 0) + 0.001;
        }
    }
    _job.iter += 1;
    var _now = _job.ll;
    var _converged = (_now - _job.prev < 0.000001 * abs(_now)) || _job.iter >= _job.iterations;
    _job.prev = _now;
    if (!_converged) {
        __gmsa_style_fit_begin_pass(_job);
        return;
    }

    // a restart finished: the best at this number of styles so far?
    if (_now > _job.best_ll) {
        _job.best_ll = _now;
        _job.best_w = __gmsa_style_copy(_job.w);
        _job.best_mu = __gmsa_style_copy(_job.mu);
        _job.best_va = __gmsa_style_copy(_job.va);
    }
    _job.r += 1;
    _job.phase = 0;
    _job.seeds = [];
    // one style has one answer, restarts can't improve on it
    if (_job.r < ((_k == 1) ? 1 : _job.restarts)) return;

    // every restart at this number done: is it the best number so far, by BIC?
    var _bic = -2 * _job.best_ll + (_k * 2 * _d + _k - 1) * ln(_n);
    if (_bic < _job.top_bic) {
        _job.top_bic = _bic;
        _job.top_k = _k;
        _job.top_w = _job.best_w;
        _job.top_mu = _job.best_mu;
        _job.top_va = _job.best_va;
        _job.top_ll = _job.best_ll;
        _job.worse = 0;
    } else {
        _job.worse += 1;
    }
    _job.k += 1;
    _job.r = 0;
    _job.best_ll = -infinity;
    // stop trying more styles once patience counts in a row were no better
    if (_job.k <= _job.kmax && _job.worse < _job.patience) return;
    __gmsa_style_fit_finish(_job);
}

function __gmsa_style_fit_begin_pass(_job) {
    var _k = _job.k;
    var _d = _job.d;
    _job.nk = array_create(_k, 0);
    _job.s1 = array_create(_k * _d, 0);
    _job.s2 = array_create(_k * _d, 0);
    _job.lp = array_create(_k, 0);
    _job.norm = array_create(_k, 0);
    _job.iv = array_create(_k * _d, 0);
    for (var _c = 0; _c < _k; _c++) {
        var _l = ln(max(_job.w[_c], 0.000000000001));
        for (var _j = 0; _j < _d; _j++) {
            var _va = _job.va[_c * _d + _j];
            _l -= 0.5 * ln(2 * pi * _va);
            _job.iv[_c * _d + _j] = 1 / _va;
        }
        _job.norm[_c] = _l;
    }
    _job.ll = 0;
    _job.cursor = 0;
}

function __gmsa_style_copy(_a) {
    var _b = array_create(array_length(_a), 0);
    array_copy(_b, 0, _a, 0, array_length(_a));
    return _b;
}

function __gmsa_style_fit_finish(_job) {
    var _set = _job.set;
    var _k = _job.top_k;
    var _d = _job.d;
    var _new = [];
    for (var _c = 0; _c < _k; _c++) {
        var _mean = array_create(_d, 0);
        var _var = array_create(_d, 0);
        for (var _j = 0; _j < _d; _j++) {
            _mean[_j] = _job.top_mu[_c * _d + _j] * _job.scale[_j] + _job.centre[_j];
            _var[_j] = _job.top_va[_c * _d + _j] * sqr(_job.scale[_j]);
        }
        // weights average 1, like a hand-written style's default: a style's weight is how common it is against an average one
        array_push(_new, { name : "", weight : _job.top_w[_c] * _k, mean : _mean, variance : _var, hand : false });
    }
    // closest pairs first: an old named style and a new one within keep (in the data's spreads, per measure) share the name
    var _old = [];
    var _hand = [];
    for (var _s = 0; _s < array_length(_set.styles); _s++) {
        if (_set.styles[_s].hand) array_push(_hand, _set.styles[_s]);
        else if (_set.styles[_s].name != "") array_push(_old, _set.styles[_s]);
    }
    var _taken_old = array_create(array_length(_old), false);
    var _taken_new = array_create(_k, false);
    repeat (min(array_length(_old), _k)) {
        var _bo = -1;
        var _bn = -1;
        var _bd = infinity;
        for (var _o = 0; _o < array_length(_old); _o++) {
            if (_taken_old[_o]) continue;
            for (var _c = 0; _c < _k; _c++) {
                if (_taken_new[_c]) continue;
                var _dist = 0;
                for (var _j = 0; _j < _d; _j++) _dist += sqr((_old[_o].mean[_j] - _new[_c].mean[_j]) / _job.scale[_j]);
                _dist = sqrt(_dist / _d);
                if (_dist < _bd) {
                    _bd = _dist;
                    _bo = _o;
                    _bn = _c;
                }
            }
        }
        if (_bo < 0 || _bd > _job.keep) break;
        _taken_old[_bo] = true;
        _taken_new[_bn] = true;
        _new[_bn].name = _old[_bo].name;
    }
    var _styles = [];
    for (var _s = 0; _s < array_length(_hand); _s++) array_push(_styles, _hand[_s]);
    for (var _c = 0; _c < _k; _c++) array_push(_styles, _new[_c]);
    _set.styles = _styles;
    _job.found = _k;
    _job.bic = _job.top_bic;
    _job.done = true;
    _job.x = []; // the sessions aren't needed any more
}