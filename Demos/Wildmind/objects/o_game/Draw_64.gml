player_hud_draw();
gmui_draw_gui();
if (demo_paused() && !global.demo_menu) {
    draw_set_colour(c_white);
    draw_text(display_get_gui_width() div 2 - 30, 20, "Paused");
}