if (keyboard_check_pressed(ord("S"))) shuffle(); // new secret rules, the learning crew has to find out again
if (keyboard_check_pressed(ord("H"))) reveal = !reveal;
if (keyboard_check_pressed(ord("R"))) reset();
if (keyboard_check_pressed(ord("P"))) paused = !paused;
if (shuffled_flash > 0) shuffled_flash--;

if (mouse_check_button_pressed(mb_left)) {
    for (var _i = 0; _i < array_length(goblins); _i++) {
        if (point_distance(mouse_x, mouse_y, goblins[_i].x, goblins[_i].y) < 12) selected = goblins[_i];
    }
}

// time moves only when not paused, Space lets one frame through
if (!paused || keyboard_check_pressed(vk_space)) {
    frame++;
    day_time += 1 / day_length;
    if (day_time >= 1) day_time -= 1;
    if (keyboard_check_pressed(ord("N"))) day_time = (day_time + 0.5) mod 1;
    night = (day_time >= 0.5);
    for (var _i = 0; _i < array_length(goblins); _i++) act(goblins[_i]);
}