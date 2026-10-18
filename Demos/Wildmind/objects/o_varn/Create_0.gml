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
situation = undefined; // what he saw when the current attack started, see duel_situation
using_read = false; // whether he's acting on it
timing = { timing : "on_time", sure : 0 }; // his guess at when the player will roll or dodge
tactic = "";        // "hold" or "quick" when he plays against that timing
windup_time = 0;    // this attack's windup, shorter when quick
windup_at = 0;      // when the windup started, on the game clock
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
        situation = duel_situation(id, target);
        read = duel_read(doing, situation);
        using_read = (read.sure >= DUEL_READ_SURE && read.dodge != "stay");
        thought = using_read ? "you'll dodge " + duel_dodge_words(read.dodge) + " (" + string(round(read.sure * 100)) + "%)" : "";
        timing = duel_timing_read();
        tactic = "";
        if (timing.sure >= DUEL_READ_SURE && timing.timing == "early") tactic = "hold";
        if (timing.sure >= DUEL_READ_SURE && timing.timing == "late") tactic = "quick";
        if (tactic != "") {
            var _plan = (tactic == "hold") ? "you dodge early, I'll wait" : "you dodge late, quick one";
            thought = ((thought == "") ? "" : thought + ", ") + _plan + " (" + string(round(timing.sure * 100)) + "%)";
        }
        windup_time = (tactic == "quick") ? _a.windup * VARN_QUICK : _a.windup;
        windup_at = demo_now();
        if (using_read || tactic != "") varn_taunt_read(id);
        var _to = point_direction(x, y, target.x, target.y);
        //if (_a.shape == varn_shape.CIRCLE) { // the slam lands where the player will be: where he stands, or where Varn expects him to roll
        //    var _px = target.x;
        //    var _py = target.y;
        //    if (using_read) {
        //        _px += lengthdir_x(DUEL_DODGE_DISTANCE * 0.8, _to + duel_dodge_angle(read.dodge));
        //        _py += lengthdir_y(DUEL_DODGE_DISTANCE * 0.8, _to + duel_dodge_angle(read.dodge));
        //    }
        //    var _len = min(_a.range, point_distance(x, y, _px, _py));
        //    var _dir = point_direction(x, y, _px, _py);
        //    slam_x = x + lengthdir_x(_len, _dir);
        //    slam_y = y + lengthdir_y(_len, _dir);
        //}
        if (_a.shape == varn_shape.SIDE) { // the side he expects the player to roll into, or the side the player is on
            if (using_read && read.dodge == "dodge_left") sweep_side = 90;
            else if (using_read && read.dodge == "dodge_right") sweep_side = -90;
            else sweep_side = (angle_difference(_to, facing) >= 0) ? 90 : -90;
        }
        watch = doing;
        watch_x = target.x;
        watch_y = target.y;
        watch_from = _to;
        if (_a.shape == varn_shape.CIRCLE) aim_slam(infinity); // after the watch, the aim measures from where the player stood
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
    tactic = "";
    attack = undefined;
    swing = undefined;
    start(varn_state.FREE);
};

aim_slam = function(_step) { // moves the slam toward where the player will be. _step is how far it may move, infinity to snap
    var _px = target.x;
    var _py = target.y;
    if (using_read) { // the rest of the dodge he expects: what the player already moved that way doesn't count twice
        var _way = watch_from + duel_dodge_angle(read.dodge);
        var _done = lengthdir_x(1, _way) * (target.x - watch_x) + lengthdir_y(1, _way) * (target.y - watch_y);
        var _left = max(0, o_duel.reads.dodge_dist - _done);
        _px += lengthdir_x(_left, _way);
        _py += lengthdir_y(_left, _way);
    }
    var _len = min(attack.range, point_distance(x, y, _px, _py));
    var _dir = point_direction(x, y, _px, _py);
    var _gx = x + lengthdir_x(_len, _dir);
    var _gy = y + lengthdir_y(_len, _dir);
    var _move = min(_step, point_distance(slam_x, slam_y, _gx, _gy));
    var _md = point_direction(slam_x, slam_y, _gx, _gy);
    slam_x += lengthdir_x(_move, _md);
    slam_y += lengthdir_y(_move, _md);
};

swing_now = function() { // the hit starts
    attack_dir = facing;
    swing = demo_swing_create(id, team, attack.damage, attack.knock);
    start(varn_state.ACTIVE);
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
    tactic = "";
    varn_say(id, "My oath... ends.");
};