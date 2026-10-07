randomize(); // the demo's own randomness, GMSmartAgent never touches it

move_names = ["jab", "kick", "uppercut", "dodge", "potion", "shield"];
move_colours = [make_color_rgb(230, 120, 90), make_color_rgb(230, 170, 70), make_color_rgb(220, 80, 80),
                make_color_rgb(120, 170, 230), make_color_rgb(110, 200, 120), make_color_rgb(170, 150, 220)];
thresholds = [0.4, 0.6, 0.8];
area_w = room_width * 0.6;

// the fighter stands for you: your moves are recorded through it, with your hp and distance at the time
var _p = gmsa_profile_create("d15 fighter");
gmsa_profile_add_input(_p, gmsa_input_push("hp", 0, 100, 100));
gmsa_profile_add_input(_p, gmsa_input_push("distance", 0, 1, 0));
gmsa_profile_set_features(_p, ["hp", "distance"]);
for (var _i = 0; _i < array_length(move_names); _i++) gmsa_profile_add_action(_p, move_names[_i]);
gmsa_profile_build(_p);
fighter = gmsa_agent_create(_p);

// one learner for everything. Length 4: enough to see a combo and the move that opened it
model = gmsa_learn_ngram_create({ length : 4 });

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = true;      // the auto-player fights until you take over
habits = 0;       // which habits the auto-player has
threshold_i = 1;  // speaks at sure 0.6
timer = 0;
pred = array_create(6, 1 / 6);

// the auto-player's habits, nobody is perfect: one move in ten is anything
auto_pick = function() {
    if (random(1) < 0.1) return irandom(5);
    var _n = array_length(moves);
    var _last = (_n > 0) ? moves[_n - 1] : -1;
    var _near = !far;
    if (habits == 0) {
        if (hp < 25) return 4;                                        // hurt: a potion, whatever came before
        if (_last == 4) return 5;                                     // a potion, then the shield
        if (_last == 5) return _near ? 0 : 1;                         // then a jab up close, a kick from afar
        if (_n >= 2 && _last == 0 && moves[_n - 2] == 0) return 2;    // jab, jab, uppercut
        if (_last == 2) return 3;                                     // an uppercut, then a dodge
        if (_last == 3 && _n >= 4 && moves[_n - 4] <= 2) return moves[_n - 4]; // after a dodge, the attack that opened the combo
        return _near ? 0 : 1;
    }
    if (_last == 5) return 4;                                         // the shield, then a potion
    if (hp < 35) return 5;                                            // hurt: the shield first
    if (_last == 4) return _near ? 1 : 3;                             // then a kick up close, a dodge from afar
    if (_n >= 2 && _last == 1 && moves[_n - 2] == 1) return 2;        // kick, kick, uppercut
    if (_last == 2) return 0;                                         // an uppercut, then a jab
    return _near ? 1 : 0;
};
habit_text = [
    "hurt: potion. Potion, then shield. Shield, then jab near or kick far. Jab, jab, uppercut. Uppercut, then dodge. After a dodge, the attack that opened the combo. Otherwise jab near, kick far.",
    "Hurt: shield, then potion. Potion, then kick near or dodge far. Kick, kick, uppercut. Uppercut, then jab. Otherwise kick near, jab far.",
];

// what the learner expects next, how sure it is, and why
predict_next = function() {
    gmsa_agent_set_input(fighter, "hp", hp);
    gmsa_agent_set_input(fighter, "distance", far ? 1 : 0);
    var _e = gmsa_agent_evaluate(fighter);
    var _out = gmsa_learn_predict(model, _e);
    for (var _i = 0; _i < 6; _i++) pred[_i] = _out.p[_i];
    pred_best = _out.best;
    pred_sure = _out.sure;
    pred_conf = _out.confidence;
    speaking = (pred_sure >= thresholds[threshold_i]);
    var _lines = gmsa_learn_explain(model, _e, pred_best);
    why = _lines[0];
};

do_move = function(_m) {
    // how the prediction did
    total += 1;
    var _right = (_m == pred_best);
    array_push(recent, _right);
    if (array_length(recent) > 20) array_delete(recent, 0, 1);
    flash = 0;
    if (speaking) {
        spoke += 1;
        if (_right) spoke_right += 1;
        flash_text = _right ? "Blocked!" : "Missed it";
        flash = 45;
    }

    // learn it: the move, with the hp and distance it was made at
    gmsa_learn_observe(model, gmsa_observe(fighter, move_names, _m));
    array_push(moves, _m);
    if (array_length(moves) > 8) array_delete(moves, 0, 1);
    last_move = _m;
    move_flash = 30;

    // the fight goes on: the dummy hits back, potions heal, a knockout starts a new round
    var _hit = irandom_range(6, 14);
    if (_m == 3) _hit = 0;  // dodged
    if (_m == 5) _hit = 3;  // shielded
    if (_m == 4) hp = min(100, hp + 50);
    hp = max(0, hp - _hit);
    if (hp <= 0) {
        hp = 100;
        rounds += 1;
        gmsa_learn_ngram_break(model, fighter);  // a new round: the last one's moves don't lead into it
        array_resize(moves, 0);
        flash_text = "Knocked out, new round";
        flash = 60;
    }
    if (auto && random(1) < 0.2) far = !far;
    predict_next();
};

tick = function() {
    if (flash > 0) flash -= 1;
    if (move_flash > 0) move_flash -= 1;
    if (!auto) return;
    timer += 1;
    if (timer >= 30) {
        timer = 0;
        do_move(auto_pick());
    }
};

reset = function() {
    gmsa_learn_reset(model);  // forgets everything, every history starts over
    hp = 100;
    far = false;
    moves = [];
    recent = [];
    total = 0;
    spoke = 0;
    spoke_right = 0;
    rounds = 0;
    flash = 0;
    flash_text = "";
    last_move = -1;
    move_flash = 0;
    predict_next();
};
reset();