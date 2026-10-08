randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
measures = ["kills", "deaths", "distance", "cover"];
// the true styles the crowd plays, a minute of play each: kills, deaths, distance kept from enemies, time near cover
true_names = ["rusher", "sniper", "support", "explorer"];
true_typical = [[3.0, 8.0, 150, 0.1], [1.5, 3.0, 900, 0.6], [0.5, 2.0, 500, 0.3], [0.3, 1.0, 1500, 0.8]];
true_spread = [[0.5, 1.5, 40, 0.05], [0.3, 1.0, 120, 0.1], [0.2, 0.8, 100, 0.08], [0.1, 0.5, 150, 0.08]];
// the live player's choices: the four styles, and a mix nobody in the crowd plays
live_names = ["rusher", "sniper", "support", "explorer", "a mix nobody plays"];
live_typical = [true_typical[0], true_typical[1], true_typical[2], true_typical[3], [3.0, 1.0, 1500, 0.8]];
style_colours = [make_color_rgb(230, 110, 90), make_color_rgb(90, 150, 230), make_color_rgb(110, 210, 120), make_color_rgb(220, 190, 80), make_color_rgb(190, 120, 220), make_color_rgb(90, 210, 210)];
sessions_count = 200;

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = false;

gauss = function() {
    return sqrt(-2 * ln(max(0.000000001, random(1)))) * cos(2 * pi * random(1));
};

// a crowd of sessions, the styles in random proportions
new_crowd = function() {
    var _shares = [random_range(1, 4), random_range(1, 4), random_range(1, 4), random_range(1, 4)];
    var _total = _shares[0] + _shares[1] + _shares[2] + _shares[3];
    sessions = [];
    session_true = [];
    session_style = [];
    for (var _i = 0; _i < sessions_count; _i++) {
        var _u = random(_total);
        var _s = 0;
        while (_s < 3 && _u > _shares[_s]) {
            _u -= _shares[_s];
            _s += 1;
        }
        var _v = {};
        for (var _j = 0; _j < 4; _j++) _v[$ measures[_j]] = max(0, true_typical[_s][_j] + true_spread[_s][_j] * gauss());
        array_push(sessions, _v);
        array_push(session_true, _s);
        array_push(session_style, -1);
    }
    // the fit runs a little every frame, never all at once
    job = gmsa_style_fit(set, sessions, { max_styles : 6, restarts : 5, seed : irandom(1000000) });
    fitting = true;
};

// the true style a found one sits on, or -1 when it's near none of them
nearest_true = function(_typical) {
    static _scale = [1, 2, 400, 0.25];
    var _best = -1;
    var _bd = 1.5;
    for (var _s = 0; _s < 4; _s++) {
        var _d = 0;
        for (var _j = 0; _j < 4; _j++) _d += sqr((_typical[$ measures[_j]] - true_typical[_s][_j]) / _scale[_j]);
        _d = sqrt(_d / 4);
        if (_d < _bd) {
            _bd = _d;
            _best = _s;
        }
    }
    return _best;
};

after_fit = function() {
    fitting = false;
    // GMSmartAgent finds styles unnamed. The demo names the ones it recognizes, as you would with gmsa_style_name.
    // On a refit, styles close to named ones keep their names by themselves
    styles = gmsa_style_list(set);
    for (var _s = 0; _s < array_length(styles); _s++) {
        if (styles[_s].name != "") continue;
        var _t = nearest_true(styles[_s].typical);
        if (_t < 0) continue;
        var _taken = false;
        for (var _o = 0; _o < array_length(styles); _o++) if (styles[_o].name == true_names[_t]) _taken = true;
        if (!_taken) gmsa_style_name(set, _s, true_names[_t]);
        styles = gmsa_style_list(set);
    }
    for (var _i = 0; _i < array_length(sessions); _i++) {
        var _m = gmsa_style_match(set, sessions[_i]);
        session_style[_i] = _m.best;
    }
    fits += 1;
    found_text = "Fit " + string(fits) + ": found " + string(job.found) + " styles in " + string(sessions_count) + " sessions.";
    refresh();
};

// a minute of the live player's play, fed to its tracker as it happens
live_tick = function() {
    var _t = live_typical[live_kind];
    var _sd = true_spread[min(live_kind, 3)];
    gmsa_style_count(tracker, "kills", max(0, _t[0] + 2 * _sd[0] * gauss()));
    gmsa_style_count(tracker, "deaths", max(0, _t[1] + 2 * _sd[1] * gauss()));
    gmsa_style_sample(tracker, "distance", max(0, _t[2] + 2 * _sd[2] * gauss()));
    gmsa_style_sample(tracker, "cover", clamp(_t[3] + 2 * _sd[3] * gauss(), 0, 1));
    gmsa_style_tick(tracker);
    ticks += 1;
    if (auto && ticks mod 30 == 0) switch_live((live_kind + 1 + irandom(2)) mod 4);
    var _v = gmsa_style_values(tracker);
    array_push(trail, { x : _v.distance, y : _v.kills });
    if (array_length(trail) > 30) array_delete(trail, 0, 1);
    refresh();
};

refresh = function() {
    if (array_length(styles) == 0) return;
    live_match = gmsa_style_match(set, tracker);
    live_why = gmsa_style_explain(set, tracker);
};

switch_live = function(_k) {
    live_kind = _k;
    flash_text = "the live player now plays like " + ((_k < 4) ? "a " : "") + live_names[_k];
    flash = 60;
};

tick = function() {
    if (flash > 0) flash -= 1;
    if (fitting) {
        if (gmsa_style_fit_work(job, fast ? 16000 : 4000)) after_fit();
    }
    timer += 1;
    if (timer >= 20) {
        timer = 0;
        live_tick();
    }
};

cx = function(_d) { return chart_l + clamp(_d / 2000, 0, 1) * chart_w; };
cy = function(_k) { return chart_t + chart_h * (1 - clamp(_k / 4.5, 0, 1)); };

reset = function() {
    set = gmsa_style_set_create(measures);
    tracker = gmsa_style_tracker_create(set, { half_life : 10 });
    styles = [];
    fits = 0;
    found_text = "";
    live_kind = 0;
    live_match = undefined;
    live_why = "";
    ticks = 0;
    timer = 0;
    trail = [];
    flash = 0;
    flash_text = "";
    new_crowd();
};

chart_l = area_w * 0.1;
chart_t = room_height * 0.06;
chart_w = area_w * 0.85;
chart_h = room_height * 0.82;
reset();