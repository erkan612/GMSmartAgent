randomize(); // the demo's own randomness, GMSmartAgent never touches it

kinds = ["gold", "potion", "gem"];
kind_colour = [c_yellow, make_colour_rgb(230, 60, 90), c_aqua];
items = [];              // { x, y, kind }
by_kind = [[], [], []];  // the same items split by kind, rebuilt when loot changes
per_kind = 4;

me    = { x : room_width / 2, y : room_height / 2 + 60, hp : 100, speed : 5, target : undefined };
guard = { x : room_width / 2, y : 200, speed : 4, goal : undefined, doing : "waiting" };

spawn_item = function(_kind) {
    var _x = 0, _y = 0, _tries = 0, _free = false;
    while (!_free && _tries < 50) {
        _x = random_range(80, room_width - 80);
        _y = random_range(190, room_height - 50);
        _free = true;
        for (var _i = 0; _i < array_length(items); _i++) {
            if (point_distance(_x, _y, items[_i].x, items[_i].y) < 60) { _free = false; break; }
        }
        _tries++;
    }
    array_push(items, { x : _x, y : _y, kind : _kind });
};

sort_items = function() {
    by_kind = [[], [], []];
    for (var _i = 0; _i < array_length(items); _i++) array_push(by_kind[items[_i].kind], items[_i]);
};

for (var _k = 0; _k < 3; _k++) repeat (per_kind) spawn_item(_k);
sort_items();

// you: one action per kind of loot, described by your health and the distance
var _p = gmsa_profile_create("d7 player");
gmsa_profile_add_input(_p, gmsa_input_pull("hp", function(_agent, _target) { return _agent.owner.me.hp; }, 0, 100));
gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _item) {
    var _me = _agent.owner.me;
    return point_distance(_me.x, _me.y, _item.x, _item.y);
}, 0, 600, true));
for (var _k = 0; _k < 3; _k++) {
    gmsa_profile_add_action(_p, "take_" + kinds[_k], {
        targets : method({ k : _k }, function(_agent) { return _agent.owner.by_kind[k]; }),
    });
}
gmsa_profile_set_features(_p, ["hp", "dist"]);
player = gmsa_agent_create(gmsa_profile_build(_p), id);  // records your picks, never thinks

// a short memory, so the guard keeps up when you change habits
model = gmsa_learn_lambdamart_create({ trees : 40, buffer : 100, half_life : 50, confidence_k : 10 });
trained = false;
training = false;
train_again = false;
train_frames = 0;
picks = 0;
outcomes = []; // your last 20 picks: 1 blocked, 0 taken

// what the model thinks you'll go for next, as ordinary pull inputs. Untrained, each reads 1/3.
reads = array_create(3, undefined);
for (var _k = 0; _k < 3; _k++) {
    reads[_k] = gmsa_learn_input(model, player, "take_" + kinds[_k], { fallback : 1 / 3, refresh : 250000 });
}

// the guard: a plain designer profile, the prediction is one consideration next to distance
var _g = gmsa_profile_create("d7 guard", { commitment : 0.2 });
for (var _k = 0; _k < 3; _k++) gmsa_profile_add_input(_g, gmsa_input_pull("wants_" + kinds[_k], reads[_k]));
gmsa_profile_add_input(_g, gmsa_input_pull("near_you", function(_agent, _item) {
    var _me = _agent.owner.me;
    return point_distance(_me.x, _me.y, _item.x, _item.y);
}, 0, 600, true));
var _near = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });
for (var _k = 0; _k < 3; _k++) {
    var _a = gmsa_profile_add_action(_g, "guard_" + kinds[_k], {
        targets : method({ k : _k }, function(_agent) { return _agent.owner.by_kind[k]; }),
    });
    gmsa_action_add_consideration(_a, "wants_" + kinds[_k], gmsa_curve_make(gmsa_curve.LINEAR));
    gmsa_action_add_consideration(_a, "near_you", _near);
}
gmsa_profile_add_action(_g, "wait", { weight : 0.01 });
guard_agent = gmsa_agent_create(gmsa_profile_build(_g), id);
think_timer = 0;

record = function(_blocked) {
    array_push(outcomes, _blocked);
    if (array_length(outcomes) > 20) array_delete(outcomes, 0, 1);
};

remove_item = function(_item) {
    for (var _i = 0; _i < array_length(items); _i++) {
        if (items[_i] == _item) { array_delete(items, _i, 1); break; }
    }
    spawn_item(_item.kind);
    sort_items();
};

// a click on loot is a pick, recorded against everything on offer
pick_at = function(_mx, _my) {
    if (me.target != undefined) return;  // one pick at a time
    var _hit = -1;
    for (var _i = 0; _i < array_length(items); _i++) {
        if (point_distance(_mx, _my, items[_i].x, items[_i].y) <= 16) { _hit = _i; break; }
    }
    if (_hit < 0) return;

    var _n = array_length(items);
    var _offered = array_create(_n, undefined);
    for (var _i = 0; _i < _n; _i++) _offered[_i] = { action : "take_" + kinds[items[_i].kind], target : items[_i] };
    gmsa_learn_observe(model, gmsa_observe(player, _offered, _hit));
    picks++;
    if (picks mod 10 == 0) {
        if (training) train_again = true;
        else { training = true; train_frames = 0; }
    }
    me.target = items[_hit];
};