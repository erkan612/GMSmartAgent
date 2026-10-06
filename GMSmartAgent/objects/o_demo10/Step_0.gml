// the budget
if (keyboard_check_pressed(vk_up)) budget_index = min(budget_index + 1, array_length(budgets) - 1);
if (keyboard_check_pressed(vk_down)) budget_index = max(budget_index - 1, 0);
gmsa_scheduler_set_budget(sched, budgets[budget_index]);

if (keyboard_check_pressed(vk_space)) reset(false);
if (keyboard_check_pressed(ord("R"))) reset(true);
if (keyboard_check_pressed(ord("P"))) paused = !paused;
var _advance = !paused || keyboard_check_pressed(ord("N")); // while paused, N lets one frame through

// left click: select a goblin, take or return a key, lock or unlock a door
if (mouse_check_button_pressed(mb_left)) {
    var _done = false;
    for (var _i = 0; _i < array_length(goblins) && !_done; _i++) {
        if (point_distance(mouse_x, mouse_y, goblins[_i].x, goblins[_i].y) < 14) {
            selected = goblins[_i];
            _done = true;
        }
    }
    for (var _i = 0; _i < array_length(pedestals) && !_done; _i++) {
        if (point_distance(mouse_x, mouse_y, pedestals[_i].x, pedestals[_i].y) < 24) {
            pedestals[_i].has_key = !pedestals[_i].has_key;
            pedestals[_i].timer = 0;
            changed();
            _done = true;
        }
    }
    for (var _i = 0; _i < 3 && !_done; _i++) {
        if (abs(mouse_x - wall_x) < 22 && abs(mouse_y - vaults[_i].door_y) < 36) {
            vaults[_i].locked = !vaults[_i].locked;
            changed();
            _done = true;
        }
    }
}

// right click: take a coin, or drop one outside
if (mouse_check_button_pressed(mb_right)) {
    var _hit = -1;
    for (var _i = 0; _i < array_length(coins); _i++) {
        if (point_distance(mouse_x, mouse_y, coins[_i].x, coins[_i].y) < 12) _hit = _i;
    }
    if (_hit != -1) array_delete(coins, _hit, 1);
    else if (mouse_x < wall_x - 20) array_push(coins, { x : mouse_x, y : mouse_y });
    changed();
}

// time moves only when not paused: keys, coins, the scheduler and the goblins
if (_advance) {
    // keys come back to empty pedestals, and coins trickle in
    for (var _i = 0; _i < array_length(pedestals); _i++) {
        var _p = pedestals[_i];
        if (!_p.has_key && ++_p.timer >= 480) {
            _p.has_key = true;
            _p.timer = 0;
        }
    }
    if (++coin_timer >= 180) {
        coin_timer = 0;
        if (array_length(coins) < 10) add_coin();
    }

    // the shared budget: every goblin making or repairing a plan gets turns here
    gmsa_scheduler_step(sched);

    for (var _i = 0; _i < array_length(goblins); _i++) act(goblins[_i]);
}