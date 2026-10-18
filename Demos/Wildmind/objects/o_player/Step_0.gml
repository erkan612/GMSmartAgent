if (demo_paused()) exit;
var _dt = demo_dt();
fighter_tick(id, _dt);
state_time += _dt;
aim = point_direction(x, y, mouse_x, mouse_y);

var _mx = keyboard_check(ord("D")) - keyboard_check(ord("A"));
var _my = keyboard_check(ord("S")) - keyboard_check(ord("W"));
var _moving = (_mx != 0 || _my != 0);
if (_moving) move_dir = point_direction(0, 0, _mx, _my);

stamina_wait -= _dt;
if (stamina_wait <= 0) stamina = min(stamina_max, stamina + PLAYER_STAMINA_REGEN * _dt);

var _speed = 0;
var _dir = move_dir;
switch (state) {
    case player_state.MOVE:
        if (_moving) _speed = PLAYER_SPEED;
        if (keyboard_check_pressed(vk_space)) roll(_moving ? move_dir : aim);
        else if (mouse_check_button_pressed(mb_left) && !global.ui_mouse) attack(0);
        else if (mouse_check_button_pressed(mb_right) && !global.ui_mouse) shoot();
        else if (keyboard_check_pressed(ord("Q"))) drink();
        break;

    case player_state.ROLL:
        _speed = PLAYER_ROLL_SPEED;
        _dir = roll_dir;
        if (state_time >= PLAYER_ROLL_TIME) start(player_state.MOVE);
        break;

    case player_state.ATTACK:
        var _hit = player_combo_hit(combo);
        var _active_end = _hit.windup + PLAYER_MELEE_ACTIVE;
        if (mouse_check_button_pressed(mb_left) && !global.ui_mouse && combo < 2) combo_queued = true;
        if (state_time >= _hit.windup && state_time < _active_end) {
            if (swing == undefined) swing = demo_swing_create(id, team, _hit.damage, _hit.knock);
            demo_swing_hit_circle(swing, x + lengthdir_x(PLAYER_MELEE_REACH, attack_dir), y + lengthdir_y(PLAYER_MELEE_REACH, attack_dir), PLAYER_MELEE_RADIUS);
            _speed = 80;   // a small step into the swing
            _dir = attack_dir;
        }
        if (state_time >= _active_end) {
            if (keyboard_check_pressed(vk_space)) {
                roll(_moving ? move_dir : aim);   // the recovery can be rolled out of
            } else if (combo_queued) {
                combo_queued = false;
                attack(combo + 1);
            } else if (state_time >= _active_end + _hit.recover) {
                combo = 0;
                start(player_state.MOVE);
            }
        }
        break;

    case player_state.SHOOT:
        if (_moving) _speed = PLAYER_SPEED * PLAYER_SLOW;
        if (!shot_fired && state_time >= PLAYER_SHOT_WINDUP) {
            shot_fired = true;
            var _a = instance_create_depth(x + lengthdir_x(20, aim), y + lengthdir_y(20, aim), depth - 1, o_arrow);
            _a.dir = aim;
            _a.swing = demo_swing_create(_a, team, PLAYER_ARROW_DAMAGE, 160);
        }
        if (state_time >= PLAYER_SHOT_TIME) start(player_state.MOVE);
        break;

    case player_state.DRINK:
        if (_moving) _speed = PLAYER_SPEED * PLAYER_SLOW;
        if (state_time >= PLAYER_POTION_TIME) {
            hp = min(hp_max, hp + PLAYER_POTION_HEAL);
            start(player_state.MOVE);
        }
        break;

    case player_state.HURT:
        if (state_time >= PLAYER_HURT_TIME) start(player_state.MOVE);
        break;

    case player_state.DEAD:
        if (keyboard_check_pressed(ord("R"))) room_restart();
        break;
}

x += lengthdir_x(_speed * _dt, _dir);
y += lengthdir_y(_speed * _dt, _dir);
if (global.arena != undefined) {
    demo_arena_collide(global.arena, id);
} else {
    x = clamp(x, radius, room_width - radius);
    y = clamp(y, radius, room_height - radius);
}