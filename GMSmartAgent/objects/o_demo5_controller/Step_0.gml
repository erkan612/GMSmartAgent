// keep the room stocked
repeat (loot_target - instance_number(o_demo5_loot)) spawn();

// Q and E: influence down and up, R: forget everything learned
if (keyboard_check_pressed(ord("Q"))) influence = max(0, influence - 0.25);
if (keyboard_check_pressed(ord("E"))) influence = min(1, influence + 0.25);
if (keyboard_check_pressed(ord("Q")) || keyboard_check_pressed(ord("E"))) {
    gmsa_learn_set_influence(global.demo5_companion_profile, influence);
}
if (keyboard_check_pressed(ord("R"))) gmsa_learn_reset(global.demo5_model);