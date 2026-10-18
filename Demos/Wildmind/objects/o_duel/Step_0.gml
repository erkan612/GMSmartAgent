if (intro) {
    if (keyboard_check_pressed(ord("L"))) global.duel_learning = !global.duel_learning;
    if (keyboard_check_pressed(vk_enter)) {
        intro = false;
        global.demo_menu = false;
        demo_pause(false);
    }
    exit;
}
if (keyboard_check_pressed(ord("H"))) show_habits = !show_habits;
if (varn.dead && keyboard_check_pressed(ord("R"))) room_restart();