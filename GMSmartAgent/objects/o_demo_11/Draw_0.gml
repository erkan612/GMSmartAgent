// outside, darker at night, and the three vaults
draw_set_colour(night ? make_color_rgb(22, 26, 40) : make_color_rgb(40, 46, 56));
draw_rectangle(0, 0, wall_x, room_height, false);
draw_set_colour(night ? make_color_rgb(32, 28, 36) : make_color_rgb(52, 44, 46));
draw_rectangle(wall_x, 0, area_w, room_height, false);
draw_set_colour(c_gray);
for (var _i = 1; _i < 3; _i++) draw_line_width(wall_x, vaults[_i].top, area_w, vaults[_i].top, 4);
draw_set_colour(c_ltgray);
draw_line_width(wall_x, 0, wall_x, room_height, 6);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
var _entrance_colours = [make_color_rgb(200, 140, 80), make_color_rgb(120, 170, 220), make_color_rgb(140, 110, 80)];
for (var _v = 0; _v < 3; _v++) {
    var _vault = vaults[_v];
    for (var _e = 0; _e < 3; _e++) {
        var _o = _vault.outs[_e];
        draw_set_colour(_entrance_colours[_e]);
        draw_rectangle(wall_x - 6, _o.y - 14, wall_x + 6, _o.y + 14, false);
        draw_set_colour(c_silver);
        var _label = entrance_names[_e];
        if (reveal) _label += " " + string(round(_vault.rules[_e * 2 + (night ? 1 : 0)] * 100)) + "%";
        draw_text(wall_x - 70, _o.y, _label);
    }
    draw_set_colour(c_yellow);
    draw_rectangle(_vault.chest.x - 16, _vault.chest.y - 12, _vault.chest.x + 16, _vault.chest.y + 12, false);
    draw_set_colour(c_white);
    draw_text(_vault.chest.x, _vault.chest.y + 26, "vault " + string(_v + 1));
}
draw_set_colour(c_dkgray);
draw_circle(home.x, home.y, 40, true);
draw_set_colour(c_silver);
draw_text(home.x, home.y - 56, "home");

// goblins: grey or coloured by crew, a ring on the selected one and the path it is walking
for (var _i = 0; _i < array_length(goblins); _i++) {
    var _g = goblins[_i];
    if (_g == selected) {
        if (_g.doing != undefined && _g.leg < array_length(_g.path)) {
            draw_set_alpha(0.4);
            draw_set_colour(c_white);
            draw_line(_g.x, _g.y, _g.path[_g.leg].x, _g.path[_g.leg].y);
            draw_set_alpha(1);
        }
        draw_set_colour(c_white);
        draw_circle(_g.x, _g.y, 12, true);
    }
    draw_set_colour(teams[_g.team].colour);
    draw_circle(_g.x, _g.y, 7, false);
    if (_g.has_loot) {
        draw_set_colour(c_yellow);
        draw_circle(_g.x + 7, _g.y - 7, 3, false);
    }
}