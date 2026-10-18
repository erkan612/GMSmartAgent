event_inherited();
team = 2;
radius = 34;
hp_max = 3000;
hp = hp_max;
knock_scale = 0.1; // he barely moves when hit
nav = undefined;   // set by o_duel
agent = undefined;
target = noone;
facing = 270;
state = varn_state.FREE;
state_time = 0;
doing = "";        // the action he's carrying out
attack = undefined;
attack_dir = 0;
swing = undefined;
slam_x = x;
slam_y = y;
read = { dodge : "stay", sure : 0 }; // his guess at the player's dodge for the current attack
using_read = false; // whether he's acting on it
thought = "";
speech = "";        // what he says out loud, in a bubble
speech_time = 0;
taunt_wait = 0;     // seconds before he taunts again
first_read = true;
sweep_side = 90;    // 90 sweeps to his left, -90 to his right
watch = "";         // the attack whose answer he's waiting to see
watch_x = x;        // where the player stood when it started
watch_y = y;
watch_from = 0;
repath_wait = 0;
goal_x = x;
goal_y = y;

start = function(_state) {
    state = _state;
    state_time = 0;
};

take = function(_option) { // acts on a fresh choice from his agent
    gmsa_agent_set_current_option(agent, _option);
    doing = _option.action.name;
    var _a = varn_attack(doing);
    if (_a != undefined) {
        attack = _a;
        read = duel_read(doing);
        using_read = (read.sure >= DUEL_READ_SURE && read.dodge != "stay");
        thought = using_read ? "you'll dodge " + duel_dodge_words(read.dodge) + " (" + string(round(read.sure * 100)) + "%)" : "";
        if (using_read) varn_taunt_read(id);
        var _to = point_direction(x, y, target.x, target.y);
        if (_a.shape == varn_shape.CIRCLE) { // the slam lands where the player will be: where he stands, or where Varn expects him to roll
            var _px = target.x;
            var _py = target.y;
            if (using_read) {
                _px += lengthdir_x(DUEL_DODGE_DISTANCE * 0.8, _to + duel_dodge_angle(read.dodge));
                _py += lengthdir_y(DUEL_DODGE_DISTANCE * 0.8, _to + duel_dodge_angle(read.dodge));
            }
            var _len = min(_a.range, point_distance(x, y, _px, _py));
            var _dir = point_direction(x, y, _px, _py);
            slam_x = x + lengthdir_x(_len, _dir);
            slam_y = y + lengthdir_y(_len, _dir);
        }
        if (_a.shape == varn_shape.SIDE) { // the side he expects the player to roll into, or the side the player is on
            if (using_read && read.dodge == "dodge_left") sweep_side = 90;
            else if (using_read && read.dodge == "dodge_right") sweep_side = -90;
            else sweep_side = (angle_difference(_to, facing) >= 0) ? 90 : -90;
        }
        watch = doing;
        watch_x = target.x;
        watch_y = target.y;
        watch_from = _to;
        gmsa_agent_set_busy(agent, true);
        gmnav_agent_stop(nav);
        start(varn_state.WINDUP);
    } else if (doing == "guard") {
        gmsa_agent_set_busy(agent, true);
        gmnav_agent_stop(nav);
        start(varn_state.GUARD);
    }
};

finish = function() { // an attack or guard is over: he thinks again at once
    gmsa_agent_set_busy(agent, false);
    gmsa_agent_clear_current(agent);
    gmsa_agent_wake(agent);
    doing = "";
    thought = "";
    using_read = false;
    attack = undefined;
    swing = undefined;
    start(varn_state.FREE);
};

strike = function(_dt) { // the active part of an attack, every step
    switch (attack.shape) {
        case varn_shape.ARC:
            demo_swing_hit_arc(swing, x, y, attack.reach, attack_dir, attack.half);
            break;
        case varn_shape.SIDE:
            demo_swing_hit_arc(swing, x, y, attack.reach, attack_dir + sweep_side, attack.half);
            break;
        case varn_shape.CIRCLE:
            demo_swing_hit_circle(swing, slam_x, slam_y, attack.radius);
            break;
        case varn_shape.CHARGE:
            x += lengthdir_x(attack.speed * _dt, attack_dir);
            y += lengthdir_y(attack.speed * _dt, attack_dir);
            demo_swing_hit_circle(swing, x, y, radius + 6);
            break;
    }
};

blocks = function(_from_dir) { // the shield stops what comes from the front while he guards
    return state == varn_state.GUARD && abs(angle_difference(_from_dir, facing)) < 60;
};

on_death = function() {
    gmsa_agent_set_busy(agent, true);
    gmnav_agent_stop(nav);
    doing = "";
    thought = "";
    using_read = false;
    varn_say(id, "My oath... ends.");
};