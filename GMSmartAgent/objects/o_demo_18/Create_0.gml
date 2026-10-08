randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
moves = ["attack", "block", "escape"];
places = ["at the bridge", "in the cave", "by the well", "at the gate", "in the market"];

// the fighter stands for the player: stamina, hp and how many enemies are around
var _p = gmsa_profile_create("d18 fighter");
gmsa_profile_add_input(_p, gmsa_input_push("stamina", 0, 1, 0.5));
gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 1, 0.5));
gmsa_profile_add_input(_p, gmsa_input_push("enemies", 0, 1, 0.5));
gmsa_profile_set_features(_p, ["stamina", "hp", "enemies"]);
for (var _i = 0; _i < array_length(moves); _i++) gmsa_profile_add_action(_p, moves[_i]);
gmsa_profile_build(_p);
fighter = gmsa_agent_create(_p);

// two learners, the same moves
bayes = gmsa_learn_bayes_create();
neighbor = gmsa_learn_neighbor_create();

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = true;
timer = 0;
bn_p = array_create(3, 0);
nn_p = array_create(3, 0);

// the auto-fighter: cornered, it escapes. Otherwise low stamina blocks, else it attacks. One move in twenty is anything
auto_pick = function() {
    if (random(1) < 0.05) return irandom(2);
    if (cornered) return 2;
    return (stamina < 0.5) ? 1 : 0;
};

// what each learner expects, per move
predict_next = function() {
    var _e = gmsa_agent_evaluate(fighter);
    var _n = array_length(_e.options);
    var _a = gmsa_learn_predict(bayes, _e);
    for (var _i = 0; _i < _n; _i++) bn_p[_e.options[_i].action.index] = _a.p[_i];
    bn_best = _e.options[_a.best].action.index;
    bn_sure = _a.sure;
    var _la = gmsa_learn_explain(bayes, _e, _a.best);
    bn_why = _la[0];
    var _b = gmsa_learn_predict(neighbor, _e);
    for (var _i = 0; _i < _n; _i++) nn_p[_e.options[_i].action.index] = _b.p[_i];
    nn_best = _e.options[_b.best].action.index;
    nn_sure = _b.sure;
    var _lb = gmsa_learn_explain(neighbor, _e, _b.best);
    nn_why = _lb[0];
};

// a new moment. One in twenty the fighter is cornered: hp under 10% and enemies over 90%, both at once
new_moment = function() {
    stamina = random(1);
    hp = random(1);
    enemies = random(1);
    if (random(1) < 0.05) {
        hp = random(0.1);
        enemies = 0.9 + random(0.1);
    }
    cornered = (hp < 0.1 && enemies > 0.9);
    place = places[irandom(array_length(places) - 1)];
    gmsa_agent_set_input(fighter, "stamina", stamina);
    gmsa_agent_set_input(fighter, "hp", hp);
    gmsa_agent_set_input(fighter, "enemies", enemies);
    predict_next();
};

act = function(_move) {
    // did each learner point at this move, overall and when cornered
    array_push(bn_recent, bn_best == _move);
    array_push(nn_recent, nn_best == _move);
    if (array_length(bn_recent) > 100) array_delete(bn_recent, 0, 1);
    if (array_length(nn_recent) > 100) array_delete(nn_recent, 0, 1);
    if (cornered) {
        corners += 1;
        array_push(bn_corner, bn_best == _move);
        array_push(nn_corner, nn_best == _move);
        if (array_length(bn_corner) > 30) array_delete(bn_corner, 0, 1);
        if (array_length(nn_corner) > 30) array_delete(nn_corner, 0, 1);
    }

    // the choice, recorded once, learned by both, with where it happened as a note
    var _d = gmsa_observe(fighter, moves, _move);
    gmsa_learn_observe(bayes, _d, place);     // Naive Bayes ignores the note
    gmsa_learn_observe(neighbor, _d, place);  // nearest neighbor keeps it with the moment

    total += 1;
    flash_text = moves[_move] + " " + place;
    flash = 40;
    new_moment();
};

tick = function() {
    if (flash > 0) flash -= 1;
    if (!auto) return;
    timer += 1;
    if (timer >= 40) {
        timer = 0;
        act(auto_pick());
    }
};

// where each move's button stands
move_box = function(_move) {
    var _x = area_w * (0.22 + _move * 0.28);
    var _y = room_height * 0.82;
    return { l : _x - 60, t : _y - 28, r : _x + 60, b : _y + 28, x : _x, y : _y };
};

reset = function() {
    gmsa_learn_reset(bayes);
    gmsa_learn_reset(neighbor);
    bn_recent = [];
    nn_recent = [];
    bn_corner = [];
    nn_corner = [];
    total = 0;
    corners = 0;
    flash = 0;
    flash_text = "";
    new_moment();
};
reset();