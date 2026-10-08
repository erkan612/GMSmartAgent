if (keyboard_check_pressed(ord("F"))) {
    fast = !fast;
    slow = false;
}
if (keyboard_check_pressed(ord("D"))) {
    slow = !slow;
    fast = false;
}
if (keyboard_check_pressed(ord("P"))) paused = !paused;
if (keyboard_check_pressed(ord("R"))) reset();
if (keyboard_check_pressed(ord("A"))) {
    auto = !auto;
    timer = 0;
}
if (keyboard_check_pressed(ord("H"))) show_true = !show_true;
if (keyboard_check_pressed(ord("J"))) join();
if (keyboard_check_pressed(ord("B"))) fair();

// click a bot's row: its explanation in the panel
if (mouse_check_button_pressed(mb_left) && mouse_x < area_w) {
    var _row = floor((mouse_y - ladder_t) / row_h);
    if (_row >= 0 && _row < array_length(row_names)) selected = row_names[_row];
}

// paused or auto off: Space or N plays one match. Fast: four frames per frame. Slow: one frame in four
if ((paused || !auto) && (keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("N")))) next_match();
if (!paused) {
    if (slow) {
        slow_count = (slow_count + 1) mod 4;
        if (slow_count == 0) tick();
    } else {
        repeat (fast ? 4 : 1) tick();
    }
}