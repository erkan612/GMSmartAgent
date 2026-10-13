function test_learn_outcome() {
    gmsa_test_suite("Learn outcome", function() {

        gmsa_test_case("validation", function() {
            gmsa_test_assert_throws(function() { gmsa_learn_linear_create({ learns : 5 }); }, "unknown target");
            gmsa_test_assert_throws(function() { gmsa_learn_linear_create({ temperature : 0 }); }, "temperature 0");

            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent);
            __test_track_act(_agent, 0.9, 0.1);
            var _ticket = gmsa_learn_remember(_agent);
            var _out = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            var _ctx = { agent : _agent, ticket : _ticket, out : _out };

            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_outcome(gmsa_learn_linear_create(), ticket, 1); }), "choice model");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_observe(out, gmsa_observe(agent, ["go_a", "go_b"], 0)); }), "observe on outcome model");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_outcome(out, ticket, "good"); }), "reward not a number");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_outcome(out, {}, 1); }), "not a ticket");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_reward(out, gmsa_agent_create(__test_track_profile(true)), 1); }), "untracked agent");
        });

        gmsa_test_case("a ticket teaches its decision", function() {
            var _m = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            var _agent = __test_outcome_agent();
            gmsa_learn_track(_agent);
            var _rng = gmsa_rng_create(4);
            repeat (40) {
                __test_outcome_act(_agent, 0.5, 0.5, _rng);
                var _t = gmsa_learn_remember(_agent);
                gmsa_learn_outcome(_m, _t, (_t.options[_t.chosen].action.name == "a1") ? 1 : 0);
                gmsa_agent_clear_current(_agent); // each choice is its own episode
            }
            var _a1 = __test_outcome_p(_m, _agent, 0.5, 0.5, "a1");
            gmsa_test_assert_true(_a1 > __test_outcome_p(_m, _agent, 0.5, 0.5, "a0"), "a1 above a0");
            gmsa_test_assert_true(_a1 > __test_outcome_p(_m, _agent, 0.5, 0.5, "a2"), "a1 above a2");
        });

        gmsa_test_case("ambient rewards fade by age", function() {
            var _clock = gmsa_test_clock(0, 0);
            var _m = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent, { clock : _clock.fn, window : 1000 });

            _clock.now = 0;
            __test_track_act(_agent, 0.9, 0.1);  // go_a
            _clock.now = 400;
            __test_track_act(_agent, 0.1, 0.9);  // go_b, go_a ends at 400
            _clock.now = 600;
            gmsa_test_assert_equal(gmsa_learn_reward(_m, _agent, 1), 2, "both credited");
            var _a = _m.data.b[0], _b = _m.data.b[1];
            gmsa_test_assert_true(_a > 0, "ended decision gets some");
            gmsa_test_assert_true(_b > _a, "current decision gets more");

            _clock.now = 1500;
            gmsa_test_assert_equal(gmsa_learn_reward(_m, _agent, 1), 1, "outside the window gets none");
            gmsa_test_assert_equal(_m.data.b[0], _a, "go_a unchanged");
        });

        gmsa_test_case("rare choices count more, up to a limit", function() {
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent);
            __test_track_act(_agent, 0.9, 0.1);
            var _t = gmsa_learn_remember(_agent);
            var _steps = [];
            var _odds = [1, 0.25, 0.01];
            for (var _i = 0; _i < 3; _i++) {
                var _m = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
                _t.probability = _odds[_i];
                gmsa_learn_outcome(_m, _t, 0.01); // tiny reward, so every step stays small
                _steps[_i] = _m.data.b[0];
            }
            gmsa_test_assert_near(_steps[1], _steps[0] * 4, 0.000001, "probability 0.25 counts 4 times");
            gmsa_test_assert_near(_steps[2], _steps[0] * GMSA_LEARN_ODDS_CLIP, 0.000001, "clipped");
        });

        gmsa_test_case("frozen models don't learn outcomes", function() {
            var _m = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            var _agent = gmsa_agent_create(__test_track_profile(true));
            gmsa_learn_track(_agent);
            __test_track_act(_agent, 0.9, 0.1);
            gmsa_learn_freeze(_m);
            gmsa_test_assert_false(gmsa_learn_outcome(_m, gmsa_learn_remember(_agent), 1), "outcome");
            gmsa_test_assert_equal(gmsa_learn_reward(_m, _agent, 1), 0, "reward");
            gmsa_test_assert_equal(array_length(_m.data.b), 0, "nothing learned");
        });

        gmsa_test_case("an agent learns what works", function() {
            // a0 pays 0.6, a1 pays 0.9 when x1 is high and 0.2 when low, a2 pays 0.3
            var _m = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            var _agent = __test_outcome_agent();
            gmsa_learn_track(_agent);
            gmsa_agent_set_model(_agent, _m, 1);
            var _rng = gmsa_rng_create(7);
            var _early = 0, _late = 0;
            for (var _e = 0; _e < 300; _e++) {
                var _x1 = gmsa_rng_next(_rng), _x2 = gmsa_rng_next(_rng);
                __test_outcome_act(_agent, _x1, _x2, _rng);
                var _t = gmsa_learn_remember(_agent);
                var _name = _t.options[_t.chosen].action.name;
                var _pay = (_name == "a0") ? 0.6 : ((_name == "a1") ? ((_x1 > 0.5) ? 0.9 : 0.2) : 0.3);
                gmsa_learn_outcome(_m, _t, _pay + gmsa_rng_next(_rng) * 0.2 - 0.1);
                gmsa_agent_clear_current(_agent);
                if (_e < 50) _early += _pay / 50;
                if (_e >= 200) _late += _pay / 100;
            }
            gmsa_test_assert_true(__test_outcome_p(_m, _agent, 0.75, 0.5, "a1") > __test_outcome_p(_m, _agent, 0.75, 0.5, "a0"), "a1 when x1 is high");
            gmsa_test_assert_true(__test_outcome_p(_m, _agent, 0.25, 0.5, "a0") > __test_outcome_p(_m, _agent, 0.25, 0.5, "a1"), "a0 when x1 is low");
            gmsa_test_assert_true(_late > _early, "earns more after learning");
        });
		
        gmsa_test_case("RankNet learns what works", function() {
            var _m = gmsa_learn_ranknet_create({ learns : gmsa_learn_target.OUTCOMES });
            var _r = __test_outcome_run(_m, 600, 0);
            var _a = _r.agent;
            var _p0h = __test_outcome_p(_m, _a, 0.75, 0.5, "a0"), _p1h = __test_outcome_p(_m, _a, 0.75, 0.5, "a1"), _p2h = __test_outcome_p(_m, _a, 0.75, 0.5, "a2");
            var _p0l = __test_outcome_p(_m, _a, 0.25, 0.5, "a0"), _p1l = __test_outcome_p(_m, _a, 0.25, 0.5, "a1"), _p2l = __test_outcome_p(_m, _a, 0.25, 0.5, "a2");
            gmsa_test_assert_true(ln(_p1h / _p0h) > ln(_p1l / _p0l), "a1 gains more from high x1 than a0");
            gmsa_test_assert_true(_p1h > _p2h, "a1 beats a2 when x1 is high");
            gmsa_test_assert_true(_p0l > _p2l, "a0 beats a2 when x1 is low");
            gmsa_test_assert_true(_r.late > _r.early, "earns more after learning");
        });

        gmsa_test_case("LambdaMART learns what works", function() {
            var _m = gmsa_learn_lambdamart_create({ learns : gmsa_learn_target.OUTCOMES, trees : 30 });
            var _r = __test_outcome_run(_m, 300, 50);
            var _a = _r.agent;
            gmsa_test_assert_true(__test_outcome_p(_m, _a, 0.75, 0.5, "a1") > __test_outcome_p(_m, _a, 0.75, 0.5, "a0"), "a1 when x1 is high");
            gmsa_test_assert_true(__test_outcome_p(_m, _a, 0.25, 0.5, "a0") > __test_outcome_p(_m, _a, 0.25, 0.5, "a1"), "a0 when x1 is low");
            gmsa_test_assert_true(_r.late > _r.early, "earns more after learning");
        });
		
        gmsa_test_case("Count learns what works", function() {
            var _m = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES, bins : 2 }); // the payoff splits x1 at 0.5
            var _r = __test_outcome_run(_m, 300, 0);
            var _a = _r.agent;
            gmsa_test_assert_true(__test_outcome_p(_m, _a, 0.75, 0.5, "a1") > __test_outcome_p(_m, _a, 0.75, 0.5, "a0"), "a1 when x1 is high");
            gmsa_test_assert_true(__test_outcome_p(_m, _a, 0.25, 0.5, "a0") > __test_outcome_p(_m, _a, 0.25, 0.5, "a1"), "a0 when x1 is low");
            gmsa_test_assert_true(_r.late > _r.early, "earns more after learning");

            gmsa_agent_set_input(_a, "x1", 0.75);
            gmsa_agent_set_input(_a, "x2", 0.5);
            var _d = gmsa_agent_evaluate(_a);
            var _lines = gmsa_learn_explain(_m, _d, 0);
            gmsa_test_assert_true(string_pos("averages", _lines[0]) > 0 || string_pos("not tried", _lines[0]) > 0, "explains averages");
        });
		
        gmsa_test_case("saves keep what they learned from", function() {
            var _choice = gmsa_learn_linear_create();
            var _outcome = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            var _ctx = { choice_json : gmsa_learn_save(_choice), outcome_json : gmsa_learn_save(_outcome) };

            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_learn_load(gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES }), choice_json);
            }), "choice save into an outcome model");
            gmsa_test_assert_throws(method(_ctx, function() {
                gmsa_learn_load(gmsa_learn_linear_create(), outcome_json);
            }), "outcome save into a choice model");
            gmsa_test_assert_true(gmsa_learn_load(gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES }), _ctx.outcome_json), "outcome into outcome");

            // a save from before outcome learning has no learns field, it's a choice save
            var _old = json_parse(_ctx.choice_json);
            variable_struct_remove(_old, "learns");
            gmsa_test_assert_true(gmsa_learn_load(gmsa_learn_linear_create(), json_stringify(_old)), "old saves load as choices");
        });

        gmsa_test_case("a failed load leaves the model as it was", function() {
            var _m = gmsa_learn_count_create();
            var _agent = __test_rn_agent(["drink", "loot", "flee"]);
            repeat (10) __test_rn_observe(_m, _agent, 0.2, 0.8, 0);
            var _before = __test_rn_p(_m, _agent, 0.2, 0.8, "drink");
            var _samples = _m.samples;

            var _other = gmsa_learn_count_create({ bins : 2 });
            repeat (5) __test_rn_observe(_other, _agent, 0.9, 0.1, 1);
            var _ctx = { m : _m, json : gmsa_learn_save(_other) };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_learn_load(m, json); }), "bins differ");

            gmsa_test_assert_near(__test_rn_p(_m, _agent, 0.2, 0.8, "drink"), _before, 0.000001, "same predictions");
            gmsa_test_assert_near(_m.samples, _samples, 0.000001, "same amount of data");
        });
		
        gmsa_test_case("a rarely picked option's outcome counts once toward confidence", function() {
            var _makers = [
                function() { return gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES }); },
                function() { return gmsa_learn_ngram_create({ learns : gmsa_learn_target.OUTCOMES }); },
                function() { return gmsa_learn_neighbor_create({ learns : gmsa_learn_target.OUTCOMES }); },
                function() { return gmsa_learn_bayes_create({ learns : gmsa_learn_target.OUTCOMES }); },
                function() { return gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES }); },
            ];
            var _names = ["count", "ngram", "neighbor", "bayes", "linear"];
            for (var _i = 0; _i < array_length(_makers); _i++) {
                var _c = __test_outcome_odds_confidence(_makers[_i]);
                gmsa_test_assert_true(_c[1] > 0, _names[_i] + ": learned something");
                gmsa_test_assert_near(_c[0], _c[1], 0.000001, _names[_i] + ": " + string(_c[0]) + " against " + string(_c[1]));
            }
        });
		
        gmsa_test_case("explain says how many outcomes, not their weight", function() {
            var _makers = [
                function() { return gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES }); },
                function() { return gmsa_learn_ngram_create({ learns : gmsa_learn_target.OUTCOMES }); },
            ];
            for (var _k = 0; _k < array_length(_makers); _k++) {
                var _m = _makers[_k]();
                var _agent = __test_outcome_agent();
                gmsa_learn_track(_agent);
                gmsa_agent_set_input(_agent, "x1", 0.3);
                gmsa_agent_set_input(_agent, "x2", 0.7);
                var _o = gmsa_decision_get_chosen(gmsa_agent_think(_agent, 0, gmsa_rng_create(4)));
                gmsa_agent_set_current_option(_agent, _o);
                var _ticket = gmsa_learn_remember(_agent);
                _ticket.probability = 0.05;   // rarely picked: each outcome weighs 10 for the estimate
                repeat (3) gmsa_learn_outcome(_m, _ticket, 1);
                var _e = gmsa_agent_evaluate(_agent, 0);
                var _i = 0;
                while (_e.options[_i].action != _o.action) _i++;
                var _line = gmsa_learn_explain(_m, _e, _i)[0];
                gmsa_test_assert_true(string_pos("from 3.0 outcomes", _line) > 0, _m.tier_name + ": " + _line);
            }
        });

        gmsa_test_case("a ticket from before a profile swap credits its own action", function() {
            var _first = __test_swap_profile("swap first", ["go", "stay"], [1, 0.5]);
            var _second = __test_swap_profile("swap second", ["stay"], [1]);   // the same names, in another order
            var _m = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
            var _agent = gmsa_agent_create(_first);
            gmsa_learn_track(_agent);
            var _ticket = __test_swap_act(_agent, "go");
            gmsa_agent_set_profile(_agent, _second);
            gmsa_learn_outcome(_m, _ticket, 1);

            var _e = gmsa_agent_evaluate(gmsa_agent_create(_first), 0);
            for (var _i = 0; _i < array_length(_e.options); _i++) {
                var _line = gmsa_learn_explain(_m, _e, _i)[0];
                var _want = (_e.options[_i].action.name == "go") ? "go averages +0.50 from 1.0 outcomes" : "stay not tried yet";
                gmsa_test_assert_true(string_pos(_want, _line) > 0, _line);
            }
        });

        gmsa_test_case("a sequence learner reads earlier steps through their own profile", function() {
            var _makers = [
                function() { return gmsa_learn_ngram_create({ learns : gmsa_learn_target.OUTCOMES, length : 1 }); },
                function() { return gmsa_learn_tdnn_create({ learns : gmsa_learn_target.OUTCOMES, length : 1, replay : 0 }); },
            ];
            var _first = __test_swap_profile("swap many", ["go", "wait", "hide"], [0.2, 0.3, 0.9]);
            var _second = __test_swap_profile("swap one", ["go"], [1]);
            for (var _k = 0; _k < array_length(_makers); _k++) {
                var _m = _makers[_k]();
                var _agent = gmsa_agent_create(_first);
                gmsa_learn_track(_agent, { size : 2 });
                __test_swap_act(_agent, "hide");   // index 2 in the first profile, which the second doesn't have
                gmsa_agent_clear_current(_agent);
                gmsa_agent_set_profile(_agent, _second);
                var _ticket = __test_swap_act(_agent, "go");
                gmsa_test_assert_true(gmsa_learn_outcome(_m, _ticket, 1), _m.tier_name + ": learns after the swap");
                var _p = gmsa_learn_predict(_m, gmsa_agent_evaluate(_agent, 0));
                gmsa_test_assert_equal(array_length(_p.p), 1, _m.tier_name + ": and predicts after it");
            }
        });
    });
}

function __test_outcome_agent() {
    var _p = gmsa_profile_create("outcome test", { select : gmsa_select.TOP_N_WEIGHTED, top_n : 3 });
    gmsa_profile_add_input(_p, gmsa_input_push("x1"));
    gmsa_profile_add_input(_p, gmsa_input_push("x2"));
    gmsa_profile_add_action(_p, "a0");
    gmsa_profile_add_action(_p, "a1");
    gmsa_profile_add_action(_p, "a2");
    gmsa_profile_set_features(_p, ["x1", "x2"]);
    return gmsa_agent_create(gmsa_profile_build(_p));
}

function __test_outcome_act(_agent, _x1, _x2, _rng) {
    gmsa_agent_set_input(_agent, "x1", _x1);
    gmsa_agent_set_input(_agent, "x2", _x2);
    gmsa_agent_set_current_option(_agent, gmsa_decision_get_chosen(gmsa_agent_think(_agent, 1, _rng)));
}

function __test_outcome_p(_model, _agent, _x1, _x2, _action) {
    gmsa_agent_set_input(_agent, "x1", _x1);
    gmsa_agent_set_input(_agent, "x2", _x2);
    var _d = gmsa_agent_evaluate(_agent);
    var _r = gmsa_learn_predict(_model, _d);
    for (var _i = 0; _i < array_length(_d.options); _i++) {
        if (_d.options[_i].action.name == _action) return _r.p[_i];
    }
    return -1;
}

function __test_outcome_run(_model, _episodes, _train_every) {
    var _agent = __test_outcome_agent();
    gmsa_learn_track(_agent);
    gmsa_agent_set_model(_agent, _model, 1);
    var _rng = gmsa_rng_create(7);
    var _early = 0, _late = 0;
    for (var _e = 0; _e < _episodes; _e++) {
        var _x1 = gmsa_rng_next(_rng), _x2 = gmsa_rng_next(_rng);
        __test_outcome_act(_agent, _x1, _x2, _rng);
        var _t = gmsa_learn_remember(_agent);
        var _name = _t.options[_t.chosen].action.name;
        var _pay = (_name == "a0") ? 0.6 : ((_name == "a1") ? ((_x1 > 0.5) ? 0.9 : 0.2) : 0.3);
        gmsa_learn_outcome(_model, _t, _pay + gmsa_rng_next(_rng) * 0.2 - 0.1);
        gmsa_agent_clear_current(_agent);
        if (_train_every > 0 && (_e + 1) mod _train_every == 0) gmsa_learn_train(_model);
        if (_e < 50) _early += _pay / 50;
        if (_e >= _episodes - 100) _late += _pay / 100;
    }
    return { agent : _agent, early : _early, late : _late };
}

function __test_outcome_odds_confidence(_make) { // confidence after one outcome, once from a rarely picked option, once from a sure one
    var _out = [0, 0];
    var _odds = [0.05, 1];
    for (var _i = 0; _i < 2; _i++) {
        var _m = _make();
        var _agent = __test_outcome_agent();
        gmsa_learn_track(_agent);
        gmsa_agent_set_input(_agent, "x1", 0.3);
        gmsa_agent_set_input(_agent, "x2", 0.7);
        var _d = gmsa_agent_think(_agent, 0, gmsa_rng_create(4));
        gmsa_agent_set_current_option(_agent, gmsa_decision_get_chosen(_d));
        var _ticket = gmsa_learn_remember(_agent);
        _ticket.probability = _odds[_i];
        gmsa_learn_outcome(_m, _ticket, 1);
        _out[_i] = gmsa_learn_predict(_m, gmsa_agent_evaluate(_agent, 0)).confidence;
    }
    return _out;
}

function __test_swap_profile(_name, _actions, _weights) { // one push input as the feature, the actions given
    var _p = gmsa_profile_create(_name);
    gmsa_profile_add_input(_p, gmsa_input_push("x"));
    gmsa_profile_set_features(_p, ["x"]);
    for (var _i = 0; _i < array_length(_actions); _i++) gmsa_profile_add_action(_p, _actions[_i], { weight : _weights[_i] });
    return gmsa_profile_build(_p);
}

function __test_swap_act(_agent, _name) { // acts on the option named, from the agent's own decision, and returns its ticket
    var _d = gmsa_agent_think(_agent, 0);
    for (var _i = 0; _i < array_length(_d.options); _i++) {
        if (_d.options[_i].action.name != _name) continue;
        gmsa_agent_set_current_option(_agent, _d.options[_i]);
        return gmsa_learn_remember(_agent);
    }
    return undefined;
}