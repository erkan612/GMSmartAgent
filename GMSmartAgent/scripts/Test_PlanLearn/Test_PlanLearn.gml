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
		
        gmsa_test_case("steps wiring validates", function() {
            var _d = __test_plan_steps_domain();
            var _ctx = { d : _d };
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_learn_steps(d, { inputs : ["nope"] }); }), "unknown fact");
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_learn_steps(d, { bins : 1 }); }), "bins");
            gmsa_plan_learn_steps(_d);
            gmsa_test_assert_throws(method(_ctx, function() { gmsa_plan_learn_steps(d); }), "twice");
            var _wide = gmsa_plan_domain_create("wide");
            var _names = [];
            for (var _i = 0; _i < 13; _i++) {
                gmsa_plan_add_fact(_wide, "f" + string(_i), function(_o) { return false; });
                array_push(_names, "f" + string(_i));
            }
            gmsa_test_assert_throws(method({ d : _wide, n : _names }, function() { gmsa_plan_learn_steps(d, { inputs : n }); }), "too many situations");
        });

        gmsa_test_case("a step that keeps failing is avoided", function() {
            var _d = __test_plan_steps_domain();
            var _rel = gmsa_plan_learn_steps(_d);
            gmsa_plan_domain_build(_d);
            var _owner = { raining : true };
            var _p = gmsa_plan_planner_create(_d, _owner);
            gmsa_plan_make(_p, "cross");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "walk_bridge", "the bridge first, as declared");
            gmsa_plan_step_failed(_p); // the bridge is out in the rain
            gmsa_test_assert_equal(gmsa_plan_current(_p), "wade", "the repair already avoids it");
            gmsa_test_assert_true(gmsa_plan_learn_step_chance(_rel, _p, "walk_bridge") < 0.7, "chance dropped");
            gmsa_test_assert_equal(gmsa_plan_learn_step_chance(_rel, _p, "wade"), 1, "never failed");
        });

        gmsa_test_case("reliability depends on the situation", function() {
            var _d = __test_plan_steps_domain();
            gmsa_plan_learn_steps(_d, { inputs : ["raining"] });
            gmsa_plan_domain_build(_d);
            var _owner = { raining : true };
            var _p = gmsa_plan_planner_create(_d, _owner);
            __test_plan_steps_episodes(_p, _owner, 4);
            _owner.raining = true;
            gmsa_plan_make(_p, "cross");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "wade", "wade in the rain");
            _owner.raining = false;
            gmsa_plan_make(_p, "cross");
            gmsa_test_assert_equal(gmsa_plan_current(_p), "walk_bridge", "the bridge when it's dry");
        });

        gmsa_test_case("old failures fade", function() {
            var _d = __test_plan_steps_domain();
            var _rel = gmsa_plan_learn_steps(_d, { half_life : 5 });
            gmsa_plan_domain_build(_d);
            var _owner = { raining : true };
            var _p = gmsa_plan_planner_create(_d, _owner);
            __test_plan_steps_episodes(_p, _owner, 1);
            gmsa_test_assert_true(gmsa_plan_learn_step_chance(_rel, _p, "walk_bridge") < 0.7, "fresh failure");
            __test_plan_steps_episodes(_p, _owner, 40); // only wading from now on
            gmsa_test_assert_true(gmsa_plan_learn_step_chance(_rel, _p, "walk_bridge") > 0.95, "forgotten");
        });

        gmsa_test_case("reliability saves and loads", function() {
            var _d = __test_plan_steps_domain();
            var _rel = gmsa_plan_learn_steps(_d, { inputs : ["raining"] });
            gmsa_plan_domain_build(_d);
            var _owner = { raining : true };
            var _p = gmsa_plan_planner_create(_d, _owner);
            __test_plan_steps_episodes(_p, _owner, 3);
            var _json = gmsa_plan_learn_steps_save(_rel);
            var _d2 = __test_plan_steps_domain();
            var _rel2 = gmsa_plan_learn_steps(_d2, { inputs : ["raining"] });
            gmsa_plan_domain_build(_d2);
            gmsa_plan_learn_steps_load(_rel2, _json);
            _owner.raining = true; // compare both in the rain, where the bridge has failed
            gmsa_plan_make(_p, "cross");
            var _q = gmsa_plan_planner_create(_d2, _owner);
            gmsa_plan_make(_q, "cross");
            gmsa_test_assert_equal(gmsa_plan_learn_step_chance(_rel2, _q, "walk_bridge"), gmsa_plan_learn_step_chance(_rel, _p, "walk_bridge"), "same chance");
            var _other = gmsa_plan_learn_steps(gmsa_plan_domain_create("x"));
            gmsa_test_assert_throws(method({ r : _other, j : _json }, function() { gmsa_plan_learn_steps_load(r, j); }), "other inputs");
        });
		
        gmsa_test_case("the player as a fact", function() {
            var _profile = gmsa_profile_create("player");
            gmsa_profile_add_input(_profile, gmsa_input_push("hp"));
            gmsa_profile_add_action(_profile, "left");
            gmsa_profile_add_action(_profile, "right");
            gmsa_profile_set_features(_profile, ["hp"]);
            gmsa_profile_build(_profile);
            var _player = gmsa_agent_create(_profile);
            var _habits = gmsa_learn_count_create();
            repeat (30) gmsa_learn_observe(_habits, gmsa_observe(_player, [{ action : "left" }, { action : "right" }], 0));

            var _d = gmsa_plan_domain_create("ambush");
            gmsa_plan_learn_fact(_d, "player_left", _habits, _player, "left", { refresh : 0 });
            gmsa_plan_add_step(_d, "wait_left");
            gmsa_plan_add_step(_d, "wait_right");
            var _t = gmsa_plan_add_task(_d, "ambush");
            gmsa_plan_add_method(_t, "left_side", { requires : [["player_left", ">=", 0.5]], subtasks : ["wait_left"] });
            gmsa_plan_add_method(_t, "right_side", { subtasks : ["wait_right"] });
            gmsa_plan_domain_build(_d);
            gmsa_test_assert_equal(_d.facts[0].max, 1, "a 0 to 1 fact, ready for learning too");

            var _goblin = gmsa_plan_planner_create(_d, {});
            gmsa_plan_make(_goblin, "ambush");
            gmsa_test_assert_equal(gmsa_plan_current(_goblin), "wait_left", "the player usually goes left");
            repeat (200) gmsa_learn_observe(_habits, gmsa_observe(_player, [{ action : "left" }, { action : "right" }], 1));
            gmsa_plan_make(_goblin, "ambush");
            gmsa_test_assert_equal(gmsa_plan_current(_goblin), "wait_right", "habits changed, so did the ambush");
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

function __test_plan_steps_domain() {
    var _d = gmsa_plan_domain_create("crossing");
    gmsa_plan_add_fact(_d, "raining", function(_o) { return _o.raining; });
    gmsa_plan_add_step(_d, "walk_bridge");
    gmsa_plan_add_step(_d, "wade");
    var _t = gmsa_plan_add_task(_d, "cross");
    gmsa_plan_add_method(_t, "bridge", { subtasks : ["walk_bridge"] });
    gmsa_plan_add_method(_t, "ford", { subtasks : ["wade"] });
    return _d;
}

function __test_plan_steps_episodes(_p, _owner, _count) {
    var _rain = _owner.raining;
    repeat (_count) {
        _owner.raining = _rain;
        gmsa_plan_make(_p, "cross");
        var _guard = 0;
        while (gmsa_plan_get_status(_p) == gmsa_plan_status.RUNNING && _guard < 10) {
            if (gmsa_plan_current(_p) == "walk_bridge" && _owner.raining) gmsa_plan_step_failed(_p);
            else gmsa_plan_step_done(_p);
            _guard++;
        }
        _rain = !_rain; // alternate rain and dry spells
    }
    _owner.raining = _rain;
}