if (keyboard_check_pressed(ord("P")) && !global.demo_menu) demo_pause(!demo_paused());
gmui_update();
demo_debug_ui();