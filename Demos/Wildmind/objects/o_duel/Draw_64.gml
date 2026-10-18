if (instance_exists(varn)) {
    var _w = 600;
    var _x = (display_get_gui_width() - _w) / 2;
    var _y = display_get_gui_height() - 50;
    draw_set_colour(c_white);
    draw_text(_x, _y - 22, "Oathkeeper Varn");
    __hud_bar(_x, _y, _w, 12, varn.hp / varn.hp_max, make_color_rgb(190, 60, 40));
}

var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
if (show_habits || varn.dead || player.dead) duel_habits_draw(_gw - 340, 20);

if (varn.dead) {
    draw_set_halign(fa_center);
    draw_set_colour(make_color_rgb(255, 170, 90));
    draw_text_transformed(_gw / 2, _gh / 2 - 40, "Oathkeeper Varn falls", 2, 2, 0);
    draw_set_colour(c_white);
    draw_text(_gw / 2, _gh / 2 + 10, "R to fight again");
    draw_set_halign(fa_left);
}

if (intro) {
    draw_set_alpha(0.75);
    draw_set_colour(c_black);
    draw_rectangle(0, 0, _gw, _gh, false);
    draw_set_alpha(1);
    draw_set_halign(fa_center);
    draw_set_colour(make_color_rgb(255, 170, 90));
    draw_text_transformed(_gw / 2, _gh / 2 - 150, "Oathkeeper Varn", 2, 2, 0);
    draw_set_colour(c_white);
    draw_text(_gw / 2, _gh / 2 - 80, "He watches how you dodge, and learns.");
    draw_text(_gw / 2, _gh / 2 - 20, "WASD move    Mouse aim    Left click sword    Right click bow    Space roll    Q potion");
    draw_text(_gw / 2, _gh / 2 + 40, "Varn learns from you: " + (global.duel_learning ? "ON" : "OFF") + "    (L to change)");
    draw_text(_gw / 2, _gh / 2 + 100, "Press Enter to fight");
    draw_set_halign(fa_left);
}