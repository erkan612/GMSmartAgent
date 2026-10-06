randomize(); // the demo's own randomness, GMSmartAgent never touches it

// the room: outside on the left, three vaults behind one wall, each with a window, a door and a chest
area_w = room_width * 0.6;
wall_x = area_w * 0.7;
vault_colours = [make_color_rgb(120, 200, 90), make_color_rgb(90, 170, 230), make_color_rgb(230, 150, 70)];
vaults = [];
for (var _i = 0; _i < 3; _i++) {
    var _top = room_height * _i / 3;
    var _door_y = _top + room_height / 6 + 30;
    var _win_y = _top + 40;
    array_push(vaults, {
        index : _i, top : _top, bottom : _top + room_height / 3, locked : false, loots : 0,
        door_y : _door_y, win_y : _win_y,
        door_out : { x : wall_x - 26, y : _door_y }, door_in : { x : wall_x + 26, y : _door_y },
        win_out : { x : wall_x - 26, y : _win_y }, win_in : { x : wall_x + 26, y : _win_y },
        chest : { x : area_w * 0.88, y : _door_y },
    });
}
pedestals = [
    { x : area_w * 0.1, y : room_height * 0.22, has_key : true, timer : 0 },
    { x : area_w * 0.1, y : room_height * 0.78, has_key : true, timer : 0 },
];
shop = { x : area_w * 0.32, y : room_height * 0.93 };
coins = [];
coin_timer = 0;

// one scheduler for every goblin's planning, its budget is yours to change
budgets = [50, 100, 200, 500, 1000, 2000];
budget_index = 3;
sched = gmsa_scheduler_create(budgets[budget_index]);

keys_out = function() {
    var _n = 0;
    for (var _i = 0; _i < array_length(pedestals); _i++) if (pedestals[_i].has_key) _n++;
    return _n;
};
key_pedestals = function() {
    var _list = [];
    for (var _i = 0; _i < array_length(pedestals); _i++) if (pedestals[_i].has_key) array_push(_list, pedestals[_i]);
    return _list;
};
coin_index = function(_coin) {
    for (var _i = 0; _i < array_length(coins); _i++) if (coins[_i] == _coin) return _i;
    return -1;
};

// the domain: Demo 9's heist, facts read from each goblin and the world around it
var _d = gmsa_plan_domain_create("d10 crew");
gmsa_plan_add_fact(_d, "has_key", function(_g) { return _g.has_key; });
gmsa_plan_add_fact(_d, "gold", function(_g) { return _g.gold; });
gmsa_plan_add_fact(_d, "has_pick", function(_g) { return _g.has_pick; });
gmsa_plan_add_fact(_d, "inside", function(_g) { return _g.inside; });
gmsa_plan_add_fact(_d, "keys_out", function(_g) { return _g.world.keys_out(); });
gmsa_plan_add_fact(_d, "coins_left", function(_g) { return array_length(_g.world.coins); });
gmsa_plan_add_fact(_d, "door_locked", function(_g) { return _g.world.vaults[_g.vault].locked; });

var _nearest = function(_g, _t) { return 1 / (1 + point_distance(_g.x, _g.y, _t.x, _t.y) / 100); };
gmsa_plan_add_step(_d, "take_key", {
    requires : [["inside", false], ["keys_out", ">", 0]],
    effects : [["keys_out", "-", 1], ["has_key", true]],
    targets : function(_g) { return _g.world.key_pedestals(); },
    score : _nearest,
});
gmsa_plan_add_step(_d, "grab_coin", {
    requires : [["inside", false], ["coins_left", ">", 0]],
    effects : [["coins_left", "-", 1], ["gold", "+", 5]],
    targets : function(_g) { return _g.world.coins; },
    score : _nearest,
});
gmsa_plan_add_step(_d, "buy_key", { requires : [["inside", false], ["gold", ">=", 10]], effects : [["gold", "-", 10], ["has_key", true]] });
gmsa_plan_add_step(_d, "pick_lock", { requires : [["inside", false], ["has_pick", true]], effects : [["door_locked", false]] });
gmsa_plan_add_step(_d, "go_through", { requires : [["inside", false], ["door_locked", false]], effects : [["inside", true]] });
gmsa_plan_add_step(_d, "climb_window", { requires : [["inside", false]], effects : [["inside", true]] });
gmsa_plan_add_step(_d, "open_chest", { requires : [["inside", true], ["has_key", true]], effects : [["has_key", false]] });

var _get_key = gmsa_plan_add_task(_d, "get_key");
gmsa_plan_add_method(_get_key, "have_it", { requires : [["has_key", true]], subtasks : [] });
gmsa_plan_add_method(_get_key, "take", { requires : [["keys_out", ">", 0]], subtasks : ["take_key"] });
gmsa_plan_add_method(_get_key, "buy", { subtasks : ["get_gold", "buy_key"] });
var _get_gold = gmsa_plan_add_task(_d, "get_gold");
gmsa_plan_add_method(_get_gold, "enough", { requires : [["gold", ">=", 10]], subtasks : [] });
gmsa_plan_add_method(_get_gold, "grab", { requires : [["coins_left", ">", 0]], subtasks : ["grab_coin", "get_gold"] });
var _get_in = gmsa_plan_add_task(_d, "get_in");
gmsa_plan_add_method(_get_in, "already", { requires : [["inside", true]], subtasks : [] });
gmsa_plan_add_method(_get_in, "door", { requires : [["door_locked", false]], subtasks : ["go_through"] });
gmsa_plan_add_method(_get_in, "pick", { requires : [["has_pick", true]], subtasks : ["pick_lock", "go_through"] });
gmsa_plan_add_method(_get_in, "window", { subtasks : ["climb_window"] });
var _heist = gmsa_plan_add_task(_d, "heist");
gmsa_plan_add_method(_heist, "only", { subtasks : ["get_key", "get_in", "open_chest"] });
domain = gmsa_plan_domain_build(_d);

// twelve goblins, four per vault, every planner scheduled on the one scheduler
goblins = [];
for (var _i = 0; _i < 12; _i++) {
    var _g = {
        index : _i, world : id, vault : _i mod 3, x : 0, y : 0,
        has_key : false, gold : 0, has_pick : false, inside : false,
        doing : undefined, doing_target : undefined, path : [], leg : 0, timer : 0, wait : 0,
        last_status : gmsa_plan_status.IDLE,
    };
    _g.planner = gmsa_plan_planner_create(domain, _g);
    gmsa_plan_schedule(_g.planner, sched);
    array_push(goblins, _g);
}
selected = goblins[0];

// what each step looks like in the game: the points to walk through, then how long to work there
path_for = function(_g, _step, _target) {
    var _v = vaults[_g.vault];
    switch (_step) {
        case "take_key": case "grab_coin": return [_target];
        case "buy_key": return [shop];
        case "pick_lock": return [_v.door_out];
        case "go_through": return [_v.door_out, _v.door_in];
        case "climb_window": return [_v.win_out, _v.win_in];
    }
    return [_v.chest];
};
work_time = function(_step) {
    switch (_step) {
        case "take_key": return 15;
        case "grab_coin": return 8;
        case "buy_key": return 30;
        case "pick_lock": return 90;
        case "open_chest": return 30;
    }
    return 0;
};

// the step happens in the game. False when the world no longer allows it
finish = function(_g, _step, _target) {
    var _v = vaults[_g.vault];
    switch (_step) {
        case "take_key":
            if (!_target.has_key) return false;
            _target.has_key = false;
            _target.timer = 0;
            _g.has_key = true;
            return true;
        case "grab_coin":
            var _i = coin_index(_target);
            if (_i == -1) return false;
            array_delete(coins, _i, 1);
            _g.gold += 5;
            return true;
        case "buy_key":
            if (_g.gold < 10) return false;
            _g.gold -= 10;
            _g.has_key = true;
            return true;
        case "pick_lock":
            if (!_g.has_pick) return false;
            _v.locked = false;
            return true;
        case "go_through":
            if (_v.locked) return false;
            _g.inside = true;
            return true;
        case "climb_window":
            _g.inside = true;
            return true;
        case "open_chest":
            if (!_g.has_key) return false;
            _g.has_key = false;
            _v.loots++;
            return true;
    }
    return true;
};

move_to = function(_g, _p, _speed) {
    var _dist = point_distance(_g.x, _g.y, _p.x, _p.y);
    if (_dist <= _speed) {
        _g.x = _p.x;
        _g.y = _p.y;
        return true;
    }
    _g.x += (_p.x - _g.x) / _dist * _speed;
    _g.y += (_p.y - _g.y) / _dist * _speed;
    return false;
};

spawn = function(_g) {
    _g.x = random_range(wall_x * 0.35, wall_x * 0.75);
    _g.y = random_range(60, room_height - 60);
    _g.inside = false;
    _g.has_key = false;
    _g.doing = undefined;
    _g.wait = 0;
};

start_plan = function(_g) {
    gmsa_plan_make(_g.planner, "heist"); // scheduled: only asks, the scheduler does the planning
    made++;
};

add_coin = function() {
    array_push(coins, { x : random_range(40, wall_x - 70), y : random_range(40, room_height - 40) });
};

// you changed the room: running plans check themselves, broken ones are repaired inside the budget
changed = function() {
    for (var _i = 0; _i < array_length(goblins); _i++) {
        var _g = goblins[_i];
        if (gmsa_plan_get_status(_g.planner) == gmsa_plan_status.RUNNING) gmsa_plan_refresh(_g.planner);
    }
};

// one goblin's turn: wait for its plan, do its step, or try again after a while
act = function(_g) {
    var _status = gmsa_plan_get_status(_g.planner);
    if (_g.last_status == gmsa_plan_status.RUNNING && _status == gmsa_plan_status.PLANNING) repairs++;
    _g.last_status = _status;
    if (_status == gmsa_plan_status.PLANNING) return; // waiting for its turn in the budget
    if (_status != gmsa_plan_status.RUNNING) {
        _g.wait++;
        if (_g.wait < ((_status == gmsa_plan_status.DONE) ? 45 : 90)) return;
        _g.wait = 0;
        if (_status == gmsa_plan_status.DONE) spawn(_g); // out with the loot, back for more
        start_plan(_g);
        return;
    }
    var _step = gmsa_plan_current(_g.planner);
    var _target = gmsa_plan_target(_g.planner);
    if (_step != _g.doing || _target != _g.doing_target) {
        _g.doing = _step;
        _g.doing_target = _target;
        _g.timer = 0;
        _g.leg = 0;
        _g.path = path_for(_g, _step, _target);
    }
    // the world changed under the step: another goblin took the key or the coin, or the door got locked
    var _gone = (_step == "take_key" && !_target.has_key)
        || (_step == "grab_coin" && coin_index(_target) == -1)
        || (_step == "go_through" && vaults[_g.vault].locked);
    if (_gone) {
        _g.doing = undefined;
        gmsa_plan_step_failed(_g.planner);
        return;
    }
    if (_g.leg < array_length(_g.path)) {
        var _pace = (_step == "climb_window" && _g.leg == 1) ? 0.35 : 2.2; // climbing is slow
        if (move_to(_g, _g.path[_g.leg], _pace)) _g.leg++;
        return;
    }
    _g.timer++;
    if (_g.timer < work_time(_step)) return;
    _g.doing = undefined;
    if (finish(_g, _step, _target)) gmsa_plan_step_done(_g.planner);
    else gmsa_plan_step_failed(_g.planner);
};

// Space: a new room. R: the same seeded room every time, to compare budgets
reset = function(_seeded) {
    if (_seeded) random_set_seed(1234);
    else randomize();
    for (var _i = 0; _i < 3; _i++) {
        vaults[_i].locked = false;
        vaults[_i].loots = 0;
    }
    for (var _i = 0; _i < array_length(pedestals); _i++) {
        pedestals[_i].has_key = true;
        pedestals[_i].timer = 0;
    }
    coins = [];
    repeat (10) add_coin();
    coin_timer = 0;
    made = 0;
    repairs = 0;
    for (var _i = 0; _i < array_length(goblins); _i++) {
        var _g = goblins[_i];
        spawn(_g);
        _g.gold = 0;
        _g.has_pick = (random(1) < 0.3);
        _g.last_status = gmsa_plan_status.IDLE;
        start_plan(_g); // all twelve ask at once
    }
};
made = 0;
repairs = 0;
paused = false;
reset(false);