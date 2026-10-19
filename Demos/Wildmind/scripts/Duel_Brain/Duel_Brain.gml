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
    gmsa_profile_add_input(_p, gmsa_input_pull("meleeing", function(_agent, _target) { // the player is swinging at him, close and in front
        var _v = _agent.owner;
        var _pl = _v.target;
        if (_pl.state != player_state.ATTACK || point_distance(_v.x, _v.y, _pl.x, _pl.y) > 110) return 0;
        return (abs(angle_difference(point_direction(_v.x, _v.y, _pl.x, _pl.y), _v.facing)) < 60) ? 1 : 0;
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

    var _kinds = ["cleave", "sweep", "slam", "charge"];
    for (var _i = 0; _i < 4; _i++) { // how well each attack works on this player, see duel_lands_works
        gmsa_profile_add_input(_p, gmsa_input_pull("lands_" + _kinds[_i], method({ attack : _kinds[_i] }, function(_agent, _target) {
            return duel_lands_works(attack);
        })));
        gmsa_profile_add_input(_p, gmsa_input_pull("rested_" + _kinds[_i], method({ attack : _kinds[_i] }, function(_agent, _target) { // 1 once it has rested, see duel_lands_rest
            var _at = _agent.owner.used_at[$ attack];
            return (_at == undefined || demo_now() - _at >= duel_lands_rest(attack) * 1000000) ? 1 : 0;
        })));
    }
    gmsa_profile_add_input(_p, gmsa_input_pull("close_works", function(_agent, _target) { // how well his close attacks land on this player: walking in pays when they do
        return max(duel_lands_works("cleave"), duel_lands_works("sweep"));
    }));
    var _rested = gmsa_curve_make(gmsa_curve.STEP);
    // an attack that keeps missing is used less, never dropped: each keeps a floor for what it does besides hitting
    var _works_close  = gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.65, b : 0.35 }); // cleave and sweep, down to 0.35
    var _works_slam   = gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.55, b : 0.45 }); // makes the player move and spend stamina, down to 0.45
    var _works_charge = gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.45, b : 0.55 }); // also his fastest way in, down to 0.55

    gmsa_profile_add_input(_p, gmsa_input_push("expect_punish")); // how sure he is of the player's answer to his last attack, set as he recovers. 0 again once he acts
    gmsa_profile_add_input(_p, gmsa_input_push("expect_gap"));    // backs off or drinks: a gap to close
    gmsa_profile_add_input(_p, gmsa_input_push("expect_shoot"));

    // distances below are over 0 to 500 px: 0.24 is 120 px, 0.64 is 320 px
    var _approach = gmsa_profile_add_action(_p, "approach", { weight : 0.8 });
    gmsa_action_add_consideration(_approach, "distance", gmsa_curve_make(gmsa_curve.LINEAR));
    gmsa_action_add_consideration(_approach, "close_works", gmsa_curve_make(gmsa_curve.LINEAR, { m : 0.6, b : 0.4 }));
    gmsa_action_add_consideration(_approach, "distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.24 })); // not when already in reach

    var _cleave = gmsa_profile_add_action(_p, "cleave", { cooldown : 1200000 });
    gmsa_action_add_consideration(_cleave, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : -3.57, b : 1 }));  // 0 from 140 px
    gmsa_action_add_consideration(_cleave, "angle_off", gmsa_curve_make(gmsa_curve.LINEAR, { m : -2.57, b : 1 })); // 0 from 70 degrees
    gmsa_action_add_consideration(_cleave, "lands_cleave", _works_close);
	gmsa_action_add_consideration(_cleave, "rested_cleave", _rested);

    var _sweep = gmsa_profile_add_action(_p, "sweep", { weight : 0.9, cooldown : 1500000 });
    gmsa_action_add_consideration(_sweep, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : -3.33, b : 1 })); // 0 from 150 px
    gmsa_action_add_consideration(_sweep, "sweep_chance", gmsa_curve_make(gmsa_curve.LINEAR));
    gmsa_action_add_consideration(_sweep, "lands_sweep", _works_close);
    gmsa_action_add_consideration(_sweep, "rested_sweep", _rested);

    var _slam = gmsa_profile_add_action(_p, "slam", { weight : 0.55, cooldown : 5000000 });
    gmsa_action_add_consideration(_slam, "distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.22 }));
    gmsa_action_add_consideration(_slam, "distance", gmsa_curve_make(gmsa_curve.STEP, { c : 0.64, invert : true }));
    gmsa_action_add_consideration(_slam, "lands_slam", _works_slam);
    gmsa_action_add_consideration(_slam, "rested_slam", _rested);

    var _charge = gmsa_profile_add_action(_p, "charge", { cooldown : 6000000 });
    gmsa_action_add_consideration(_charge, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : 2.5, b : -0.6 })); // from 120 px, full at 320
    gmsa_action_add_consideration(_charge, "clear_line", gmsa_curve_make(gmsa_curve.STEP));
    gmsa_action_add_consideration(_charge, "angle_off", gmsa_curve_make(gmsa_curve.STEP, { c : 0.25, invert : true })); // lined up within 45 degrees
    gmsa_action_add_consideration(_charge, "lands_charge", _works_charge);
    gmsa_action_add_consideration(_charge, "rested_charge", _rested);

    var _guard = gmsa_profile_add_action(_p, "guard", { weight : 0.9, cooldown : 4000000 });
    gmsa_action_add_consideration(_guard, "shooting", gmsa_curve_make(gmsa_curve.STEP));
    gmsa_action_add_consideration(_guard, "distance", gmsa_curve_make(gmsa_curve.LINEAR));

    // follow-ups: they only score when he's sure what the player does after his attacks
    var _counter = gmsa_profile_add_action(_p, "counter", { weight : 1.5, cooldown : 3000000 });
    gmsa_action_add_consideration(_counter, "expect_punish", gmsa_curve_make(gmsa_curve.STEP, { c : DUEL_READ_SURE }));
    gmsa_action_add_consideration(_counter, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : -3.57, b : 1 })); // 0 from 140 px
    gmsa_action_add_consideration(_counter, "lands_cleave", _works_charge);

    var _chase = gmsa_profile_add_action(_p, "chase", { weight : 1.5, cooldown : 4000000 });
    gmsa_action_add_consideration(_chase, "expect_gap", gmsa_curve_make(gmsa_curve.STEP, { c : DUEL_READ_SURE }));
    gmsa_action_add_consideration(_chase, "clear_line", gmsa_curve_make(gmsa_curve.STEP));
    gmsa_action_add_consideration(_chase, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : 3, b : -0.3 })); // from 50 px, full at 220
    gmsa_action_add_consideration(_chase, "lands_charge", _works_charge);

    var _brace = gmsa_profile_add_action(_p, "brace", { weight : 1.5, cooldown : 4000000 });
    gmsa_action_add_consideration(_brace, "expect_shoot", gmsa_curve_make(gmsa_curve.STEP, { c : DUEL_READ_SURE }));

    var _block = gmsa_profile_add_action(_p, "block", { weight : 0.9, cooldown : 4000000 });
    gmsa_action_add_consideration(_block, "meleeing", gmsa_curve_make(gmsa_curve.STEP));

    var _ward = gmsa_profile_add_action(_p, "ward", { weight : 1.5, cooldown : 4000000 }); // the counter's other answer to a punish: the shield instead of the sword
    gmsa_action_add_consideration(_ward, "expect_punish", gmsa_curve_make(gmsa_curve.STEP, { c : DUEL_READ_SURE }));
    gmsa_action_add_consideration(_ward, "distance", gmsa_curve_make(gmsa_curve.LINEAR, { m : -3.57, b : 1 })); // 0 from 140 px

    gmsa_profile_add_action(_p, "hold", { weight : 0.12 });
    return gmsa_profile_build(_p);
}