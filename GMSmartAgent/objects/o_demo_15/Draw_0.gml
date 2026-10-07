// the ring
draw_set_colour(make_color_rgb(30, 32, 38));
draw_rectangle(0, 0, area_w, room_height, false);
var _floor = room_height * 0.62;
draw_set_colour(make_color_rgb(60, 60, 70));
draw_line_width(area_w * 0.05, _floor, area_w * 0.95, _floor, 3);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// the dummy, and you: up close or backed off
var _dx = area_w * 0.72;
var _px = far ? area_w * 0.22 : area_w * 0.52;
draw_set_colour(make_color_rgb(150, 120, 90));
draw_rectangle(_dx - 18, _floor - 90, _dx + 18, _floor, false);
draw_circle(_dx, _floor - 108, 18, false);
draw_set_colour((last_move >= 0 && move_flash > 0) ? move_colours[last_move] : make_color_rgb(230, 200, 150));
draw_circle(_px, _floor - 40, 26, false);
draw_set_colour(c_white);
draw_text(_px, _floor - 40, "you");

// your hp
var _hw = 80;
draw_set_colour(c_dkgray);
draw_rectangle(_px - _hw / 2, _floor - 92, _px + _hw / 2, _floor - 82, false);
draw_set_colour((hp < 30) ? c_red : c_lime);
draw_rectangle(_px - _hw / 2, _floor - 92, _px - _hw / 2 + _hw * hp / 100, _floor - 82, false);

// your last move
if (last_move >= 0 && move_flash > 0) {
    draw_set_colour(move_colours[last_move]);
    draw_text_transformed(_px, _floor - 120, move_names[last_move], 1.5, 1.5, 0);
}

// the dummy speaks when it's sure enough
if (speaking) {
    var _say = "You'll " + move_names[pred_best] + "!";
    var _bw = string_width(_say) / 2 + 12;
    draw_set_colour(c_white);
    draw_roundrect(_dx - _bw, _floor - 172, _dx + _bw, _floor - 144, false);
    draw_set_colour(c_black);
    draw_text(_dx, _floor - 158, _say);
}
if (flash > 0) {
    draw_set_alpha(min(1, flash / 20));
    draw_set_colour((flash_text == "Blocked!") ? c_yellow : c_silver);
    draw_text_transformed(_dx, _floor - 210, flash_text, 1.6, 1.6, 0);
    draw_set_alpha(1);
}

// your last moves, oldest first
var _bx = area_w * 0.5 - 4 * 70;
var _by = room_height * 0.82;
draw_set_colour(c_gray);
draw_text(area_w * 0.5, _by - 34, "your last moves");
for (var _i = 0; _i < array_length(moves); _i++) {
    var _x = _bx + _i * 70;
    draw_set_colour(move_colours[moves[_i]]);
    draw_roundrect(_x, _by - 16, _x + 64, _by + 16, false);
    draw_set_colour(c_black);
    draw_text(_x + 32, _by, move_names[moves[_i]]);
}