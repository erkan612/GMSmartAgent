// your changes to the room
if (keyboard_check_pressed(vk_space)) reset();
if (keyboard_check_pressed(ord("R")) && !chest_open) {
    gmsa_plan_make(planner, "loot");  // from scratch, unlike a repair
    note("planned again from scratch -> " + now());
}
if (keyboard_check_pressed(ord("L"))) {
    gob.has_pick = !gob.has_pick;
    changed(gob.has_pick ? "you gave it a lockpick" : "you took its lockpick");
}
if (mouse_check_button_pressed(mb_left)) {
    if (point_distance(mouse_x, mouse_y, pedestal.x, pedestal.y) < 28 && !gob.has_key) {
        key_on_pedestal = !key_on_pedestal;
        changed(key_on_pedestal ? "you put the key back" : "you took the key");
    } else if (abs(mouse_x - wall_x) < 24 && abs(mouse_y - door_y) < 44) {
        door_locked = !door_locked;
        changed(door_locked ? "you locked the door" : "you unlocked the door");
    }
}
if (mouse_check_button_pressed(mb_right)) {
    var _hit = -1;
    for (var _i = 0; _i < array_length(coins); _i++) {
        if (point_distance(mouse_x, mouse_y, coins[_i].x, coins[_i].y) < 14) _hit = _i;
    }
    if (_hit != -1) {
        var _coin = coins[_hit];
        array_delete(coins, _hit, 1);
        if (gmsa_plan_target(planner) == _coin) {
            // the coin it was walking to is gone: the game reports the step as failed
            gmsa_plan_step_failed(planner);
            note("you took the coin it wanted -> " + now());
        } else {
            changed("you took a coin");
        }
    } else if (mouse_x < wall_x - 20) {
        array_push(coins, { x : mouse_x, y : mouse_y });
        changed("you dropped a coin");
    }
}

// the goblin does its current step: go there, work, then tell the planner how it went
var _step = gmsa_plan_current(planner);
if (_step != undefined) {
    var _target = gmsa_plan_target(planner);
    if (_step != gob.doing || _target != gob.doing_target) {
        gob.doing = _step;
        gob.doing_target = _target;
        gob.timer = 0;
    }
    if (move_to(destination(_step, _target), pace(_step))) {
        gob.timer++;
        if (gob.timer >= work_time(_step)) {
            gob.doing = undefined;
            if (finish(_step, _target)) gmsa_plan_step_done(planner);
            else {
                gmsa_plan_step_failed(planner);
                note(_step + " failed -> " + now());
            }
            if (chest_open) note("the chest is open");
        }
    }
}