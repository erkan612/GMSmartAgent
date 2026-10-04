// WASD to move
var _h = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var _v = keyboard_check(ord("S")) - keyboard_check(ord("W"));
x = clamp(x + _h * 3, 0, room_width);
y = clamp(y + _v * 3, 0, room_height);

// click loot inside your circle to take it, and record what you chose over what
if (mouse_check_button_pressed(mb_left)) {
    var _hit = instance_nearest(mouse_x, mouse_y, o_demo5_loot);
    if (_hit != noone && point_distance(mouse_x, mouse_y, _hit.x, _hit.y) <= 14
        && point_distance(x, y, _hit.x, _hit.y) <= DEMO5_REACH) {
        var _near = demo5_loot_near(id, DEMO5_REACH);
        var _offered = [];
        var _chosen = 0;
        for (var _i = 0; _i < array_length(_near); _i++) {
            array_push(_offered, { action : "take", target : _near[_i] });
            if (_near[_i] == _hit) _chosen = _i;
        }
        gmsa_learn_observe(global.demo5_model, gmsa_observe(agent, _offered, _chosen));
        taken++;
        instance_destroy(_hit);
    }
}