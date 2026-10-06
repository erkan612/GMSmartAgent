// outside, and the three vaults tinted by their goblins' colour
draw_set_colour(make_color_rgb(36, 40, 48));
draw_rectangle(0, 0, wall_x, room_height, false);
for (var _i = 0; _i < 3; _i++) {
    var _v = vaults[_i];
    draw_set_colour(merge_colour(make_color_rgb(44, 38, 42), vault_colours[_i], 0.1));
    draw_rectangle(wall_x, _v.top, area_w, _v.bottom, false);
}
draw_set_colour(c_gray);
for (var _i = 1; _i < 3; _i++) draw_line_width(wall_x, vaults[_i].top, area_w, vaults[_i].top, 4);

// the wall, with a gap for each window and door
draw_set_colour(c_ltgray);
var _y0 = 0;
for (var _i = 0; _i < 3; _i++) {
    var _v = vaults[_i];
    draw_line_width(wall_x, _y0, wall_x, _v.win_y - 20, 6);
    draw_line_width(wall_x, _v.win_y + 20, wall_x, _v.door_y - 30, 6);
    _y0 = _v.door_y + 30;
}
draw_line_width(wall_x, _y0, wall_x, room_height, 6);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
for (var _i = 0; _i < 3; _i++) {
    var _v = vaults[_i];
    draw_set_colour(make_color_rgb(120, 170, 220));
    draw_rectangle(wall_x - 3, _v.win_y - 20, wall_x + 3, _v.win_y + 20, false);
    draw_set_colour(_v.locked ? c_red : c_lime);
    draw_rectangle(wall_x - 6, _v.door_y - 30, wall_x + 6, _v.door_y + 30, !_v.locked);
    draw_set_colour(vault_colours[_i]);
    draw_rectangle(_v.chest.x - 20, _v.chest.y - 14, _v.chest.x + 20, _v.chest.y + 14, false);
    draw_set_colour(c_white);
    draw_text(_v.chest.x, _v.chest.y + 30, "looted " + string(_v.loots));
}

// pedestals and their keys, the shop, the coins
for (var _i = 0; _i < array_length(pedestals); _i++) {
    var _p = pedestals[_i];
    draw_set_colour(c_gray);
    draw_rectangle(_p.x - 14, _p.y - 14, _p.x + 14, _p.y + 14, false);
    if (_p.has_key) {
        draw_set_colour(c_yellow);
        draw_rectangle(_p.x - 8, _p.y - 3, _p.x + 8, _p.y + 3, false);
    }
}
draw_set_colour(make_color_rgb(120, 80, 40));
draw_rectangle(shop.x - 30, shop.y - 12, shop.x + 30, shop.y + 12, false);
draw_set_colour(c_silver);
draw_text(shop.x, shop.y - 26, "shop, key 10g");
draw_set_colour(c_yellow);
for (var _i = 0; _i < array_length(coins); _i++) draw_circle(coins[_i].x, coins[_i].y, 6, false);

// goblins: their vault's colour, "..." while their plan is being made, "?" when no plan works right now
for (var _i = 0; _i < array_length(goblins); _i++) {
    var _g = goblins[_i];
    var _status = gmsa_plan_get_status(_g.planner);
    if (_g == selected) {
        if (_g.doing != undefined && _g.leg < array_length(_g.path)) {
            draw_set_alpha(0.4);
            draw_set_colour(c_white);
            draw_line(_g.x, _g.y, _g.path[_g.leg].x, _g.path[_g.leg].y);
            draw_set_alpha(1);
        }
        draw_set_colour(c_white);
        draw_circle(_g.x, _g.y, 13, true);
    }
    draw_set_colour(vault_colours[_g.vault]);
    draw_circle(_g.x, _g.y, 9, false);
    if (_g.has_key) {
        draw_set_colour(c_yellow);
        draw_rectangle(_g.x + 8, _g.y - 2, _g.x + 16, _g.y + 2, false);
    }
    draw_set_colour(c_white);
    if (_status == gmsa_plan_status.PLANNING) draw_text(_g.x, _g.y - 18, "...");
    else if (_status == gmsa_plan_status.FAILED) draw_text(_g.x, _g.y - 18, "?");
}