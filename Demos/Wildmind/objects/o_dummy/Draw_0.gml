fighter_draw(demo_art("dummy"), 0);
__hud_bar(x - 20, y - 30, 40, 4, hp / hp_max, make_color_rgb(200, 50, 60));
if (damage_show > 0) {
    draw_set_colour(c_yellow);
    draw_set_halign(fa_center);
    draw_text(x, y - 50 + damage_show * 20, string(last_damage));
    draw_set_halign(fa_left);
}