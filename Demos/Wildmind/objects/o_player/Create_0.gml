event_inherited();
team = 1;
stamina_max = PLAYER_STAMINA_MAX;
stamina = stamina_max;
stamina_wait = 0;      // seconds before stamina refills again
potions = 3;
state = player_state.MOVE;
state_time = 0;        // seconds in the current state
aim = 0;
move_dir = 0;          // the last way the player moved, rolls go this way
vel_x = 0;             // how the player is really moving, px per second, smoothed. what Varn reads
vel_y = 0;
roll_dir = 0;          // rolls and dodges go this way
roll_wait = 0;         // seconds before the next roll
dodge_wait = 0;        // seconds before the next dodge
evade_queued = player_state.ROLL;
evade_queue_time = 0;
evade_at = -1;         // when the last roll or dodge started, on the game clock
attack_dir = 0;
combo = 0;             // which hit of the combo, 0 to 2
combo_queued = false;
swing = undefined;
shot_fired = false;

start = function(_state) {
    state = _state;
    state_time = 0;
};

spend = function(_cost) { // false when there isn't enough stamina
    if (stamina < _cost) return false;
    stamina -= _cost;
    stamina_wait = PLAYER_STAMINA_WAIT;
    return true;
};

roll = function(_dir) {
    if (roll_wait > 0 || !spend(PLAYER_ROLL_COST)) return false;
    roll_dir = _dir;
    invuln = max(invuln, PLAYER_ROLL_INVULN);
    swing = undefined;
    roll_wait = PLAYER_ROLL_TIME + PLAYER_ROLL_WAIT; // counted from the start, so a hit mid roll doesn't skip it
    dodge_wait = max(dodge_wait, PLAYER_ROLL_TIME + PLAYER_EVADE_LOCK);
    evade_at = demo_now();
    start(player_state.ROLL);
    return true;
};

dodge = function(_dir) { // a quick step, no invulnerability
    if (dodge_wait > 0 || !spend(PLAYER_DODGE_COST)) return false;
    roll_dir = _dir;
    swing = undefined;
    dodge_wait = PLAYER_DODGE_TIME + PLAYER_DODGE_WAIT;
    roll_wait = max(roll_wait, PLAYER_DODGE_TIME + PLAYER_EVADE_LOCK);
    evade_at = demo_now();
    start(player_state.DODGE);
    return true;
};

evade = function(_dir) { // fires a pressed roll or dodge, true when one started
    if (evade_queue_time <= 0) return false;
    var _started = (evade_queued == player_state.ROLL) ? roll(_dir) : dodge(_dir);
    if (_started) evade_queue_time = 0;
    return _started;
};

attack = function(_hit) {
    if (!spend(PLAYER_MELEE_COST)) return;
    combo = _hit;
    combo_queued = false;
    attack_dir = aim;
    swing = undefined;
    start(player_state.ATTACK);
};

shoot = function() {
    if (!spend(PLAYER_SHOT_COST)) return;
    shot_fired = false;
    start(player_state.SHOOT);
};

drink = function() {
    if (potions <= 0) return;
    potions--; // a hit while drinking wastes it
    start(player_state.DRINK);
};

on_hurt = function(_damage) {
    swing = undefined;
    invuln = PLAYER_HURT_INVULN;
    start(player_state.HURT);
};

on_death = function() {
    start(player_state.DEAD);
};