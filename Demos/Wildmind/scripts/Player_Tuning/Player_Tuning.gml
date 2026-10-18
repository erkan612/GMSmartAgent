enum player_state { MOVE, ROLL, ATTACK, SHOOT, DRINK, HURT, DEAD }

// speeds in px per second, times in seconds
#macro PLAYER_SPEED 220
#macro PLAYER_ROLL_SPEED 520
#macro PLAYER_ROLL_TIME 0.35
#macro PLAYER_ROLL_INVULN 0.25
#macro PLAYER_ROLL_COST 20
#macro PLAYER_STAMINA_MAX 120
#macro PLAYER_STAMINA_REGEN 55
#macro PLAYER_STAMINA_WAIT 0.45
#macro PLAYER_MELEE_COST 8
#macro PLAYER_MELEE_ACTIVE 0.1
#macro PLAYER_MELEE_REACH 30
#macro PLAYER_MELEE_RADIUS 26
#macro PLAYER_SHOT_COST 12
#macro PLAYER_SHOT_WINDUP 0.2
#macro PLAYER_SHOT_TIME 0.4
#macro PLAYER_ARROW_SPEED 700
#macro PLAYER_ARROW_DAMAGE 18
#macro PLAYER_POTION_TIME 0.9
#macro PLAYER_POTION_HEAL 40
#macro PLAYER_HURT_TIME 0.25
#macro PLAYER_HURT_INVULN 0.4
#macro PLAYER_SLOW 0.4

function player_combo_hit(_i) { // each hit of the three hit combo
    static _hits = [
        { windup : 0.10, recover : 0.22, damage : 14, knock : 220 },
        { windup : 0.10, recover : 0.22, damage : 14, knock : 220 },
        { windup : 0.18, recover : 0.35, damage : 26, knock : 420 },
    ];
    return _hits[_i];
}