think_timer--;
if (think_timer <= 0) {
    think_timer = 10;
    gmsa_agent_think(agent);
}

var _decision = gmsa_agent_consume(agent);
if (_decision != undefined) {
    var _option = gmsa_decision_get_chosen(_decision);
    if (_option == undefined) {
        goal = noone;
        gmsa_agent_clear_current(agent);
    } else {
        goal = _option.target;
        gmsa_agent_set_current_option(agent, _option);
    }
}

if (is_struct(goal) || instance_exists(goal)) {
    if (point_distance(x, y, goal.x, goal.y) <= move_speed) {
        x = goal.x;
        y = goal.y;
        if (is_struct(goal)) {
            wander_pick();
        } else {
            array_push(recent, goal.kind);
            if (array_length(recent) > 10) array_delete(recent, 0, 1);
            instance_destroy(goal);
        }
        goal = noone;
        gmsa_agent_clear_current(agent);
        think_timer = 0;
    } else {
        var _dir = point_direction(x, y, goal.x, goal.y);
        x += lengthdir_x(move_speed, _dir);
        y += lengthdir_y(move_speed, _dir);
    }
}