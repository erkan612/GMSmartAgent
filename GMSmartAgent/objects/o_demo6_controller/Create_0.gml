randomize();              // the demo's own randomness, GMSmartAgent never touches it

cx = room_width / 2;      // where "you" stand, distance is measured from here
cy = room_height / 2 + 40;
items = [];               // { x, y, red, big, p }, p holds each model's opinion of the item
item_count = 16;
view = 0;                 // whose opinion is drawn

// one profile describes a pick: three inputs per item
var _p = gmsa_profile_create("d6 pick");
gmsa_profile_add_input(_p, gmsa_input_pull("red", function(_agent, _item) { return _item.red; }, 0, 1, true));
gmsa_profile_add_input(_p, gmsa_input_pull("big", function(_agent, _item) { return _item.big; }, 0, 1, true));
gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _item) {
    var _o = _agent.owner;
    return point_distance(_o.cx, _o.cy, _item.x, _item.y);
}, 0, 400, true));
gmsa_profile_add_action(_p, "pick", { targets : function(_agent) { return _agent.owner.items; } });
gmsa_profile_set_features(_p, ["red", "big", "dist"]);
profile = gmsa_profile_build(_p);
player = gmsa_agent_create(profile, id); // records your picks, never thinks

// three models watch the same picks
models = [
    { name : "Linear",     model : gmsa_learn_linear_create(),     colour : c_yellow,  confidence : 0, line : "", ranks : [] },
    { name : "RankNet",    model : gmsa_learn_ranknet_create(),    colour : c_lime,    confidence : 0, line : "", ranks : [] },
    { name : "LambdaMART", model : gmsa_learn_lambdamart_create(), colour : c_fuchsia, confidence : 0, line : "", ranks : [] },
];
lambdamart = models[2].model;
training = false;      // LambdaMART learns in batches, in the background
train_again = false;   // 10 more picks arrived while it was training
train_frames = 0;
picks = 0;

spawn_item = function() {
    var _x = cx, _y = cy, _tries = 0, _free = false;
    while (!_free && _tries < 50) {
        var _angle = random(360);
        var _range = random_range(80, 400);
        _x = cx + lengthdir_x(_range, _angle);
        _y = cy + lengthdir_y(_range, _angle) * 0.7;
        _free = true;
        for (var _i = 0; _i < array_length(items); _i++) {
            if (point_distance(_x, _y, items[_i].x, items[_i].y) < 55) { _free = false; break; }
        }
        _tries++;
    }
    array_push(items, { x : _x, y : _y, red : irandom(1), big : irandom(1), p : array_create(array_length(models), 0) });
};

// every model's opinion of every item: how likely you are to pick it
refresh = function() {
    var _d = gmsa_agent_evaluate(player);
    for (var _m = 0; _m < array_length(models); _m++) {
        var _entry = models[_m];
        var _r = gmsa_learn_predict(_entry.model, _d);
        _entry.confidence = _r.confidence;
        var _best = 0;
        for (var _i = 0; _i < array_length(_d.options); _i++) {
            var _item = _d.options[_i].target;
            _item.p[_m] = _r.p[_i];
            if (_r.p[_i] > _r.p[_best]) _best = _i;
        }
        _entry.line = "no opinion yet";
        if (_r.confidence > 0) {
            var _lines = gmsa_learn_explain(_entry.model, _d, _best);
            _entry.line = "favorite right now, " + _lines[0];
        }
    }
};

// a click on an item is a pick
pick_at = function(_mx, _my) {
    var _hit = -1;
    for (var _i = 0; _i < array_length(items); _i++) {
        var _it = items[_i];
        if (point_distance(_mx, _my, _it.x, _it.y) <= (_it.big ? 26 : 16)) { _hit = _i; break; }
    }
    if (_hit < 0) return;
    var _item = items[_hit];
    var _n = array_length(items);

    // where your pick ranked in each model's opinion: 100% its favorite, about 50% a random guess
    for (var _m = 0; _m < array_length(models); _m++) {
        var _entry = models[_m];
        if (_entry.confidence <= 0) continue;
        var _mine = _item.p[_m];
        var _below = 0;
        for (var _i = 0; _i < _n; _i++) {
            if (_i == _hit) continue;
            var _other = items[_i].p[_m];
            if (_other < _mine) _below += 1;
            else if (_other == _mine) _below += 0.5;
        }
        array_push(_entry.ranks, _below / (_n - 1));
        if (array_length(_entry.ranks) > 20) array_delete(_entry.ranks, 0, 1);
    }

    // record the pick against everything that was on offer, every model learns from it
    var _offered = array_create(_n, undefined);
    for (var _i = 0; _i < _n; _i++) _offered[_i] = { action : "pick", target : items[_i] };
    var _d = gmsa_observe(player, _offered, _hit);
    for (var _m = 0; _m < array_length(models); _m++) gmsa_learn_observe(models[_m].model, _d);
    picks++;

    array_delete(items, _hit, 1);
    spawn_item();

    if (picks mod 10 == 0) {
        if (training) train_again = true;
        else { training = true; train_frames = 0; }
    }
    refresh();
};

repeat (item_count) spawn_item();
refresh();