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
if (keyboard_check_pressed(ord("S"))) {
    kind = (kind + 1) mod array_length(kinds);
    reset();
}
if (keyboard_check_pressed(ord("T"))) {
    target_i = (target_i + 1) mod array_length(targets);
    reset();
}

// paused or auto off: Space or N fights once. Fast: four frames per frame. Slow: one frame in four
if ((paused || !auto) && (keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("N")))) fight();
if (!paused) {
    if (slow) {
        slow_count = (slow_count + 1) mod 4;
        if (slow_count == 0) tick();
    } else {
        repeat (fast ? 4 : 1) tick();
    }
}