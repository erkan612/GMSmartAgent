// day and night, N skips to the other half
day_time += 1 / day_length;
if (day_time >= 1) day_time -= 1;
if (keyboard_check_pressed(ord("N"))) day_time = (day_time + 0.5) mod 1;
is_day = (day_time < 0.5);

if (keyboard_check_pressed(ord("S"))) shuffle();  // new secret rules, mid-race
if (keyboard_check_pressed(ord("H"))) reveal = !reveal;
if (shuffled_flash > 0) shuffled_flash--;

// place or drag the wolf
if (mouse_check_button(mb_left)) {
    wolf.x = mouse_x;
    wolf.y = mouse_y;
}
if (mouse_check_button_pressed(mb_right)) {
    wolf.x = -1000;
    wolf.y = -1000;
}

// foragers decide at the nest, inside the budget
gmsa_scheduler_step(sched);

for (var _i = 0; _i < array_length(foragers); _i++) {
    var _f = foragers[_i];
    var _team = teams[_f.team];

    if (_f.state == 0) {  // at the nest, waiting for a decision
        if (_f.wait > 0) { _f.wait--; continue; }
        var _d = gmsa_agent_consume(_f.agent);
        if (_d == undefined) continue;
        var _option = gmsa_decision_get_chosen(_d);
        if (_option == undefined) continue;
        gmsa_agent_set_current_option(_f.agent, _option);
        _f.ticket = (_team.model != undefined) ? gmsa_learn_remember(_f.agent) : undefined;
        _f.patch = _option.target;
        _f.state = 1;
        gmsa_scheduler_remove(sched, _f.agent);  // no thinking while out on a trip
        continue;
    }

    var _tx = (_f.state == 1) ? _f.patch.x + _f.ox : cx + _f.ox;
    var _ty = (_f.state == 1) ? _f.patch.y + _f.oy : cy + _f.oy;
    var _dist = point_distance(_f.x, _f.y, _tx, _ty);
    if (_dist > 3) {
        var _dir = point_direction(_f.x, _f.y, _tx, _ty);
        _f.x += lengthdir_x(3, _dir);
        _f.y += lengthdir_y(3, _dir);
        continue;
    }

    if (_f.state == 1) {  // arrived at the patch
        if (point_distance(wolf.x, wolf.y, _f.patch.x, _f.patch.y) < wolf.reach) {
            _team.caught++;
            _team.food -= 1;
            _team.second_food -= 1;
            report(_f, -1);
            _f.x = cx;
            _f.y = cy;
            back_home(_f, 60);
        } else {
            _f.haul = is_day ? _f.patch.day_pay : _f.patch.night_pay;
            _f.state = 2;
        }
    } else {              // home with the haul
        _team.food += _f.haul;
        _team.second_food += _f.haul;
        report(_f, _f.haul);
        back_home(_f, 10);
    }
}

// LambdaMART retrains every 25 trips, 2 ms per step
for (var _t = 0; _t < 4; _t++) {
    var _team = teams[_t];
    if (_team.training && gmsa_learn_train(_team.model, 2000)) {
        _team.training = _team.train_again;
        _team.train_again = false;
    }
}

// food per minute, once a second
step_count++;
if (step_count mod 60 == 0) {
    for (var _t = 0; _t < 4; _t++) {
        var _team = teams[_t];
        array_delete(_team.recent, 0, 1);
        array_push(_team.recent, _team.second_food);
        _team.second_food = 0;
        var _sum = 0;
        for (var _s = 0; _s < 60; _s++) _sum += _team.recent[_s];
        _team.rate = _sum;
        array_push(_team.history, _sum);
        if (array_length(_team.history) > 120) array_delete(_team.history, 0, 1);
    }
}

if (keyboard_check_pressed(ord("R"))) {
    for (var _t = 0; _t < 4; _t++) {
        var _team = teams[_t];
        if (_team.model != undefined) gmsa_learn_reset(_team.model);
        _team.food = 0;
        _team.caught = 0;
        _team.outcomes = 0;
        _team.recent = array_create(60, 0);
        _team.history = [];
        _team.training = false;
        _team.train_again = false;
    }
}