randomize(); // the demo's own randomness, GMSmartAgent never touches it

// the room: home on the left, three vaults behind a wall, the guard's post in front of each vault's door
area_w = room_width * 0.6;
wall_x = area_w * 0.62;
home = { x : area_w * 0.12, y : room_height * 0.5 };
vaults = [];
for (var _i = 0; _i < 3; _i++) {
    var _top = room_height * _i / 3;
    var _mid = _top + room_height / 6;
    array_push(vaults, {
        top   : _top,
        post  : { x : wall_x - 90, y : _mid },  // where the guard stands
        out   : { x : wall_x - 24, y : _mid },  // the door, outside
        in    : { x : wall_x + 24, y : _mid },  // the door, inside
        chest : { x : wall_x + 70, y : _mid },
    });
}
watch_length = 180; // frames between bells, the guard takes a post at every bell
watch_time = 0;
bell_flash = 0;
paused = false;
fast = false;
frame = 0;
popups = []; // "caught" and "+loot" where they happen
habit_names = ["you", "patrol 1, 2, 3", "chase the last raid", "random"];
guard = { habit : 1, post : 0, queued : 0, last_raid : 0, x : vaults[0].post.x, y : vaults[0].post.y, arrived : true };

// the guard as an agent nobody runs: it only describes the guard's choices, so a model can learn them
var _gp = gmsa_profile_create("d12 guard");
var _features = [];
for (var _i = 0; _i < 3; _i++) {
    var _n = string(_i + 1);
    gmsa_profile_add_input(_gp, gmsa_input_pull("at_" + _n, method({ v : _i }, function(_agent) { return (_agent.owner.post == v) ? 1 : 0; })));
    gmsa_profile_add_input(_gp, gmsa_input_pull("raided_" + _n, method({ v : _i }, function(_agent) { return (_agent.owner.last_raid == v) ? 1 : 0; })));
    array_push(_features, "at_" + _n, "raided_" + _n);
    gmsa_profile_add_action(_gp, "guard_" + _n);
}
gmsa_profile_set_features(_gp, _features);
gmsa_profile_build(_gp);
guard_agent = gmsa_agent_create(_gp, guard);
guard_options = ["guard_1", "guard_2", "guard_3"];

// what the coloured crew learns: where the guard goes at the next bell, from where it is and which vault was raided last
habits = gmsa_learn_linear_create({ learn_rate : 0.5, half_life : 40, confidence_k : 5 });
avoid_above = 0.4;

// a vault is safe while the lantern isn't there, and for the learning crew, while the guard probably isn't coming
safe = function(_n, _learning) {
    var _r = [["inside", false], ["lantern_" + _n, false]];
    if (_learning) array_push(_r, ["next_" + _n, "<", avoid_above]);
    return _r;
};

// the same raid for both crews, the learning crew also has the guard's next post as facts
make_domain = function(_name, _learning) {
    var _d = gmsa_plan_domain_create(_name);
    for (var _i = 0; _i < 3; _i++) {
        var _n = string(_i + 1);
        gmsa_plan_add_fact(_d, "lantern_" + _n, method({ v : _i, world : id }, function(_g) { return world.guard.post == v; }));
        if (_learning) gmsa_plan_learn_fact(_d, "next_" + _n, habits, guard_agent, "guard_" + _n, { fallback : 1 / 3 });
    }
    gmsa_plan_add_fact(_d, "inside", function(_g) { return _g.inside; });
    gmsa_plan_add_fact(_d, "has_loot", function(_g) { return _g.has_loot; });
    var _raid = gmsa_plan_add_task(_d, "raid", { select : gmsa_select.TOP_N_WEIGHTED, top_n : 3 });
    for (var _i = 0; _i < 3; _i++) {
        var _n = string(_i + 1);
        gmsa_plan_add_step(_d, "sneak_" + _n, { requires : safe(_n, _learning) });
        gmsa_plan_add_step(_d, "break_in_" + _n, { requires : safe(_n, _learning), effects : [["inside", true]] });
        var _params = { subtasks : ["sneak_" + _n, "break_in_" + _n, "grab_loot", "run_home"] };
        // the less likely the guard comes, the more the vault appeals
        if (_learning) _params.score = method({ v : _i, world : id }, function(_g, _state) { return 1 - _state[world.next_fact[v]]; });
        gmsa_plan_add_method(_raid, "vault_" + _n, _params);
    }
    gmsa_plan_add_step(_d, "grab_loot", { requires : [["inside", true]], effects : [["has_loot", true]] });
    gmsa_plan_add_step(_d, "run_home", { requires : [["has_loot", true]], effects : [["inside", false]] });
    return gmsa_plan_domain_build(_d);
};
grey_domain = make_domain("d12 designer", false);
learn_domain = make_domain("d12 learning", true);
next_fact = [];
next_read = []; // the same reads the crew uses, for the room and the panel
for (var _i = 0; _i < 3; _i++) {
    var _n = string(_i + 1);
    array_push(next_fact, gmsa_plan_fact_index(learn_domain, "next_" + _n));
    array_push(next_read, gmsa_learn_input(habits, guard_agent, "guard_" + _n, { fallback : 1 / 3 }));
}

teams = [
    { name : "Designer's plan", colour : c_gray, results : [] }, // results: true caught, false got away with loot
    { name : "Learning crew", colour : make_color_rgb(90, 200, 230), results : [] },
];

goblins = [];
for (var _i = 0; _i < 8; _i++) {
    var _g = {
        index : _i, team : _i div 4, vault : 0, at_vault : -1, x : 0, y : 0, inside : false, has_loot : false,
        doing : undefined, path : [], leg : 0, timer : 0, wait : 0,
    };
    _g.planner = gmsa_plan_planner_create((_g.team == 0) ? grey_domain : learn_domain, _g, { seed : 200 + _i });
    array_push(goblins, _g);
}
selected = goblins[4];

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

popup = function(_x, _y, _text, _colour) {
    array_push(popups, { x : _x, y : _y, text : _text, colour : _colour, life : 60 });
};

// the last 20 raids of a crew
record = function(_team, _caught) {
    var _r = teams[_team].results;
    array_push(_r, _caught);
    if (array_length(_r) > 20) array_delete(_r, 0, 1);
};
caught_count = function(_team) {
    var _r = teams[_team].results;
    var _c = 0;
    for (var _i = 0; _i < array_length(_r); _i++) if (_r[_i]) _c++;
    return _c;
};

send_home = function(_g) {
    _g.x = home.x + random_range(-30, 30);
    _g.y = home.y + random_range(-60, 60);
    _g.inside = false;
    _g.has_loot = false;
    _g.at_vault = -1;
    _g.doing = undefined;
};

start_raid = function(_g) {
    _g.wait = 0;
    _g.inside = false;
    _g.has_loot = false;
    _g.at_vault = -1;
    _g.doing = undefined;
    gmsa_plan_make(_g.planner, "raid");
};

// what each step looks like in the game: where to walk, how long to work there
path_for = function(_g, _step) {
    var _v = vaults[_g.vault];
    if (_step == "grab_loot") return [_v.chest];
    if (_step == "run_home") return [_v.in, _v.out, home];
    return [_v.out]; // sneaking up or breaking in, both at the door
};
work_time = function(_step) {
    if (string_pos("break_in_", _step) == 1) return 60;
    return (_step == "grab_loot") ? 20 : 0;
};

act = function(_g) {
    if (gmsa_plan_get_status(_g.planner) != gmsa_plan_status.RUNNING) {
        if (++_g.wait >= 30) start_raid(_g);
        return;
    }
    var _step = gmsa_plan_current(_g.planner);
    if (_step != _g.doing) {
        _g.doing = _step;
        _g.timer = 0;
        _g.leg = 0;
        var _breaking = (string_pos("break_in_", _step) == 1);
        if (_breaking || string_pos("sneak_", _step) == 1) _g.vault = real(string_char_at(_step, string_length(_step))) - 1;
        if (_breaking) _g.at_vault = _g.vault;
        _g.path = path_for(_g, _step);
    }
    if (_g.leg < array_length(_g.path)) {
        if (move_to(_g, _g.path[_g.leg], 3)) {
            _g.leg++;
            if (_step == "run_home" && _g.leg == 2) _g.at_vault = -1; // out of the door, away from the vault
        }
        return;
    }
    if (++_g.timer < work_time(_step)) return;
    _g.doing = undefined;
    if (string_pos("break_in_", _step) == 1) _g.inside = true;
    if (_step == "grab_loot") {
        _g.has_loot = true;
        guard.last_raid = _g.vault; // the alarm tells the guard which vault was hit
    }
    if (_step == "run_home") {
        _g.inside = false;
        _g.has_loot = false;
        record(_g.team, false);
        popup(_g.x, _g.y - 16, "+loot", c_yellow);
    }
    gmsa_plan_step_done(_g.planner);
};

// the guard catches goblins at the vault it is posted at, and anyone who walks into it there
catch_goblins = function() {
    for (var _i = 0; _i < array_length(goblins); _i++) {
        var _g = goblins[_i];
        if (gmsa_plan_get_status(_g.planner) != gmsa_plan_status.RUNNING) continue;
        var _seen = guard.arrived && (_g.at_vault == guard.post || point_distance(_g.x, _g.y, guard.x, guard.y) < 40);
        if (!_seen) continue;
        gmsa_plan_stop(_g.planner);
        record(_g.team, true);
        popup(_g.x, _g.y - 16, "caught", c_red);
        send_home(_g);
        _g.wait = -60; // a while in the cells
    }
};

// the bell: the guard takes its next post, and the learning crew watches where it went
ring = function() {
    var _next = guard.post;
    switch (guard.habit) {
        case 0: _next = guard.queued; break;
        case 1: _next = (guard.post + 1) mod 3; break;
        case 2: _next = guard.last_raid; break;
        case 3: _next = irandom(2); break;
    }
    gmsa_learn_observe(habits, gmsa_observe(guard_agent, guard_options, _next));
    guard.post = _next;
    guard.queued = _next;
    bell_flash = 30;
};

// one frame of the night
tick = function() {
    frame++;
    if (bell_flash > 0) bell_flash--;
    if (++watch_time >= watch_length) {
        watch_time = 0;
        ring();
    }
    guard.arrived = move_to(guard, vaults[guard.post].post, 5);
    for (var _i = 0; _i < array_length(goblins); _i++) act(goblins[_i]);
    catch_goblins();
    for (var _i = array_length(popups) - 1; _i >= 0; _i--) {
        popups[_i].y -= 0.5;
        if (--popups[_i].life <= 0) array_delete(popups, _i, 1);
    }
};

reset = function() {
    gmsa_learn_reset(habits);
    guard.post = 0;
    guard.queued = 0;
    guard.last_raid = 0;
    guard.x = vaults[0].post.x;
    guard.y = vaults[0].post.y;
    watch_time = 0;
    popups = [];
    for (var _t = 0; _t < 2; _t++) teams[_t].results = [];
    for (var _i = 0; _i < array_length(goblins); _i++) {
        var _g = goblins[_i];
        if (gmsa_plan_get_status(_g.planner) == gmsa_plan_status.RUNNING) gmsa_plan_stop(_g.planner);
        send_home(_g);
        _g.wait = 30 - irandom(120); // set out at different times
    }
};
reset();