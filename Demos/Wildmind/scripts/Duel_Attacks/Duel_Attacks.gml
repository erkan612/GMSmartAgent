enum varn_state { FREE, WINDUP, HOLD, ACTIVE, RECOVER, GUARD }
enum varn_shape { ARC, SIDE, CIRCLE, CHARGE }

#macro VARN_GUARD_TIME 1.2
#macro VARN_HOLD_TIME 0.45 // how long he holds a swing against an early dodger
#macro VARN_HOLD_STEP 260  // how fast he steps in, and the slam follows, while holding
#macro VARN_QUICK 0.65     // his windup against a late dodger, as a share of the normal one
#macro VARN_PLAIN_LOCK 0.2 // with no read to act on he aims only at the start of a windup, then commits

function varn_attack(_name) { // each attack's shape and timing, undefined for actions that aren't attacks. times in seconds
    // lock: the part of the windup he keeps turning toward the player, after that the direction is fixed
    static _attacks = {
        cleave      : { shape : varn_shape.ARC,    windup : 0.60, lock : 0.75, active : 0.15, recover : 0.70, damage : 22, knock : 360, reach : 120, half : 70 },
        sweep       : { shape : varn_shape.SIDE,   windup : 0.55, lock : 0.60, active : 0.15, recover : 0.60, damage : 18, knock : 300, reach : 130, half : 75 }, // the side is picked when he commits
        slam        : { shape : varn_shape.CIRCLE, windup : 0.90, lock : 0.75, active : 0.12, recover : 0.90, damage : 30, knock : 420, radius : 85, range : 260 },
        charge      : { shape : varn_shape.CHARGE, windup : 0.55, lock : 0.80, active : 0.45, recover : 0.80, damage : 25, knock : 480, speed : 620 },
    };
    return _attacks[$ _name];
}

function varn_sees_arrows(_v) { // the player is drawing the bow, or an arrow is on its way to him
    if (_v.target.state == player_state.SHOOT) return true;
    with (o_arrow) {
        if (point_distance(x, y, _v.x, _v.y) < 300 && abs(angle_difference(point_direction(x, y, _v.x, _v.y), dir)) < 20) return true;
    }
    return false;
}