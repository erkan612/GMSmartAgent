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