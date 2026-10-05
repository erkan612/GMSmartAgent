randomize(); // the demo's own randomness, GMSmartAgent never touches it

// the world: a nest, six patches with secret payoffs, a wolf, day and night
cx = room_width * 0.64;
cy = room_height * 0.56;
patches = [];
for (var _i = 0; _i < 6; _i++) {
    var _angle = _i * 60 + 30;
    array_push(patches, {
        index : _i, name : chr(ord("A") + _i),
        x : cx + lengthdir_x(230, _angle), y : cy + lengthdir_y(230, _angle) * 0.85,
        day_pay : 0, night_pay : 0,  // secret: no profile reads these
    });
}
wolf = { x : -1000, y : -1000, reach : 90 };  // off the field until you place it
day_time = 0;       // 0 to 1, the first half is day
day_length = 1800;  // steps per full day and night
is_day = true;
reveal = false;
shuffled_flash = 0;

// new secret rules: every patch pays differently by day and by night, the best patch changes with the time
shuffle = function() {
    var _values = [-0.4, 0.2, 0.5, 0.8, 1.0];
    var _best_day, _best_night;
    do {
        _best_day = 0;
        _best_night = 0;
        for (var _i = 0; _i < 6; _i++) {
            patches[_i].day_pay = _values[irandom(4)];
            patches[_i].night_pay = _values[irandom(4)];
            if (patches[_i].day_pay > patches[_best_day].day_pay) _best_day = _i;
            if (patches[_i].night_pay > patches[_best_night].night_pay) _best_night = _i;
        }
    } until (_best_day != _best_night);
    shuffled_flash = 90;
};
shuffle();

// a profile sees the time, the wolf's distance and which patch it is. Never the payoffs.
make_profile = function(_name, _designer_guess) {
    var _p = gmsa_profile_create(_name, { select : gmsa_select.TOP_N_WEIGHTED, top_n : 6 });
    gmsa_profile_add_input(_p, gmsa_input_pull("daylight", function(_agent, _patch) { return _agent.owner.is_day ? 1 : 0; }));
    gmsa_profile_add_input(_p, gmsa_input_pull("wolf_dist", function(_agent, _patch) {
        var _w = _agent.owner.wolf;
        return point_distance(_w.x, _w.y, _patch.x, _patch.y);
    }, 0, 400, true));
    var _features = ["daylight", "wolf_dist"];
    for (var _k = 0; _k < 6; _k++) {
        var _name_k = "patch_" + string(_k);
        gmsa_profile_add_input(_p, gmsa_input_pull(_name_k, method({ k : _k }, function(_agent, _patch) {
            return (_patch.index == k) ? 1 : 0;
        }), 0, 1, true));
        array_push(_features, _name_k);
    }
    var _a = gmsa_profile_add_action(_p, "forage", { targets : function(_agent) { return _agent.owner.patches; } });
    if (_designer_guess) {
        // all a designer can know here: wolves are dangerous. The payoffs are secret.
        gmsa_action_add_consideration(_a, "wolf_dist", gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.9, b : 0.1 }));
    }
    gmsa_profile_set_features(_p, _features);
    return gmsa_profile_build(_p);
};
guess_profile = make_profile("d8 designer guess", true);
learn_profile = make_profile("d8 learner", false);

sched = gmsa_scheduler_create(2000);  // every forager thinks inside 2 ms per step

// four teams, each learning team shares one model between its 25 foragers
var _o = gmsa_learn_target.OUTCOMES;
var _models = [undefined, gmsa_learn_linear_create({ learns : _o }), gmsa_learn_ranknet_create({ learns : _o }),
               gmsa_learn_lambdamart_create({ learns : _o, trees : 40 })];
var _names = ["Designer's guess", "Linear", "RankNet", "LambdaMART"];
var _colours = [c_gray, c_yellow, c_lime, c_fuchsia];
teams = [];
for (var _t = 0; _t < 4; _t++) {
    array_push(teams, {
        name : _names[_t], colour : _colours[_t], model : _models[_t],
        food : 0, caught : 0, second_food : 0, recent : array_create(60, 0), rate : 0, history : [],
        outcomes : 0, training : false, train_again : false,
    });
}

foragers = [];
for (var _t = 0; _t < 4; _t++) {
    repeat (25) {
        var _agent = gmsa_agent_create((_t == 0) ? guess_profile : learn_profile, id);
        if (teams[_t].model != undefined) {
            gmsa_learn_track(_agent);                          // each trip is a decision with an outcome
            gmsa_agent_set_model(_agent, teams[_t].model, 1);  // the team's shared model
        }
        gmsa_scheduler_add(sched, _agent);
        array_push(foragers, {
            team : _t, agent : _agent, x : cx, y : cy, ox : random_range(-12, 12), oy : random_range(-12, 12),
            state : 0, patch : undefined, haul : 0, ticket : undefined, wait : irandom(60),
        });
    }
}
step_count = 0;

// a trip's result: the patch's secret payoff, or -1 for meeting the wolf
report = function(_f, _reward) {
    var _team = teams[_f.team];
    if (_team.model == undefined) return;
    gmsa_learn_outcome(_team.model, _f.ticket, _reward);
    gmsa_agent_clear_current(_f.agent);  // each trip is its own decision
    _team.outcomes++;
    if (_team.model.tier == gmsa_learn_tier.LAMBDAMART && _team.outcomes mod 25 == 0) {
        if (_team.training) _team.train_again = true;
        else _team.training = true;
    }
};

back_home = function(_f, _wait) {
    _f.state = 0;
    _f.wait = _wait;
    _f.patch = undefined;
    gmsa_scheduler_add(sched, _f.agent); // think again while waiting at the nest
};