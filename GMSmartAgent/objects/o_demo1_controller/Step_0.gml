// 1-4 spawn key, chest, potion, heart at the mouse position
for (var _k = 0; _k < 4; _k++) {
    if (keyboard_check_pressed(ord(string(_k + 1)))) {
        instance_create_depth(mouse_x, mouse_y, 0, o_demo1_item, { kind : _k });
    }
}
if (mouse_check_button_pressed(mb_right)) {
    with (o_demo1_agent) hp = max(1, hp - 20);
}
if (keyboard_check_pressed(ord("R"))) room_restart();