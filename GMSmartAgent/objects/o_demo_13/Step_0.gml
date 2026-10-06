if (keyboard_check_pressed(ord("H"))) flaw = (flaw + 1) mod array_length(flaw_names);
if (keyboard_check_pressed(ord("F"))) fast = !fast;
if (keyboard_check_pressed(ord("R"))) reset();
if (keyboard_check_pressed(ord("P"))) paused = !paused;
if (mouse_check_button_pressed(mb_left)) toggle(mouse_x, mouse_y);

// paused: Space lets one frame through. Fast: four frames per frame
var _runs = paused ? (keyboard_check_pressed(vk_space) ? 1 : 0) : (fast ? 4 : 1);
repeat (_runs) tick();