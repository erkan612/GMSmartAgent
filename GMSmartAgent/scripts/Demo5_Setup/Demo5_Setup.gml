#macro DEMO5_REACH 220   // how far the player can take loot
#macro DEMO5_SIGHT 420   // how far the companion looks

enum demo5_loot { COIN, GEM }

function demo5_player_profile_build() {
    var _p = gmsa_profile_create("player");
    gmsa_profile_add_input(_p, gmsa_input_pull("value", function(_agent, _target) { return _target.value; }, 0, 1, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, DEMO5_REACH, true));
    gmsa_profile_add_action(_p, "take", { targets : function(_agent) { return demo5_loot_near(_agent.owner, DEMO5_REACH); } });
    gmsa_profile_set_features(_p, ["value", "dist"]);
    return gmsa_profile_build(_p);
}

function demo5_companion_profile_build(_model, _influence) {
    var _p = gmsa_profile_create("companion", { commitment : 0.15 });
    gmsa_profile_add_input(_p, gmsa_input_pull("value", function(_agent, _target) { return _target.value; }, 0, 1, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("dist", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, DEMO5_SIGHT, true));

    var _a = gmsa_profile_add_action(_p, "take", { targets : function(_agent) { return demo5_loot_near(_agent.owner, DEMO5_SIGHT); } });
    gmsa_action_add_consideration(_a, "dist", gmsa_curve_make(gmsa_curve.LINEAR, { m : -0.6, b : 1 })); // 1 up close, 0.4 at the edge

    gmsa_profile_add_action(_p, "wander", { weight : 0.02, targets : function(_agent) { return [_agent.owner.wander_point]; } });

    gmsa_profile_set_features(_p, ["value", "dist"]);
    gmsa_profile_set_model(_p, _model, _influence);
    return gmsa_profile_build(_p);
}

function demo5_loot_near(_inst, _radius) {
    var _found = [];
    var _x = _inst.x, _y = _inst.y;
    with (o_demo5_loot) {
        if (point_distance(x, y, _x, _y) <= _radius) array_push(_found, id);
    }
    return _found;
}

function demo5_target_name(_target) {
    if (is_struct(_target)) return "point";
    if (!instance_exists(_target)) return "gone";
    return (_target.kind == demo5_loot.GEM) ? "gem" : "coin";
}