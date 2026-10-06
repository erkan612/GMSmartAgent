randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
var _a = area_w, _h = room_height;
bank = { l : _a * 0.32, r : _a * 0.68, t : _h * 0.25, b : _h * 0.6 };
spot_names = ["hideout", "across the street", "cafe", "building site", "van", "front door", "back door", "roof hatch",
              "lobby", "office", "vault", "car", "manhole", "market"];
places = [
    { x : _a * 0.08, y : _h * 0.92 },          // 0 hideout
    { x : _a * 0.5,  y : _h * 0.75 },          // 1 across the street
    { x : _a * 0.12, y : _h * 0.15 },          // 2 cafe
    { x : _a * 0.88, y : _h * 0.12 },          // 3 building site, the ladder
    { x : _a * 0.1,  y : _h * 0.55 },          // 4 van, the drill
    { x : _a * 0.5,  y : bank.b + 14 },        // 5 front door
    { x : bank.r + 14, y : _h * 0.42 },        // 6 back door
    { x : _a * 0.5,  y : bank.t - 14 },        // 7 roof hatch
    { x : _a * 0.5,  y : _h * 0.47 },          // 8 lobby
    { x : _a * 0.38, y : _h * 0.33 },          // 9 office, the code
    { x : _a * 0.62, y : _h * 0.33 },          // 10 vault
    { x : _a * 0.9,  y : _h * 0.75 },          // 11 car
    { x : _a * 0.75, y : _h * 0.92 },          // 12 manhole
    { x : _a * 0.32, y : _h * 0.08 },          // 13 market
];
// where each step walks, in order, the last spot is where it ends. Getaways leave by the back door first when inside
step_path = { case_the_bank : [1], fetch_drill : [4], steal_keycard : [2], enter_back_door : [6, 8], take_ladder : [3],
              enter_roof : [7, 8], bribe_guard : [5], walk_in_front : [5, 8], find_code : [9], enter_code : [10],
              drill_vault : [10], drive_off : [11], sewer_escape : [12], blend_in : [13] };
via_back = { drive_off : true, sewer_escape : true, blend_in : true };
work = { case_the_bank : 120, fetch_drill : 60, steal_keycard : 90, enter_back_door : 60, take_ladder : 60, enter_roof : 120,
         bribe_guard : 120, walk_in_front : 30, find_code : 90, enter_code : 90, drill_vault : 360,
         drive_off : 60, sewer_escape : 300, blend_in : 120 };  // frames
walk_speed = 3;

// the town as you set it (click to change), and the ladder, which returns after every job unless you take it away
town = { guard_at_cafe : true, ladder : true, code : true, car : true, sewer : true, crowd : true };
allow_ladder = true;
dirty = false;
paused = false;
fast = false;
frame = 0;
started = 0;
jobs = [];  // { entry, crack, away, time }, newest last
job = { entry : "", crack : "", away : "" };

// a step's cost in seconds: the walk from where the robber will be, along its path, then the work. Bribes cost money too
cost_of = function(_step) {
    return method({ ctrl : id, step : _step }, function(_r, _state) {
        var _from = ctrl.places[_state[ctrl.at_fact]];
        var _x = _from.x;
        var _y = _from.y;
        var _dist = 0;
        if (variable_struct_exists(ctrl.via_back, step) && _state[ctrl.inside_fact]) {
            var _b = ctrl.places[6];
            _dist += point_distance(_x, _y, _b.x, _b.y);
            _x = _b.x;
            _y = _b.y;
        }
        var _path = ctrl.step_path[$ step];
        for (var _i = 0; _i < array_length(_path); _i++) {
            var _p = ctrl.places[_path[_i]];
            _dist += point_distance(_x, _y, _p.x, _p.y);
            _x = _p.x;
            _y = _p.y;
        }
        return _dist / (ctrl.walk_speed * 60) + ctrl.work[$ step] / 60 + ((step == "bribe_guard") ? 3 : 0);
    });
};

var _d = gmsa_plan_domain_create("d14 bank job");
var _mine = ["inside", "has_keycard", "has_ladder", "has_cash", "bribed", "has_code", "has_drill", "has_loot", "away"];
for (var _i = 0; _i < array_length(_mine); _i++) gmsa_plan_add_fact(_d, _mine[_i], method({ n : _mine[_i] }, function(_r) { return _r[$ n]; }));
var _town = variable_struct_get_names(town);
for (var _i = 0; _i < array_length(_town); _i++) gmsa_plan_add_fact(_d, _town[_i], method({ n : _town[_i] }, function(_r) { return _r.ctrl.town[$ n]; }));
gmsa_plan_add_fact(_d, "at", function(_r) { return _r.at; });

var _add = function(_d, _name, _requires, _effects) {
    var _path = step_path[$ _name];
    array_push(_effects, ["at", _path[array_length(_path) - 1]]);
    gmsa_plan_add_step(_d, _name, { requires : _requires, effects : _effects, cost : cost_of(_name) });
};
// the recipe's own steps
_add(_d, "case_the_bank",   [], []);
_add(_d, "fetch_drill",     [["has_drill", false]], [["has_drill", true]]);
_add(_d, "find_code",       [["inside", true], ["code", true], ["has_code", false]], [["has_code", true]]);
_add(_d, "enter_code",      [["inside", true], ["has_code", true], ["has_loot", false]], [["has_loot", true]]);
_add(_d, "drill_vault",     [["inside", true], ["has_drill", true], ["has_loot", false]], [["has_loot", true]]);
// the actions the goals search through
_add(_d, "steal_keycard",   [["guard_at_cafe", true], ["has_keycard", false]], [["has_keycard", true]]);
_add(_d, "enter_back_door", [["has_keycard", true], ["inside", false]], [["inside", true]]);
_add(_d, "take_ladder",     [["ladder", true], ["has_ladder", false]], [["has_ladder", true], ["ladder", false]]);
_add(_d, "enter_roof",      [["has_ladder", true], ["inside", false]], [["inside", true]]);
_add(_d, "bribe_guard",     [["guard_at_cafe", false], ["has_cash", true], ["bribed", false]], [["bribed", true], ["has_cash", false]]);
_add(_d, "walk_in_front",   [["bribed", true], ["inside", false]], [["inside", true]]);
_add(_d, "drive_off",       [["has_loot", true], ["car", true]], [["away", true], ["inside", false]]);
_add(_d, "sewer_escape",    [["has_loot", true], ["sewer", true]], [["away", true], ["inside", false]]);
_add(_d, "blend_in",        [["has_loot", true], ["crowd", true]], [["away", true], ["inside", false]]);

// the goals: only the outcome is written, the robber finds the way
gmsa_plan_add_goal(_d, "get_inside", { conditions : [["inside", true]], variety : 0.25,
    actions : ["steal_keycard", "enter_back_door", "take_ladder", "enter_roof", "bribe_guard", "walk_in_front"] });
gmsa_plan_add_goal(_d, "get_away", { conditions : [["away", true]], variety : 0.25,
    actions : ["drive_off", "sewer_escape", "blend_in"] });

// the recipes: the designer's structure
var _prepare = gmsa_plan_add_task(_d, "prepare");
gmsa_plan_add_method(_prepare, "travel_light", { subtasks : [] });
gmsa_plan_add_method(_prepare, "bring_the_drill", { subtasks : ["fetch_drill"] });
var _crack = gmsa_plan_add_task(_d, "crack_vault");
gmsa_plan_add_method(_crack, "code", { subtasks : ["find_code", "enter_code"] });
gmsa_plan_add_method(_crack, "drill", { subtasks : ["drill_vault"] });
var _job = gmsa_plan_add_task(_d, "job");
gmsa_plan_add_method(_job, "the_plan", { subtasks : ["case_the_bank", "prepare", "get_inside", "crack_vault", "get_away"] });
domain = gmsa_plan_domain_build(_d);
at_fact = gmsa_plan_fact_index(domain, "at");
inside_fact = gmsa_plan_fact_index(domain, "inside");

robber = {
    ctrl : id, x : 0, y : 0, at : 0,
    inside : false, has_keycard : false, has_ladder : false, has_cash : true, bribed : false,
    has_code : false, has_drill : false, has_loot : false, away : false,
    doing : undefined, path : [], leg : 0, timer : 0, wait : 0,
};
robber.planner = gmsa_plan_planner_create(domain, robber, { budget : 8000, slice : 1500 });

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
    var _out = [];
    if (variable_struct_exists(via_back, _step) && robber.inside) array_push(_out, places[6]);
    var _path = step_path[$ _step];
    for (var _i = 0; _i < array_length(_path); _i++) array_push(_out, places[_path[_i]]);
    return _out;
};

// the step happens in town. False when the town changed under it
finish = function(_step) {
    var _r = robber;
    switch (_step) {
        case "fetch_drill": _r.has_drill = true; break;
        case "steal_keycard":
            if (!town.guard_at_cafe) return false;  // the guard isn't at the cafe
            _r.has_keycard = true;
            break;
        case "take_ladder":
            if (!town.ladder) return false;
            town.ladder = false;
            _r.has_ladder = true;
            break;
        case "bribe_guard":
            if (town.guard_at_cafe) return false;  // nobody at the door to bribe
            _r.bribed = true;
            _r.has_cash = false;
            break;
        case "enter_back_door": _r.inside = true; job.entry = "back door"; break;
        case "enter_roof": _r.inside = true; job.entry = "roof"; break;
        case "walk_in_front": _r.inside = true; job.entry = "front door"; break;
        case "find_code":
            if (!town.code) return false;
            _r.has_code = true;
            break;
        case "enter_code": _r.has_loot = true; job.crack = "code"; break;
        case "drill_vault": _r.has_loot = true; job.crack = "drill"; break;
        case "drive_off":
            if (!town.car) return false;
            _r.away = true; _r.inside = false; job.away = "car";
            break;
        case "sewer_escape":
            if (!town.sewer) return false;
            _r.away = true; _r.inside = false; job.away = "sewer";
            break;
        case "blend_in":
            if (!town.crowd) return false;
            _r.away = true; _r.inside = false; job.away = "crowd";
            break;
    }
    return true;
};

// a new job: back at the hideout, the ladder back on site unless you took it away
respawn = function() {
    var _r = robber;
    town.ladder = allow_ladder;
    _r.at = 0;
    _r.x = places[0].x;
    _r.y = places[0].y;
    _r.inside = false;
    _r.has_keycard = false;
    _r.has_ladder = false;
    _r.has_cash = true;
    _r.bribed = false;
    _r.has_code = false;
    _r.has_drill = false;
    _r.has_loot = false;
    _r.away = false;
    _r.doing = undefined;
    _r.wait = 0;
    job = { entry : "", crack : "", away : "" };
    started = frame;
    gmsa_plan_make(_r.planner, "job");
};

act = function() {
    var _r = robber;
    if (_r.away) {
        if (++_r.wait >= 90) respawn();
        return;
    }
    var _status = gmsa_plan_get_status(_r.planner);
    if (_status == gmsa_plan_status.PLANNING) {
        gmsa_plan_work(_r.planner); // a slice of planning per frame
        return;
    }
    if (_status != gmsa_plan_status.RUNNING) {
        if (++_r.wait < 60) return;
        _r.wait = 0;
        _r.doing = undefined;
        gmsa_plan_make(_r.planner, "job"); // try again, from wherever it stands
        return;
    }
    var _step = gmsa_plan_current(_r.planner);
    if (_step != _r.doing) {
        _r.doing = _step;
        _r.timer = 0;
        _r.leg = 0;
        _r.path = path_for(_step);
    }
    if (_r.leg < array_length(_r.path)) {
        if (move_to(_r, _r.path[_r.leg], walk_speed)) {
            _r.leg++;
            if (_r.leg == array_length(_r.path)) {
                var _sp = step_path[$ _step];
                _r.at = _sp[array_length(_sp) - 1];
            }
        }
        return;
    }
    if (++_r.timer < work[$ _step]) return;
    _r.doing = undefined;
    if (!finish(_step)) {
        gmsa_plan_step_failed(_r.planner);
        return;
    }
    gmsa_plan_step_done(_r.planner);
    if (_r.away) {
        array_push(jobs, { entry : job.entry, crack : job.crack, away : job.away, time : (frame - started) / 60 });
        if (array_length(jobs) > 5) array_delete(jobs, 0, 1);
    }
};

tick = function() {
    frame++;
    act();
    if (dirty) {
        // the town changed: the plan is checked against it, and the broken part repaired
        dirty = false;
        if (gmsa_plan_get_status(robber.planner) == gmsa_plan_status.RUNNING) gmsa_plan_refresh(robber.planner);
    }
};

// click a place to change the town
toggle = function(_x, _y) {
    var _hit = -1;
    var _spots = [2, 5, 3, 9, 11, 12, 13];
    for (var _i = 0; _i < array_length(_spots); _i++) {
        var _p = places[_spots[_i]];
        if (point_distance(_p.x, _p.y, _x, _y) < 30) _hit = _spots[_i];
    }
    switch (_hit) {
        case 2: case 5: town.guard_at_cafe = !town.guard_at_cafe; break;
        case 3:
            allow_ladder = !allow_ladder;
            if (!robber.has_ladder) town.ladder = allow_ladder;
            break;
        case 9: town.code = !town.code; break;
        case 11: town.car = !town.car; break;
        case 12: town.sewer = !town.sewer; break;
        case 13: town.crowd = !town.crowd; break;
        default: return;
    }
    dirty = true;
};

reset = function() {
    town.guard_at_cafe = true;
    town.code = true;
    town.car = true;
    town.sewer = true;
    town.crowd = true;
    allow_ladder = true;
    jobs = [];
    respawn();
};
reset();