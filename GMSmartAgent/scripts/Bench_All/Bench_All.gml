function gmsa_bench_all() {
    show_debug_message("[GMSA Bench] running on " + (code_is_compiled() ? "YYC" : "VM"));
    __gmsa_bench_curves();
    __gmsa_bench_scale_targets([10, 50, 100, 200, 500]);
    __gmsa_bench_scale_considerations([1, 4, 8, 16]);
    __gmsa_bench_scale_actions([5, 20, 50, 100]);
    __gmsa_bench_scale_agents([100, 1000, 5000, 10000], 2000);
    __gmsa_bench_net();
    __gmsa_bench_learn_tiers([3, 10, 30]);
    __gmsa_bench_lambdamart_train([100, 500], 2000);
    __gmsa_bench_outcomes([3, 10]);
    __gmsa_bench_plan([10, 100]);
    __gmsa_bench_plan_slices();
	__gmsa_bench_plan_learn();
	__gmsa_bench_plan_goap();
	__gmsa_bench_learn_sequences();
	__gmsa_bench_learn_bayes_neighbor();
	__gmsa_bench_rating();
	__gmsa_bench_style([200, 1000], 2000);
}

function __gmsa_bench_report(_name, _total_us, _count, _unit) {
    show_debug_message("[GMSA Bench] " + _name + ": " + string_format(_total_us / _count, 1, 3) + " us per " + _unit
        + "  (" + string(_count) + " runs, " + string_format(_total_us / 1000, 1, 1) + " ms total)");
}

function __gmsa_bench_line(_text) {
    show_debug_message("[GMSA Bench] " + _text);
}

function __gmsa_bench_time_thinks(_agent, _n) {
    for (var _i = 0; _i < 20; _i++) gmsa_agent_think(_agent, _i);
    var _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_agent_think(_agent, _i);
    return (get_timer() - _t) / _n;
}

function __gmsa_bench_curves() {
    var _curves = [
        ["linear",   gmsa_curve_make(gmsa_curve.LINEAR)],
        ["power",    gmsa_curve_make(gmsa_curve.POWER)],
        ["logistic", gmsa_curve_make(gmsa_curve.LOGISTIC)],
        ["step",     gmsa_curve_make(gmsa_curve.STEP)],
    ];
    var _n = 100000;
    for (var _c = 0; _c < array_length(_curves); _c++) {
        var _curve = _curves[_c][1];
        var _sum = 0;
        var _t = get_timer();
        for (var _i = 0; _i < _n; _i++) _sum += gmsa_curve_eval(_curve, _i / _n);
        __gmsa_bench_line("curve " + _curves[_c][0] + ": " + string_format((get_timer() - _t) / _n, 1, 3) + " us per eval");
    }
}

function __gmsa_bench_think_simple() {
    var _p = __gmsa_tests_simple_profile(["a", "b", "c"]);
    var _ag = gmsa_agent_create(_p);
    gmsa_agent_set_input(_ag, "a", 0.3);
    gmsa_agent_set_input(_ag, "b", 0.6);
    gmsa_agent_set_input(_ag, "c", 0.9);
    for (var _i = 0; _i < 100; _i++) gmsa_agent_think(_ag, _i); // warm up the pool
    var _n = 10000;
    var _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_agent_think(_ag, _i);
    __gmsa_bench_report("think simple (3 options)", get_timer() - _t, _n, "think");
}

function __gmsa_bench_scale_targets(_sizes) {
    for (var _s = 0; _s < array_length(_sizes); _s++) {
        var _count = _sizes[_s];
        var _ctx = { list : [] };
        for (var _i = 0; _i < _count; _i++) array_push(_ctx.list, { d : (_i + 1) / (_count + 1) });

        var _p = gmsa_profile_create("targets");
        gmsa_profile_add_input(_p, gmsa_input_pull("d", function(_agent, _target) { return _target.d; }, 0, 1, true));
        var _a = gmsa_profile_add_action(_p, "pick", { targets : method(_ctx, function(_agent) { return list; }) });
        gmsa_action_add_consideration(_a, "d", gmsa_curve_make(gmsa_curve.LINEAR));
        var _ag = gmsa_agent_create(gmsa_profile_build(_p));

        var _us = __gmsa_bench_time_thinks(_ag, max(50, ceil(20000 / _count)));
        __gmsa_bench_line("targets " + string(_count) + ": " + string_format(_us, 1, 1) + " us per think, "
            + string_format(_us / _count, 1, 2) + " us per option");
    }
}

function __gmsa_bench_scale_considerations(_sizes) {
    for (var _s = 0; _s < array_length(_sizes); _s++) {
        var _count = _sizes[_s];
        var _p = gmsa_profile_create("considerations");
        var _a = gmsa_profile_add_action(_p, "act");
        for (var _i = 0; _i < _count; _i++) {
            var _name = "in" + string(_i);
            gmsa_profile_add_input(_p, gmsa_input_push(_name, 0, 1, 0.9));
            gmsa_action_add_consideration(_a, _name, gmsa_curve_make(gmsa_curve.LINEAR));
        }
        var _ag = gmsa_agent_create(gmsa_profile_build(_p));
        var _us = __gmsa_bench_time_thinks(_ag, 5000);
        __gmsa_bench_line("considerations " + string(_count) + ": " + string_format(_us, 1, 1) + " us per think, "
            + string_format(_us / _count, 1, 2) + " us per consideration");
    }
}

function __gmsa_bench_scale_actions(_sizes) {
    for (var _s = 0; _s < array_length(_sizes); _s++) {
        var _count = _sizes[_s];
        var _p = gmsa_profile_create("actions");
        for (var _i = 0; _i < _count; _i++) {
            var _name = "a" + string(_i);
            gmsa_profile_add_input(_p, gmsa_input_push(_name, 0, 1, (_i + 1) / (_count + 1)));
            var _a = gmsa_profile_add_action(_p, _name);
            gmsa_action_add_consideration(_a, _name, gmsa_curve_make(gmsa_curve.LINEAR));
        }
        var _ag = gmsa_agent_create(gmsa_profile_build(_p));
        var _us = __gmsa_bench_time_thinks(_ag, max(200, ceil(20000 / _count)));
        __gmsa_bench_line("actions " + string(_count) + ": " + string_format(_us, 1, 1) + " us per think, "
            + string_format(_us / _count, 1, 2) + " us per option");
    }
}

function __gmsa_bench_scale_agents(_sizes, _budget) {
    var _p = __gmsa_tests_simple_profile(["a", "b", "c"]);
    for (var _s = 0; _s < array_length(_sizes); _s++) {
        var _count = _sizes[_s];
        var _sched = gmsa_scheduler_create(_budget);
        var _t = get_timer();
        for (var _i = 0; _i < _count; _i++) {
            var _ag = gmsa_agent_create(_p);
            gmsa_agent_set_input(_ag, "a", 0.5);
            gmsa_scheduler_add(_sched, _ag);
        }
        var _create_ms = (get_timer() - _t) / 1000;

        // cold lap
        var _cold_thinks = 0, _cold_steps = 0, _cold_worst = 0;
        while (_cold_thinks < _count) {
            _cold_thinks += gmsa_scheduler_step(_sched);
            _cold_steps++;
            _cold_worst = max(_cold_worst, _sched.stats.time);
        }

        // warm steps
        var _steps = 60, _thinks = 0, _worst = 0;
        for (var _i = 0; _i < _steps; _i++) {
            _thinks += gmsa_scheduler_step(_sched);
            _worst = max(_worst, _sched.stats.time);
        }
        var _per_step = _thinks / _steps;

        __gmsa_bench_line("agents " + string(_count) + ", budget " + string(_budget) + " us:");
        __gmsa_bench_line("   create " + string_format(_create_ms, 1, 1) + " ms");
        __gmsa_bench_line("   cold lap " + string(_cold_steps) + " steps, worst step " + string(_cold_worst)
            + " us (overshoot " + string(max(0, _cold_worst - _budget)) + " us)");
        __gmsa_bench_line("   warm " + string_format(_per_step, 1, 1) + " thinks per step, each agent re-thinks every "
            + string_format(_count / _per_step, 1, 1) + " steps, worst step " + string(_worst)
            + " us (overshoot " + string(max(0, _worst - _budget)) + " us)");
    }
}

function __gmsa_bench_think_targets() {
    var _ctx = { list : [] };
    for (var _i = 0; _i < 10; _i++) array_push(_ctx.list, { d : _i / 10 });
    var _targets = method(_ctx, function(_agent) { return list; });

    var _p = gmsa_profile_create("bench", { select : gmsa_select.TOP_N_WEIGHTED, top_n : 3, commitment : 0.1 });
    gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _target) { return _target.d; }, 0, 1, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("hp", function(_agent, _target) { return _agent.owner.hp; }, 0, 100));
    gmsa_profile_add_input(_p, gmsa_input_push("flag"));
    var _near = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });
    var _a;
    _a = gmsa_profile_add_action(_p, "attack", { targets : _targets });
    gmsa_action_add_consideration(_a, "dist", _near);
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LOGISTIC));
    _a = gmsa_profile_add_action(_p, "chase", { targets : _targets });
    gmsa_action_add_consideration(_a, "dist", gmsa_curve_make(gmsa_curve.POWER));
    _a = gmsa_profile_add_action(_p, "heal");
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR, { invert : true }));
    _a = gmsa_profile_add_action(_p, "flee");
    gmsa_action_add_consideration(_a, "hp", gmsa_curve_make(gmsa_curve.LINEAR, { invert : true }));
    gmsa_action_add_consideration(_a, "flag", gmsa_curve_make(gmsa_curve.STEP));
    gmsa_profile_add_action(_p, "idle", { weight : 0.05 });
    gmsa_profile_build(_p);

    var _ag = gmsa_agent_create(_p, { hp : 60 });
    gmsa_agent_set_input(_ag, "flag", 1);
    _ag.rng = gmsa_rng_create(3);
    for (var _i = 0; _i < 100; _i++) gmsa_agent_think(_ag, _i);
    var _n = 5000;
    var _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_agent_think(_ag, _i);
    __gmsa_bench_report("think targeted (" + string(array_length(_ag.decision.options)) + " options)", get_timer() - _t, _n, "think");
}

function __gmsa_bench_scheduler() {
    var _p = __gmsa_tests_simple_profile(["a", "b", "c"]);
    var _s = gmsa_scheduler_create(2000);
    for (var _i = 0; _i < 1000; _i++) {
        var _ag = gmsa_agent_create(_p);
        gmsa_agent_set_input(_ag, "a", 0.5);
        gmsa_scheduler_add(_s, _ag);
    }
    var _warm = 0;
    while (_warm < 1000) _warm += gmsa_scheduler_step(_s); // every agent has thought once

    var _steps = 60, _thinks = 0, _worst = 0;
    for (var _i = 0; _i < _steps; _i++) {
        _thinks += gmsa_scheduler_step(_s);
        _worst = max(_worst, _s.stats.time);
    }
    show_debug_message("[GMSA Bench] scheduler 2 ms budget, 1000 agents: " + string_format(_thinks / _steps, 1, 1)
        + " thinks per step, worst step " + string(_worst) + " us (overshoot " + string(max(0, _worst - 2000)) + " us)");
}

function __gmsa_bench_net() {
    var _configs = [
        ["6 in, [8, 1]",      6, [8, 1]],
        ["12 in, [16, 1]",    12, [16, 1]],
        ["12 in, [16, 8, 1]", 12, [16, 8, 1]],
    ];
    for (var _c = 0; _c < array_length(_configs); _c++) {
        var _inputs = _configs[_c][1];
        var _net = gmsa_net_create(_inputs, _configs[_c][2], { optimizer : gmsa_net_optimizer.ADAM });
        var _x = array_create(_inputs, 0);
        for (var _i = 0; _i < _inputs; _i++) _x[_i] = (_i + 1) / (_inputs + 1);

        var _n = 5000;
        var _t = get_timer();
        for (var _i = 0; _i < _n; _i++) gmsa_net_forward(_net, _x);
        var _forward = (get_timer() - _t) / _n;

        _t = get_timer();
        for (var _i = 0; _i < _n; _i++) gmsa_net_train(_net, _x, 0.5);
        var _train = (get_timer() - _t) / _n;

        __gmsa_bench_line("net " + _configs[_c][0] + ": forward " + string_format(_forward, 1, 1)
            + " us, train step " + string_format(_train, 1, 1) + " us");
    }
}

function __gmsa_bench_learn_agent(_actions) {
    var _p = gmsa_profile_create("bench learn");
    gmsa_profile_add_input(_p, gmsa_input_push("hp"));
    gmsa_profile_add_input(_p, gmsa_input_push("danger"));
    gmsa_profile_add_input(_p, gmsa_input_push("gold"));
    for (var _i = 0; _i < _actions; _i++) gmsa_profile_add_action(_p, "a" + string(_i));
    gmsa_profile_set_features(_p, ["hp", "danger", "gold"]);
    return gmsa_agent_create(gmsa_profile_build(_p));
}

function __gmsa_bench_learn_feed(_agent, _rng) {
    gmsa_agent_set_input(_agent, "hp", gmsa_rng_next(_rng));
    gmsa_agent_set_input(_agent, "danger", gmsa_rng_next(_rng));
    gmsa_agent_set_input(_agent, "gold", gmsa_rng_next(_rng));
}

function __gmsa_bench_learn_tiers(_option_counts) {
    var _tiers = ["count", "linear", "ranknet", "lambdamart"];
    for (var _o = 0; _o < array_length(_option_counts); _o++) {
        var _count = _option_counts[_o];
        var _names = array_create(_count, "");
        for (var _i = 0; _i < _count; _i++) _names[_i] = "a" + string(_i);

        // baseline think without a model
        var _plain = __gmsa_bench_learn_agent(_count);
        var _base = __gmsa_bench_time_thinks(_plain, 1000);

        for (var _t = 0; _t < array_length(_tiers); _t++) {
            var _model;
            switch (_tiers[_t]) {
                case "count":      _model = gmsa_learn_count_create(); break;
                case "linear":     _model = gmsa_learn_linear_create(); break;
                case "ranknet":    _model = gmsa_learn_ranknet_create(); break;
                case "lambdamart": _model = gmsa_learn_lambdamart_create(); break;
            }
            var _agent = __gmsa_bench_learn_agent(_count);
            var _rng = gmsa_rng_create(7);

            // observe, timed per call so feeding inputs and recording the choice stay outside
            var _n = 200;
            var _observe = 0;
            for (var _i = 0; _i < _n; _i++) {
                __gmsa_bench_learn_feed(_agent, _rng);
                var _d = gmsa_observe(_agent, _names, floor(gmsa_rng_next(_rng) * _count));
                var _t0 = get_timer();
                gmsa_learn_observe(_model, _d);
                _observe += get_timer() - _t0;
            }
            _observe /= _n;

            var _train_ms = 0;
            if (_tiers[_t] == "lambdamart") {
                var _t0 = get_timer();
                gmsa_learn_train(_model);
                _train_ms = (get_timer() - _t0) / 1000;
            }

            // predict
            __gmsa_bench_learn_feed(_agent, _rng);
            var _eval = gmsa_agent_evaluate(_agent);
            var _np = 1000;
            var _t0 = get_timer();
            for (var _i = 0; _i < _np; _i++) gmsa_learn_predict(_model, _eval);
            var _predict = (get_timer() - _t0) / _np;

            // re-ranked think
            var _ranked = __gmsa_bench_learn_agent(_count);
            gmsa_agent_set_model(_ranked, _model, 1);
            var _think = __gmsa_bench_time_thinks(_ranked, 1000);

            var _line = "learn " + _tiers[_t] + ", " + string(_count) + " options: observe " + string_format(_observe, 1, 1)
                + " us, predict " + string_format(_predict, 1, 1) + " us, re-ranked think +"
                + string_format(_think - _base, 1, 1) + " us (base " + string_format(_base, 1, 1) + " us)";
            if (_train_ms > 0) _line += ", train " + string_format(_train_ms, 1, 1) + " ms";
            __gmsa_bench_line(_line);
        }
    }
}

function __gmsa_bench_lambdamart_train(_sizes, _budget) {
    var _actions = 5;
    var _names = array_create(_actions, "");
    for (var _i = 0; _i < _actions; _i++) _names[_i] = "a" + string(_i);

    for (var _s = 0; _s < array_length(_sizes); _s++) {
        var _size = _sizes[_s];
        var _model = gmsa_learn_lambdamart_create({ buffer : _size });
        var _agent = __gmsa_bench_learn_agent(_actions);
        var _rng = gmsa_rng_create(11);
        repeat (_size) {
            __gmsa_bench_learn_feed(_agent, _rng);
            // a learnable habit: a0 when hurt, otherwise random
            var _chosen = (gmsa_rng_next(_rng) < 0.5) ? 0 : floor(gmsa_rng_next(_rng) * _actions);
            gmsa_learn_observe(_model, gmsa_observe(_agent, _names, _chosen));
        }

        var _t = get_timer();
        gmsa_learn_train(_model);
        var _full_ms = (get_timer() - _t) / 1000;

        var _calls = 0, _worst = 0, _done = false;
        while (!_done) {
            var _t0 = get_timer();
            _done = gmsa_learn_train(_model, _budget);
            _worst = max(_worst, get_timer() - _t0);
            _calls += 1;
        }

        __gmsa_bench_line("lambdamart train, " + string(_size) + " choices (" + string(_size * _actions) + " rows), 100 trees:");
        __gmsa_bench_line("   unbudgeted " + string_format(_full_ms, 1, 1) + " ms");
        __gmsa_bench_line("   budget " + string(_budget) + " us: " + string(_calls) + " calls, worst call " + string(_worst)
            + " us (overshoot " + string(max(0, _worst - _budget)) + " us)");
    }
}

function __gmsa_bench_outcomes(_option_counts) {
    var _tiers = ["count", "linear", "ranknet", "lambdamart"];
    for (var _o = 0; _o < array_length(_option_counts); _o++) {
        var _count = _option_counts[_o];

        var _plain = __gmsa_bench_learn_agent(_count);
        var _tracked = __gmsa_bench_learn_agent(_count);
        gmsa_learn_track(_tracked);
        var _rng = gmsa_rng_create(3);
        __gmsa_bench_learn_feed(_plain, _rng);
        __gmsa_bench_learn_feed(_tracked, _rng);
        var _dp = gmsa_agent_think(_plain, 1);
        var _dt = gmsa_agent_think(_tracked, 1);
        var _n = 2000;
        var _t = get_timer();
        for (var _i = 0; _i < _n; _i++) gmsa_agent_set_current_option(_plain, _dp.options[_i mod 2]);
        var _base = (get_timer() - _t) / _n;
        _t = get_timer();
        for (var _i = 0; _i < _n; _i++) gmsa_agent_set_current_option(_tracked, _dt.options[_i mod 2]);
        var _switch = (get_timer() - _t) / _n - _base;
        __gmsa_bench_line("track, " + string(_count) + " options: a switch adds " + string_format(_switch, 1, 1)
            + " us (untracked " + string_format(_base, 1, 1) + " us)");

        for (var _m = 0; _m < array_length(_tiers); _m++) {
            var _model;
            switch (_tiers[_m]) {
                case "count":      _model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES }); break;
                case "linear":     _model = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES }); break;
                case "ranknet":    _model = gmsa_learn_ranknet_create({ learns : gmsa_learn_target.OUTCOMES }); break;
                case "lambdamart": _model = gmsa_learn_lambdamart_create({ learns : gmsa_learn_target.OUTCOMES }); break;
            }
            var _ticket = gmsa_learn_remember(_tracked);

            var _no = 300;
            _t = get_timer();
            for (var _i = 0; _i < _no; _i++) gmsa_learn_outcome(_model, _ticket, 0.5);
            var _outcome = (get_timer() - _t) / _no;

            var _nr = 100, _credited = 0;
            _t = get_timer();
            for (var _i = 0; _i < _nr; _i++) _credited = gmsa_learn_reward(_model, _tracked, 0.5);
            var _reward = (get_timer() - _t) / _nr;

            var _line = "outcome " + _tiers[_m] + ", " + string(_count) + " options: outcome " + string_format(_outcome, 1, 1)
                + " us, reward over " + string(_credited) + " decisions " + string_format(_reward, 1, 1) + " us";
            if (_tiers[_m] == "lambdamart") {
                _t = get_timer();
                gmsa_learn_train(_model);
                _line += ", train " + string_format((get_timer() - _t) / 1000, 1, 1) + " ms ("
                    + string(array_length(_model.data.buffer)) + " outcomes)";
            }
            __gmsa_bench_line(_line);
        }
    }
}

function __gmsa_bench_plan(_lengths) {
    // grab every coin, one step per coin
    var _d = gmsa_plan_domain_create("bench coins");
    gmsa_plan_add_fact(_d, "coins", function(_o) { return _o.coins; });
    gmsa_plan_add_step(_d, "grab", { requires : [["coins", ">", 0]], effects : [["coins", "-", 1]] });
    gmsa_plan_add_step(_d, "stop");
    var _task = gmsa_plan_add_task(_d, "grab_all");
    gmsa_plan_add_method(_task, "more", { requires : [["coins", ">", 0]], subtasks : ["grab", "grab_all"] });
    gmsa_plan_add_method(_task, "done", { subtasks : ["stop"] });
    gmsa_plan_domain_build(_d);

    for (var _l = 0; _l < array_length(_lengths); _l++) {
        var _len = _lengths[_l];
        var _owner = { coins : _len };
        var _p = gmsa_plan_planner_create(_d, _owner, { depth : _len + 8, budget : 100000 });
        var _n = 100;
        var _t = get_timer();
        for (var _i = 0; _i < _n; _i++) gmsa_plan_make(_p, "grab_all");
        var _make = (get_timer() - _t) / _n;
        var _nodes = gmsa_plan_nodes_used(_p);

        // running it: the game takes a coin, then reports the step done
        var _steps = 0;
        var _time = 0;
        repeat (20) {
            _owner.coins = _len;
            gmsa_plan_make(_p, "grab_all");
            _t = get_timer();
            while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING) {
                if (gmsa_plan_current(_p) == "grab") _owner.coins -= 1;
                gmsa_plan_step_done(_p);
                _steps++;
            }
            _time += get_timer() - _t;
        }
        __gmsa_bench_line("plan, " + string(_len + 1) + " steps: make " + string_format(_make, 1, 1) + " us ("
            + string(_nodes) + " nodes, " + string_format(_make / _nodes, 1, 2) + " us each), step_done "
            + string_format(_time / _steps, 1, 1) + " us");
    }

    // backtracking: the right method is the last of 20, every wrong one fails at its last step
    var _bd = gmsa_plan_domain_create("bench backtrack");
    gmsa_plan_add_fact(_bd, "x", function(_o) { return 0; });
    gmsa_plan_add_step(_bd, "work", { effects : [["x", "+", 1]] });
    gmsa_plan_add_step(_bd, "fail", { requires : [["x", "<", 0]] });
    gmsa_plan_add_step(_bd, "finish");
    var _choose = gmsa_plan_add_task(_bd, "choose");
    for (var _m = 0; _m < 19; _m++) gmsa_plan_add_method(_choose, "wrong_" + string(_m), { subtasks : ["work", "work", "work", "fail"] });
    gmsa_plan_add_method(_choose, "right", { subtasks : ["work", "finish"] });
    gmsa_plan_domain_build(_bd);
    var _bp = gmsa_plan_planner_create(_bd, {});
    var _n = 200;
    var _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_plan_make(_bp, "choose");
    __gmsa_bench_line("plan, backtracking through 19 wrong methods: make " + string_format((get_timer() - _t) / _n, 1, 1)
        + " us (" + string(gmsa_plan_nodes_used(_bp)) + " nodes)");

    // repairing: the door gets locked mid-plan and the get_in task is replanned
    var _owner = { door_locked : false, has_pick : true };
    var _rp = gmsa_plan_planner_create(__test_plan_door_domain(), _owner);
    var _repair = 0;
    repeat (_n) {
        _owner.door_locked = false;
        gmsa_plan_make(_rp, "heist");
        _owner.door_locked = true;
        _t = get_timer();
        gmsa_plan_refresh(_rp);
        _repair += get_timer() - _t;
    }
    _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_plan_refresh(_rp); // nothing broken now
    var _fine = (get_timer() - _t) / _n;
    _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_plan_explain(_rp);
    var _explain = (get_timer() - _t) / _n;
    __gmsa_bench_line("plan, refresh: repairing a broken task " + string_format(_repair / _n, 1, 1)
        + " us, nothing broken " + string_format(_fine, 1, 1) + " us, explain " + string_format(_explain, 1, 1) + " us");
}

function __gmsa_bench_plan_slices() {
    // scheduled planners with nothing to plan: what each scheduler step costs
    var _counts = [12, 100];
    var _coins = __test_plan_slice_coins();
    for (var _c = 0; _c < array_length(_counts); _c++) {
        var _s = gmsa_scheduler_create(2000);
        repeat (_counts[_c]) gmsa_plan_schedule(gmsa_plan_planner_create(_coins, { coins : 3 }), _s);
        var _n = 1000;
        var _t = get_timer();
        repeat (_n) gmsa_scheduler_step(_s);
        __gmsa_bench_line("plan, " + string(_counts[_c]) + " idle scheduled planners: "
            + string_format((get_timer() - _t) / _n, 1, 1) + " us per scheduler step");
    }

    // the same 101 step plan in one call, and in 200 us slices
    var _n = 50;
    var _whole = gmsa_plan_planner_create(_coins, { coins : 100 }, { depth : 128 });
    var _t = get_timer();
    repeat (_n) gmsa_plan_make(_whole, "grab_all");
    var _one = (get_timer() - _t) / _n;
    var _sliced = gmsa_plan_planner_create(_coins, { coins : 100 }, { depth : 128, slice : 200 });
    var _calls = 0;
    var _worst = 0;
    _t = get_timer();
    repeat (_n) {
        var _t1 = get_timer();
        gmsa_plan_make(_sliced, "grab_all");
        _worst = max(_worst, get_timer() - _t1);
        _calls++;
        while (gmsa_plan_get_status(_sliced) == gmsa_plan_status.PLANNING) {
            _t1 = get_timer();
            gmsa_plan_work(_sliced);
            _worst = max(_worst, get_timer() - _t1);
            _calls++;
        }
    }
    __gmsa_bench_line("plan, 101 steps: one call " + string_format(_one, 1, 1) + " us, in 200 us slices "
        + string_format((get_timer() - _t) / _n, 1, 1) + " us over " + string_format(_calls / _n, 1, 1)
        + " calls, worst call " + string(round(_worst)) + " us");

    // twelve planners asking at once, each plan about 100 nodes, on one scheduler
    var _vault = __test_plan_vault(true);
    var _budgets = [100, 200, 500, 1000, 2000];
    for (var _b = 0; _b < array_length(_budgets); _b++) {
        var _budget = _budgets[_b];
        var _s = gmsa_scheduler_create(_budget);
        var _planners = [];
        repeat (12) {
            var _p = gmsa_plan_planner_create(_vault, { ready : true });
            gmsa_plan_schedule(_p, _s);
            gmsa_plan_make(_p, "heist");
            array_push(_planners, _p);
        }
        var _steps = 0;
        var _worst_step = 0;
        var _busy = true;
        while (_busy && _steps < 100000) {
            gmsa_scheduler_step(_s);
            _worst_step = max(_worst_step, _s.stats.time);
            _steps++;
            _busy = false;
            for (var _i = 0; _i < 12; _i++) {
                if (gmsa_plan_get_status(_planners[_i]) == gmsa_plan_status.PLANNING) {
                    _busy = true;
                    break;
                }
            }
        }
        __gmsa_bench_line("plan, 12 planners at once, budget " + string(_budget) + " us: ready after " + string(_steps)
            + " steps, worst step " + string(round(_worst_step)) + " us (over by " + string(round(max(0, _worst_step - _budget))) + " us)");
    }
}

function __gmsa_bench_plan_learn(_runs = 1000) {
    show_debug_message("Plan learn benchmarks, " + string(_runs) + " runs each, average per call");
    var _names = ["designer", "step reliability", "learned methods", "both"];
    for (var _k = 0; _k < 4; _k++) {
        var _b = __gmsa_bench_plan_learn_domain(_k == 1 || _k == 3, _k == 2 || _k == 3);
        var _o = { night : false, vault : 0, inside : false, has_loot : false };
        var _p = gmsa_plan_planner_create(_b.domain, _o);
        for (var _i = 0; _i < 20; _i++) __gmsa_bench_plan_learn_episode(_p, _o, _i mod 2 == 0);  // warm up

        var _make = 0;
        for (var _i = 0; _i < _runs; _i++) {
            _o.night = (_i mod 2 == 0);
            _o.vault = _i mod 3;
            _o.inside = false;
            _o.has_loot = false;
            var _t = get_timer();
            gmsa_plan_make(_p, "raid");
            _make += get_timer() - _t;
            gmsa_plan_stop(_p);
        }
        var _clean = 0;
        var _failing = 0;
        for (var _i = 0; _i < _runs; _i++) {
            _o.night = (_i mod 2 == 0);
            _o.vault = _i mod 3;
            _clean += __gmsa_bench_plan_learn_episode(_p, _o, false);
            _failing += __gmsa_bench_plan_learn_episode(_p, _o, true);
        }
        show_debug_message(_names[_k] + ": make " + string_format(_make / _runs, 1, 1)
            + " us, raid " + string_format(_clean / _runs, 1, 1)
            + " us, raid with a failed entrance " + string_format(_failing / _runs, 1, 1) + " us");
    }
    __gmsa_bench_plan_learn_facts(_runs);
}

function __gmsa_bench_plan_learn_domain(_reliable, _learned) {
    var _d = gmsa_plan_domain_create("bench plan learn");
    gmsa_plan_add_fact(_d, "night", function(_o) { return _o.night; });
    gmsa_plan_add_fact(_d, "vault", function(_o) { return _o.vault; }, { min : 0, max : 2 });
    gmsa_plan_add_fact(_d, "inside", function(_o) { return _o.inside; });
    gmsa_plan_add_fact(_d, "has_loot", function(_o) { return _o.has_loot; });
    gmsa_plan_add_step(_d, "approach", { requires : [["inside", false]] });
    gmsa_plan_add_step(_d, "enter_door", { requires : [["inside", false]], effects : [["inside", true]] });
    gmsa_plan_add_step(_d, "enter_window", { requires : [["inside", false]], effects : [["inside", true]] });
    gmsa_plan_add_step(_d, "dig_tunnel", { requires : [["inside", false]], effects : [["inside", true]] });
    gmsa_plan_add_step(_d, "take_loot", { requires : [["inside", true]], effects : [["has_loot", true]] });
    gmsa_plan_add_step(_d, "escape", { requires : [["has_loot", true]], effects : [["inside", false]] });
    var _get_in = gmsa_plan_add_task(_d, "get_in");
    gmsa_plan_add_method(_get_in, "door", { subtasks : ["enter_door"] });
    gmsa_plan_add_method(_get_in, "window", { subtasks : ["enter_window"] });
    gmsa_plan_add_method(_get_in, "tunnel", { subtasks : ["dig_tunnel"] });
    var _raid = gmsa_plan_add_task(_d, "raid");
    gmsa_plan_add_method(_raid, "only", { subtasks : ["approach", "get_in", "take_loot", "escape"] });
    var _out = { domain : _d, reliability : undefined, model : undefined };
    if (_reliable) _out.reliability = gmsa_plan_learn_steps(_d, { inputs : ["night", "vault"] });
    if (_learned) {
        _out.model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
        gmsa_plan_learn_methods(_get_in, _out.model, { inputs : ["night", "vault"] });
    }
    gmsa_plan_domain_build(_d);
    return _out;
}

function __gmsa_bench_plan_learn_episode(_p, _o, _fail_first) {
    _o.inside = false;
    _o.has_loot = false;
    var _t = get_timer();
    gmsa_plan_make(_p, "raid");
    var _failed = !_fail_first;
    var _guard = 0;
    while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING && _guard++ < 50) {
        var _step = gmsa_plan_current(_p);
        var _entrance = (_step == "enter_door" || _step == "enter_window" || _step == "dig_tunnel");
        if (_entrance && !_failed) {
            _failed = true;
            gmsa_plan_step_failed(_p);
            continue;
        }
        if (_entrance) _o.inside = true;
        if (_step == "take_loot") _o.has_loot = true;
        if (_step == "escape") _o.inside = false;
        gmsa_plan_step_done(_p);
    }
    if (gmsa_plan_get_status(_p) == gmsa_plan_status.DONE) gmsa_plan_reward(_p, 1);
    return get_timer() - _t;
}

function __gmsa_bench_plan_learn_facts(_runs) {
    var _gp = gmsa_profile_create("bench guard");
    gmsa_profile_add_input(_gp, gmsa_input_pull("at", function(_agent) { return _agent.owner.post; }, 0, 2));
    gmsa_profile_add_input(_gp, gmsa_input_pull("raided", function(_agent) { return _agent.owner.raid; }, 0, 2));
    gmsa_profile_set_features(_gp, ["at", "raided"]);
    for (var _k = 1; _k <= 3; _k++) gmsa_profile_add_action(_gp, "guard_" + string(_k));
    gmsa_profile_build(_gp);
    var _guard = { post : 0, raid : 0 };
    var _agent = gmsa_agent_create(_gp, _guard);
    var _model = gmsa_learn_linear_create();
    var _options = ["guard_1", "guard_2", "guard_3"];
    for (var _i = 0; _i < 60; _i++) {
        _guard.post = _i mod 3;
        gmsa_learn_observe(_model, gmsa_observe(_agent, _options, (_i + 1) mod 3));
    }

    // a clock the bench moves by hand: moved, the cache is stale, held, it is fresh
    global.__gmsa_bench_now = 0;
    var _clock = function() { return global.__gmsa_bench_now; };
    var _read = gmsa_learn_input(_model, _agent, "guard_2", { refresh : 1, clock : _clock });
    var _first = 0;
    var _cached = 0;
    for (var _i = 0; _i < _runs; _i++) {
        global.__gmsa_bench_now += 10;
        var _t = get_timer();
        _read(undefined, undefined);
        _first += get_timer() - _t;
        _t = get_timer();
        _read(undefined, undefined);
        _cached += get_timer() - _t;
    }
    show_debug_message("player fact read: first in a frame " + string_format(_first / _runs, 1, 1)
        + " us, cached " + string_format(_cached / _runs, 1, 1) + " us");

    // three vaults, each method needs its vault's prediction below 0.4, plain facts against learned ones
    var _names = ["plain facts", "player facts, first in a frame", "player facts, cached"];
    for (var _v = 0; _v < 3; _v++) {
        var _d = gmsa_plan_domain_create("bench player facts");
        var _raid = gmsa_plan_add_task(_d, "raid");
        for (var _k = 1; _k <= 3; _k++) {
            var _n = string(_k);
            if (_v == 0) gmsa_plan_add_fact(_d, "next_" + _n, function(_o) { return 0.2; }, { min : 0, max : 1 });
            else gmsa_plan_learn_fact(_d, "next_" + _n, _model, _agent, "guard_" + _n, { refresh : 1, clock : _clock });
            gmsa_plan_add_step(_d, "go_" + _n, { requires : [["next_" + _n, "<", 0.4]] });
            gmsa_plan_add_method(_raid, "vault_" + _n, { subtasks : ["go_" + _n] });
        }
        gmsa_plan_domain_build(_d);
        var _p = gmsa_plan_planner_create(_d, {});
        var _make = 0;
        for (var _i = 0; _i < _runs; _i++) {
            if (_v == 1) global.__gmsa_bench_now += 10;
            var _t = get_timer();
            gmsa_plan_make(_p, "raid");
            _make += get_timer() - _t;
            gmsa_plan_stop(_p);
        }
        show_debug_message("make, " + _names[_v] + ": " + string_format(_make / _runs, 1, 1) + " us");
    }
}

function __gmsa_bench_plan_goap(_runs = 20) {
    var _p = gmsa_plan_planner_create(__test_plan_camp_live(), __test_plan_camper());
    var _t = __gmsa_bench_goap_make(_p, "warm", _runs);
    show_debug_message("[GMSA Bench] goap, the camp (5 actions): " + string_format(_t, 1, 1) + " us, " + string(gmsa_plan_nodes_used(_p)) + " nodes");

    // a chain to the goal, with distractions: pruned they disappear, unpruned the search wades through them
    var _sizes = [[4, 2], [8, 4], [10, 6]];
    var _modes = ["pruned", "no pruning", "no pruning, cost functions", "no pruning, variety 0.3"];
    for (var _s = 0; _s < array_length(_sizes); _s++) {
        var _chain = _sizes[_s][0];
        var _noise = _sizes[_s][1];
        for (var _m = 0; _m < 4; _m++) {
            var _q = gmsa_plan_planner_create(__gmsa_bench_goap_domain(_chain, _noise, _m), {}, { budget : 20000 });
            var _tm = __gmsa_bench_goap_make(_q, "done", _runs);
            var _nodes = gmsa_plan_nodes_used(_q);
            show_debug_message("[GMSA Bench] goap, chain " + string(_chain + 1) + " with " + string(_noise) + " distractions ("
                + string(_chain + 1 + _noise) + " actions), " + _modes[_m] + ": " + string_format(_tm, 1, 1) + " us, "
                + string(_nodes) + " nodes, " + string_format(_tm / max(1, _nodes), 1, 2) + " us per node");
        }
    }

    // the biggest, unpruned, in 1 ms slices
    var _ps = gmsa_plan_planner_create(__gmsa_bench_goap_domain(10, 6, 1), {}, { budget : 20000, slice : 1000 });
    var _t0 = get_timer();
    gmsa_plan_make(_ps, "done");
    var _dt = get_timer() - _t0;
    var _calls = 1;
    var _total = _dt;
    var _worst = _dt;
    while (gmsa_plan_get_status(_ps) == gmsa_plan_status.PLANNING && _calls < 10000) {
        _t0 = get_timer();
        gmsa_plan_work(_ps);
        _dt = get_timer() - _t0;
        _calls += 1;
        _total += _dt;
        _worst = max(_worst, _dt);
    }
    show_debug_message("[GMSA Bench] goap, the biggest unpruned in 1000 us slices: " + string_format(_total, 1, 0) + " us over "
        + string(_calls) + " calls, worst call " + string_format(_worst, 1, 0) + " us");

    // a recipe with a goal inside
    var _pe = gmsa_plan_planner_create(__test_plan_evening(), __test_plan_evening_camper());
    var _te = __gmsa_bench_goap_make(_pe, "dinner", _runs);
    show_debug_message("[GMSA Bench] goap, dinner (a recipe with a goal inside): " + string_format(_te, 1, 1) + " us, " + string(gmsa_plan_nodes_used(_pe)) + " nodes");
}

function __gmsa_bench_goap_domain(_chain, _noise, _mode) {
    var _d = gmsa_plan_domain_create("bench goap");
    for (var _i = 0; _i <= _chain; _i++) gmsa_plan_add_fact(_d, "has_" + string(_i), function(_o) { return false; });
    for (var _j = 0; _j < _noise; _j++) gmsa_plan_add_fact(_d, "n_" + string(_j), function(_o) { return false; });
    var _cost = (_mode == 2) ? function(_o, _s) { return 1; } : 1;
    for (var _i = 0; _i <= _chain; _i++) {
        var _req = (_i == 0) ? [] : [["has_" + string(_i - 1), true]];
        gmsa_plan_add_step(_d, "make_" + string(_i), { requires : _req, effects : [["has_" + string(_i), true]], cost : _cost });
    }
    for (var _j = 0; _j < _noise; _j++) {
        gmsa_plan_add_step(_d, "fiddle_" + string(_j), { requires : [["n_" + string(_j), false]], effects : [["n_" + string(_j), true]], cost : _cost });
    }
    gmsa_plan_add_goal(_d, "done", { conditions : [["has_" + string(_chain), true]], variety : (_mode == 3) ? 0.3 : 0, prune : (_mode == 0) });
    return gmsa_plan_domain_build(_d);
}

function __gmsa_bench_goap_make(_p, _name, _runs) {
    gmsa_plan_make(_p, _name); // warm up, so arrays are grown before timing
    gmsa_plan_stop(_p);
    var _total = 0;
    repeat (_runs) {
        var _t = get_timer();
        gmsa_plan_make(_p, _name);
        _total += get_timer() - _t;
        gmsa_plan_stop(_p);
    }
    return _total / _runs;
}

function __gmsa_bench_learn_sequences(_runs = 300) {
    show_debug_message("Learn sequence benchmarks, " + string(_runs) + " choices each after 500 to warm up, average per call");
    var _cases = [
        { kind : "ngram", length : 1, inputs : 1, actions : 4 },
        { kind : "ngram", length : 3, inputs : 1, actions : 4 },
        { kind : "ngram", length : 8, inputs : 1, actions : 4 },
        { kind : "ngram", length : 3, inputs : 4, actions : 4 },
        { kind : "ngram", length : 3, inputs : 1, actions : 12 },
        { kind : "ngram", length : 8, inputs : 4, actions : 12 },
        { kind : "tdnn", length : 3, inputs : 1, actions : 4, replay : 0 },
        { kind : "tdnn", length : 3, inputs : 1, actions : 4, replay : 4 },
        { kind : "tdnn", length : 3, inputs : 1, actions : 4, replay : 8 },
        { kind : "tdnn", length : 8, inputs : 1, actions : 4, replay : 4 },
        { kind : "tdnn", length : 3, inputs : 4, actions : 4, replay : 4 },
        { kind : "tdnn", length : 3, inputs : 1, actions : 12, replay : 4 },
        { kind : "tdnn", length : 3, inputs : 1, actions : 4, replay : 4, layers : [32, 16] },
    ];
    for (var _k = 0; _k < array_length(_cases); _k++) __gmsa_bench_seq_case(_cases[_k], _runs);
}

function __gmsa_bench_seq_case(_c, _runs) {
    var _b = __gmsa_bench_seq_agent(_c.inputs, _c.actions);
    var _layers = variable_struct_exists(_c, "layers") ? _c.layers : [16];
    var _m = (_c.kind == "ngram") ? gmsa_learn_ngram_create({ length : _c.length })
        : gmsa_learn_tdnn_create({ length : _c.length, replay : _c.replay, layers : _layers });
    var _rng = gmsa_rng_create(11);
    var _last = 0;
    var _obs = 0;
    var _worst = 0;
    var _pred = 0;
    var _train = 0;
    var _train_worst = 0;
    for (var _i = 0; _i < 500 + _runs; _i++) {
        for (var _j = 0; _j < _c.inputs; _j++) gmsa_agent_set_input(_b.agent, _b.inputs[_j], gmsa_rng_next(_rng));
        // a habit: usually the action after the last one, sometimes anything
        var _pick = (gmsa_rng_next(_rng) < 0.7) ? (_last + 1) mod _c.actions : floor(gmsa_rng_next(_rng) * _c.actions);
        if (_i >= 500) {
            var _e = gmsa_agent_evaluate(_b.agent);
            var _t = get_timer();
            gmsa_learn_predict(_m, _e);
            _pred += get_timer() - _t;
        }
        var _d = gmsa_observe(_b.agent, _b.actions, _pick);
        var _t2 = get_timer();
        gmsa_learn_observe(_m, _d);
        var _dt = get_timer() - _t2;
        var _t3 = get_timer();
        gmsa_learn_train(_m);
        var _dt3 = get_timer() - _t3;
        if (_i >= 500) {
            _obs += _dt;
            _worst = max(_worst, _dt);
            _train += _dt3;
            _train_worst = max(_train_worst, _dt3);
        }
        _last = _pick;
    }
    var _name = ((_c.kind == "ngram") ? "n-gram" : "TDNN") + " length " + string(_c.length) + ", " + string(_c.inputs)
        + ((_c.inputs == 1) ? " input, " : " inputs, ") + string(_c.actions) + " actions";
    if (_c.kind == "tdnn") {
        var _ls = "";
        for (var _i = 0; _i < array_length(_layers); _i++) _ls += ((_i > 0) ? "," : "") + string(_layers[_i]);
        _name += ", replay " + string(_c.replay) + ", layers [" + _ls + "]";
    }
    var _extra = (_c.kind == "ngram") ? ", " + string(_m.data.count) + " contexts"
        : ", replays " + string_format(_train / _runs, 1, 1) + " us (slowest " + string(_train_worst) + " us)";
    show_debug_message(_name + ": predict " + string_format(_pred / _runs, 1, 1) + " us, observe "
        + string_format(_obs / _runs, 1, 1) + " us (slowest " + string(_worst) + " us)" + _extra);
}

function __gmsa_bench_seq_agent(_inputs, _actions) {
    static _count = 0;
    _count += 1;
    var _p = gmsa_profile_create("bench sequences " + string(_count));
    var _names = [];
    for (var _i = 0; _i < _inputs; _i++) {
        gmsa_profile_add_input(_p, gmsa_input_push("in" + string(_i), 0, 1, 0.5));
        array_push(_names, "in" + string(_i));
    }
    gmsa_profile_set_features(_p, _names);
    var _acts = [];
    for (var _a = 0; _a < _actions; _a++) {
        gmsa_profile_add_action(_p, "act" + string(_a));
        array_push(_acts, "act" + string(_a));
    }
    gmsa_profile_build(_p);
    return { agent : gmsa_agent_create(_p), actions : _acts, inputs : _names };
}

function __gmsa_bench_learn_bayes_neighbor(_runs = 300) {
    show_debug_message("Learn Naive Bayes and nearest neighbor benchmarks, " + string(_runs)
        + " choices each after warming up (500, or until the memory is full), average per call");
    var _cases = [
        { kind : "count", inputs : 4, actions : 4 },
        { kind : "count", inputs : 1, actions : 1, shelf : 8 },
        { kind : "bayes", inputs : 4, actions : 4 },
        { kind : "bayes", inputs : 12, actions : 4 },
        { kind : "bayes", inputs : 4, actions : 12 },
        { kind : "bayes", inputs : 4, actions : 4, bins : 64 },
        { kind : "bayes", inputs : 4, actions : 4, outcomes : true },
        { kind : "bayes", inputs : 1, actions : 1, shelf : 8 },
        { kind : "neighbor", inputs : 4, actions : 4, capacity : 64 },
        { kind : "neighbor", inputs : 4, actions : 4, capacity : 256 },
        { kind : "neighbor", inputs : 4, actions : 4, capacity : 1024 },
        { kind : "neighbor", inputs : 4, actions : 4, capacity : 2048 },
        { kind : "neighbor", inputs : 12, actions : 4, capacity : 256 },
        { kind : "neighbor", inputs : 4, actions : 12, capacity : 256 },
        { kind : "neighbor", inputs : 4, actions : 4, capacity : 256, outcomes : true },
        { kind : "neighbor", inputs : 4, actions : 4, capacity : 1024, outcomes : true },
        { kind : "neighbor", inputs : 1, actions : 1, shelf : 8, capacity : 256 },
        { kind : "neighbor", inputs : 1, actions : 1, shelf : 8, capacity : 1024 },
    ];
    for (var _k = 0; _k < array_length(_cases); _k++) __gmsa_bench_bn_case(_cases[_k], _runs);
}

function __gmsa_bench_bn_case(_c, _runs) {
    static _count = 0;
    _count += 1;
    var _neighbor = (_c.kind == "neighbor");
    var _shelf = variable_struct_exists(_c, "shelf") ? _c.shelf : 0;
    var _outcomes = variable_struct_exists(_c, "outcomes") && _c.outcomes;
    var _names = [];
    for (var _j = 0; _j < _c.inputs; _j++) array_push(_names, "in" + string(_j));
    var _acts = [];
    for (var _a = 0; _a < _c.actions; _a++) array_push(_acts, "act" + string(_a));
    var _space = (_shelf > 0)
        ? gmsa_learn_space("bench bn " + string(_count), _acts, _names, { situational : array_create(_c.inputs, false) })
        : gmsa_learn_space("bench bn " + string(_count), _acts, _names);
    var _params = { learns : _outcomes ? gmsa_learn_target.OUTCOMES : gmsa_learn_target.CHOICES };
    if (variable_struct_exists(_c, "bins")) _params.bins = _c.bins;
    if (_neighbor) _params.capacity = _c.capacity;
    var _m = _neighbor ? gmsa_learn_neighbor_create(_params)
        : ((_c.kind == "count") ? gmsa_learn_count_create(_params) : gmsa_learn_bayes_create(_params));
    var _warm = _neighbor ? max(500, _c.capacity + 100) : 500;
    var _n = (_shelf > 0) ? _shelf : _c.actions;
    var _rng = gmsa_rng_create(11);
    var _pred = 0;
    var _obs = 0;
    var _worst = 0;
    for (var _i = 0; _i < _warm + _runs; _i++) {
        var _x = array_create(_c.inputs, 0);
        for (var _j = 0; _j < _c.inputs; _j++) _x[_j] = gmsa_rng_next(_rng);
        var _opts = [];
        var _habit = 0;
        for (var _o = 0; _o < _n; _o++) {
            if (_shelf > 0) {
                var _own = array_create(_c.inputs, 0);
                for (var _j = 0; _j < _c.inputs; _j++) _own[_j] = gmsa_rng_next(_rng);
                array_push(_opts, { action : 0, inputs : _own });
                if (_own[0] < _opts[_habit].inputs[0]) _habit = _o; // the cheapest
            } else {
                array_push(_opts, { action : _o, inputs : _x });
            }
        }
        if (_shelf == 0) _habit = min(_n - 1, floor(_x[0] * _n)); // set by the first input
        var _pick = (gmsa_rng_next(_rng) < 0.7) ? _habit : floor(gmsa_rng_next(_rng) * _n);

        if (_i >= _warm) {
            var _t = get_timer();
            gmsa_learn_space_predict(_m, _space, _opts);
            _pred += get_timer() - _t;
        }
        var _t2 = get_timer();
        if (_outcomes) gmsa_learn_space_outcome(_m, _space, _opts, _pick, 1 / _n, (_pick == _habit) ? 1 : -0.5);
        else gmsa_learn_space_observe(_m, _space, _opts, _pick);
        var _dt = get_timer() - _t2;
        if (_i >= _warm) {
            _obs += _dt;
            _worst = max(_worst, _dt);
        }
    }
    var _name = (_neighbor ? "neighbor capacity " + string(_c.capacity) : _c.kind) + ", " + string(_c.inputs)
        + ((_c.inputs == 1) ? " input, " : " inputs, ")
        + ((_shelf > 0) ? string(_shelf) + " targets" : string(_c.actions) + " actions")
        + (variable_struct_exists(_c, "bins") ? ", bins " + string(_c.bins) : "") + (_outcomes ? ", outcomes" : "");
    var _extra = _neighbor ? ", " + string(array_length(_m.data.mem)) + " moments" : "";
    show_debug_message(_name + ": predict " + string_format(_pred / _runs, 1, 1) + " us, "
        + (_outcomes ? "outcome " : "observe ") + string_format(_obs / _runs, 1, 1) + " us (slowest " + string(_worst) + " us)" + _extra);
}

function __gmsa_bench_rating() {
    var _rng = gmsa_rng_create(7);
    var _p = gmsa_rating_pool_create();
    var _names = array_create(100, "");
    for (var _i = 0; _i < 100; _i++) {
        _names[_i] = "p" + string(_i);
        gmsa_rating_set(_p, _names[_i], { rating : 1200 + 600 * gmsa_rng_next(_rng) });
    }

    // [label, teams, players per team]
    var _shapes = [["1 v 1", 2, 1], ["free for all of 8", 8, 1], ["5 v 5", 2, 5], ["4 teams of 4", 4, 4]];
    var _n = 2000;
    for (var _s = 0; _s < array_length(_shapes); _s++) {
        var _matches = array_create(_n, 0);
        for (var _m = 0; _m < _n; _m++) _matches[_m] = __gmsa_bench_rating_match(_names, _rng, _shapes[_s][1], _shapes[_s][2]);
        var _t = get_timer();
        for (var _m = 0; _m < _n; _m++) gmsa_rating_match(_p, _matches[_m]);
        __gmsa_bench_report("rating match, " + _shapes[_s][0], get_timer() - _t, _n, "match");
    }

    var _t = get_timer();
    for (var _i = 0; _i < 10000; _i++) gmsa_rating_chance(_p, _names[_i mod 100], _names[(_i * 7 + 1) mod 100]);
    __gmsa_bench_report("rating chance", get_timer() - _t, 10000, "call");

    var _cands = array_create(10, "");
    for (var _i = 0; _i < 10; _i++) _cands[_i] = _names[_i * 10 + 5];
    _t = get_timer();
    for (var _i = 0; _i < 5000; _i++) gmsa_rating_pick(_p, _names[_i mod 100], _cands, 0.6);
    __gmsa_bench_report("rating pick, 10 candidates", get_timer() - _t, 5000, "call");

    _t = get_timer();
    for (var _i = 0; _i < 2000; _i++) gmsa_rating_explain(_p, _names[_i mod 100]);
    __gmsa_bench_report("rating explain", get_timer() - _t, 2000, "call");

    // balance: the quick split alone (budget 0) against the full search (default budget), and how fair each is
    var _lobbies = [[8, 2], [10, 2], [12, 3], [16, 4], [20, 4], [30, 5]];
    var _runs = 20;
    for (var _l = 0; _l < array_length(_lobbies); _l++) {
        var _size = _lobbies[_l][0];
        var _teams = _lobbies[_l][1];
        var _quick_us = 0, _full_us = 0, _quick_gap = 0, _full_gap = 0, _worst = 0;
        for (var _r = 0; _r < _runs; _r++) {
            var _start = floor(gmsa_rng_next(_rng) * 100);
            var _lobby = array_create(_size, "");
            for (var _i = 0; _i < _size; _i++) _lobby[_i] = _names[(_start + _i) mod 100];
            var _t0 = get_timer();
            var _q = gmsa_rating_balance(_p, _lobby, _teams, 0);
            _quick_us += get_timer() - _t0;
            _t0 = get_timer();
            var _f = gmsa_rating_balance(_p, _lobby, _teams);
            var _dt = get_timer() - _t0;
            _full_us += _dt;
            _worst = max(_worst, _dt);
            _quick_gap += __gmsa_bench_rating_gap(_p, _q);
            _full_gap += __gmsa_bench_rating_gap(_p, _f);
        }
        __gmsa_bench_line("rating balance, " + string(_size) + " players into " + string(_teams) + " teams: quick "
            + string_format(_quick_us / _runs, 1, 0) + " us (gap " + string_format(_quick_gap / _runs, 1, 1) + "), searched "
            + string_format(_full_us / _runs, 1, 0) + " us, worst " + string(_worst) + " us (gap " + string_format(_full_gap / _runs, 1, 1) + ")");
    }
    __gmsa_bench_line("   gap: strongest team's average rating minus the weakest's, in rating points");
}

function __gmsa_bench_rating_match(_names, _rng, _teams, _size) {
    var _start = floor(gmsa_rng_next(_rng) * 100);
    var _out = array_create(_teams, 0);
    var _places = array_create(_teams, 0);
    for (var _t = 0; _t < _teams; _t++) {
        var _team = array_create(_size, "");
        for (var _i = 0; _i < _size; _i++) _team[_i] = _names[(_start + _t * _size + _i) mod 100];
        _out[_t] = _team;
        _places[_t] = _t + 1;
    }
    for (var _t = _teams - 1; _t > 0; _t--) {
        var _j = floor(gmsa_rng_next(_rng) * (_t + 1));
        var _x = _places[_t];
        _places[_t] = _places[_j];
        _places[_j] = _x;
    }
    return { teams : _out, places : _places };
}

function __gmsa_bench_rating_gap(_p, _teams) {
    var _lo = infinity, _hi = -infinity;
    for (var _t = 0; _t < array_length(_teams); _t++) {
        var _team = _teams[_t];
        var _s = 0;
        for (var _i = 0; _i < array_length(_team); _i++) _s += gmsa_rating_get(_p, _team[_i]).rating;
        _s /= array_length(_team);
        _lo = min(_lo, _s);
        _hi = max(_hi, _s);
    }
    return _hi - _lo;
}

function __gmsa_bench_style(_sizes, _budget) {
    var _set = __test_style_set();
    var _tr = gmsa_style_tracker_create(_set);
    var _n = 10000;
    var _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_style_count(_tr, "kills");
    __gmsa_bench_report("style count", get_timer() - _t, _n, "call");
    _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_style_sample(_tr, "distance", _i mod 500);
    __gmsa_bench_report("style sample", get_timer() - _t, _n, "call");
    _t = get_timer();
    for (var _i = 0; _i < _n; _i++) gmsa_style_tick(_tr);
    __gmsa_bench_report("style tick, 4 measures", get_timer() - _t, _n, "call");

    var _counts = [3, 8];
    var _rng = gmsa_rng_create(9);
    for (var _c = 0; _c < array_length(_counts); _c++) {
        var _s = __test_style_set();
        for (var _k = 0; _k < _counts[_c]; _k++) {
            gmsa_style_add(_s, "s" + string(_k), { kills : 10 * gmsa_rng_next(_rng), deaths : 20 * gmsa_rng_next(_rng),
                distance : 2000 * gmsa_rng_next(_rng), cover : gmsa_rng_next(_rng) });
        }
        var _player = gmsa_style_tracker_create(_s);
        __test_style_play(_player, 0, 20);
        _t = get_timer();
        for (var _i = 0; _i < 2000; _i++) gmsa_style_match(_s, _player);
        __gmsa_bench_report("style match, " + string(_counts[_c]) + " styles", get_timer() - _t, 2000, "call");
        _t = get_timer();
        for (var _i = 0; _i < 2000; _i++) gmsa_style_explain(_s, _player);
        __gmsa_bench_report("style explain, " + string(_counts[_c]) + " styles", get_timer() - _t, 2000, "call");
    }

    for (var _z = 0; _z < array_length(_sizes); _z++) {
        var _s = __test_style_set();
        var _sessions = __test_style_sessions(gmsa_rng_create(31), _sizes[_z], 4);
        var _t0 = get_timer();
        var _job = gmsa_style_fit(_s, _sessions);
        var _setup = get_timer() - _t0;
        var _calls = 0, _worst = 0, _total = 0, _done = false;
        while (!_done) {
            var _t1 = get_timer();
            _done = gmsa_style_fit_work(_job, _budget);
            var _dt = get_timer() - _t1;
            _total += _dt;
            _worst = max(_worst, _dt);
            _calls += 1;
        }
        __gmsa_bench_line("style fit, " + string(_sizes[_z]) + " sessions of 4 true styles, defaults (up to 8 styles, 20 restarts): found " + string(_job.found));
        __gmsa_bench_line("   setup " + string_format(_setup / 1000, 1, 1) + " ms (not sliced), work " + string_format(_total / 1000, 1, 1)
            + " ms in " + string(_calls) + " calls of " + string(_budget) + " us, worst call " + string(_worst)
            + " us (overshoot " + string(max(0, _worst - _budget)) + " us)");
    }
}