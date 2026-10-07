// the shop
draw_set_colour(make_color_rgb(34, 30, 28));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_colour(make_color_rgb(90, 66, 44));
draw_rectangle(area_w * 0.05, room_height * 0.42 + 52, area_w * 0.95, room_height * 0.42 + 64, false);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// the items, each learner's guess ringed: blue the n-gram, green the TDNN
for (var _i = 0; _i <= array_length(shelf); _i++) {
    var _b = item_box(_i);
    if (_i == ng_best) {
        draw_set_colour(make_color_rgb(90, 140, 230));
        draw_rectangle(_b.l - 10, _b.t - 10, _b.r + 10, _b.b + 10, true);
        draw_rectangle(_b.l - 11, _b.t - 11, _b.r + 11, _b.b + 11, true);
    }
    if (_i == td_best) {
        draw_set_colour(make_color_rgb(110, 210, 120));
        draw_rectangle(_b.l - 5, _b.t - 5, _b.r + 5, _b.b + 5, true);
        draw_rectangle(_b.l - 6, _b.t - 6, _b.r + 6, _b.b + 6, true);
    }
    draw_set_colour((_i == 0) ? make_color_rgb(150, 150, 165) : make_color_rgb(150, 60, 160));
    draw_roundrect(_b.l, _b.t, _b.r, _b.b, false);
    draw_set_colour(c_white);
    draw_text(_b.x, _b.y - 14, (_i == 0) ? "sword" : "potion");
    draw_text(_b.x, _b.y + 12, string((_i == 0) ? sword.price : shelf[_i - 1].price) + " g");
}
draw_set_colour(make_color_rgb(90, 140, 230));
draw_text(area_w * 0.3, room_height * 0.42 - 92, "blue: the n-gram's guess");
draw_set_colour(make_color_rgb(110, 210, 120));
draw_text(area_w * 0.7, room_height * 0.42 - 92, "green: the TDNN's guess");

if (flash > 0) {
    draw_set_alpha(min(1, flash / 15));
    draw_set_colour(c_yellow);
    draw_text_transformed(area_w * 0.5, room_height * 0.18, flash_text, 1.4, 1.4, 0);
    draw_set_alpha(1);
}

// the last buys, oldest first
var _by = room_height * 0.82;
draw_set_colour(c_gray);
draw_text(area_w * 0.5, _by - 34, "last buys");
var _bx = area_w * 0.5 - array_length(bought) * 45;
for (var _i = 0; _i < array_length(bought); _i++) {
    var _k = bought[_i];
    var _x = _bx + _i * 90;
    draw_set_colour((_k.kind == "sword") ? make_color_rgb(150, 150, 165) : make_color_rgb(150, 60, 160));
    draw_roundrect(_x, _by - 16, _x + 84, _by + 16, false);
    draw_set_colour(c_white);
    draw_text(_x + 42, _by, _k.kind + " " + string(_k.price));
}