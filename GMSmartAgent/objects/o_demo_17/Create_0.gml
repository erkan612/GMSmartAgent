randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
reports = ["gold", "army", "time", "rain", "morale", "fog", "supplies", "spies"];
lanes = ["left", "middle", "right"];
report = array_create(array_length(reports), 0);

// the attacker stands for the player: eight scout reports, three lanes
var _p = gmsa_profile_create("d17 attacker");
for (var _i = 0; _i < array_length(reports); _i++) gmsa_profile_add_input(_p, gmsa_input_push(reports[_i], 0, 1, 0.5));
gmsa_profile_set_features(_p, reports);
for (var _i = 0; _i < array_length(lanes); _i++) gmsa_profile_add_action(_p, lanes[_i]);
gmsa_profile_build(_p);
attacker = gmsa_agent_create(_p);

// two learners, the same attacks. With 8 inputs Count can only cut each in two: 2^8 = 256 situations
// (3 cuts would be 6561, over its limit of 4096), and it has to see each situation to learn it
count = gmsa_learn_count_create({ bins : 2 });
bayes = gmsa_learn_bayes_create();

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = true;
habits = 0;
timer = 0;
ct_p = array_create(3, 0);
by_p = array_create(3, 0);
habit_text = [
    "A big army (over 60%) goes up the middle. Otherwise at night (time under 25% or over 75%) the left, by day the right.",
    "Poor (gold under 30%) raids the right. Otherwise in rain (over 50%) the left, else the middle.",
];
habit_uses = [[1, 2], [0, 3]];  // the reports each habit looks at, the other six don't matter

// the auto-attacker's habits, one attack in ten is anywhere
auto_pick = function() {
    if (random(1) < 0.1) return irandom(2);
    if (habits == 0) {
        if (report[1] > 0.6) return 1;
        return (report[2] < 0.25 || report[2] > 0.75) ? 0 : 2;
    }
    if (report[0] < 0.3) return 2;
    return (report[3] > 0.5) ? 0 : 1;
};

// what each learner expects, per lane
predict_next = function() {
    var _e = gmsa_agent_evaluate(attacker);
    var _n = array_length(_e.options);
    var _a = gmsa_learn_predict(count, _e);
    for (var _i = 0; _i < _n; _i++) ct_p[_e.options[_i].action.index] = _a.p[_i];
    ct_best = _e.options[_a.best].action.index;
    ct_sure = _a.sure;
    var _la = gmsa_learn_explain(count, _e, _a.best);
    ct_why = _la[0];
    var _b = gmsa_learn_predict(bayes, _e);
    for (var _i = 0; _i < _n; _i++) by_p[_e.options[_i].action.index] = _b.p[_i];
    by_best = _e.options[_b.best].action.index;
    by_sure = _b.sure;
    var _lb = gmsa_learn_explain(bayes, _e, _b.best);
    by_why = _lb[0];
};

// a new scout report, every value anywhere from 0 to 100%
new_report = function() {
    for (var _i = 0; _i < array_length(reports); _i++) {
        report[_i] = random(1);
        gmsa_agent_set_input(attacker, reports[_i], report[_i]);
    }
    predict_next();
};

attack = function(_lane) {
    // did each learner point at this lane
    array_push(ct_recent, ct_best == _lane);
    array_push(by_recent, by_best == _lane);
    if (array_length(ct_recent) > 100) array_delete(ct_recent, 0, 1);
    if (array_length(by_recent) > 100) array_delete(by_recent, 0, 1);

    // the choice, recorded once, learned by both
    var _d = gmsa_observe(attacker, lanes, _lane);
    gmsa_learn_observe(count, _d);
    gmsa_learn_observe(bayes, _d);

    total += 1;
    shot_lane = _lane;
    shot = 40;
    flash_text = "attack on the " + lanes[_lane];
    flash = 40;
    new_report();
};

tick = function() {
    if (flash > 0) flash -= 1;
    if (shot > 0) shot -= 1;
    if (!auto) return;
    timer += 1;
    if (timer >= 40) {
        timer = 0;
        attack(auto_pick());
    }
};

// where each lane runs, from your camp up to their fort
lane_box = function(_lane) {
    var _x = area_w * (0.22 + _lane * 0.28);
    return { l : _x - 60, t : room_height * 0.16, r : _x + 60, b : room_height * 0.6, x : _x };
};

reset = function() {
    gmsa_learn_reset(count);
    gmsa_learn_reset(bayes);
    ct_recent = [];
    by_recent = [];
    total = 0;
    shot = 0;
    shot_lane = 0;
    flash = 0;
    flash_text = "";
    new_report();
};
reset();