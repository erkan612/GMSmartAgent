randomize(); // the demo's own randomness, GMSmartAgent never touches it

// the room: outside on the left, the vault on the right, a door and a window in the wall between
var _w = room_width * 0.6;
var _h = room_height;
wall_x = _w * 0.62;
door_y = _h * 0.58;
win_y = _h * 0.16;
start = { x : _w * 0.36, y : _h * 0.5 };
pedestal = { x : _w * 0.14, y : _h * 0.22 };
shop = { x : _w * 0.14, y : _h * 0.8 };
chest = { x : _w * 0.85, y : door_y };
door_out = { x : wall_x - 28, y : door_y };
door_in = { x : wall_x + 28, y : door_y };
win_out = { x : wall_x - 28, y : win_y };
win_in = { x : wall_x + 28, y : win_y };

// the domain: facts are read from this controller, steps are what the goblin can do, tasks are its recipes
var _d = gmsa_plan_domain_create("d9 heist");
gmsa_plan_add_fact(_d, "has_key", function(_o) { return _o.gob.has_key; });
gmsa_plan_add_fact(_d, "gold", function(_o) { return _o.gob.gold; });
gmsa_plan_add_fact(_d, "has_pick", function(_o) { return _o.gob.has_pick; });
gmsa_plan_add_fact(_d, "inside", function(_o) { return _o.gob.inside; });
gmsa_plan_add_fact(_d, "key_on_pedestal", function(_o) { return _o.key_on_pedestal; });
gmsa_plan_add_fact(_d, "coins_left", function(_o) { return array_length(_o.coins); });
gmsa_plan_add_fact(_d, "door_locked", function(_o) { return _o.door_locked; });

gmsa_plan_add_step(_d, "walk_to_pedestal", { requires : [["inside", false], ["key_on_pedestal", true]] });
gmsa_plan_add_step(_d, "take_key", { requires : [["key_on_pedestal", true]], effects : [["key_on_pedestal", false], ["has_key", true]] });
gmsa_plan_add_step(_d, "grab_coin", {
    requires : [["inside", false], ["coins_left", ">", 0]],
    effects : [["coins_left", "-", 1], ["gold", "+", 5]],
    targets : function(_o) { return _o.coins; },
    score : function(_o, _coin) { return 1 / (1 + point_distance(_o.gob.x, _o.gob.y, _coin.x, _coin.y) / 100); },  // nearest first
});
gmsa_plan_add_step(_d, "walk_to_shop", { requires : [["inside", false]] });
gmsa_plan_add_step(_d, "buy_key", { requires : [["gold", ">=", 10]], effects : [["gold", "-", 10], ["has_key", true]] });
gmsa_plan_add_step(_d, "walk_to_door", { requires : [["inside", false]] });
gmsa_plan_add_step(_d, "pick_lock", { requires : [["has_pick", true]], effects : [["door_locked", false]] });
gmsa_plan_add_step(_d, "go_through", { requires : [["door_locked", false]], effects : [["inside", true]] });
gmsa_plan_add_step(_d, "walk_to_window", { requires : [["inside", false]] });
gmsa_plan_add_step(_d, "climb_window", { effects : [["inside", true]] });
gmsa_plan_add_step(_d, "walk_to_chest", { requires : [["inside", true]] });
gmsa_plan_add_step(_d, "open_chest", { requires : [["inside", true], ["has_key", true]] });

var _get_key = gmsa_plan_add_task(_d, "get_key");
gmsa_plan_add_method(_get_key, "have_it", { requires : [["has_key", true]], subtasks : [] });
gmsa_plan_add_method(_get_key, "take", { requires : [["key_on_pedestal", true]], subtasks : ["walk_to_pedestal", "take_key"] });
gmsa_plan_add_method(_get_key, "buy", { subtasks : ["get_gold", "walk_to_shop", "buy_key"] });

var _get_gold = gmsa_plan_add_task(_d, "get_gold"); // uses itself: one coin, then get_gold again
gmsa_plan_add_method(_get_gold, "enough", { requires : [["gold", ">=", 10]], subtasks : [] });
gmsa_plan_add_method(_get_gold, "grab", { requires : [["coins_left", ">", 0]], subtasks : ["grab_coin", "get_gold"] });

var _get_in = gmsa_plan_add_task(_d, "get_in");
gmsa_plan_add_method(_get_in, "already", { requires : [["inside", true]], subtasks : [] });
gmsa_plan_add_method(_get_in, "door", { requires : [["door_locked", false]], subtasks : ["walk_to_door", "go_through"] });
gmsa_plan_add_method(_get_in, "pick", { requires : [["has_pick", true]], subtasks : ["walk_to_door", "pick_lock", "go_through"] });
gmsa_plan_add_method(_get_in, "window", { subtasks : ["walk_to_window", "climb_window"] });  // slow, so last

var _loot = gmsa_plan_add_task(_d, "loot");
gmsa_plan_add_method(_loot, "only", { subtasks : ["get_key", "get_in", "walk_to_chest", "open_chest"] });
domain = gmsa_plan_domain_build(_d);
planner = gmsa_plan_planner_create(domain, id);

// what each step looks like in the game: where the goblin goes, how fast, how long it works there
destination = function(_step, _target) {
    switch (_step) {
        case "walk_to_pedestal": case "take_key": return pedestal;
        case "walk_to_shop": case "buy_key": return shop;
        case "grab_coin": return _target;
        case "walk_to_door": case "pick_lock": return door_out;
        case "go_through": return door_in;
        case "walk_to_window": return win_out;
        case "climb_window": return win_in;
    }
    return chest;
};
pace = function(_step) { return (_step == "climb_window") ? 0.3 : 3; };
work_time = function(_step) {
    switch (_step) {
        case "take_key": return 20;
        case "grab_coin": return 10;
        case "buy_key": return 40;
        case "pick_lock": return 120;
        case "open_chest": return 40;
    }
    return 0;
};

// the step happens in the game. False when the world no longer allows it
finish = function(_step, _target) {
    switch (_step) {
        case "take_key":
            if (!key_on_pedestal) return false;
            key_on_pedestal = false;
            gob.has_key = true;
            return true;
        case "grab_coin":
            for (var _i = 0; _i < array_length(coins); _i++) {
                if (coins[_i] == _target) {
                    array_delete(coins, _i, 1);
                    gob.gold += 5;
                    return true;
                }
            }
            return false;
        case "buy_key":
            if (gob.gold < 10) return false;
            gob.gold -= 10;
            gob.has_key = true;
            return true;
        case "pick_lock":
            if (!gob.has_pick) return false;
            door_locked = false;
            return true;
        case "go_through":
            if (door_locked) return false;
            gob.inside = true;
            return true;
        case "climb_window":
            gob.inside = true;
            return true;
        case "open_chest":
            if (!gob.has_key) return false;
            chest_open = true;
            return true;
    }
    return true; // walking always works
};

move_to = function(_p, _speed) {
    var _d = point_distance(gob.x, gob.y, _p.x, _p.y);
    if (_d <= _speed) {
        gob.x = _p.x;
        gob.y = _p.y;
        return true;
    }
    gob.x += (_p.x - gob.x) / _d * _speed;
    gob.y += (_p.y - gob.y) / _d * _speed;
    return false;
};

note = function(_text) {
    array_push(events, _text);
    if (array_length(events) > 7) array_delete(events, 0, 1);
};

now = function() {
    var _c = gmsa_plan_current(planner);
    if (_c != undefined) return "now " + _c;
    if (gmsa_plan_get_status(planner) == gmsa_plan_status.DONE) return "done";
    return "no plan";
};

// you changed the room: a running plan checks itself and repairs, otherwise the goblin tries to plan again
changed = function(_text) {
    if (!chest_open) {
        if (gmsa_plan_get_status(planner) == gmsa_plan_status.RUNNING) gmsa_plan_refresh(planner);
        else gmsa_plan_make(planner, "loot");
    }
    note(_text + " -> " + now());
};

reset = function() {
    gob = { x : start.x, y : start.y, has_key : false, gold : 0, has_pick : false, inside : false,
            doing : undefined, doing_target : undefined, timer : 0 };
    key_on_pedestal = true;
    door_locked = false;
    chest_open = false;
    coins = [];
    repeat (3) array_push(coins, { x : random_range(60, wall_x - 80), y : random_range(80, room_height - 80) });
    events = [];
    gmsa_plan_make(planner, "loot");
    note("a new heist -> " + now());
};
reset();