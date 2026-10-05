// you
draw_set_colour(c_white);
draw_circle(cx, cy, 10, false);

// items, brightened by the selected model's opinion: brighter means more likely to be picked
var _entry = models[view];
var _max = 0;
for (var _i = 0; _i < array_length(items); _i++) _max = max(_max, items[_i].p[view]);
var _show = (_entry.confidence > 0 && _max > 0);

for (var _i = 0; _i < array_length(items); _i++) {
    var _it = items[_i];
    var _base = _it.red ? make_colour_rgb(230, 70, 70) : make_colour_rgb(70, 130, 230);
    var _t = _show ? _it.p[view] / _max : 1;
    draw_set_colour(merge_colour(make_colour_rgb(40, 40, 48), _base, 0.12 + 0.88 * _t));
    draw_circle(_it.x, _it.y, _it.big ? 22 : 12, false);
}

// every model's favorite, one ring each, the selected model's drawn thicker
for (var _m = 0; _m < array_length(models); _m++) {
    if (models[_m].confidence <= 0) continue;  // no opinion yet
    var _fav = -1, _best = 0;
    for (var _i = 0; _i < array_length(items); _i++) {
        if (items[_i].p[_m] > _best) { _best = items[_i].p[_m]; _fav = _i; }
    }
    if (_fav < 0) continue;
    var _f = items[_fav];
    var _r = (_f.big ? 22 : 12) + 6 + _m * 5;
    draw_set_colour(models[_m].colour);
    draw_circle(_f.x, _f.y, _r, true);
    if (_m == view) {
        draw_circle(_f.x, _f.y, _r + 1, true);
        draw_circle(_f.x, _f.y, _r + 2, true);
    }
}
draw_set_colour(c_white);