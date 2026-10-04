// think every 10 steps, no scheduler in this demo
think_timer--;
if (think_timer <= 0) {
    think_timer = 10;
    gmsa_agent_think(agent);
}

// act on a fresh decision
var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _option = gmsa_decision_get_chosen(_decision);
    if (_option == undefined || _option.target == undefined) {
        goal = noone;
        gmsa_agent_clear_current(agent);
    } else {
        goal = _option.target;
        gmsa_agent_set_current_option(agent, _option);
    }
}

// move, then pick up or reroll the wander point on arrival
if (is_struct(goal) || instance_exists(goal)) {
    var _dist = point_distance(x, y, goal.x, goal.y);
    if (_dist <= move_speed) {
        x = goal.x;
        y = goal.y;
        if (is_struct(goal)) {
            wander_pick();
        } else {
            switch (goal.kind) {
                case demo1_item.KEY:    keys++; break;
                case demo1_item.CHEST:  if (keys > 0) { keys--; chests++; } break;
                case demo1_item.POTION: sight += 60; break;
                case demo1_item.HEART:  hp = min(hp_max, hp + 50); break;
            }
            instance_destroy(goal);
        }
        goal = noone;
        gmsa_agent_clear_current(agent);
        think_timer = 0; // decide again right away
    } else {
        var _dir = point_direction(x, y, goal.x, goal.y);
        x += lengthdir_x(move_speed, _dir);
        y += lengthdir_y(move_speed, _dir);
    }
}