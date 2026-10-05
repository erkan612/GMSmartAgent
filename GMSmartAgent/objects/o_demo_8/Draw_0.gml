// the field, day or night
draw_set_colour(is_day ? make_colour_rgb(34, 52, 30) : make_colour_rgb(18, 22, 44));
draw_rectangle(0, 0, room_width, room_height, false);

// the wolf's reach
draw_set_colour(make_colour_rgb(120, 40, 40));
draw_circle(wolf.x, wolf.y, wolf.reach, true);

// patches all look alike: their payoffs are secret
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
for (var _i = 0; _i < array_length(patches); _i++) {
    var _pt = patches[_i];
    draw_set_colour(make_colour_rgb(150, 120, 70));
    draw_circle(_pt.x, _pt.y, 22, false);
    if (point_distance(wolf.x, wolf.y, _pt.x, _pt.y) < wolf.reach) {
        draw_set_colour(c_red);
        draw_circle(_pt.x, _pt.y, 27, true);
    }
    draw_set_colour(c_black);
    draw_text(_pt.x, _pt.y, _pt.name);
    if (reveal) {
        draw_set_colour(c_white);
        draw_text(_pt.x, _pt.y + 36, "day " + string_format(_pt.day_pay, 1, 1) + ", night " + string_format(_pt.night_pay, 1, 1));
    }
}
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// the nest
draw_set_colour(make_colour_rgb(120, 85, 50));
draw_circle(cx, cy, 26, false);

// the wolf
draw_set_colour(c_ltgray);
draw_circle(wolf.x, wolf.y, 12, false);

// foragers, bigger while carrying food home
for (var _i = 0; _i < array_length(foragers); _i++) {
    var _f = foragers[_i];
    draw_set_colour(teams[_f.team].colour);
    draw_circle(_f.x, _f.y, (_f.state == 2) ? 4 : 2.5, false);
}
draw_set_colour(c_white);