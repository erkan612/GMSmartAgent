if (demo_paused()) exit;
var _dt = demo_dt();
speech_time -= _dt;
taunt_wait -= _dt;
if (dead) exit;
fighter_tick(id, _dt);
state_time += _dt;
var _alive = instance_exists(target) && !target.dead;
var _to_player = _alive ? point_direction(x, y, target.x, target.y) : facing;

switch (state) {
    case varn_state.FREE:
        facing += angle_difference(_to_player, facing) * min(1, 6 * _dt);
        var _d = gmsa_agent_consume(agent);
        if (_d != undefined && _alive && !o_duel.hold_varn) {
            var _o = gmsa_decision_get_chosen(_d);
            if (_o != undefined) take(_o);
        }
        if (state == varn_state.FREE && doing == "approach" && _alive && !o_duel.hold_varn) {
            repath_wait -= _dt;
            if (repath_wait <= 0 && point_distance(goal_x, goal_y, target.x, target.y) > 24) {
                demo_nav_goto(nav, o_duel.nav_grid, target.x, target.y);
                goal_x = target.x;
                goal_y = target.y;
                repath_wait = 0.3;
            }
            gmnav_agent_update(nav);
            x += nav.vx * _dt * 60; // GMNav speeds are per frame, this keeps them on the game clock
            y += nav.vy * _dt * 60;
        } else if (state == varn_state.FREE) {
            gmnav_agent_stop(nav);
        }
        break;

    case varn_state.WINDUP:
        if (state_time < windup_time * attack.lock) {
            var _aim = _to_player;
            if (using_read && (attack.shape == varn_shape.ARC || attack.shape == varn_shape.CHARGE)) { // aims ahead of the roll he expects
                var _lead = (attack.shape == varn_shape.CHARGE) ? 110 : 60;
                var _ax = target.x + lengthdir_x(_lead, _to_player + duel_dodge_angle(read.dodge));
                var _ay = target.y + lengthdir_y(_lead, _to_player + duel_dodge_angle(read.dodge));
                _aim = point_direction(x, y, _ax, _ay);
            }
            facing += angle_difference(_aim, facing) * min(1, 4 * _dt);
        }
        if (state_time >= windup_time) {
            if (watch != "" && instance_exists(target)) { // the hit comes now: where did the player go since the windup started, and when
                duel_read_learn(watch, duel_dodge_kind(target.x - watch_x, target.y - watch_y, watch_from));
                if (target.evade_at >= windup_at) duel_timing_learn((demo_now() - target.evade_at) / 1000000);
                watch = "";
            }
            if (tactic == "hold") start(varn_state.HOLD);
            else swing_now();
        }
        break;

    case varn_state.HOLD: // he waits out an early roll or dodge, then follows the player and swings
        if (_alive) {
            var _face = _to_player;
            if (attack.shape == varn_shape.SIDE) _face = _to_player - sweep_side * 0.67; // keeps the player inside the swept side
            facing += angle_difference(_face, facing) * min(1, 8 * _dt);
            var _dist = point_distance(x, y, target.x, target.y);
            if ((attack.shape == varn_shape.ARC || attack.shape == varn_shape.SIDE) && _dist > attack.reach * 0.7) {
                x += lengthdir_x(VARN_HOLD_STEP * _dt, _to_player);
                y += lengthdir_y(VARN_HOLD_STEP * _dt, _to_player);
            }
            if (attack.shape == varn_shape.CIRCLE) {
                var _len = min(attack.range, _dist);
                var _gx = x + lengthdir_x(_len, _to_player);
                var _gy = y + lengthdir_y(_len, _to_player);
                var _move = min(VARN_HOLD_STEP * _dt, point_distance(slam_x, slam_y, _gx, _gy));
                var _md = point_direction(slam_x, slam_y, _gx, _gy);
                slam_x += lengthdir_x(_move, _md);
                slam_y += lengthdir_y(_move, _md);
            }
        }
        if (state_time >= VARN_HOLD_TIME) swing_now();
        break;

    case varn_state.ACTIVE:
        strike(_dt);
        if (state_time >= attack.active) {
            var _landed = array_length(swing.hit) > 0;
            if (tactic != "" && _landed) varn_taunt_timing(id);
            else if ((using_read || tactic != "") && !_landed) varn_taunt_miss(id); // he played a guess and caught nothing
            start(varn_state.RECOVER);
        }
        break;

    case varn_state.RECOVER:
        if (state_time >= attack.recover) finish();
        break;

    case varn_state.GUARD:
        facing += angle_difference(_to_player, facing) * min(1, 3 * _dt);
        if (state_time >= VARN_GUARD_TIME) finish();
        break;
}

demo_arena_collide(global.arena, id);
nav.x = x;
nav.y = y;