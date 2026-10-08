draw_set_colour(make_color_rgb(30, 30, 26));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_valign(fa_middle);

// the ladder, best first by Weng-Lin: its rating with how unsure it is, Elo's rating, the hidden skill on H
ladder_t = room_height * 0.06;
row_h = room_height * 0.56 / 9;
var _ax_l = area_w * 0.16;
var _ax_w = area_w * 0.8;
var _vx = function(_v, _l, _w) { return _l + clamp((_v - lo) / (hi - lo), 0, 1) * _w; };

for (var _v = 1000; _v <= 2300; _v += 100) {
    var _gx = _vx(_v, _ax_l, _ax_w);
    draw_set_colour((_v mod 500 == 0) ? make_color_rgb(70, 70, 64) : make_color_rgb(44, 44, 40));
    draw_line(_gx, ladder_t - 8, _gx, ladder_t + row_h * 9);
    if (_v mod 500 == 0) {
        draw_set_halign(fa_center);
        draw_set_colour(c_gray);
        draw_text(_gx, ladder_t - 18, string(_v));
    }
}

var _rows = [];
for (var _i = 0; _i < array_length(bots); _i++) array_push(_rows, { b : bots[_i], r : gmsa_rating_get(pool, bots[_i].name) });
array_sort(_rows, function(_a, _b) { return (_b.r.rating > _a.r.rating) ? 1 : ((_b.r.rating < _a.r.rating) ? -1 : 0); });
row_names = [];
for (var _i = 0; _i < array_length(_rows); _i++) {
    var _b = _rows[_i].b;
    var _r = _rows[_i].r;
    array_push(row_names, _b.name);
    var _y = ladder_t + (_i + 0.5) * row_h;
    if (_b.name == selected) {
        draw_set_colour(make_color_rgb(50, 50, 44));
        draw_rectangle(0, _y - row_h / 2, area_w, _y + row_h / 2, false);
    }
    draw_set_halign(fa_left);
    draw_set_colour(_b.newcomer ? c_orange : c_white);
    draw_text(area_w * 0.03, _y, string(_i + 1) + ". " + _b.name);

    // Weng-Lin: a bar as wide as how unsure it is, either side of its rating
    draw_set_alpha(0.35);
    draw_set_colour(wl_colour);
    draw_rectangle(_vx(_r.rating - _r.unsure, _ax_l, _ax_w), _y - 6, _vx(_r.rating + _r.unsure, _ax_l, _ax_w), _y + 6, false);
    draw_set_alpha(1);
    draw_circle(_vx(_r.rating, _ax_l, _ax_w), _y, 6, false);
    draw_set_colour(elo_colour);
    draw_circle(_vx(_b.elo, _ax_l, _ax_w), _y, 5, false);
    if (show_true) {
        var _tx = _vx(_b.skill, _ax_l, _ax_w);
        draw_set_colour(c_white);
        draw_line_width(_tx, _y - 11, _tx, _y + 11, 2);
    }
}

if (flash > 0) {
    draw_set_halign(fa_center);
    draw_set_alpha(min(1, flash / 15));
    draw_set_colour(c_yellow);
    draw_text_transformed(area_w * 0.5, room_height * 0.65, flash_text, 1.2, 1.2, 0);
    draw_set_alpha(1);
}

// how far each system's chance was from the truth, over the last 40 two-sided matches
var _cl = area_w * 0.08;
var _cw = area_w * 0.86;
var _ct = room_height * 0.72;
var _ch = room_height * 0.22;
var _top = 0.3;
draw_set_halign(fa_center);
draw_set_colour(c_white);
draw_text(_cl + _cw / 2, _ct - 14, "How far each one's chance was from the truth, last 40 two-sided matches");
draw_set_colour(make_color_rgb(44, 44, 40));
for (var _g = 0.1; _g < _top; _g += 0.1) draw_line(_cl, _ct + _ch * (1 - _g / _top), _cl + _cw, _ct + _ch * (1 - _g / _top));
draw_set_colour(c_gray);
draw_rectangle(_cl, _ct, _cl + _cw, _ct + _ch, true);
draw_set_halign(fa_right);
draw_text(_cl - 6, _ct + _ch * (1 - 0.1 / _top), "0.1");
draw_text(_cl - 6, _ct + _ch * (1 - 0.2 / _top), "0.2");
var _curves = [curve_wl, curve_elo];
var _colours = [wl_colour, elo_colour];
for (var _k = 0; _k < 2; _k++) {
    var _c = _curves[_k];
    draw_set_colour(_colours[_k]);
    for (var _i = 1; _i < array_length(_c); _i++) {
        var _x0 = _cl + (_i - 1) / 299 * _cw;
        var _x1 = _cl + _i / 299 * _cw;
        draw_line_width(_x0, _ct + _ch * (1 - min(_c[_i - 1], _top) / _top), _x1, _ct + _ch * (1 - min(_c[_i], _top) / _top), 2);
    }
}
draw_set_halign(fa_left);
draw_set_valign(fa_top);