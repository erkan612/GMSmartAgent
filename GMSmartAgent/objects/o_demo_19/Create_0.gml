randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
acts = ["fish", "hunt", "rest"];
act_colour = [make_color_rgb(70, 130, 210), make_color_rgb(60, 150, 70), make_color_rgb(200, 175, 110)];
map_l = area_w * 0.05;
map_t = room_height * 0.04;
map_w = area_w * 0.9;
map_h = room_height * 0.56;
forests = [{ x : 0.2, y : 0.25, r : 0.15 }, { x : 0.78, y : 0.78, r : 0.15 }];
landmarks = [
    { name : "by the mill", x : 0.12, y : 0.6 },
    { name : "near the old oak", x : 0.45, y : 0.15 },
    { name : "at the ford", x : 0.6, y : 0.45 },
    { name : "by the shrine", x : 0.9, y : 0.3 },
    { name : "at the camp", x : 0.35, y : 0.88 },
];

// only where the wanderer stands: x and y, 0 to 1 across the map. Neither alone says anything
space = gmsa_learn_space("d19 map", acts, ["x", "y"]);
bayes = gmsa_learn_bayes_create();
// a memory of 1024 stops, kept long: the habit never changes, and the map can only be as detailed as what's remembered
neighbor = gmsa_learn_neighbor_create({ capacity : 1024, half_life : 1000 });

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = true;
walk = 0;
bn_p = array_create(3, 0);
nn_p = array_create(3, 0);
heat_w = 24;
heat_h = 14;
heat_count = heat_w * heat_h;

river_y = function(_x) {
    return 0.5 + 0.18 * sin(2 * pi * _x * 1.5);
};

// the wanderer's habit: by the river it fishes, in a forest it hunts, elsewhere it rests
zone = function(_x, _y) {
    if (abs(_y - river_y(_x)) < 0.08) return 0;
    for (var _i = 0; _i < array_length(forests); _i++) {
        if (point_distance(_x, _y, forests[_i].x, forests[_i].y) < forests[_i].r) return 1;
    }
    return 2;
};

auto_pick = function() {
    if (random(1) < 0.05) return irandom(2);
    return zone(here_x, here_y);
};

// the note for a spot: the nearest landmark
note_for = function(_x, _y) {
    var _b = 0;
    for (var _i = 1; _i < array_length(landmarks); _i++) {
        if (point_distance(_x, _y, landmarks[_i].x, landmarks[_i].y) < point_distance(_x, _y, landmarks[_b].x, landmarks[_b].y)) _b = _i;
    }
    return landmarks[_b].name;
};

// the three choices at a spot, each with the spot as its inputs
offer = function(_x, _y) {
    var _in = [_x, _y];
    return [{ action : 0, inputs : _in }, { action : 1, inputs : _in }, { action : 2, inputs : _in }];
};

// a learner's guess at a spot: the action, how sure, and every probability
guess = function(_model, _options) {
    var _r = gmsa_learn_space_predict(_model, space, _options);
    var _b = 0;
    for (var _i = 1; _i < 3; _i++) if (_r.p[_i] > _r.p[_b]) _b = _i;
    return { a : _b, s : _r.confidence * _r.p[_b], p : [_r.p[0], _r.p[1], _r.p[2]] };
};

predict_next = function() {
    var _o = offer(here_x, here_y);
    var _gb = guess(bayes, _o);
    bn_p = _gb.p;
    bn_best = _gb.a;
    bn_sure = _gb.s;
    var _lb = gmsa_learn_space_explain(bayes, space, _o, bn_best);
    bn_why = _lb[0];
    var _gn = guess(neighbor, _o);
    nn_p = _gn.p;
    nn_best = _gn.a;
    nn_sure = _gn.s;
    var _ln = gmsa_learn_space_explain(neighbor, space, _o, nn_best);
    nn_why = _ln[0];
};

act = function(_a) {
    // did each learner point at this action, overall and off the open fields
    array_push(bn_recent, bn_best == _a);
    array_push(nn_recent, nn_best == _a);
    if (array_length(bn_recent) > 100) array_delete(bn_recent, 0, 1);
    if (array_length(nn_recent) > 100) array_delete(nn_recent, 0, 1);
    if (zone(here_x, here_y) != 2) {
        array_push(bn_place, bn_best == _a);
        array_push(nn_place, nn_best == _a);
        if (array_length(bn_place) > 30) array_delete(bn_place, 0, 1);
        if (array_length(nn_place) > 30) array_delete(nn_place, 0, 1);
    }

    // the choice, learned by both, with the nearest landmark as a note
    var _note = note_for(here_x, here_y);
    var _o = offer(here_x, here_y);
    gmsa_learn_space_observe(bayes, space, _o, _a, _note);     // Naive Bayes ignores the note
    gmsa_learn_space_observe(neighbor, space, _o, _a, _note);  // nearest neighbor keeps it with the moment

    array_push(trail, { x : here_x, y : here_y, a : _a });
    if (array_length(trail) > 40) array_delete(trail, 0, 1);
    total += 1;
    flash_text = acts[_a] + " " + _note;
    flash = 40;

    // walk on to a new spot
    from_x = here_x;
    from_y = here_y;
    if (auto) {
        here_x = random(1);
        here_y = random(1);
    }
    predict_next();
};

tick = function() {
    if (flash > 0) flash -= 1;
    if (!auto) return;
    walk += 1;
    if (walk >= 40) {
        walk = 0;
        act(auto_pick());
    }
};

// redraw a few cells of each learner's map, the whole map over many frames
heat_step = function(_cells) {
    repeat (_cells) {
        var _cx = (heat_next mod heat_w + 0.5) / heat_w;
        var _cy = (heat_next div heat_w + 0.5) / heat_h;
        var _o = offer(_cx, _cy);
        var _gb = guess(bayes, _o);
        heat_bn[heat_next] = _gb.a;
        heat_bs[heat_next] = _gb.s;
        var _gn = guess(neighbor, _o);
        heat_nn[heat_next] = _gn.a;
        heat_ns[heat_next] = _gn.s;
        heat_next = (heat_next + 1) mod heat_count;
    }
};

sx = function(_x) { return map_l + _x * map_w; };
sy = function(_y) { return map_t + _y * map_h; };

reset = function() {
    gmsa_learn_reset(bayes);
    gmsa_learn_reset(neighbor);
    bn_recent = [];
    nn_recent = [];
    bn_place = [];
    nn_place = [];
    trail = [];
    total = 0;
    flash = 0;
    flash_text = "";
    walk = 0;
    heat_bn = array_create(heat_count, -1);
    heat_bs = array_create(heat_count, 0);
    heat_nn = array_create(heat_count, -1);
    heat_ns = array_create(heat_count, 0);
    heat_next = 0;
    here_x = random(1);
    here_y = random(1);
    from_x = here_x;
    from_y = here_y;
    predict_next();
};
reset();