flash = max(0, flash - 1);

// bats near the player get the higher tier, so they decide first
tier_timer--;
if (tier_timer <= 0) {
    tier_timer = 30;
    var _near = global.demo4_tiers
        && point_distance(x, y, global.demo4_player_x, global.demo4_player_y) < 250;
    gmsa_scheduler_set_priority(global.demo4_ai, agent, _near ? 1 : 0);
}

// movement and energy, the game's side of things
var _tx = x, _ty = y, _spd = 1.5;
switch (state) {
    case "chase":
        _tx = global.demo4_player_x;
        _ty = global.demo4_player_y;
        _spd = 2.5;
        energy -= 0.15;
        break;
    case "roost":
        _tx = home_x;
        _ty = home_y;
        _spd = 2;
        if (point_distance(x, y, home_x, home_y) < 4) energy += 0.4;
        else energy -= 0.05;
        break;
    default:
        if (point_distance(x, y, wander_x, wander_y) < 4) {
            wander_x = random_range(20, room_width - 20);
            wander_y = random_range(20, room_height - 20);
        }
        _tx = wander_x;
        _ty = wander_y;
        energy -= 0.05;
        break;
}
energy = clamp(energy, 0, 100);

var _dist = point_distance(x, y, _tx, _ty);
if (_dist > _spd) {
    var _dir = point_direction(x, y, _tx, _ty);
    x += lengthdir_x(_spd, _dir);
    y += lengthdir_y(_spd, _dir);
} else {
    x = _tx;
    y = _ty;
}