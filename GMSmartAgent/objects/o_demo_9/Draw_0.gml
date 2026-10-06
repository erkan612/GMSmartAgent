var _w = room_width * 0.6;

// outside and the vault
draw_set_color(make_color_rgb(38, 42, 50));
draw_rectangle(0, 0, wall_x, room_height, false);
draw_set_color(make_color_rgb(50, 38, 38));
draw_rectangle(wall_x, 0, _w, room_height, false);

// the wall, with gaps for the window and the door
draw_set_color(c_ltgray);
draw_line_width(wall_x, 0, wall_x, win_y - 30, 6);
draw_line_width(wall_x, win_y + 30, wall_x, door_y - 44, 6);
draw_line_width(wall_x, door_y + 44, wall_x, room_height, 6);
draw_set_color(make_color_rgb(120, 170, 220));
draw_rectangle(wall_x - 3, win_y - 30, wall_x + 3, win_y + 30, false);
draw_set_color(door_locked ? c_red : c_lime);
draw_rectangle(wall_x - 6, door_y - 44, wall_x + 6, door_y + 44, !door_locked);

draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_set_color(c_silver);
draw_text(wall_x - 60, win_y, "window");
draw_text(wall_x - 70, door_y - 60, door_locked ? "door, locked" : "door");

// pedestal and key
draw_set_color(c_gray);
draw_rectangle(pedestal.x - 16, pedestal.y - 16, pedestal.x + 16, pedestal.y + 16, false);
if (key_on_pedestal) {
    draw_set_color(c_yellow);
    draw_rectangle(pedestal.x - 9, pedestal.y - 3, pedestal.x + 9, pedestal.y + 3, false);
}
draw_set_color(c_silver);
draw_text(pedestal.x, pedestal.y + 32, "pedestal");

// shop
draw_set_color(make_color_rgb(120, 80, 40));
draw_rectangle(shop.x - 34, shop.y - 14, shop.x + 34, shop.y + 14, false);
draw_set_color(c_silver);
draw_text(shop.x, shop.y + 30, "shop, a key for 10 gold");

// coins
draw_set_color(c_yellow);
for (var _i = 0; _i < array_length(coins); _i++) draw_circle(coins[_i].x, coins[_i].y, 7, false);

// chest
draw_set_color(chest_open ? c_yellow : make_color_rgb(140, 90, 40));
draw_rectangle(chest.x - 22, chest.y - 16, chest.x + 22, chest.y + 16, false);
draw_set_color(c_silver);
draw_text(chest.x, chest.y + 32, chest_open ? "chest, open" : "chest");

// the goblin, where it is heading and how far its work is
if (gob.doing != undefined) {
    var _dest = destination(gob.doing, gob.doing_target);
    draw_set_alpha(0.35);
    draw_set_color(c_lime);
    draw_line(gob.x, gob.y, _dest.x, _dest.y);
    draw_set_alpha(1);
    var _work = work_time(gob.doing);
    if (_work > 0 && gob.timer > 0) {
        draw_set_color(c_dkgray);
        draw_rectangle(gob.x - 16, gob.y + 18, gob.x + 16, gob.y + 22, false);
        draw_set_color(c_lime);
        draw_rectangle(gob.x - 16, gob.y + 18, gob.x - 16 + 32 * gob.timer / _work, gob.y + 22, false);
    }
}
draw_set_color(make_color_rgb(90, 170, 70));
draw_circle(gob.x, gob.y, 12, false);
var _carry = string(gob.gold) + "g";
if (gob.has_key) _carry += ", key";
if (gob.has_pick) _carry += ", pick";
draw_set_color(c_white);
draw_text(gob.x, gob.y - 24, _carry);