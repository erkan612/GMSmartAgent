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
roll_dir = 0;
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
    if (!spend(PLAYER_ROLL_COST)) return;
    roll_dir = _dir;
    invuln = max(invuln, PLAYER_ROLL_INVULN);
    swing = undefined;
    start(player_state.ROLL);
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