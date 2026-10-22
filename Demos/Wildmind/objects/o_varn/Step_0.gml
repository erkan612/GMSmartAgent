if (demo_paused()) exit;
var _dt = demo_dt();
speech_time -= _dt;
taunt_wait -= _dt;
if (dead) exit;
fighter_tick(id, _dt);
state_time += _dt;
var _alive = instance_exists(target) && !target.dead;
if (after != undefined && _alive) { // watching what the player does after his attack
    if (target.state == player_state.ATTACK) after.attacked = true;
    if (target.state == player_state.SHOOT) after.shot = true;
    if (target.state == player_state.DRINK) after.drank = true;
    if (demo_now() - after.at >= DUEL_AFTER_WINDOW * 1000000) after_end();
}
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
            nav_stop();
        }
        break;

    case varn_state.WINDUP:
        if (state_time < windup_time * ((using_read || following) ? attack.lock : VARN_PLAIN_LOCK)) { // a warning that keeps following the player means he has a read
            var _aim = _to_player;
            if (using_read && (attack.shape == varn_shape.ARC || attack.shape == varn_shape.CHARGE)) { // aims ahead of the roll he expects
                var _lead = (attack.shape == varn_shape.CHARGE) ? 110 : 60;
                var _ax = target.x + lengthdir_x(_lead, _to_player + duel_dodge_angle(read.dodge));
                var _ay = target.y + lengthdir_y(_lead, _to_player + duel_dodge_angle(read.dodge));
                _aim = point_direction(x, y, _ax, _ay);
            }
            facing += angle_difference(_aim, facing) * min(1, 4 * _dt);
            if (attack.shape == varn_shape.CIRCLE && using_read) aim_slam(VARN_HOLD_STEP * _dt); // only when he's sure: the circle follows the dodge he expects
        }
        if (state_time >= windup_time) {
            if (watch != "" && instance_exists(target)) { // the hit comes now: where did the player go since the windup started, and when
                var _evaded = (target.evade_at >= windup_at);
                var _kind;
                if (_evaded) _kind = duel_dodge_kind(lengthdir_x(100, target.roll_dir), lengthdir_y(100, target.roll_dir), watch_from); // the way they rolled or dodged
                else if (varn_in_zone(id, target.x, target.y)) _kind = "stay"; // still where it lands: moving around isn't an answer
                else _kind = duel_dodge_kind(target.x - watch_x, target.y - watch_y, watch_from); // walked out of it
                duel_read_learn(watch, situation, _kind);
                if (_evaded) o_duel.reads.dodge_dist = lerp(o_duel.reads.dodge_dist, point_distance(watch_x, watch_y, target.x, target.y), 0.3);
                if (target.evade_at >= windup_at) duel_timing_learn((demo_now() - target.evade_at) / 1000000);
                watch = "";
            }
            if (tactic == "hold") {
                hold_dir = facing;
                start(varn_state.HOLD);
            } else {
                swing_now();
            }
        }
        break;

    case varn_state.HOLD: // he waits out an early roll or dodge, then follows the player and swings
        if (_alive) {
            var _face = _to_player;
            if (attack.shape == varn_shape.SIDE) _face = _to_player - sweep_side * 0.67; // keeps the player inside the swept side
            facing += angle_difference(_face, facing) * min(1, 8 * _dt);
            facing = hold_dir + clamp(angle_difference(facing, hold_dir), -30, 30); // he waits out the roll, he doesn't spin after it
            var _dist = point_distance(x, y, target.x, target.y);
            var _ahead = abs(angle_difference(_to_player, facing)) < 60;
            if ((attack.shape == varn_shape.ARC || attack.shape == varn_shape.SIDE) && _ahead && _dist > attack.reach * 0.7) {
                x += lengthdir_x(VARN_HOLD_WALK * _dt, _to_player);
                y += lengthdir_y(VARN_HOLD_WALK * _dt, _to_player);
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
            if (played && _landed) o_duel.reads.caught += 1;
            if (tactic != "" && _landed) varn_taunt_timing(id);
            else if ((using_read || tactic != "") && !_landed) varn_taunt_miss(id); // he played a guess and caught nothing
            var _base = varn_attack_base(doing);
            duel_lands_learn(_base, _landed);
            //var _l = o_duel.reads.lands[$ _base];
            if (global.duel_learning && !_landed && duel_lands_works(_base) <= 0.34 && !variable_struct_exists(given_up, _base)) {
                given_up[$ _base] = true;
                varn_say(id, "Hm. You read that one.");
                taunt_wait = 8;
            }
            start(varn_state.RECOVER);
            after_start(_landed);
        }
        break;

    case varn_state.RECOVER:
        if (state_time >= recover_time) finish();
        break;

    case varn_state.GUARD:
        facing += angle_difference(_to_player, facing) * min(1, 3 * _dt);
        if (state_time >= VARN_GUARD_TIME) finish();
        break;
}

demo_arena_collide(global.arena, id);
nav.x = x;
nav.y = y;