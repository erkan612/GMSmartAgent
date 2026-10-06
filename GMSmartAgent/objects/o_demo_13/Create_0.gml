randomize(); // the demo's own randomness, GMSmartAgent never touches it

// the room, and the spots actions happen at
area_w = room_width * 0.6;
var _l = 40, _t = 40, _r = area_w - 40, _b = room_height - 40;
var _w = _r - _l, _h = _b - _t;
wall = { l : _l, t : _t, r : _r, b : _b };
spot_names = ["start", "bed", "box", "cabinet", "drawer", "chair", "window", "door", "vent"];
places = [
    { x : _l + _w * 0.5,  y : _t + _h * 0.55 },  // 0 start
    { x : _l + _w * 0.15, y : _t + _h * 0.18 },  // 1 bed, the code is under it
    { x : _l + _w * 0.85, y : _t + _h * 0.8 },   // 2 box, the key is in it
    { x : _l + _w * 0.12, y : _t + _h * 0.8 },   // 3 cabinet, the crowbar
    { x : _l + _w * 0.85, y : _t + _h * 0.18 },  // 4 drawer, the screwdriver
    { x : _l + _w * 0.32, y : _t + _h * 0.55 },  // 5 the chair's spot
    { x : _l + _w * 0.5,  y : _t + 24 },         // 6 under the window
    { x : _r - 24,        y : _t + _h * 0.5 },   // 7 the door
    { x : _l + 24,        y : _b - 24 },         // 8 the vent
];
step_spot = { read_code : 1, open_box_code : 2, take_crowbar : 3, pry_box : 2, take_key : 2, unlock_door : 7,
              take_screwdriver : 4, open_vent : 8, crawl_out : 8, move_chair : 6, smash_window : 6, climb_out : 6 };
work = { read_code : 60, open_box_code : 90, take_crowbar : 60, pry_box : 240, take_key : 30, unlock_door : 90,
         take_screwdriver : 60, open_vent : 180, crawl_out : 240, move_chair : 60, smash_window : 180, climb_out : 90 };  // frames
walk_speed = 3;

// what you allow in the room (click to change), and the room as it is right now
allow = { code : true, key : true, crowbar : true, screwdriver : true, chair : true };
cell = { code_exists : true, key_in_box : true, crowbar_exists : true, screwdriver_exists : true, chair_exists : true,
         box_open : false, chair_at_window : false, glass_broken : false, vent_open : false };
flaw_names = ["none", "reinforced glass", "rusted vent screws", "smudged code"];
flaw = 1;
dirty = false;
paused = false;
fast = false;
frame = 0;
started = 0;
escapes = [];   // { time, route }, newest last
failures = 0;

// an action's cost in seconds: the walk from where the agent will be (the "at" fact), then the work
cost_of = function(_step) {
    return method({ ctrl : id, step : _step }, function(_agent, _state) {
        var _from = ctrl.places[_state[ctrl.at_fact]];
        var _to = ctrl.places[ctrl.step_spot[$ step]];
        var _dist = point_distance(_from.x, _from.y, _to.x, _to.y);
        if (step == "move_chair") {  // to the chair first, then carry it to the window
            var _c = ctrl.places[5];
            _dist = point_distance(_from.x, _from.y, _c.x, _c.y) + point_distance(_c.x, _c.y, _to.x, _to.y);
        }
        return _dist / (ctrl.walk_speed * 60) + ctrl.work[$ step] / 60;
    });
};

// the actions: what each needs, what it does. No recipes, no order
var _d = gmsa_plan_domain_create("d13 escape");
var _mine = ["has_code", "has_key", "has_crowbar", "has_screwdriver", "out"];
for (var _i = 0; _i < array_length(_mine); _i++) gmsa_plan_add_fact(_d, _mine[_i], method({ n : _mine[_i] }, function(_a) { return _a[$ n]; }));
var _room = variable_struct_get_names(cell);
for (var _i = 0; _i < array_length(_room); _i++) gmsa_plan_add_fact(_d, _room[_i], method({ n : _room[_i] }, function(_a) { return _a.ctrl.cell[$ n]; }));
gmsa_plan_add_fact(_d, "at", function(_a) { return _a.at; });

var _add = function(_d, _name, _requires, _effects) {
    array_push(_effects, ["at", step_spot[$ _name]]);
    gmsa_plan_add_step(_d, _name, { requires : _requires, effects : _effects, cost : cost_of(_name) });
};
_add(_d, "read_code",        [["code_exists", true], ["has_code", false]],              [["has_code", true]]);
_add(_d, "open_box_code",    [["has_code", true], ["box_open", false]],                 [["box_open", true]]);
_add(_d, "take_crowbar",     [["crowbar_exists", true], ["has_crowbar", false]],        [["has_crowbar", true], ["crowbar_exists", false]]);
_add(_d, "pry_box",          [["has_crowbar", true], ["box_open", false]],              [["box_open", true]]);
_add(_d, "take_key",         [["box_open", true], ["key_in_box", true], ["has_key", false]], [["has_key", true], ["key_in_box", false]]);
_add(_d, "unlock_door",      [["has_key", true]],                                       [["out", true]]);
_add(_d, "take_screwdriver", [["screwdriver_exists", true], ["has_screwdriver", false]], [["has_screwdriver", true], ["screwdriver_exists", false]]);
_add(_d, "open_vent",        [["has_screwdriver", true], ["vent_open", false]],         [["vent_open", true]]);
_add(_d, "crawl_out",        [["vent_open", true]],                                     [["out", true]]);
_add(_d, "move_chair",       [["chair_exists", true], ["chair_at_window", false]],      [["chair_at_window", true]]);
_add(_d, "smash_window",     [["chair_at_window", true], ["glass_broken", false]],      [["glass_broken", true]]);
_add(_d, "climb_out",        [["chair_at_window", true], ["glass_broken", true]],       [["out", true]]);
gmsa_plan_add_goal(_d, "escape", { conditions : [["out", true]] });

// it learns which actions keep failing, old evidence fades so a fixed flaw gets noticed again
reliability = gmsa_plan_learn_steps(_d, { half_life : 20 });
domain = gmsa_plan_domain_build(_d);
at_fact = gmsa_plan_fact_index(domain, "at");

agent = {
    ctrl : id, x : 0, y : 0, at : 0,
    has_code : false, has_key : false, has_crowbar : false, has_screwdriver : false, out : false,
    doing : undefined, path : [], leg : 0, timer : 0, wait : 0,
};
agent.planner = gmsa_plan_planner_create(domain, agent, { budget : 6000, slice : 1500 });

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

path_for = function(_step) {
    var _to = places[step_spot[$ _step]];
    if (_step == "move_chair") return [places[5], _to];
    return [_to];
};

// the action happens. False when it fails: the hidden flaw, or something you took away
finish = function(_step) {
    var _a = agent;
    switch (_step) {
        case "read_code":
            if (!cell.code_exists) return false;
            _a.has_code = true;
            break;
        case "open_box_code":
            if (flaw == 3 && random(1) < 0.85) return false;  // the code reads wrong
            cell.box_open = true;
            break;
        case "take_crowbar":
            if (!cell.crowbar_exists) return false;
            cell.crowbar_exists = false;
            _a.has_crowbar = true;
            break;
        case "pry_box": cell.box_open = true; break;
        case "take_key":
            if (!cell.key_in_box) return false;
            cell.key_in_box = false;
            _a.has_key = true;
            break;
        case "take_screwdriver":
            if (!cell.screwdriver_exists) return false;
            cell.screwdriver_exists = false;
            _a.has_screwdriver = true;
            break;
        case "open_vent":
            if (flaw == 2 && random(1) < 0.85) return false;  // the screws won't turn
            cell.vent_open = true;
            break;
        case "move_chair":
            if (!cell.chair_exists) return false;
            cell.chair_at_window = true;
            break;
        case "smash_window":
            if (flaw == 1 && random(1) < 0.85) return false;  // the glass holds
            cell.glass_broken = true;
            break;
        case "unlock_door": case "crawl_out": case "climb_out":
            _a.out = true;
            break;
    }
    return true;
};

route_of = function(_step) {
    switch (_step) {
        case "unlock_door": return "door";
        case "crawl_out": return "vent";
    }
    return "window";
};

// a new attempt: the room as you allow it, the agent back in the middle
respawn = function() {
    cell.code_exists = allow.code;
    cell.key_in_box = allow.key;
    cell.crowbar_exists = allow.crowbar;
    cell.screwdriver_exists = allow.screwdriver;
    cell.chair_exists = allow.chair;
    cell.box_open = false;
    cell.chair_at_window = false;
    cell.glass_broken = false;
    cell.vent_open = false;
    var _a = agent;
    _a.has_code = false;
    _a.has_key = false;
    _a.has_crowbar = false;
    _a.has_screwdriver = false;
    _a.out = false;
    _a.at = 0;
    _a.x = places[0].x;
    _a.y = places[0].y;
    _a.doing = undefined;
    _a.wait = 0;
    started = frame;
    gmsa_plan_make(_a.planner, "escape");
};

act = function() {
    var _a = agent;
    if (_a.out) {
        if (++_a.wait >= 60) respawn();
        return;
    }
    var _status = gmsa_plan_get_status(_a.planner);
    if (_status == gmsa_plan_status.PLANNING) {
        gmsa_plan_work(_a.planner);  // a slice of planning per frame
        return;
    }
    if (_status != gmsa_plan_status.RUNNING) {
        if (++_a.wait < 30) return;
        _a.wait = 0;
        _a.doing = undefined;
        gmsa_plan_make(_a.planner, "escape");
        return;
    }
    var _step = gmsa_plan_current(_a.planner);
    if (_step != _a.doing) {
        _a.doing = _step;
        _a.timer = 0;
        _a.leg = 0;
        _a.path = path_for(_step);
    }
    if (_a.leg < array_length(_a.path)) {
        if (move_to(_a, _a.path[_a.leg], walk_speed)) {
            _a.leg++;
            if (_a.leg == array_length(_a.path)) _a.at = step_spot[$ _step];
        }
        return;
    }
    if (++_a.timer < work[$ _step]) return;
    _a.doing = undefined;
    if (!finish(_step)) {
        failures++;
        gmsa_plan_step_failed(_a.planner);
        return;
    }
    gmsa_plan_step_done(_a.planner);
    if (_a.out) {
        array_push(escapes, { time : (frame - started) / 60, route : route_of(_step) });
        if (array_length(escapes) > 6) array_delete(escapes, 0, 1);
    }
};

// one frame
tick = function() {
    frame++;
    act();
    if (dirty) {
        // you changed the room: a plan built on the old room is checked, and repaired when broken
        dirty = false;
        if (gmsa_plan_get_status(agent.planner) == gmsa_plan_status.RUNNING) gmsa_plan_refresh(agent.planner);
    }
};

// click an object: take it out of the room, or put it back
toggle = function(_x, _y) {
    var _a = agent;
    var _near = function(_p, _x, _y) { return point_distance(_p.x, _p.y, _x, _y) < 30; };
    var _chair = cell.chair_at_window ? places[6] : places[5];
    if (_near(places[1], _x, _y)) {
        allow.code = !allow.code;
        cell.code_exists = allow.code;
    } else if (_near(places[2], _x, _y)) {
        allow.key = !allow.key;
        if (!_a.has_key) cell.key_in_box = allow.key;
    } else if (_near(places[3], _x, _y)) {
        allow.crowbar = !allow.crowbar;
        if (!_a.has_crowbar) cell.crowbar_exists = allow.crowbar;
    } else if (_near(places[4], _x, _y)) {
        allow.screwdriver = !allow.screwdriver;
        if (!_a.has_screwdriver) cell.screwdriver_exists = allow.screwdriver;
    } else if (_near(_chair, _x, _y)) {
        allow.chair = !allow.chair;
        cell.chair_exists = allow.chair;
        if (!allow.chair) cell.chair_at_window = false;
    } else {
        return;
    }
    dirty = true;
};

reset = function() {
    gmsa_plan_learn_steps_reset(reliability);
    allow.code = true;
    allow.key = true;
    allow.crowbar = true;
    allow.screwdriver = true;
    allow.chair = true;
    escapes = [];
    failures = 0;
    respawn();
};
reset();