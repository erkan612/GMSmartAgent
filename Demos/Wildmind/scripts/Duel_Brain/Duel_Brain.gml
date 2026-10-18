function varn_profile() {
    static _profile = __varn_profile_build();
    return _profile;
}

function __varn_profile_build() {
    var _p = gmsa_profile_create("varn", { commitment : 0.15, select : gmsa_select.TOP_N_WEIGHTED, top_n : 2 });
    gmsa_profile_add_input(_p, gmsa_input_pull("distance", function(_agent, _target) {
        var _v = _agent.owner;
        return point_distance(_v.x, _v.y, _v.target.x, _v.target.y);
    }, 0, 500));
    gmsa_profile_add_input(_p, gmsa_input_pull("angle_off", function(_agent, _target) { // 0 when he faces the player, 180 when his back is turned
        var _v = _agent.owner;
        return abs(angle_difference(point_direction(_v.x, _v.y, _v.target.x, _v.target.y), _v.facing));
    }, 0, 180));
    gmsa_profile_add_input(_p, gmsa_input_pull("side", function(_agent, _target) { // 1 when the player is fully to his left, 0 fully to his right
        var _v = _agent.owner;
        return 0.5 + clamp(angle_difference(point_direction(_v.x, _v.y, _v.target.x, _v.target.y), _v.facing), -90, 90) / 180;
    }));
    gmsa_profile_add_input(_p, gmsa_input_pull("shooting", function(_agent, _target) {
        return varn_sees_arrows(_agent.owner) ? 1 : 0;
    }));
    gmsa_profile_add_input(_p, gmsa_input_pull("clear_line", function(_agent, _target) { // no pillar in the way of a charge
        var _v = _agent.owner;
        return demo_arena_line_clear(global.arena, _v.x, _v.y, _v.target.x, _v.target.y, _v.radius) ? 1 : 0;
    }));
    gmsa_profile_add_input(_p, gmsa_input_pull("sweep_chance", function(_agent, _target) { // the player is off to one side, or Varn expects a roll to one
        var _v = _agent.owner;
        var _off = min(1, abs(angle_difference(point_direction(_v.x, _v.y, _v.target.x, _v.target.y), _v.facing)) / 60);
        var _r = duel_read("sweep", duel_situation(_v, _v.target));
        var _side = (_r.dodge == "dodge_left" || _r.dodge == "dodge_right") ? _r.sure : 0;
        return max(_off, _side);
    }));

    // distances below are over 0 to 500 px: 0.24 is 120 px, 0.64 is 320 px
    var _approach = gmsa_profile_add_action(_p, "approach", { weight : 0.5 });
    gmsa_action_add_consideration(_approach, "distance", gmsa_curve_make(gmsa_curve.LINEAR));
    gmsa_action_add_consideration(_approach, "distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.24 })); // not when already in reach

    var _cleave = gmsa_profile_add_action(_p, "cleave", { cooldown : 1200000 });
    gmsa_action_add_consideration(_cleave, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : -3.57, b : 1 }));  // 0 from 140 px
    gmsa_action_add_consideration(_cleave, "angle_off", gmsa_curve_make(gmsa_curve.LINEAR, { m : -2.57, b : 1 })); // 0 from 70 degrees

    var _sweep = gmsa_profile_add_action(_p, "sweep", { weight : 0.9, cooldown : 1500000 });
    gmsa_action_add_consideration(_sweep, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : -3.33, b : 1 })); // 0 from 150 px
    gmsa_action_add_consideration(_sweep, "sweep_chance", gmsa_curve_make(gmsa_curve.LINEAR));

    var _slam = gmsa_profile_add_action(_p, "slam", { weight : 0.55, cooldown : 5000000 });
    gmsa_action_add_consideration(_slam, "distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.22 }));
    gmsa_action_add_consideration(_slam, "distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.64, invert : true }));

    var _charge = gmsa_profile_add_action(_p, "charge", { cooldown : 6000000 });
    gmsa_action_add_consideration(_charge, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : 2.5, b : -0.6 })); // from 120 px, full at 320
    gmsa_action_add_consideration(_charge, "clear_line", gmsa_curve_make(gmsa_curve.STEP));
    gmsa_action_add_consideration(_charge, "angle_off", gmsa_curve_make(gmsa_curve.STEP, { c : 0.25, invert : true })); // lined up within 45 degrees

    var _guard = gmsa_profile_add_action(_p, "guard", { weight : 0.9, cooldown : 4000000 });
    gmsa_action_add_consideration(_guard, "shooting", gmsa_curve_make(gmsa_curve.STEP));
    gmsa_action_add_consideration(_guard, "distance", gmsa_curve_make(gmsa_curve.LINEAR));

    gmsa_profile_add_action(_p, "hold", { weight : 0.12 });
    return gmsa_profile_build(_p);
}