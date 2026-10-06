function test_plan_learn() {
    gmsa_test_suite("PlanLearn", function() {

        gmsa_test_case("wiring validates", function() {
            var _model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
            var _built = __test_plan_learn_domain(undefined, undefined);
            gmsa_test_assert_throws(method({ t : _built.get_key, m : _model }, function() { gmsa_plan_learn_methods(t, m); }), "already built");
            var _open = __test_plan_learn_domain_open();
            var _ctx = { t : _open.get_key, m : _model };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_learn_methods(t, gmsa_learn_count_create()); }), "a choices model");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_learn_methods(t, m, { inputs : ["nope"] }); }), "unknown fact");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_learn_methods(t, m, { influence : 2 }); }), "influence");
            var _one = gmsa_plan_add_task(_open.domain, "single");
            gmsa_plan_add_method(_one, "only", { subtasks : ["buy_key"] });
            gmsa_test_assert_throws(method({ t : _one, m : _model }, function() { gmsa_plan_learn_methods(t, m); }), "one method");
        });

        gmsa_test_case("a number fact needs a range", function() {
            var _model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
            var _bad = __test_plan_learn_domain(_model, undefined); // every fact, gold has no range
            var _p = gmsa_plan_planner_create(_bad.domain, { guard_awake : false, gold : 3, allow_steal : 1 });
            gmsa_test_assert_throws(method({ p : _p }, function() { gmsa_plan_make(p, "get_key"); }), "gold is a number");
            var _good = __test_plan_learn_domain(gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES }), ["guard_awake"]);
            var _q = gmsa_plan_planner_create(_good.domain, { guard_awake : false, gold : 3, allow_steal : 1 });
            gmsa_test_assert_equal(gmsa_plan_make(_q, "get_key"), true, "left out of inputs");
        });

        gmsa_test_case("count learns which method works when", function() {
            var _model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
            var _x = __test_plan_learn_domain(_model, ["guard_awake"]);
            var _owner = { guard_awake : false, gold : 3, allow_steal : 1 };
            var _p = gmsa_plan_planner_create(_x.domain, _owner, { seed : 4 });
            __test_plan_learn_episodes(_p, _owner, 300);
            gmsa_test_assert_true(__test_plan_learn_count(_p, _owner, false, "steal") >= 45, "steal while the guard sleeps");
            gmsa_test_assert_true(__test_plan_learn_count(_p, _owner, true, "buy") >= 45, "buy while he's awake");
        });

        gmsa_test_case("linear learns it too", function() {
            var _model = gmsa_learn_linear_create({ learns : gmsa_learn_target.OUTCOMES });
            var _x = __test_plan_learn_domain(_model, ["guard_awake"]);
            var _owner = { guard_awake : false, gold : 3, allow_steal : 1 };
            var _p = gmsa_plan_planner_create(_x.domain, _owner, { seed : 4 });
            __test_plan_learn_episodes(_p, _owner, 300);
            gmsa_test_assert_true(__test_plan_learn_count(_p, _owner, false, "steal") > 30, "mostly steal while the guard sleeps");
            gmsa_test_assert_true(__test_plan_learn_count(_p, _owner, true, "buy") > 30, "mostly buy while he's awake");
        });

        gmsa_test_case("learning stays under the designer", function() {
            var _model = gmsa_learn_count_create({ learns : gmsa_learn_target.OUTCOMES });
            var _x = __test_plan_learn_domain(_model, ["guard_awake"]);
            var _owner = { guard_awake : false, gold : 3, allow_steal : 1 };
            var _p = gmsa_plan_planner_create(_x.domain, _owner, { seed : 4 });
            __test_plan_learn_episodes(_p, _owner, 300);
            _owner.allow_steal = 0; // the designer rules stealing out
            gmsa_test_assert_equal(__test_plan_learn_count(_p, _owner, false, "buy"), 50, "a ruled out method stays out");
        });
    });
}

function __test_plan_learn_domain_open() {
    var _d = gmsa_plan_domain_create("learn heist");
    gmsa_plan_add_fact(_d, "guard_awake", function(_o) { return _o.guard_awake; });
    gmsa_plan_add_fact(_d, "gold", function(_o) { return _o.gold; });
    gmsa_plan_add_step(_d, "steal_key");
    gmsa_plan_add_step(_d, "buy_key");
    var _t = gmsa_plan_add_task(_d, "get_key");
    gmsa_plan_add_method(_t, "steal", { score : function(_o, _s) { return _o.allow_steal; }, subtasks : ["steal_key"] });
    gmsa_plan_add_method(_t, "buy", { subtasks : ["buy_key"] });
    return { domain : _d, get_key : _t };
}

function __test_plan_learn_domain(_model, _inputs) {
    var _x = __test_plan_learn_domain_open();
    if (_model != undefined) {
        var _params = (_inputs == undefined) ? {} : { inputs : _inputs };
        gmsa_plan_learn_methods(_x.get_key, _model, _params);
    }
    gmsa_plan_domain_build(_x.domain);
    return _x;
}

function __test_plan_learn_episodes(_p, _owner, _count) {
    var _rng = gmsa_rng_create(21);
    repeat (_count) {
        _owner.guard_awake = (gmsa_rng_next(_rng) < 0.5);
        gmsa_plan_make(_p, "get_key");
        var _guard = 0;
        while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING && _guard < 10) {
            var _step = gmsa_plan_current(_p);
            if (_step == "steal_key" && _owner.guard_awake) {
                gmsa_plan_step_failed(_p);
            } else {
                gmsa_plan_step_done(_p);
                if (_step == "buy_key") gmsa_plan_reward(_p, -0.6);
            }
            _guard++;
        }
    }
}

function __test_plan_learn_count(_p, _owner, _awake, _method) {
    _owner.guard_awake = _awake;
    var _n = 0;
    repeat (50) {
        gmsa_plan_make(_p, "get_key");
        if (__test_plan_names(_p) == _method + "_key") _n++;
        gmsa_plan_stop(_p); // interrupted: nothing is learned from these
    }
    return _n;
}