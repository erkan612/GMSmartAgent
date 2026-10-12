/* GMSA Kit; utility like module
*  agents described as data, assembled and run for you.
*  Kit invents nothing; everything it builds is a real
*  profile and a real agent, so every plain call still
*  works on them. Kit wraps the cycle, never a feature.
*/

// Profiles
function gmsa_kit_profile(_name, _def = undefined) { // a profile from one struct, built the first time and the same profile every time after, def: { inputs, actions, commitment (0.15), select, top_n, learn, prepare }
    var _store = __gmsa_kit_profiles();
    if (!is_string(_name) || _name == "") throw "GMSA: a Kit profile needs a name";
    var _have = _store[$ _name];
    if (_have != undefined) return _have;
    if (!is_struct(_def)) throw "GMSA: Kit profile '" + _name + "' needs its definition the first time it's asked for";
    var _where = "Kit profile '" + _name + "'";
    __gmsa_kit_check_keys(_def, ["inputs", "actions", "commitment", "select", "top_n", "learn", "prepare"], _where);

    var _actions = _def[$ "actions"];
    if (!is_struct(_actions)) throw "GMSA: " + _where + " needs actions";
    var _names = variable_struct_get_names(_actions);
    if (array_length(_names) == 0) throw "GMSA: " + _where + " needs at least one action";
    array_sort(_names, true); // struct keys keep no order, and action order breaks ties: by name, the same every run

    var _p = gmsa_profile_create(_name, {
        select : __gmsa_param(_def, "select", gmsa_select.BEST),
        top_n : __gmsa_param(_def, "top_n", 3),
        commitment : __gmsa_param(_def, "commitment", 0.15),
    });

    var _inputs = __gmsa_param(_def, "inputs", {});
    if (!is_struct(_inputs)) throw "GMSA: " + _where + " inputs must be a struct of name : input";
    var _in = variable_struct_get_names(_inputs);
    array_sort(_in, true);
    for (var _i = 0; _i < array_length(_in); _i++) gmsa_profile_add_input(_p, __gmsa_kit_input_for(_where, _in[_i], _inputs[$ _in[_i]]));

    var _handlers = {};
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _an = _names[_i];
        var _ad = _actions[$ _an];
        var _aw = _where + " action '" + _an + "'";
        if (!is_struct(_ad)) throw "GMSA: " + _aw + " must be a struct, {} for one with nothing to set";
        __gmsa_kit_check_keys(_ad, ["weight", "cooldown", "targets", "consider", "start", "step", "stop", "plan", "interruptible"], _aw);
        var _params = {};
        if (_ad[$ "weight"] != undefined) _params.weight = _ad.weight;
        if (_ad[$ "cooldown"] != undefined) _params.cooldown = _ad.cooldown;
        if (_ad[$ "targets"] != undefined) _params.targets = _ad.targets;
        var _act = gmsa_profile_add_action(_p, _an, _params);

        var _consider = _ad[$ "consider"];
        if (is_struct(_consider)) {
            var _cn = variable_struct_get_names(_consider);
            array_sort(_cn, true);
            for (var _k = 0; _k < array_length(_cn); _k++) gmsa_action_add_consideration(_act, _cn[_k], _consider[$ _cn[_k]]);
        } else if (is_array(_consider)) {
            for (var _k = 0; _k < array_length(_consider); _k++) {
                var _pair = _consider[_k];
                if (!is_array(_pair) || array_length(_pair) != 2) throw "GMSA: " + _aw + " consider pairs must be [input, curve]";
                gmsa_action_add_consideration(_act, _pair[0], _pair[1]);
            }
        } else if (_consider != undefined) {
            throw "GMSA: " + _aw + " consider must be a struct of input : curve, or an array of [input, curve] pairs";
        }

        var _h = { start : _ad[$ "start"], step : _ad[$ "step"], stop : _ad[$ "stop"], plan : _ad[$ "plan"], interruptible : __gmsa_param(_ad, "interruptible", true) };
        if (_h.start != undefined && !__gmsa_kit_is_function(_h.start)) throw "GMSA: " + _aw + " start must be a function";
        if (_h.step != undefined && !__gmsa_kit_is_function(_h.step)) throw "GMSA: " + _aw + " step must be a function";
        if (_h.stop != undefined && !__gmsa_kit_is_function(_h.stop)) throw "GMSA: " + _aw + " stop must be a function";
        if (_h.plan != undefined && (!is_string(_h.plan) || _h.plan == "")) throw "GMSA: " + _aw + " plan must be a task or goal name";
        if (_h.plan != undefined && _h.step != undefined) throw "GMSA: " + _aw + " has both step and plan, its plan's steps do the work";
        if (!is_bool(_h.interruptible)) throw "GMSA: " + _aw + " interruptible must be true or false";
        if (!_h.interruptible && _h.step == undefined && _h.plan == undefined) throw "GMSA: " + _aw + " can't be interrupted, so it needs a step or a plan to end by itself";
        _handlers[$ _an] = _h;
    }

    var _learn = _def[$ "learn"];
    if (_learn != undefined) gmsa_profile_set_features(_p, _learn);
    var _prepare = _def[$ "prepare"];
    if (_prepare != undefined) {
        if (!__gmsa_kit_is_function(_prepare)) throw "GMSA: " + _where + " prepare must be a function";
        _prepare(_p);
    }
    var _built = gmsa_profile_build(_p);
    _built.kit = { handlers : _handlers };
    _store[$ _name] = _built;
    return _built;
}

function gmsa_kit_profile_forget(_name) { // forgets a Kit profile, so the next gmsa_kit_profile with its name builds it again
    var _store = __gmsa_kit_profiles();
    if (variable_struct_exists(_store, _name)) variable_struct_remove(_store, _name);
}

// Inputs: each becomes a pull input named by its key in the profile
function gmsa_kit_input_var(_variable, _min = 0, _max = 1) { // the owner's own variable, from min to max
    __gmsa_kit_check_variable(_variable, "input_var");
    __gmsa_kit_check_range(_min, _max, "input_var");
    return __gmsa_kit_input_spec(method({ v : _variable }, function(_agent, _target) { return __gmsa_kit_read(_agent.owner, v, "owner"); }), _min, _max, false);
}

function gmsa_kit_input_target_var(_variable, _min = 0, _max = 1) { // per target: the target's own variable, from min to max
    __gmsa_kit_check_variable(_variable, "input_target_var");
    __gmsa_kit_check_range(_min, _max, "input_target_var");
    return __gmsa_kit_input_spec(method({ v : _variable }, function(_agent, _target) { return __gmsa_kit_read(_target, v, "target"); }), _min, _max, true);
}

function gmsa_kit_input_distance(_max) { // per target: how far the target is from the owner, 0 to max pixels
    if (!__gmsa_kit_above_zero(_max)) throw "GMSA: Kit input_distance needs a max distance above 0";
    return __gmsa_kit_input_spec(function(_agent, _target) {
        var _o = _agent.owner;
        return point_distance(_o.x, _o.y, _target.x, _target.y);
    }, 0, _max, true);
}

function gmsa_kit_input_count(_what, _radius, _max) { // how many of an object (or of an array of things) are within radius of the owner, 0 to max
    if (!__gmsa_kit_above_zero(_radius)) throw "GMSA: Kit input_count needs a radius above 0";
    if (!__gmsa_kit_above_zero(_max)) throw "GMSA: Kit input_count needs a max above 0";
    return __gmsa_kit_input_spec(method({ what : _what, radius : _radius }, function(_agent, _target) {
        return array_length(__gmsa_kit_gather(_agent.owner, what, radius, infinity));
    }), 0, _max, false);
}

function gmsa_kit_input_read(_callback, _min = 0, _max = 1, _per_target = false) { // the general form: callback(owner, target) returning a raw value from min to max
    if (!__gmsa_kit_is_function(_callback)) throw "GMSA: Kit input_read needs a function (owner, target)";
    __gmsa_kit_check_range(_min, _max, "input_read");
    return __gmsa_kit_input_spec(method({ fn : _callback }, function(_agent, _target) { return fn(_agent.owner, _target); }), _min, _max, _per_target);
}

// Targets: each returns a targets callback for an action. what: an object, or an array of instances or structs
function gmsa_kit_targets_near(_what, _radius) {
    if (!__gmsa_kit_above_zero(_radius)) throw "GMSA: Kit targets_near needs a radius above 0";
    return method({ what : _what, radius : _radius }, function(_agent) { return __gmsa_kit_gather(_agent.owner, what, radius, infinity); });
}

function gmsa_kit_targets_nearest(_what, _count, _radius = infinity) { // the count nearest, within radius
    if (!is_numeric(_count) || _count < 1 || frac(_count) != 0) throw "GMSA: Kit targets_nearest needs a whole count of 1 or more";
    if (!__gmsa_kit_above_zero(_radius)) throw "GMSA: Kit targets_nearest needs a radius above 0";
    return method({ what : _what, count : _count, radius : _radius }, function(_agent) { return __gmsa_kit_gather(_agent.owner, what, radius, count); });
}

function gmsa_kit_targets_all(_what) {
    return method({ what : _what }, function(_agent) { return __gmsa_kit_gather(_agent.owner, what, infinity, infinity); });
}

function gmsa_kit_targets_from(_callback) { // your own list: callback(owner) returning an array
    if (!__gmsa_kit_is_function(_callback)) throw "GMSA: Kit targets_from needs a function (owner)";
    return method({ fn : _callback }, function(_agent) { return fn(_agent.owner); });
}

// Curves by intent. Every input reaches a curve as 0 to 1
function gmsa_kit_curve_near(_reach = 1) { // closer is better: 1 at 0, 0 at reach
    if (!__gmsa_kit_above_zero(_reach)) throw "GMSA: Kit curve_near needs a reach above 0";
    return gmsa_curve_make(gmsa_curve.LINEAR, { m : -1 / _reach, b : 1 });
}

function gmsa_kit_curve_far(_reach = 1) { // farther is better: 0 at 0, 1 at reach
    if (!__gmsa_kit_above_zero(_reach)) throw "GMSA: Kit curve_far needs a reach above 0";
    return gmsa_curve_make(gmsa_curve.LINEAR, { m : 1 / _reach, b : 0 });
}

function gmsa_kit_curve_near_only(_reach = 0.15, _sharpness = 20) { // only really close counts: near 1 up to reach, then a fast drop
    __gmsa_kit_check_number(_reach, "curve_near_only reach");
    if (!__gmsa_kit_above_zero(_sharpness)) throw "GMSA: Kit curve_near_only needs a sharpness above 0";
    return gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -_sharpness, c : _reach });
}

function gmsa_kit_curve_more(_shape = 1) { // more is better. shape below 1: any amount counts. Above 1: only big amounts do
    if (!__gmsa_kit_above_zero(_shape)) throw "GMSA: Kit curve_more needs a shape above 0";
    return gmsa_curve_make(gmsa_curve.POWER, { k : _shape });
}

function gmsa_kit_curve_less(_shape = 1) { // less is better. shape below 1: any amount already hurts. Above 1: only big amounts do
    if (!__gmsa_kit_above_zero(_shape)) throw "GMSA: Kit curve_less needs a shape above 0";
    return gmsa_curve_make(gmsa_curve.POWER, { k : _shape, invert : true });
}

function gmsa_kit_curve_low(_threshold = 0.4, _sharpness = 10) { // urgent as the input drops (health): 0.5 at threshold, steeper with sharpness
    __gmsa_kit_check_number(_threshold, "curve_low threshold");
    if (!__gmsa_kit_above_zero(_sharpness)) throw "GMSA: Kit curve_low needs a sharpness above 0";
    return gmsa_curve_make(gmsa_curve.LOGISTIC, { k : -_sharpness, c : _threshold });
}

function gmsa_kit_curve_high(_threshold = 0.6, _sharpness = 10) { // urgent as the input rises (danger): 0.5 at threshold
    __gmsa_kit_check_number(_threshold, "curve_high threshold");
    if (!__gmsa_kit_above_zero(_sharpness)) throw "GMSA: Kit curve_high needs a sharpness above 0";
    return gmsa_curve_make(gmsa_curve.LOGISTIC, { k : _sharpness, c : _threshold });
}

function gmsa_kit_curve_at_least(_threshold = 0.5) { // a hard gate: 1 from threshold up, 0 below, and a 0 vetoes the option
    __gmsa_kit_check_number(_threshold, "curve_at_least threshold");
    return gmsa_curve_make(gmsa_curve.STEP, { c : _threshold });
}

function gmsa_kit_curve_below(_threshold = 0.5) { // a hard gate: 1 below threshold, 0 from it up
    __gmsa_kit_check_number(_threshold, "curve_below threshold");
    return gmsa_curve_make(gmsa_curve.STEP, { c : _threshold, invert : true });
}

function gmsa_kit_curve_peak(_center = 0.5, _width = 0.2) { // best in the middle: 1 at center, about 0.37 at width away
    __gmsa_kit_check_number(_center, "curve_peak center");
    if (!__gmsa_kit_above_zero(_width)) throw "GMSA: Kit curve_peak needs a width above 0";
    return gmsa_curve_make(gmsa_curve.CUSTOM, { func : method({ c : _center, w : _width }, function(_x) { return exp(-sqr((_x - c) / w)); }) });
}

function gmsa_kit_curve_band(_from = 0.3, _to = 0.7, _ramp = 0) { // good inside a range: 1 from from to to. ramp above 0 fades to 0 over that far outside, a trapezoid
    __gmsa_kit_check_number(_from, "curve_band from");
    __gmsa_kit_check_number(_to, "curve_band to");
    if (_from > _to) throw "GMSA: Kit curve_band needs from at or below to";
    if (!is_numeric(_ramp) || _ramp < 0) throw "GMSA: Kit curve_band needs a ramp of 0 or more";
    return gmsa_curve_make(gmsa_curve.CUSTOM, { func : method({ a : _from, b : _to, r : _ramp }, function(_x) {
        if (_x >= a && _x <= b) return 1;
        if (r * 1000000000000 <= 0) return 0;
        var _d = (_x < a) ? a - _x : _x - b;
        return max(0, 1 - _d / r);
    }) });
}

function gmsa_kit_curve_valley(_center = 0.5, _width = 0.5) { // worst in the middle: 0 at center, 1 at width away
    __gmsa_kit_check_number(_center, "curve_valley center");
    if (!__gmsa_kit_above_zero(_width)) throw "GMSA: Kit curve_valley needs a width above 0";
    return gmsa_curve_make(gmsa_curve.POWER, { m : 1 / sqr(_width), k : 2, c : _center });
}

function gmsa_kit_curve_ease() { // a smooth S-shaped rise from 0 to 1
    return gmsa_curve_make(gmsa_curve.CUSTOM, { func : function(_x) { return _x * _x * (3 - 2 * _x); } });
}

function gmsa_kit_curve_soft(_curve, _floor = 0.2) { // any curve, never below floor: it still matters, it never vetoes. For matters of taste
    if (!is_struct(_curve)) throw "GMSA: Kit curve_soft needs a curve to soften";
    if (!is_numeric(_floor) || _floor < 0 || _floor > 1) throw "GMSA: Kit curve_soft needs a floor between 0 and 1";
    return gmsa_curve_make(gmsa_curve.CUSTOM, { func : method({ c : _curve, f : _floor }, function(_x) { return f + (1 - f) * gmsa_curve_eval(c, _x); }) });
}

function gmsa_kit_draw_curve(_curve, _x, _y, _w, _h) { // a curve's shape in a box, with its middle lines, in the current draw colour
    var _alpha = draw_get_alpha();
    draw_set_alpha(_alpha * 0.35);
    draw_rectangle(_x, _y, _x + _w, _y + _h, true);
    draw_line(_x + _w / 2, _y, _x + _w / 2, _y + _h);
    draw_line(_x, _y + _h / 2, _x + _w, _y + _h / 2);
    draw_set_alpha(_alpha);
    var _px = _x;
    var _py = _y + _h * (1 - gmsa_curve_eval(_curve, 0));
    for (var _i = 1; _i <= 64; _i++) {
        var _cx = _x + _w * _i / 64;
        var _cy = _y + _h * (1 - gmsa_curve_eval(_curve, _i / 64));
        draw_line(_px, _py, _cx, _cy);
        _px = _cx;
        _py = _cy;
    }
}

// Agents
enum gmsa_kit_step { RUNNING, DONE, FAILED }

function gmsa_kit_agent_create(_profile, _owner = undefined, _params = undefined) { // a real agent whose actions Kit runs, gmsa_kit_agent_update once a step. params: { think_every (10), scheduler, priority, interval, thinks (true), model, influence (1), domain, planner }
    if (!is_struct(_profile) || _profile[$ "built"] != true) throw "GMSA: a Kit agent needs a built profile, from gmsa_kit_profile or gmsa_profile_build";
    var _where = "Kit agent for '" + string(_profile.name) + "'";
    if (_params == undefined) _params = {};
    if (!is_struct(_params)) throw "GMSA: " + _where + " params must be a struct";
    __gmsa_kit_check_keys(_params, ["think_every", "scheduler", "priority", "interval", "thinks", "model", "influence", "domain", "planner"], _where);
    var _thinks = __gmsa_param(_params, "thinks", true);
    if (!is_bool(_thinks)) throw "GMSA: " + _where + " thinks must be true or false";

    var _scheduler = _params[$ "scheduler"];
    if (!_thinks && (_scheduler != undefined || variable_struct_exists(_params, "think_every"))) throw "GMSA: " + _where + " doesn't think, so it takes no scheduler or think_every";
    if (_scheduler != undefined) {
        if (!is_struct(_scheduler) || !variable_struct_exists(_scheduler, "tiers")) throw "GMSA: " + _where + " scheduler must come from gmsa_scheduler_create";
        if (variable_struct_exists(_params, "think_every")) throw "GMSA: " + _where + " has a scheduler, which paces its thinking: give interval instead of think_every";
    } else if (variable_struct_exists(_params, "priority") || variable_struct_exists(_params, "interval")) {
        throw "GMSA: " + _where + " has priority or interval, which belong to a scheduler: give a scheduler too, or use think_every";
    }
    var _every = __gmsa_param(_params, "think_every", 10);
    if (!is_numeric(_every) || _every < 1 || frac(_every) != 0) throw "GMSA: " + _where + " think_every must be a whole number of 1 or more";
    var _priority = __gmsa_param(_params, "priority", 0);
    if (!is_numeric(_priority)) throw "GMSA: " + _where + " priority must be a number";
    var _interval = __gmsa_param(_params, "interval", 0);
    if (!is_numeric(_interval) || _interval < 0) throw "GMSA: " + _where + " interval must be 0 or more microseconds";

    var _agent = gmsa_agent_create(_profile, _owner, { priority : _priority, interval : _interval });
    var _kit = _profile[$ "kit"];
    _agent.kit = {
        handlers  : is_struct(_kit) ? _kit.handlers : {},
        thinks    : _thinks,
        scheduler : _scheduler,
        every     : _every,
        timer     : 0,
        action    : undefined,
        target    : undefined,
        handler   : undefined,
        instance  : false,
        serial    : 0,
        ticket    : undefined,
        planner   : undefined,
        phandlers : {},
        pstep     : undefined,
        ptarget   : undefined,
        phandler  : undefined,
        pinstance : false,
    };
    __gmsa_kit_learn_setup(_agent, _params, _where);
    __gmsa_kit_plan_setup(_agent, _params, _where);
    if (_scheduler != undefined) gmsa_scheduler_add(_scheduler, _agent);
    return _agent;
}

function gmsa_kit_agent_update(_agent) { // once a step: thinks when due, takes what it chose, runs the current action
    var _kit = __gmsa_kit_state(_agent);
    if (!_kit.thinks) return;
    if (_kit.scheduler == undefined) {
        if (_kit.timer <= 0) {
            gmsa_agent_think(_agent);
            _kit.timer = _kit.every;
        }
        _kit.timer--;
    }
    __gmsa_kit_take(_agent, _kit);
    if (_kit.action == undefined) return;
    if (_kit.instance && !instance_exists(_kit.target)) {
        __gmsa_kit_finish(_agent, _kit, gmsa_kit_step.FAILED);
        return;
    }
    if (_kit.handler.plan != undefined) {
        __gmsa_kit_plan_update(_agent, _kit);
        return;
    }
    var _step = _kit.handler.step;
    if (_step == undefined) return;
    var _serial = _kit.serial;
    var _r = _step(_agent.owner, _kit.target, _agent);
    if (_kit.serial != _serial) return;
    _r = __gmsa_kit_step_result(_r, "action '" + _kit.action.name + "'");
    if (_r != gmsa_kit_step.RUNNING) __gmsa_kit_finish(_agent, _kit, _r);
}

function gmsa_kit_agent_doing(_agent) { // the current action's name, "" while idle
    var _kit = __gmsa_kit_state(_agent);
    return (_kit.action == undefined) ? "" : _kit.action.name;
}

function gmsa_kit_agent_target(_agent) { // the current action's target, undefined while idle or for an action without targets
    return __gmsa_kit_state(_agent).target;
}

function gmsa_kit_agent_done(_agent, _failed = false) { // ends the current action from outside, and the agent decides again at its next update
    var _kit = __gmsa_kit_state(_agent);
    if (_kit.action == undefined) return;
    __gmsa_kit_end(_agent, _kit);
    gmsa_agent_clear_current(_agent);
    gmsa_kit_agent_decide(_agent);
}

function gmsa_kit_agent_decide(_agent) { // thinks at the next update, whatever the timer says. With a scheduler, at its next step
    var _kit = __gmsa_kit_state(_agent);
    if (_kit.scheduler == undefined) _kit.timer = 0;
    else _agent.last_think = undefined;
}

function gmsa_kit_agent_set_think_every(_agent, _every) { // updates between thinks from now on, for a Kit agent without a scheduler (with one, use gmsa_agent_set_interval). A shorter wait takes effect now, a longer one from the next think
    var _kit = __gmsa_kit_state(_agent);
    if (!_kit.thinks) throw "GMSA: this Kit agent doesn't think, so it has no think_every";
    if (_kit.scheduler != undefined) throw "GMSA: this Kit agent has a scheduler, which paces its thinking: use gmsa_agent_set_interval";
    if (!is_numeric(_every) || _every < 1 || frac(_every) != 0) throw "GMSA: think_every must be a whole number of 1 or more";
    _kit.every = _every;
    _kit.timer = min(_kit.timer, _every);
}

function gmsa_kit_agent_stop(_agent) { // stops the current action and idles until the next think
    var _kit = __gmsa_kit_state(_agent);
    if (_kit.action == undefined) return;
    __gmsa_kit_end(_agent, _kit);
    gmsa_agent_clear_current(_agent);
}

function gmsa_kit_agent_destroy(_agent) { // stops it and takes it out of its scheduler, in the owner's Destroy or Clean Up
    var _kit = __gmsa_kit_state(_agent);
    gmsa_kit_agent_stop(_agent);
    if (_kit.scheduler == undefined) return;
    gmsa_scheduler_remove(_kit.scheduler, _agent);
    if (_kit.planner != undefined) gmsa_plan_unschedule(_kit.planner);
}

// Internal
function __gmsa_kit_profiles() {
    static _store = {};
    return _store;
}

function __gmsa_kit_is_function(_v) {
    if (is_method(_v)) return true;
    return is_callable(_v) && typeof(_v) != "number";
}

function __gmsa_kit_above_zero(_v) {
    return is_numeric(_v) && _v * 1000000000000 > 0;
}

function __gmsa_kit_check_number(_v, _what) {
    if (!is_numeric(_v)) throw "GMSA: Kit " + _what + " must be a number";
}

function __gmsa_kit_check_variable(_v, _what) {
    if (!is_string(_v) || _v == "") throw "GMSA: Kit " + _what + " needs a variable name";
}

function __gmsa_kit_check_range(_min, _max, _what) {
    if (!is_numeric(_min) || !is_numeric(_max) || _min == _max) throw "GMSA: Kit " + _what + " needs a min and max that differ";
}

function __gmsa_kit_check_keys(_def, _known, _where) {
    var _keys = variable_struct_get_names(_def);
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _ok = false;
        for (var _k = 0; _k < array_length(_known); _k++) if (_keys[_i] == _known[_k]) _ok = true;
        if (!_ok) {
            var _list = "";
            for (var _k = 0; _k < array_length(_known); _k++) _list += ((_k > 0) ? ", " : "") + _known[_k];
            throw "GMSA: " + _where + " has an unknown field '" + _keys[_i] + "'. Known: " + _list;
        }
    }
}

function __gmsa_kit_input_spec(_callback, _min, _max, _per_target) {
    return { __gmsa_kit_input : true, callback : _callback, min : _min, max : _max, per_target : _per_target };
}

function __gmsa_kit_input_for(_where, _key, _v) {
    if (is_struct(_v) && variable_struct_exists(_v, "__gmsa_kit_input")) return gmsa_input_pull(_key, _v.callback, _v.min, _v.max, _v.per_target);
    if (is_struct(_v) && variable_struct_exists(_v, "source") && variable_struct_exists(_v, "name")) {
        if (_v.name != _key) throw "GMSA: " + _where + " has the input '" + _v.name + "' under the name '" + _key + "', they must match";
        return _v;
    }
    if (__gmsa_kit_is_function(_v)) return gmsa_input_pull(_key, method({ fn : _v }, function(_agent, _target) { return fn(_agent.owner, _target); }), 0, 1, false);
    throw "GMSA: " + _where + " input '" + _key + "' must be a Kit input, a plain input or a function (owner, target) returning 0 to 1";
}

function __gmsa_kit_read(_thing, _variable, _who) {
    var _v = undefined;
    if (is_struct(_thing)) _v = _thing[$ _variable];
    else if (instance_exists(_thing)) _v = variable_instance_get(_thing, _variable);
    if (!is_numeric(_v)) throw "GMSA: Kit reads '" + _variable + "' from the " + _who + ", which has no number by that name";
    return _v;
}

function __gmsa_kit_gather(_owner, _what, _radius, _count) {
    var _out = [];
    var _ox = _owner.x;
    var _oy = _owner.y;
    if (is_array(_what)) {
        for (var _i = 0; _i < array_length(_what); _i++) {
            var _t = _what[_i];
            if (_t == _owner) continue;
            if (!is_struct(_t) && !instance_exists(_t)) continue;
            if (point_distance(_ox, _oy, _t.x, _t.y) <= _radius) array_push(_out, _t);
        }
    } else {
        with (_what) {
            if (id != _owner && point_distance(_ox, _oy, x, y) <= _radius) array_push(_out, id);
        }
    }
    if (_count < array_length(_out)) {
        array_sort(_out, method({ ox : _ox, oy : _oy }, function(_a, _b) { return point_distance(ox, oy, _a.x, _a.y) - point_distance(ox, oy, _b.x, _b.y); }));
        array_resize(_out, _count);
    }
    return _out;
}


function __gmsa_kit_state(_agent) {
    var _kit = is_struct(_agent) ? _agent[$ "kit"] : undefined;
    if (!is_struct(_kit)) throw "GMSA: this needs an agent from gmsa_kit_agent_create";
    return _kit;
}

function __gmsa_kit_no_handler() {
    static _none = { start : undefined, step : undefined, stop : undefined, plan : undefined, interruptible : true };
    return _none;
}

function __gmsa_kit_is_instance(_t) {
    if (_t == undefined || is_struct(_t) || is_string(_t) || is_array(_t) || is_method(_t)) return false;
    return instance_exists(_t);
}

function __gmsa_kit_take(_agent, _kit) {
    var _decision = gmsa_agent_consume(_agent);
    if (_decision == undefined) return;
    var _option = gmsa_decision_get_chosen(_decision);
    if (_kit.action != undefined && !_kit.handler.interruptible) {
        if (_option != undefined && _option.action == _kit.action && _option.target == _kit.target) gmsa_agent_set_current_option(_agent, _option);
        return;
    }
    if (_option == undefined) {
        if (_kit.action == undefined) return;
        __gmsa_kit_end(_agent, _kit);
        gmsa_agent_clear_current(_agent);
        return;
    }
    var _same = (_option.action == _kit.action && _option.target == _kit.target);
    if (!_same && _kit.action != undefined) __gmsa_kit_end(_agent, _kit);
    gmsa_agent_set_current_option(_agent, _option);
    if (_same) return;
    if (_agent[$ "__history"] != undefined) _kit.ticket = gmsa_learn_remember(_agent);
    var _handler = _kit.handlers[$ _option.action.name];
    _kit.action = _option.action;
    _kit.target = _option.target;
    _kit.handler = (_handler != undefined) ? _handler : __gmsa_kit_no_handler();
    _kit.instance = __gmsa_kit_is_instance(_option.target);
    _kit.serial++;
    var _serial = _kit.serial;
    if (_kit.handler.start != undefined) _kit.handler.start(_agent.owner, _kit.target, _agent);
    if (_kit.serial == _serial && _kit.handler.plan != undefined) gmsa_plan_make(_kit.planner, _kit.handler.plan);
}

function __gmsa_kit_end(_agent, _kit) {
    var _handler = _kit.handler;
    var _target = _kit.target;
    _kit.action = undefined;
    _kit.target = undefined;
    _kit.handler = undefined;
    _kit.instance = false;
    _kit.serial++;
    if (_handler.plan != undefined) __gmsa_kit_plan_halt(_agent, _kit);
    if (_handler.stop != undefined) _handler.stop(_agent.owner, _target, _agent);
}

function __gmsa_kit_finish(_agent, _kit, _status) {
    __gmsa_kit_end(_agent, _kit);
    gmsa_agent_clear_current(_agent);
    if (_kit.scheduler != undefined) {
        _agent.last_think = undefined;
        return;
    }
    gmsa_agent_think(_agent);
    _kit.timer = _kit.every - 1;
    __gmsa_kit_take(_agent, _kit);
}


function __gmsa_kit_step_result(_r, _what) {
    if (_r == undefined) return gmsa_kit_step.RUNNING;
    if ((!is_numeric(_r) && !is_bool(_r)) || (_r != gmsa_kit_step.RUNNING && _r != gmsa_kit_step.DONE && _r != gmsa_kit_step.FAILED)) {
        throw "GMSA: Kit " + _what + " step returned " + string(_r) + ": return true when done, false while running, or a gmsa_kit_step";
    }
    return (_r == gmsa_kit_step.FAILED) ? gmsa_kit_step.FAILED : ((_r == gmsa_kit_step.RUNNING) ? gmsa_kit_step.RUNNING : gmsa_kit_step.DONE);
}