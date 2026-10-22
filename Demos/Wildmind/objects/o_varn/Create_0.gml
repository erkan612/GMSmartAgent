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
hold_dir = 0;       // where he was aiming when the hold began
recover_time = 0;   // this attack's recovery, shorter when he's ready for the player's answer
after = undefined;  // what the player does after his attack, while he watches
follow = { answer : "wait", sure : 0 }; // his guess at it
following = false;  // the current attack is a follow-up he planned
given_up = {};      // attacks he has said won't work on this player
used_at = {};       // when he last used each attack, see duel_lands_rest
played = false;     // the current attack is shaped by something he learned
phase = 1;
leap_dir = 0;
volley_fired = false;
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

nav_stop = function() { // stops walking and forgets the goal, so the next approach asks for a fresh path
    gmnav_agent_stop(nav);
    goal_x = -100000;
    repath_wait = 0;
};

take = function(_option) { // acts on a fresh choice from his agent
    gmsa_agent_set_current_option(agent, _option);
    doing = _option.action.name;
    following = (doing == "counter" || doing == "chase" || doing == "brace" || doing == "ward");
    if (following) varn_taunt_follow(id);
    gmsa_agent_set_input(agent, "expect_punish", 0); // the follow-up window ends with this choice
    gmsa_agent_set_input(agent, "expect_gap", 0);
    gmsa_agent_set_input(agent, "expect_shoot", 0);
    var _a = varn_attack(doing);
    var _kind = varn_attack_base(doing);
    if (_a != undefined) {
        attack = _a;
        used_at[$ _kind] = demo_now();
        situation = duel_situation(id, target);
        read = duel_read(_kind, situation);
        using_read = (read.sure >= DUEL_READ_SURE && read.dodge != "stay");
        thought = using_read ? "you'll dodge " + duel_dodge_words(read.dodge) + " (" + string(round(read.sure * 100)) + "%)" : "";
        timing = duel_timing_read();
        tactic = "";
        if (timing.sure >= DUEL_READ_SURE && timing.timing == "early" && using_read && read.dodge == "dodge_back") tactic = "hold"; // early and away: the roll is spent before the hit
        if (timing.sure >= DUEL_READ_SURE && timing.timing == "late") tactic = "quick";
        if (tactic != "") {
            var _plan = (tactic == "hold") ? "you roll away early, I'll wait" : "you dodge late, quick one";
            thought = ((thought == "") ? "" : thought + ", ") + _plan + " (" + string(round(timing.sure * 100)) + "%)";
        }
        //windup_time = (tactic == "quick") ? _a.windup * VARN_QUICK : _a.windup;
        //windup_time = _a.windup * VARN_WINDUP_SCALE * ((tactic == "quick") ? VARN_QUICK : 1);
        windup_time = max(VARN_MIN_WINDUP, _a.windup * VARN_WINDUP_SCALE * ((tactic == "quick") ? VARN_QUICK : 1));
        windup_at = demo_now();
        if (using_read || tactic != "") varn_taunt_read(id);
        played = using_read || tactic != "" || following;
        if (played) o_duel.reads.played += 1;
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
        watch = _kind;
        watch_x = target.x;
        watch_y = target.y;
        watch_from = _to;
        if (_a.shape == varn_shape.CIRCLE) aim_slam(infinity); // after the watch, the aim measures from where the player stood
        if (!varn_threatens(id)) watch = ""; // an attack that can't reach the player asks no answer of them
        gmsa_agent_set_busy(agent, true);
        nav_stop();
        start(varn_state.WINDUP);
    } else if (doing == "guard" || doing == "brace" || doing == "block" || doing == "ward") {
        gmsa_agent_set_busy(agent, true);
        nav_stop();
        start(varn_state.GUARD);
    } else if (doing == "leap") {
        leap_dir = varn_leap_dir(id);
        gmsa_agent_set_busy(agent, true);
        nav_stop();
        start(varn_state.LEAP);
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
    following = false;
    attack = undefined;
    swing = undefined;
    start(varn_state.FREE);
};

after_start = function(_landed) { // his attack is over: guess what the player does next, and start watching what they really do
    if (after != undefined) after_end();
    var _base = varn_attack_base(doing);
    var _dist = point_distance(x, y, target.x, target.y);
    after = { attack : _base, landed : _landed, close : _dist < 170, dist : _dist, at : demo_now(), attacked : false, shot : false, drank : false };
    follow = duel_after_read(_base, _landed, _dist < 170);
    var _sure = (follow.sure >= DUEL_READ_SURE && follow.answer != "wait") ? follow.sure : 0;
    gmsa_agent_set_input(agent, "expect_punish", (follow.answer == "punish") ? _sure : 0);
    gmsa_agent_set_input(agent, "expect_gap", (follow.answer == "back_off" || follow.answer == "drink") ? _sure : 0);
    gmsa_agent_set_input(agent, "expect_shoot", (follow.answer == "shoot") ? _sure : 0);
    recover_time = attack.recover;
    if (_sure > 0) {
        thought = duel_after_words(follow.answer) + " (" + string(round(_sure * 100)) + "%)";
        if (follow.answer == "punish" || follow.answer == "drink") recover_time = min(recover_time, VARN_SHORT_RECOVER);
    } else {
        follow.sure = 0;
    }
};

after_end = function() { // the watch is over: learn what the player did
    duel_after_learn(after, duel_after_kind(after, point_distance(x, y, target.x, target.y)));
    after = undefined;
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
    volley_fired = false;
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
        case varn_shape.VOLLEY:
            if (!volley_fired) {
                volley_fired = true;
                for (var _i = 0; _i < attack.count; _i++) {
                    var _d = attack_dir + (_i - (attack.count - 1) / 2) * attack.spread;
                    var _b = instance_create_depth(x + lengthdir_x(radius, _d), y + lengthdir_y(radius, _d), depth - 1, o_bolt);
                    _b.dir = _d;
                    _b.fly = attack.speed;
                    _b.swing = swing;
                    _b.life = attack.active;
                }
            }
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
    nav_stop();
    doing = "";
    thought = "";
    using_read = false;
    tactic = "";
    following = false;
    varn_say(id, "My oath... ends.");
};