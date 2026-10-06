randomize(); // the demo's own randomness, GMSmartAgent never touches it

// the room: home on the left, three vaults behind a wall, each with a window (top), a door (middle) and a tunnel (bottom)
area_w = room_width * 0.6;
wall_x = area_w * 0.62;
home = { x : area_w * 0.12, y : room_height * 0.5 };
entrance_names = ["door", "window", "tunnel"];
entrance_steps = ["enter_door", "enter_window", "dig_tunnel"];
entrance_work = [30, 60, 120]; // frames each entrance takes
vaults = [];
for (var _i = 0; _i < 3; _i++) {
    var _top = room_height * _i / 3;
    var _h = room_height / 3;
    var _ys = [_top + _h * 0.5, _top + _h * 0.2, _top + _h * 0.8]; // door, window, tunnel
    var _outs = [];
    var _ins = [];
    for (var _e = 0; _e < 3; _e++) {
        array_push(_outs, { x : wall_x - 24, y : _ys[_e] });
        array_push(_ins, { x : wall_x + 24, y : _ys[_e] });
    }
    array_push(vaults, {
        index : _i, top : _top, bottom : _top + _h, outs : _outs, ins : _ins,
        wait : { x : wall_x - 90, y : _top + _h * 0.5 },
        chest : { x : area_w * 0.85, y : _top + _h * 0.5 },
        rules : array_create(6, 0), // secret: rules[entrance * 2 + night], the chance that entrance works
    });
}
day_time = 0;
day_length = 1800;
night = false;
reveal = false;
shuffled_flash = 0;
paused = false;
frame = 0;

// new secret rules: for every vault, by day and by night, one good entrance, one so-so, one bad
shuffle = function() {
    var _values = [0.9, 0.4, 0.1];
    for (var _v = 0; _v < 3; _v++) {
        for (var _t = 0; _t < 2; _t++) {
            var _order = [0, 1, 2];
            for (var _i = 2; _i > 0; _i--) {
                var _j = irandom(_i);
                var _swap = _order[_i];
                _order[_i] = _order[_j];
                _order[_j] = _swap;
            }
            for (var _e = 0; _e < 3; _e++) vaults[_v].rules[_e * 2 + _t] = _values[_order[_e]];
        }
    }
    shuffled_flash = 120;
};

// the same domain for both crews: get into a vault by its door, window or tunnel, take the loot, escape.
// Facts: night, which vault, inside, has the loot. Nothing here knows the secret rules
make_domain = function(_name) {
    var _d = gmsa_plan_domain_create(_name);
    gmsa_plan_add_fact(_d, "night", function(_g) { return _g.world.night; });
    for (var _i = 0; _i < 3; _i++) {
        gmsa_plan_add_fact(_d, "vault_" + string(_i + 1), method({ v : _i }, function(_g) { return _g.vault == v; }));
    }
    gmsa_plan_add_fact(_d, "inside", function(_g) { return _g.inside; });
    gmsa_plan_add_fact(_d, "has_loot", function(_g) { return _g.has_loot; });
    gmsa_plan_add_step(_d, "approach", { requires : [["inside", false]] });
    gmsa_plan_add_step(_d, "enter_door", { requires : [["inside", false]], effects : [["inside", true]] });
    gmsa_plan_add_step(_d, "enter_window", { requires : [["inside", false]], effects : [["inside", true]] });
    gmsa_plan_add_step(_d, "dig_tunnel", { requires : [["inside", false]], effects : [["inside", true]] });
    gmsa_plan_add_step(_d, "take_loot", { requires : [["inside", true]], effects : [["has_loot", true]] });
    gmsa_plan_add_step(_d, "escape", { requires : [["has_loot", true]], effects : [["inside", false]] });
    var _get_in = gmsa_plan_add_task(_d, "get_in");
    gmsa_plan_add_method(_get_in, "door", { subtasks : ["enter_door"] });
    gmsa_plan_add_method(_get_in, "window", { subtasks : ["enter_window"] });
    gmsa_plan_add_method(_get_in, "tunnel", { subtasks : ["dig_tunnel"] });
    var _raid = gmsa_plan_add_task(_d, "raid");
    gmsa_plan_add_method(_raid, "only", { subtasks : ["approach", "get_in", "take_loot", "escape"] });
    return { domain : _d, get_in : _get_in };
};

// the grey crew: the designer's plan as written
var _grey = make_domain("d11 designer");
grey_domain = gmsa_plan_domain_build(_grey.domain);

// the learning crew: which steps fail where, and which entrance is best where, both from the plans' own results
var _learn = make_domain("d11 learning");
var _situation = ["night", "vault_1", "vault_2", "vault_3"];
reliability = gmsa_plan_learn_steps(_learn.domain, { inputs : _situation, half_life : 200 });
entrance_sense = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES, half_life : 200 });
gmsa_plan_learn_methods(_learn.get_in, entrance_sense, { inputs : _situation });
learn_domain = gmsa_plan_domain_build(_learn.domain);

teams = [
    { name : "Designer's plan", colour : c_gray, loots : [], fails : [] },
    { name : "Learning crew", colour : make_color_rgb(90, 200, 230), loots : [], fails : [] },
];

goblins = [];
for (var _i = 0; _i < 16; _i++) {
    var _g = {
        index : _i, world : id, team : _i div 8, vault : 0, x : 0, y : 0, inside : false, has_loot : false,
        doing : undefined, path : [], leg : 0, timer : 0, wait : irandom(60), start : 0,
    };
    _g.planner = gmsa_plan_planner_create((_g.team == 0) ? grey_domain : learn_domain, _g, { seed : 100 + _i });
    array_push(goblins, _g);
}
selected = goblins[8];

// what each step looks like in the game: where to walk, how long to work there
path_for = function(_g, _step) {
    var _v = vaults[_g.vault];
    switch (_step) {
        case "approach": return [_v.wait];
        case "enter_door": return [_v.outs[0]];
        case "enter_window": return [_v.outs[1]];
        case "dig_tunnel": return [_v.outs[2]];
        case "take_loot": return [_v.chest];
        case "escape": return [_v.ins[0]];
    }
    return [home];
};
work_time = function(_step) {
    for (var _e = 0; _e < 3; _e++) if (entrance_steps[_e] == _step) return entrance_work[_e];
    return (_step == "take_loot") ? 20 : 0;
};

// the step happens: entrances work by the vault's secret rules, everything else always works
finish = function(_g, _step) {
    var _v = vaults[_g.vault];
    for (var _e = 0; _e < 3; _e++) {
        if (entrance_steps[_e] != _step) continue;
        if (random(1) >= _v.rules[_e * 2 + (night ? 1 : 0)]) return false;
        _g.inside = true;
        _g.x = _v.ins[_e].x;
        _g.y = _v.ins[_e].y;
        return true;
    }
    if (_step == "take_loot") _g.has_loot = true;
    if (_step == "escape") {
        _g.inside = false;
        _g.x = home.x + random_range(-30, 30);
        _g.y = home.y + random_range(-60, 60);
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

// a new raid on a random vault
start_raid = function(_g) {
    _g.vault = irandom(2);
    _g.inside = false;
    _g.has_loot = false;
    _g.doing = undefined;
    _g.start = frame;
    _g.x = home.x + random_range(-30, 30);
    _g.y = home.y + random_range(-60, 60);
    gmsa_plan_make(_g.planner, "raid");
};

act = function(_g) {
    var _status = gmsa_plan_get_status(_g.planner);
    if (_status != gmsa_plan_status.RUNNING) {
        if (++_g.wait < 30) return;
        _g.wait = 0;
        if (_status == gmsa_plan_status.FAILED) array_push(teams[_g.team].fails, frame);
        start_raid(_g);
        return;
    }
    var _step = gmsa_plan_current(_g.planner);
    if (_step != _g.doing) {
        _g.doing = _step;
        _g.timer = 0;
        _g.leg = 0;
        _g.path = path_for(_g, _step);
    }
    if (_g.leg < array_length(_g.path)) {
        if (move_to(_g, _g.path[_g.leg], 2.5)) _g.leg++;
        return;
    }
    if (++_g.timer < work_time(_step)) return;
    _g.doing = undefined;
    if (!finish(_g, _step)) {
        gmsa_plan_step_failed(_g.planner);
        return;
    }
    gmsa_plan_step_done(_g.planner);
    if (gmsa_plan_get_status(_g.planner) == gmsa_plan_status.DONE) {
        // the loot, worth less the longer the raid took: a quick entrance beats a slow one that also works
        gmsa_plan_reward(_g.planner, 1 - (frame - _g.start) / 900);
        array_push(teams[_g.team].loots, frame);
    }
};

// loot or failures in the last minute
per_minute = function(_list) {
    while (array_length(_list) > 0 && _list[0] < frame - 3600) array_delete(_list, 0, 1);
    return array_length(_list);
};

reset = function() {
    shuffle();
    gmsa_learn_reset(entrance_sense);
    gmsa_plan_learn_steps_reset(reliability);
    for (var _t = 0; _t < 2; _t++) {
        teams[_t].loots = [];
        teams[_t].fails = [];
    }
    for (var _i = 0; _i < array_length(goblins); _i++) start_raid(goblins[_i]);
};
reset();