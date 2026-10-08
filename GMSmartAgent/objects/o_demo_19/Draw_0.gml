draw_set_colour(make_color_rgb(30, 30, 26));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// the land: open fields, two forests, the river over them
draw_set_colour(make_color_rgb(96, 88, 60));
draw_rectangle(map_l, map_t, map_l + map_w, map_t + map_h, false);
draw_set_colour(make_color_rgb(46, 92, 50));
for (var _i = 0; _i < array_length(forests); _i++) {
    var _f = forests[_i];
    draw_ellipse(sx(_f.x - _f.r), sy(_f.y - _f.r), sx(_f.x + _f.r), sy(_f.y + _f.r), false);
}
draw_set_colour(make_color_rgb(60, 110, 180));
for (var _i = 0; _i < 80; _i++) {
    var _x0 = _i / 80;
    var _x1 = (_i + 1) / 80;
    draw_line_width(sx(_x0), sy(river_y(_x0)), sx(_x1), sy(river_y(_x1)), 0.16 * map_h);
}
draw_set_colour(c_black);
draw_rectangle(0, 0, area_w, map_t - 1, false);
draw_rectangle(0, map_t + map_h + 1, area_w, room_height * 0.62, false);
draw_set_colour(make_color_rgb(30, 30, 26));
draw_rectangle(0, 0, area_w, map_t - 1, false);
draw_rectangle(0, map_t + map_h + 1, area_w, room_height * 0.62, false);
draw_rectangle(0, 0, map_l - 1, room_height * 0.62, false);
draw_rectangle(map_l + map_w + 1, 0, area_w, room_height * 0.62, false);

// landmarks, the notes the game gives
for (var _i = 0; _i < array_length(landmarks); _i++) {
    var _m = landmarks[_i];
    draw_set_colour(c_white);
    draw_rectangle(sx(_m.x) - 3, sy(_m.y) - 3, sx(_m.x) + 3, sy(_m.y) + 3, false);
    draw_set_colour(c_silver);
    draw_text(sx(_m.x), sy(_m.y) + 14, _m.name);
}

// the last stops, coloured by what was done there
for (var _i = 0; _i < array_length(trail); _i++) {
    var _s = trail[_i];
    draw_set_alpha(0.3 + 0.7 * (_i + 1) / array_length(trail));
    draw_set_colour(act_colour[_s.a]);
    draw_circle(sx(_s.x), sy(_s.y), 5, false);
}
draw_set_alpha(1);

// the wanderer walking to its next stop, the stop ringed
var _f = auto ? walk / 40 : 1;
draw_set_colour(c_orange);
draw_circle(sx(here_x), sy(here_y), 12, true);
draw_set_colour(c_white);
draw_circle(sx(lerp(from_x, here_x, _f)), sy(lerp(from_y, here_y, _f)), 8, false);

if (flash > 0) {
    draw_set_alpha(min(1, flash / 15));
    draw_set_colour(c_yellow);
    draw_text_transformed(area_w * 0.5, room_height * 0.635, flash_text, 1.3, 1.3, 0);
    draw_set_alpha(1);
}

// each learner's map: what it would guess at every spot, brighter where it's sure
var _hw = map_w * 0.48;
var _hh = room_height * 0.27;
var _ht = room_height * 0.7;
var _lefts = [map_l, map_l + map_w - _hw];
var _titles = ["Naive Bayes' map", "nearest neighbor's map"];
var _cw = _hw / heat_w;
var _ch = _hh / heat_h;
for (var _k = 0; _k < 2; _k++) {
    draw_set_colour(c_white);
    draw_text(_lefts[_k] + _hw / 2, _ht - 14, _titles[_k]);
    for (var _c = 0; _c < heat_count; _c++) {
        var _a = (_k == 0) ? heat_bn[_c] : heat_nn[_c];
        var _s = (_k == 0) ? heat_bs[_c] : heat_ns[_c];
        var _x = _lefts[_k] + (_c mod heat_w) * _cw;
        var _y = _ht + (_c div heat_w) * _ch;
        draw_set_colour((_a < 0) ? make_color_rgb(40, 40, 40) : merge_colour(make_color_rgb(40, 40, 40), act_colour[_a], 0.3 + 0.7 * _s));
        draw_rectangle(_x, _y, _x + _cw, _y + _ch, false);
    }
    draw_set_colour(c_gray);
    draw_rectangle(_lefts[_k], _ht, _lefts[_k] + _hw, _ht + _hh, true);
}