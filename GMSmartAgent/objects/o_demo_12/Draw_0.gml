// outside at night, the vaults, the wall
draw_set_colour(make_color_rgb(20, 24, 38));
draw_rectangle(0, 0, wall_x, room_height, false);
draw_set_colour(make_color_rgb(32, 28, 36));
draw_rectangle(wall_x, 0, area_w, room_height, false);
draw_set_colour(c_gray);
for (var _i = 1; _i < 3; _i++) draw_line_width(wall_x, vaults[_i].top, area_w, vaults[_i].top, 4);
draw_set_colour(c_ltgray);
draw_line_width(wall_x, 0, wall_x, room_height, 6);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
for (var _v = 0; _v < 3; _v++) {
    var _vault = vaults[_v];
    draw_set_colour(make_color_rgb(200, 140, 80));
    draw_rectangle(wall_x - 6, _vault.out.y - 14, wall_x + 6, _vault.out.y + 14, false);
    draw_set_colour(c_yellow);
    draw_rectangle(_vault.chest.x - 14, _vault.chest.y - 10, _vault.chest.x + 14, _vault.chest.y + 10, false);
    draw_set_colour(c_white);
    draw_text(_vault.chest.x, _vault.chest.y + 26, "vault " + string(_v + 1));

    // the learning crew's view of this post: how likely the guard comes here at the next bell
    var _next = next_read[_v](undefined, undefined);
    var _avoid = (_next >= avoid_above);
    draw_set_colour(_avoid ? c_orange : c_dkgray);
    draw_circle(_vault.post.x, _vault.post.y, _avoid ? 22 : 10, true);
    draw_text(_vault.post.x, _vault.post.y - 36, "next " + string(round(_next * 100)) + "%");
}
draw_set_colour(c_dkgray);
draw_circle(home.x, home.y, 40, true);
draw_set_colour(c_silver);
draw_text(home.x, home.y - 56, "home");

// the guard and its lantern
draw_set_alpha(0.15);
draw_set_colour(c_yellow);
draw_circle(guard.x, guard.y, 40, false);
draw_set_alpha(1);
draw_set_colour(make_color_rgb(255, 200, 120));
draw_circle(guard.x, guard.y, 9, false);
if (bell_flash > 0) {
    draw_set_colour(c_yellow);
    draw_text(guard.x - 40, guard.y, "bell!");
}

// goblins, a ring on the selected one and the path it is walking
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

// what just happened
for (var _i = 0; _i < array_length(popups); _i++) {
    var _p = popups[_i];
    draw_set_alpha(_p.life / 60);
    draw_set_colour(_p.colour);
    draw_text(_p.x, _p.y, _p.text);
}
draw_set_alpha(1);