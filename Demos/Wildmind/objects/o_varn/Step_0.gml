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
        if (state_time < attack.windup * attack.lock) {
            var _aim = _to_player;
            if (using_read && (attack.shape == varn_shape.ARC || attack.shape == varn_shape.CHARGE)) { // aims ahead of the roll he expects
                var _lead = (attack.shape == varn_shape.CHARGE) ? 110 : 60;
                var _ax = target.x + lengthdir_x(_lead, _to_player + duel_dodge_angle(read.dodge));
                var _ay = target.y + lengthdir_y(_lead, _to_player + duel_dodge_angle(read.dodge));
                _aim = point_direction(x, y, _ax, _ay);
            }
            facing += angle_difference(_aim, facing) * min(1, 4 * _dt);
        }
        if (state_time >= attack.windup) {
            if (watch != "" && instance_exists(target)) { // the hit comes now: where did the player go since the windup started
                duel_read_learn(watch, duel_dodge_kind(target.x - watch_x, target.y - watch_y, watch_from));
                watch = "";
            }
            attack_dir = facing;
            swing = demo_swing_create(id, team, attack.damage, attack.knock);
            start(varn_state.ACTIVE);
        }
        break;

    case varn_state.ACTIVE:
        strike(_dt);
        if (state_time >= attack.active) {
            if (using_read && array_length(swing.hit) == 0) varn_taunt_miss(id); // he aimed at a guess and caught nothing
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