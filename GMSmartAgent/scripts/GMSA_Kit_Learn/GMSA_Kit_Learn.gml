/* GMSA Kit; learning
*  the player's picks recorded in one call, and how an
*  agent's actions went reported in one call. Models are
*  attached with gmsa_kit_agent_create's model and influence.
*/

function gmsa_kit_observe_pick(_model, _agent, _target, _action = undefined, _note = undefined) { // the player picked this: everything the player's agent could choose is offered, and the pick recorded. action names it when a target has several
    if (!is_struct(_agent) || !variable_struct_exists(_agent, "profile")) throw "GMSA: Kit observe_pick needs the player's agent";
    if (_action != undefined && !is_string(_action)) throw "GMSA: Kit observe_pick action must be an action name";
    var _options = gmsa_agent_evaluate(_agent).options;
    var _n = array_length(_options);
    var _offered = array_create(_n, undefined);
    var _chosen = -1;
    for (var _i = 0; _i < _n; _i++) {
        var _o = _options[_i];
        _offered[_i] = { action : _o.action.index, target : _o.target };
        if (_o.target != _target) continue;
        if (_action != undefined && _o.action.name != _action) continue;
        if (_chosen >= 0) throw "GMSA: Kit observe_pick found several actions on that target, name the one picked";
        _chosen = _i;
    }
    if (_chosen < 0) throw "GMSA: Kit observe_pick found nothing on offer for that " + ((_action != undefined) ? "action '" + _action + "' and target" : "target");
    var _decision = gmsa_observe(_agent, _offered, _chosen);
    gmsa_agent_consume(_agent);
    return gmsa_learn_observe(_model, _decision, _note);
}

function gmsa_kit_outcome(_agent, _reward, _note = undefined) { // how the current action went, or the last one while idle. Needs a model that learns outcomes
    var _kit = __gmsa_kit_state(_agent);
    var _model = __gmsa_kit_outcome_model(_agent, "outcome");
    if (_kit.ticket == undefined) throw "GMSA: Kit outcome has nothing to judge yet, the agent hasn't started an action";
    return gmsa_learn_outcome(_model, _kit.ticket, _reward, _note);
}

function gmsa_kit_reward(_agent, _reward, _note = undefined) { // a reward for the agent's recent decisions, more for the nearer ones, and for its plan's methods. Returns how many were credited
    var _kit = __gmsa_kit_state(_agent);
    var _model = __gmsa_kit_model_of(_agent);
    var _learns = (_model != undefined && _model.learns == gmsa_learn_target.OUTCOMES);
    if (!_learns && _kit.planner == undefined) __gmsa_kit_outcome_model(_agent, "reward");
    var _n = 0;
    if (_learns) _n += gmsa_learn_reward(_model, _agent, _reward, _note);
    if (_kit.planner != undefined) _n += gmsa_plan_reward(_kit.planner, _reward);
    return _n;
}

// Internal
function __gmsa_kit_learn_setup(_agent, _params, _where) {
    var _model = _params[$ "model"];
    if (_model == undefined) {
        if (variable_struct_exists(_params, "influence")) throw "GMSA: " + _where + " has influence but no model";
    } else {
        if (!_agent.kit.thinks) throw "GMSA: " + _where + " doesn't think, so a model has nothing to re-rank: give the model to gmsa_kit_observe_pick instead";
        if (_agent.profile.features == undefined) throw "GMSA: " + _where + " has a model, so its profile needs learn : [the inputs the model reads]";
        gmsa_agent_set_model(_agent, _model, __gmsa_param(_params, "influence", 1));
    }
    var _m = __gmsa_kit_model_of(_agent);
    if (_agent.kit.thinks && _m != undefined && _m.learns == gmsa_learn_target.OUTCOMES) gmsa_learn_track(_agent);
}

function __gmsa_kit_model_of(_agent) {
    return (_agent.model != undefined) ? _agent.model : _agent.profile.model;
}

function __gmsa_kit_outcome_model(_agent, _what) {
    var _model = __gmsa_kit_model_of(_agent);
    if (_model == undefined) throw "GMSA: Kit " + _what + " needs an agent with a model, give one to gmsa_kit_agent_create";
    if (_model.learns != gmsa_learn_target.OUTCOMES) throw "GMSA: Kit " + _what + " needs a model that learns outcomes, create it with learns : gmsa_learn_target.OUTCOMES";
    return _model;
}