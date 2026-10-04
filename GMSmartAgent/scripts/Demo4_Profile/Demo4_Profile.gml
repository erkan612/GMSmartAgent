function demo4_profile() {
    static _profile = __demo4_profile_build();
    return _profile;
}

function __demo4_profile_build() {
    var _p = gmsa_profile_create("bat", { commitment : 0.2 });

    gmsa_profile_add_input(_p, gmsa_input_pull("player_dist", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, global.demo4_player_x, global.demo4_player_y);
    }, 0, 400));
    gmsa_profile_add_input(_p, gmsa_input_pull("energy", function(_agent, _target) {
        return _agent.owner.energy;
    }, 0, 100));

    var _a;
    // chase when the player is close and the bat has energy to spare
    _a = gmsa_profile_add_action(_p, "chase");
    gmsa_action_add_consideration(_a, "player_dist", gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 }));
    gmsa_action_add_consideration(_a, "energy", gmsa_curve_make(gmsa_curve.LOGISTIC, { k : 12, c : 0.35 }));

    // fly home to rest when energy runs low
    _a = gmsa_profile_add_action(_p, "roost");
    gmsa_action_add_consideration(_a, "energy", gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -12, c : 0.25 }));

    // fallback
    gmsa_profile_add_action(_p, "wander", { weight : 0.15 });

    return gmsa_profile_build(_p);
}

function demo4_on_decide(_agent) {
    var _bat = _agent.owner;
    var _option = gmsa_decision_get_chosen(_agent.decision);
    if (_option != undefined) {
        _bat.state = _option.action.name;
        gmsa_agent_set_current_option(_agent, _option);
    }
    _bat.flash = 4;
    if (_agent.priority > 0) global.demo4_near_thinks++;
    else global.demo4_far_thinks++;
}

function demo4_spawn(_count) {
    repeat (_count) {
        instance_create_depth(random_range(20, room_width - 20), random_range(20, room_height - 20), 0, o_demo4_bat);
    }
}