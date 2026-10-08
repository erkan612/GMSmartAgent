draw_set_colour(make_color_rgb(30, 30, 26));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

var _cl = area_w * 0.1;
var _cw = area_w * 0.85;
var _fx = function(_t, _l, _w) { return _l + _t / fights_max * _w; };

// top: the player's hidden skill, and the monster each lane put in front of it
var _tt = room_height * 0.06;
var _th = room_height * 0.4;
var _lo = 900;
var _hi = 2300;
var _ry = function(_v, _t, _h, _lo, _hi) { return _t + _h * (1 - (_v - _lo) / (_hi - _lo)); };
draw_set_colour(c_white);
draw_text(_cl + _cw / 2, _tt - 14, "The player's hidden skill (white) and the monsters it fought");
for (var _i = 0; _i < array_length(monster_rating); _i++) {
    var _gy = _ry(monster_rating[_i], _tt, _th, _lo, _hi);
    draw_set_colour(make_color_rgb(44, 44, 40));
    draw_line(_cl, _gy, _cl + _cw, _gy);
    draw_set_halign(fa_right);
    draw_set_colour(c_gray);
    draw_text(_cl - 6, _gy, monster_names[_i]);
}
draw_set_colour(c_gray);
draw_rectangle(_cl, _tt, _cl + _cw, _tt + _th, true);
for (var _t = 0; _t < fights; _t++) {
    var _x = _fx(_t, _cl, _cw);
    draw_set_colour(fixed_colour);
    draw_circle(_x, _ry(monster_rating[hist_f[_t]], _tt, _th, _lo, _hi) + 3, 2, false);
    draw_set_colour(rating_colour);
    draw_circle(_x, _ry(monster_rating[hist_r[_t]], _tt, _th, _lo, _hi) - 3, 2, false);
    if (_t > 0) {
        draw_set_colour(c_white);
        draw_line_width(_fx(_t - 1, _cl, _cw), _ry(hist_skill[_t - 1], _tt, _th, _lo, _hi), _x, _ry(hist_skill[_t], _tt, _th, _lo, _hi), 2);
    }
}

if (flash > 0) {
    draw_set_halign(fa_center);
    draw_set_alpha(min(1, flash / 15));
    draw_set_colour(c_yellow);
    draw_text(area_w * 0.5, room_height * 0.5, flash_text);
    draw_set_alpha(1);
}

// bottom: wins in the last 20 fights, against the target, with 40 to 80% shaded
var _bt = room_height * 0.58;
var _bh = room_height * 0.36;
var _p = targets[target_i];
draw_set_halign(fa_center);
draw_set_colour(c_white);
draw_text(_cl + _cw / 2, _bt - 14, "Wins in the last 20 fights. The dashed line is the target");
draw_set_alpha(0.12);
draw_set_colour(c_white);
draw_rectangle(_cl, _bt + _bh * 0.2, _cl + _cw, _bt + _bh * 0.6, false);
draw_set_alpha(1);
draw_set_colour(c_gray);
draw_rectangle(_cl, _bt, _cl + _cw, _bt + _bh, true);
draw_set_halign(fa_right);
draw_text(_cl - 6, _bt, "100%");
draw_text(_cl - 6, _bt + _bh / 2, "50%");
draw_text(_cl - 6, _bt + _bh, "0%");
draw_set_colour(c_orange);
for (var _x = _cl; _x < _cl + _cw; _x += 12) draw_line(_x, _bt + _bh * (1 - _p), min(_x + 6, _cl + _cw), _bt + _bh * (1 - _p));
var _lists = [won_r, won_f];
var _colours = [rating_colour, fixed_colour];
for (var _k = 0; _k < 2; _k++) {
    draw_set_colour(_colours[_k]);
    for (var _t = 2; _t <= fights; _t++) {
        var _a = last20(_lists[_k], _t - 1);
        var _b = last20(_lists[_k], _t);
        draw_line_width(_fx(_t - 1, _cl, _cw), _bt + _bh * (1 - _a), _fx(_t, _cl, _cw), _bt + _bh * (1 - _b), 2);
    }
}
draw_set_halign(fa_left);
draw_set_valign(fa_top);