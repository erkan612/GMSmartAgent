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
if (keyboard_check_pressed(ord("A"))) auto = !auto;
if (keyboard_check_pressed(ord("G")) && !fitting) new_crowd();
for (var _k = 0; _k < 5; _k++) if (keyboard_check_pressed(ord(string(_k + 1)))) switch_live(_k);

// paused: Space or N plays one minute. Fast: four frames per frame. Slow: one frame in four
if (paused) {
    if (keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("N"))) live_tick();
} else if (slow) {
    slow_count = (slow_count + 1) mod 4;
    if (slow_count == 0) tick();
} else {
    repeat (fast ? 4 : 1) tick();
}