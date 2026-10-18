enum varn_state { FREE, WINDUP, HOLD, ACTIVE, RECOVER, GUARD }
enum varn_shape { ARC, SIDE, CIRCLE, CHARGE }

#macro VARN_GUARD_TIME 1.2
#macro VARN_HOLD_TIME 0.45 // how long he holds a swing against an early dodger
#macro VARN_HOLD_STEP 260  // how fast the slam circle follows the player
#macro VARN_HOLD_WALK 90   // how fast he steps in while holding a swing, slower than his walk (150)
#macro VARN_QUICK 0.8      // his windup against a late dodger, as a share of the normal one
#macro VARN_WINDUP_SCALE 1.15 // every windup, for tuning how fast he feels
#macro VARN_PLAIN_LOCK 0.2 // with no read to act on he aims only at the start of a windup, then commits
#macro VARN_SHORT_RECOVER 0.25 // his recovery when he's ready for what the player does next

function varn_attack(_name) { // each attack's shape and timing, undefined for actions that aren't attacks. times in seconds
    // lock: the part of the windup he keeps turning toward the player, after that the direction is fixed
    static _attacks = {
        cleave      : { shape : varn_shape.ARC,    windup : 0.60, lock : 0.75, active : 0.15, recover : 0.70, damage : 22, knock : 360, reach : 120, half : 70 },
        sweep       : { shape : varn_shape.SIDE,   windup : 0.55, lock : 0.60, active : 0.15, recover : 0.60, damage : 18, knock : 300, reach : 130, half : 75 }, // the side is picked when he commits
        slam        : { shape : varn_shape.CIRCLE, windup : 0.90, lock : 0.75, active : 0.12, recover : 0.90, damage : 30, knock : 420, radius : 85, range : 260 },
        charge      : { shape : varn_shape.CHARGE, windup : 0.55, lock : 0.80, active : 0.45, recover : 0.80, damage : 25, knock : 480, speed : 620 },
        counter     : { shape : varn_shape.ARC,    windup : 0.30, lock : 0.80, active : 0.12, recover : 0.60, damage : 20, knock : 380, reach : 120, half : 70 }, // a quick cleave against a player who punishes
        chase       : { shape : varn_shape.CHARGE, windup : 0.45, lock : 0.80, active : 0.50, recover : 0.80, damage : 25, knock : 480, speed : 640 },              // a charge after a player who backs off or drinks
    };
    return _attacks[$ _name];
}

function varn_attack_base(_name) { // the follow-ups count as the attacks they come from, for what Varn learns
    switch (_name) {
        case "counter": return "cleave";
        case "chase":   return "charge";
    }
    return _name;
}

function varn_sees_arrows(_v) { // the player is drawing the bow, or an arrow is on its way to him
    if (_v.target.state == player_state.SHOOT) return true;
    with (o_arrow) {
        if (point_distance(x, y, _v.x, _v.y) < 300 && abs(angle_difference(point_direction(x, y, _v.x, _v.y), dir)) < 20) return true;
    }
    return false;
}

function varn_threatens(_v) { // whether the attack he's starting can reach the player at all
    var _a = _v.attack;
    var _d = point_distance(_v.x, _v.y, _v.target.x, _v.target.y);
    switch (_a.shape) {
        case varn_shape.ARC:
        case varn_shape.SIDE:   return _d <= _a.reach + 60;
        case varn_shape.CHARGE: return _d <= _a.speed * _a.active + _v.radius;
    }
    return true; // the slam is aimed at the player
}

function varn_in_zone(_v, _x, _y) { // whether the current attack, as aimed right now, would catch the player standing there
    var _a = _v.attack;
    var _r = _v.target.radius;
    switch (_a.shape) {
        case varn_shape.ARC:
        case varn_shape.SIDE:
            var _dir = _v.facing + ((_a.shape == varn_shape.SIDE) ? _v.sweep_side : 0);
            return point_distance(_v.x, _v.y, _x, _y) <= _a.reach + _r && abs(angle_difference(point_direction(_v.x, _v.y, _x, _y), _dir)) <= _a.half;
        case varn_shape.CIRCLE:
            return point_distance(_v.slam_x, _v.slam_y, _x, _y) <= _a.radius + _r;
        case varn_shape.CHARGE:
            var _dx = _x - _v.x;
            var _dy = _y - _v.y;
            var _along = _dx * lengthdir_x(1, _v.facing) + _dy * lengthdir_y(1, _v.facing);
            var _across = abs(_dx * lengthdir_x(1, _v.facing + 90) + _dy * lengthdir_y(1, _v.facing + 90));
            return _along >= 0 && _along <= _a.speed * _a.active + _v.radius && _across <= _v.radius + _r;
    }
    return false;
}