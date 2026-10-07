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
if (keyboard_check_pressed(ord("T"))) {
    threshold_i = (threshold_i + 1) mod array_length(thresholds);
    predict_next();
}
// step in or back off
if (keyboard_check_pressed(vk_right) || keyboard_check_pressed(vk_left)) {
    far = keyboard_check_pressed(vk_left);
    predict_next();
}
// your own moves, any time
for (var _i = 0; _i < 6; _i++) {
    if (keyboard_check_pressed(ord(string(_i + 1)))) do_move(_i);
}

// paused: Space or N makes one auto-player move. Fast: four frames per frame. Slow: one frame in four
if (paused) {
    if (auto && (keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("N")))) do_move(auto_pick());
} else if (slow) {
    slow_count = (slow_count + 1) mod 4;
    if (slow_count == 0) tick();
} else {
    repeat (fast ? 4 : 1) tick();
}