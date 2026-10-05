if (mouse_check_button_pressed(mb_left)) pick_at(mouse_x, mouse_y);

// your health drains, potions bring it back
me.hp = max(0, me.hp - 2 / 60);

// you walk to your pick
if (me.target != undefined) {
    var _t = me.target;
    if (point_distance(me.x, me.y, _t.x, _t.y) <= me.speed) {
        me.x = _t.x;
        me.y = _t.y;
        if (_t.kind == 1) me.hp = min(100, me.hp + 40);
        record(0);
        me.target = undefined;
        remove_item(_t);
    } else {
        var _dir = point_direction(me.x, me.y, _t.x, _t.y);
        me.x += lengthdir_x(me.speed, _dir);
        me.y += lengthdir_y(me.speed, _dir);
    }
}

// the guard decides a few times a second, then walks to its goal
think_timer--;
if (think_timer <= 0) {
    think_timer = 10;
    var _option = gmsa_decision_get_chosen(gmsa_agent_think(guard_agent));
    guard.goal = undefined;
    guard.doing = "waiting";
    if (_option != undefined) {
        gmsa_agent_set_current_option(guard_agent, _option);
        guard.doing = _option.action.name;
        guard.goal = _option.target;
    }
}
if (guard.goal != undefined) {
    var _gx = guard.goal.x, _gy = guard.goal.y;
    var _d = point_distance(guard.x, guard.y, _gx, _gy);
    if (_d > 1) {
        var _dir = point_direction(guard.x, guard.y, _gx, _gy);
        guard.x += lengthdir_x(min(guard.speed, _d), _dir);
        guard.y += lengthdir_y(min(guard.speed, _d), _dir);
    }
}

// the guard reaching your pick first blocks it
if (me.target != undefined && point_distance(guard.x, guard.y, me.target.x, me.target.y) < 18) {
    var _t = me.target;
    record(1);
    me.target = undefined;
    remove_item(_t);
}

// LambdaMART retrains in the background, 4 ms per step, the old trees keep predicting meanwhile
if (training) {
    train_frames++;
    if (gmsa_learn_train(model, 4000)) {
        training = false;
        trained = true;
        if (train_again) { train_again = false; training = true; train_frames = 0; }
    }
}

if (keyboard_check_pressed(ord("R"))) {
    gmsa_learn_reset(model);
    outcomes = [];
    picks = 0;
    trained = false;
    training = false;
    train_again = false;
}