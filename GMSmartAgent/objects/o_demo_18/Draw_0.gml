// the fight
draw_set_colour(make_color_rgb(32, 28, 34));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// where it happens: the note the game gives each moment
draw_set_colour(c_silver);
draw_text(area_w * 0.5, room_height * 0.05, place);
if (cornered) {
    draw_set_colour(c_red);
    draw_text_transformed(area_w * 0.5, room_height * 0.1, "CORNERED", 1.3, 1.3, 0);
}

// the fighter, and the enemies around it
var _cx = area_w * 0.5;
var _cy = room_height * 0.34;
var _count = round(enemies * 12);
draw_set_colour(make_color_rgb(200, 70, 60));
for (var _i = 0; _i < _count; _i++) {
    var _a = _i / 12 * 360 + 90;
    draw_circle(_cx + lengthdir_x(110, _a), _cy + lengthdir_y(110, _a), 14, false);
}
draw_set_colour(make_color_rgb(110, 170, 230));
draw_circle(_cx, _cy, 22, false);

// hp and stamina
var _bw = area_w * 0.4;
var _bx = _cx - _bw / 2;
var _bars = [["hp", hp, make_color_rgb(200, 80, 70)], ["stamina", stamina, make_color_rgb(220, 190, 80)], ["enemies", enemies, make_color_rgb(200, 70, 60)]];
draw_set_halign(fa_left);
for (var _k = 0; _k < array_length(_bars); _k++) {
    var _y = room_height * 0.53 + _k * 30;
    draw_set_colour(c_silver);
    draw_text(_bx - 90, _y, _bars[_k][0] + " " + string(round(_bars[_k][1] * 100)) + "%");
    draw_set_colour(c_dkgray);
    draw_rectangle(_bx, _y - 5, _bx + _bw, _y + 5, false);
    draw_set_colour(_bars[_k][2]);
    draw_rectangle(_bx, _y - 5, _bx + _bw * _bars[_k][1], _y + 5, false);
}
draw_set_halign(fa_center);

if (flash > 0) {
    draw_set_alpha(min(1, flash / 15));
    draw_set_colour(c_yellow);
    draw_text_transformed(area_w * 0.5, room_height * 0.68, flash_text, 1.4, 1.4, 0);
    draw_set_alpha(1);
}

// the moves, each learner's guess ringed: blue Naive Bayes, green nearest neighbor
var _fills = [make_color_rgb(170, 70, 60), make_color_rgb(110, 120, 140), make_color_rgb(140, 70, 160)];
for (var _i = 0; _i < array_length(moves); _i++) {
    var _b = move_box(_i);
    if (_i == bn_best) {
        draw_set_colour(make_color_rgb(90, 140, 230));
        draw_rectangle(_b.l - 10, _b.t - 10, _b.r + 10, _b.b + 10, true);
        draw_rectangle(_b.l - 11, _b.t - 11, _b.r + 11, _b.b + 11, true);
    }
    if (_i == nn_best) {
        draw_set_colour(make_color_rgb(110, 210, 120));
        draw_rectangle(_b.l - 5, _b.t - 5, _b.r + 5, _b.b + 5, true);
        draw_rectangle(_b.l - 6, _b.t - 6, _b.r + 6, _b.b + 6, true);
    }
    draw_set_colour(_fills[_i]);
    draw_roundrect(_b.l, _b.t, _b.r, _b.b, false);
    draw_set_colour(c_white);
    draw_text(_b.x, _b.y, moves[_i]);
}
draw_set_colour(make_color_rgb(90, 140, 230));
draw_text(area_w * 0.3, room_height * 0.74, "blue: Naive Bayes' guess");
draw_set_colour(make_color_rgb(110, 210, 120));
draw_text(area_w * 0.7, room_height * 0.74, "green: nearest neighbor's guess");