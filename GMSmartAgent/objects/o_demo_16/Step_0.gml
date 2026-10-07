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
if (keyboard_check_pressed(ord("S"))) habits = 1 - habits;

// click an item to buy it yourself
if (mouse_check_button_pressed(mb_left)) {
    for (var _i = 0; _i <= array_length(shelf); _i++) {
        var _b = item_box(_i);
        if (point_in_rectangle(mouse_x, mouse_y, _b.l, _b.t, _b.r, _b.b)) {
            buy(_i);
            break;
        }
    }
}

// paused: Space or N makes one auto buy. Fast: four frames per frame. Slow: one frame in four
if (paused) {
    if (auto && (keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("N")))) buy(auto_pick());
} else if (slow) {
    slow_count = (slow_count + 1) mod 4;
    if (slow_count == 0) tick();
} else {
    repeat (fast ? 4 : 1) tick();
}