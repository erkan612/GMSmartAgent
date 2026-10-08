// the field
draw_set_colour(make_color_rgb(30, 36, 28));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// their fort at the top
draw_set_colour(make_color_rgb(85, 78, 72));
draw_rectangle(area_w * 0.08, room_height * 0.03, area_w * 0.92, room_height * 0.09, false);
draw_set_colour(c_white);
draw_text(area_w * 0.5, room_height * 0.06, "their fort, guessing where you attack next");

// the lanes, each learner's guess ringed: blue Count, green Naive Bayes
for (var _i = 0; _i < array_length(lanes); _i++) {
    var _b = lane_box(_i);
    if (_i == ct_best) {
        draw_set_colour(make_color_rgb(90, 140, 230));
        draw_rectangle(_b.l - 10, _b.t - 10, _b.r + 10, _b.b + 10, true);
        draw_rectangle(_b.l - 11, _b.t - 11, _b.r + 11, _b.b + 11, true);
    }
    if (_i == by_best) {
        draw_set_colour(make_color_rgb(110, 210, 120));
        draw_rectangle(_b.l - 5, _b.t - 5, _b.r + 5, _b.b + 5, true);
        draw_rectangle(_b.l - 6, _b.t - 6, _b.r + 6, _b.b + 6, true);
    }
    draw_set_colour(make_color_rgb(62, 72, 54));
    draw_rectangle(_b.l, _b.t, _b.r, _b.b, false);
    draw_set_colour(c_white);
    draw_text(_b.x, _b.b - 16, lanes[_i]);
}
draw_set_colour(make_color_rgb(90, 140, 230));
draw_text(area_w * 0.3, room_height * 0.12, "blue: Count's guess");
draw_set_colour(make_color_rgb(110, 210, 120));
draw_text(area_w * 0.7, room_height * 0.12, "green: Naive Bayes' guess");

// the attack, running up its lane
if (shot > 0) {
    var _b = lane_box(shot_lane);
    var _yy = lerp(_b.b - 34, _b.t + 20, 1 - shot / 40);
    draw_set_colour(c_orange);
    draw_triangle(_b.x, _yy - 14, _b.x - 10, _yy + 6, _b.x + 10, _yy + 6, false);
}

if (flash > 0) {
    draw_set_alpha(min(1, flash / 15));
    draw_set_colour(c_yellow);
    draw_text_transformed(area_w * 0.5, room_height * 0.66, flash_text, 1.4, 1.4, 0);
    draw_set_alpha(1);
}

// the scout's report, the two the auto-attacker's habit looks at in orange
var _ry = room_height * 0.75;
draw_set_colour(c_gray);
draw_text(area_w * 0.5, _ry - 24, "the scout's report");
draw_set_halign(fa_left);
var _w = area_w * 0.2;
for (var _i = 0; _i < array_length(reports); _i++) {
    var _x = area_w * (0.05 + (_i mod 4) * 0.235);
    var _y = _ry + (_i div 4) * 46;
    var _used = auto && (habit_uses[habits][0] == _i || habit_uses[habits][1] == _i);
    draw_set_colour(_used ? c_orange : c_silver);
    draw_text(_x, _y, reports[_i] + " " + string(round(report[_i] * 100)) + "%");
    draw_set_colour(c_dkgray);
    draw_rectangle(_x, _y + 12, _x + _w, _y + 20, false);
    draw_set_colour(_used ? c_orange : make_color_rgb(120, 130, 140));
    draw_rectangle(_x, _y + 12, _x + _w * report[_i], _y + 20, false);
}