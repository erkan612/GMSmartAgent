if (intro) {
    if (keyboard_check_pressed(ord("L"))) global.duel_learning = !global.duel_learning;
    if (keyboard_check_pressed(vk_enter)) {
        intro = false;
        fight_start = demo_now();
        global.demo_menu = false;
        demo_pause(false);
    }
    exit;
}
if (fight_end < 0 && (varn.dead || player.dead)) {
    fight_end = demo_now();
    summary = duel_summary_lines();
}
if (keyboard_check_pressed(ord("H"))) show_habits = !show_habits;
if (cheat_stamina) player.stamina = player.stamina_max;
if (varn.dead && keyboard_check_pressed(ord("R"))) room_restart();