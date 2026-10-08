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
    walk = 0;
    from_x = here_x;
    from_y = here_y;
}

// wandering yourself: click the map to walk there, then 1, 2 or 3
if (!auto) {
    if (mouse_check_button_pressed(mb_left) && point_in_rectangle(mouse_x, mouse_y, map_l, map_t, map_l + map_w, map_t + map_h)) {
        here_x = (mouse_x - map_l) / map_w;
        here_y = (mouse_y - map_t) / map_h;
        from_x = here_x;
        from_y = here_y;
        predict_next();
    }
    if (keyboard_check_pressed(ord("1"))) act(0);
    if (keyboard_check_pressed(ord("2"))) act(1);
    if (keyboard_check_pressed(ord("3"))) act(2);
}

// paused: Space or N makes one auto stop. Fast: four frames per frame. Slow: one frame in four
if (paused) {
    if (auto && (keyboard_check_pressed(vk_space) || keyboard_check_pressed(ord("N")))) {
        walk = 0;
        act(auto_pick());
    }
} else if (slow) {
    slow_count = (slow_count + 1) mod 4;
    if (slow_count == 0) tick();
} else {
    repeat (fast ? 4 : 1) tick();
}

// the two maps keep redrawing at the same pace whatever the speed
heat_step(4);