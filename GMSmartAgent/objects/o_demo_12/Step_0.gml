if (keyboard_check_pressed(ord("A"))) guard.habit = (guard.habit + 1) mod 4;
for (var _k = 0; _k < 3; _k++) {
    if (keyboard_check_pressed(ord(string(_k + 1)))) { // you take over: your next post
        guard.habit = 0;
        guard.queued = _k;
    }
}
if (keyboard_check_pressed(ord("F"))) fast = !fast;
if (keyboard_check_pressed(ord("R"))) reset();
if (keyboard_check_pressed(ord("P"))) paused = !paused;

if (mouse_check_button_pressed(mb_left)) {
    for (var _i = 0; _i < array_length(goblins); _i++) {
        if (point_distance(mouse_x, mouse_y, goblins[_i].x, goblins[_i].y) < 12) selected = goblins[_i];
    }
}

// paused: Space lets one frame through. Fast: four frames per frame
var _runs = paused ? (keyboard_check_pressed(vk_space) ? 1 : 0) : (fast ? 4 : 1);
repeat (_runs) tick();