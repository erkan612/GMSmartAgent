enum demo1_item { KEY, CHEST, POTION, HEART }

function demo1_profile() {
    static _profile = __demo1_profile_build();
    return _profile;
}

function __demo1_profile_build() {
    var _p = gmsa_profile_create("seeker", { commitment : 0.15 });

    // inputs, all read from the agent instance (the caller's world)
    gmsa_profile_add_input(_p, gmsa_input_pull("dist_ratio", function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y) / _o.sight;
    }, 0, 1, true));
    gmsa_profile_add_input(_p, gmsa_input_pull("missing_hp", function(_agent, _target) {
        return 1 - _agent.owner.hp / _agent.owner.hp_max;
    }));
    gmsa_profile_add_input(_p, gmsa_input_pull("has_key", function(_agent, _target) {
        return _agent.owner.keys > 0;
    }));

    // curves
    var _near     = gmsa_curve_make(gmsa_curve.LINEAR, { m : -1, b : 1 });                  // 1 on top of it, 0 at the sight edge
    var _need     = gmsa_curve_make(gmsa_curve.LOGISTIC, { k : 10, c : 0.5, b : -0.01 });   // exactly 0 at full hp
    var _key_gate = gmsa_curve_make(gmsa_curve.STEP, { c : 0.5 });                          // 0 without a key
    var _greed    = gmsa_curve_make(gmsa_curve.LINEAR, { m : -0.6, b : 1 });                // 1 at full hp, 0.4 when nearly dead

    var _a;
    _a = gmsa_profile_add_action(_p, "get_key", { targets : __demo1_targets(demo1_item.KEY) });
    gmsa_action_add_consideration(_a, "dist_ratio", _near);
    gmsa_action_add_consideration(_a, "missing_hp", _greed);

    _a = gmsa_profile_add_action(_p, "open_chest", { targets : __demo1_targets(demo1_item.CHEST) });
    gmsa_action_add_consideration(_a, "dist_ratio", _near);
    gmsa_action_add_consideration(_a, "has_key", _key_gate);
    gmsa_action_add_consideration(_a, "missing_hp", _greed);

    _a = gmsa_profile_add_action(_p, "get_potion", { weight : 0.8, targets : __demo1_targets(demo1_item.POTION) });
    gmsa_action_add_consideration(_a, "dist_ratio", _near);
    gmsa_action_add_consideration(_a, "missing_hp", _greed);

    // health is worth walking for; distance only halves a heart's value at the sight edge
    var _near_heart = gmsa_curve_make(gmsa_curve.LINEAR, { m : -0.5, b : 1 });
    _a = gmsa_profile_add_action(_p, "get_heart", { weight : 1.5, targets : __demo1_targets(demo1_item.HEART) });
    gmsa_action_add_consideration(_a, "dist_ratio", _near_heart);
    gmsa_action_add_consideration(_a, "missing_hp", _need);

    gmsa_profile_add_action(_p, "wander", {
        weight  : 0.03,
        targets : function(_agent) { return [_agent.owner.wander_point]; },
    });

    return gmsa_profile_build(_p);
}

function __demo1_targets(_kind) {
    return method({ kind : _kind }, function(_agent) {
        return _agent.owner.find(kind);
    });
}

function demo1_item_name(_kind) {
    static _names = ["key", "chest", "potion", "heart"];
    return _names[_kind];
}

function demo1_item_colour(_kind) {
    static _colours = [c_yellow, c_orange, c_fuchsia, c_red];
    return _colours[_kind];
}