function demo_debug_init() {
    global.debug = { open : false, nav : false, hitboxes : false, god : false, scene : undefined };
    global.ui_mouse = false; // true while the mouse is over the debug window, so clicks there don't reach the game
}

function demo_debug_ui() { // the debug window on F1, after gmui_update. A scene adds its own part through global.debug.scene
    var _d = global.debug;
    if (keyboard_check_pressed(vk_f1)) _d.open = !_d.open;
    global.ui_mouse = false;
    if (!_d.open) return;
    if (gmui_begin_window("Debug", display_get_gui_width() - 580, 90, 560, 520)) {
        gmui_text("fps: " + string(round(fps_real)));
        gmui_text("game time: " + string(demo_now() div 1000000) + " s");
        var _paused = gmui_checkbox(demo_paused(), "Paused (P)");
        if (_paused != demo_paused()) demo_pause(_paused);
        _d.god = gmui_checkbox(_d.god, "Player can't be hurt");
        _d.hitboxes = gmui_checkbox(_d.hitboxes, "Show hitboxes");
        _d.nav = gmui_checkbox(_d.nav, "Show navigation");
        if (_d.scene != undefined) {
            gmui_separator();
            _d.scene();
        }
        gmui_end_window();
    }
    global.ui_mouse = gmui_container_is_hovered("Debug");
}