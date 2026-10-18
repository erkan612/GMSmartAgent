function player_hud_draw() { // health, stamina and potions, in Draw GUI
    if (!instance_exists(o_player)) return;
    var _p = instance_find(o_player, 0);
    __hud_bar(20, 20, 240, 14, _p.hp / _p.hp_max, make_color_rgb(200, 50, 60));
    __hud_bar(20, 40, 240, 8, _p.stamina / _p.stamina_max, make_color_rgb(90, 190, 90));
    draw_set_colour(c_white);
    draw_text(20, 54, "Potions: " + string(_p.potions));
    if (_p.state == player_state.DEAD) draw_text(20, 74, "You died. R to restart");
}

function __hud_bar(_x, _y, _w, _h, _fill, _col) {
    draw_set_colour(make_color_rgb(30, 30, 30));
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_colour(_col);
    if (_fill > 0) draw_rectangle(_x, _y, _x + _w * clamp(_fill, 0, 1), _y + _h, false);
}