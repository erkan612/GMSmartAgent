if (mouse_check_button_pressed(mb_left)) instance_create_depth(mouse_x, mouse_y, 0, o_kit_coin);
if (mouse_check_button_pressed(mb_right)) instance_create_depth(mouse_x, mouse_y, 0, o_kit_potion);
if (keyboard_check_pressed(vk_down)) with (o_kit_goblin) hp = max(0, hp - 30);
if (keyboard_check_pressed(ord("G"))) {
    repeat (20) {
        instance_create_depth(random(room_width), random(room_height), -1, o_kit_goblin);
        instance_create_depth(random(room_width), random(room_height), 0, o_kit_coin);
    }
}

var _t = 0;
with (o_kit_goblin) {
    var _s = get_timer();
    gmsa_kit_agent_update(agent);
    _t += get_timer() - _s;
}
var _n = instance_number(o_kit_goblin);
if (_n > 0) time_avg = lerp(time_avg, _t / _n, 0.05);