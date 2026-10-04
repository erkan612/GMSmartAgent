function gmsa_bench_all() {
    show_debug_message("[GMSA Bench] running on " + (code_is_compiled() ? "YYC" : "VM"));
    __gmsa_bench_curves();
    __gmsa_bench_scale_targets([10, 50, 100, 200, 500]);
    __gmsa_bench_scale_considerations([1, 4, 8, 16]);
    __gmsa_bench_scale_actions([5, 20, 50, 100]);
    __gmsa_bench_scale_agents([100, 1000, 5000, 10000], 2000);
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