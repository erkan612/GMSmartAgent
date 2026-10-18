#macro DUEL_READ_SURE 0.3       // how sure Varn has to be before he acts on a guess
#macro DUEL_DODGE_DISTANCE 180  // about how far a dodge carries the player
#macro DUEL_DODGE_MIN 40        // moving less than this before the hit counts as staying
#macro DUEL_EARLY 0.3           // a roll or dodge pressed more than this many seconds before the hit is early
#macro DUEL_LATE 0.15           // less than this is late

function duel_dodge_profile() { // the player's answer to an attack, as choices a model can learn
    static _profile = __duel_dodge_profile_build();
    return _profile;
}

function __duel_dodge_profile_build() {
    var _p = gmsa_profile_create("player_dodge");
    gmsa_profile_add_input(_p, gmsa_input_push("attack")); // which attack is coming, see varn_attack_slot
    gmsa_profile_add_action(_p, "dodge_left");
    gmsa_profile_add_action(_p, "dodge_right");
    gmsa_profile_add_action(_p, "dodge_back");
    gmsa_profile_add_action(_p, "dodge_in");
    gmsa_profile_add_action(_p, "stay");
    gmsa_profile_set_features(_p, ["attack"]);
    return gmsa_profile_build(_p);
}

function duel_timing_profile() { // when the player presses roll or dodge, as choices a model can learn
    static _profile = __duel_timing_profile_build();
    return _profile;
}

function __duel_timing_profile_build() {
    var _p = gmsa_profile_create("player_timing");
    gmsa_profile_add_input(_p, gmsa_input_push("attack"));
    gmsa_profile_add_action(_p, "early");
    gmsa_profile_add_action(_p, "on_time");
    gmsa_profile_add_action(_p, "late");
    gmsa_profile_set_features(_p, ["attack"]);
    return gmsa_profile_build(_p);
}

function duel_reads_create(_player) { // a fresh memory of the player, one per fight
    return {
        agent        : gmsa_agent_create(duel_dodge_profile(), _player),
        model        : gmsa_learn_count_create({ bins : 4, inputs : ["attack"], confidence_k : 3 }),
        timing_agent : gmsa_agent_create(duel_timing_profile(), _player),
        timing_model : gmsa_learn_count_create({ bins : 1, inputs : ["attack"], confidence_k : 3, half_life : 10 }), // one bin, so every attack teaches the same timing. fades fast, so he notices a change
        timing_avg   : 0, // seconds before the hit, for the habits panel
        timing_seen  : 0,
    };
}

function duel_timing_read() { // when Varn expects the player to roll or dodge: { timing, sure }
    var _out = { timing : "on_time", sure : 0 };
    if (!global.duel_learning) return _out;
    var _r = o_duel.reads;
    var _d = gmsa_agent_evaluate(_r.timing_agent, demo_now());
    var _pred = gmsa_learn_predict(_r.timing_model, _d);
    if (_pred.best >= 0) {
        _out.timing = _d.options[_pred.best].action.name;
        _out.sure = _pred.sure;
    }
    return _out;
}

function duel_timing_learn(_lead) { // the player pressed roll or dodge this many seconds before the hit
    static _timings = ["early", "on_time", "late"];
    if (!global.duel_learning) return;
    var _r = o_duel.reads;
    var _kind = (_lead > DUEL_EARLY) ? "early" : ((_lead < DUEL_LATE) ? "late" : "on_time");
    gmsa_learn_observe(_r.timing_model, gmsa_observe(_r.timing_agent, _timings, array_get_index(_timings, _kind), demo_now()));
    _r.timing_avg = (_r.timing_seen == 0) ? _lead : lerp(_r.timing_avg, _lead, 0.3);
    _r.timing_seen++;
}

function varn_attack_slot(_attack) { // each attack in its own quarter of the "attack" input, so Count keeps them apart
    switch (_attack) {
        case "cleave": return 0.125;
        case "sweep":  return 0.375;
        case "slam":   return 0.625;
        case "charge": return 0.875;
    }
    return 0;
}

function duel_read(_attack) { // what Varn expects the player to do against an attack: { dodge, sure }, sure is 0 when learning is off or he hasn't seen enough
    var _out = { dodge : "stay", sure : 0 };
    if (!global.duel_learning) return _out;
    var _r = o_duel.reads;
    gmsa_agent_set_input(_r.agent, "attack", varn_attack_slot(_attack));
    var _d = gmsa_agent_evaluate(_r.agent, demo_now());
    var _pred = gmsa_learn_predict(_r.model, _d);
    if (_pred.best >= 0) {
        _out.dodge = _d.options[_pred.best].action.name;
        _out.sure = _pred.sure;
    }
    return _out;
}

function duel_read_learn(_attack, _dodge) { // the player answered an attack with this dodge
    static _dodges = ["dodge_left", "dodge_right", "dodge_back", "dodge_in", "stay"];
    if (!global.duel_learning) return;
    var _r = o_duel.reads;
    gmsa_agent_set_input(_r.agent, "attack", varn_attack_slot(_attack));
    gmsa_learn_observe(_r.model, gmsa_observe(_r.agent, _dodges, array_get_index(_dodges, _dodge), demo_now()));
    o_duel.seen[$ _attack] += 1;
}

function duel_dodge_kind(_dx, _dy, _from_dir) { // how the player moved, as Varn sees it. from_dir points from Varn to where the player stood
    if (point_distance(0, 0, _dx, _dy) < DUEL_DODGE_MIN) return "stay";
    var _diff = angle_difference(point_direction(0, 0, _dx, _dy), _from_dir);
    if (abs(_diff) <= 45) return "dodge_back";
    if (abs(_diff) >= 135) return "dodge_in";
    return (_diff > 0) ? "dodge_left" : "dodge_right";
}

function duel_dodge_angle(_dodge) { // where a dodge goes, relative to the direction from Varn to the player
    switch (_dodge) {
        case "dodge_left":  return 90;
        case "dodge_right": return -90;
        case "dodge_back":  return 0;
        case "dodge_in":    return 180;
    }
    return 0;
}

function duel_dodge_words(_dodge) {
    switch (_dodge) {
        case "dodge_left":  return "to my left";
        case "dodge_right": return "to my right";
        case "dodge_back":  return "away";
        case "dodge_in":    return "past me";
    }
    return "nowhere";
}