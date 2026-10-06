function gmsa_plan_learn_methods(_task, _model, _params = {}) {
    if (!is_struct(_task) || _task[$ "methods"] == undefined || _task[$ "domain"] == undefined) {
        throw "GMSA: plan learn methods needs a task from gmsa_plan_add_task";
    }
    var _d = _task.domain;
    if (_d.built) throw "GMSA: plan learn methods must be wired before gmsa_plan_domain_build";
    __gmsa_learn_check_model(_model);
    if (_model.learns != gmsa_learn_target.OUTCOMES) {
        throw "GMSA: plan learn methods needs a model that learns from outcomes, create it with learns : gmsa_learn_target.OUTCOMES";
    }
    var _nm = array_length(_task.methods);
    if (_nm < 2) throw "GMSA: plan task '" + _task.name + "' needs at least two methods to learn which one works";
    if (_task.adjust != undefined) throw "GMSA: plan task '" + _task.name + "' already has an adjust";

    var _influence = __gmsa_param(_params, "influence", 1);
    __gmsa_learn_check_influence(_influence);
    var _success = __gmsa_param(_params, "success", 1);
    var _failure = __gmsa_param(_params, "failure", -1);
    if (!is_numeric(_success) || !is_numeric(_failure)) throw "GMSA: plan learn success and failure must be numbers";
    var _select = __gmsa_param(_params, "select", gmsa_select.TOP_N_WEIGHTED);
    if (_select != gmsa_select.BEST && _select != gmsa_select.TOP_N_WEIGHTED) throw "GMSA: plan learn select must be a gmsa_select";
    var _top_n = __gmsa_param(_params, "top_n", _nm);
    if (!is_numeric(_top_n) || _top_n < 1) throw "GMSA: plan learn top_n must be at least 1";

    // the facts the model sees, by name, in the domain's order
    var _names = __gmsa_param(_params, "inputs", undefined);
    if (_names == undefined) {
        _names = [];
        for (var _f = 0; _f < array_length(_d.facts); _f++) array_push(_names, _d.facts[_f].name);
    }
    if (!is_array(_names)) throw "GMSA: plan learn inputs must be an array of fact names";
    var _fact_index = array_create(array_length(_names), 0);
    for (var _j = 0; _j < array_length(_names); _j++) {
        _fact_index[_j] = -1;
        for (var _f = 0; _f < array_length(_d.facts); _f++) {
            if (_d.facts[_f].name == _names[_j]) {
                _fact_index[_j] = _f;
                break;
            }
        }
        if (_fact_index[_j] < 0) throw "GMSA: plan learn input '" + string(_names[_j]) + "' isn't a fact of domain '" + _d.name + "'";
    }

    var _task_index = -1;
    for (var _t = 0; _t < array_length(_d.tasks); _t++) if (_d.tasks[_t] == _task) _task_index = _t;
    var _method_names = array_create(_nm, "");
    for (var _m = 0; _m < _nm; _m++) _method_names[_m] = _task.methods[_m].name;
    var _inputs = array_create(array_length(_names), 0);
    var _options = array_create(_nm, undefined);
    for (var _m = 0; _m < _nm; _m++) _options[_m] = { action : _m, inputs : _inputs };

    var _ctx = {
        task : _task_index, task_name : _task.name, model : _model,
        space : gmsa_learn_space(_d.name + "." + _task.name, _method_names, _names),
        options : _options, inputs : _inputs, fact_index : _fact_index,
        influence : _influence, success : _success, failure : _failure,
    };
    _task.adjust = method(_ctx, __gmsa_plan_learn_adjust);
    _task.select = _select;
    _task.top_n = floor(_top_n);
    gmsa_plan_add_listener(_d, method(_ctx, __gmsa_plan_learn_listen));
    return _task;
}

// Internal, run with the wiring context as self
function __gmsa_plan_learn_adjust(_planner, _state, _scores) {
    var _nm = array_length(options);
    if (array_length(_planner.domain.tasks[task].methods) != _nm) {
        throw "GMSA: plan task '" + task_name + "' got methods after gmsa_plan_learn_methods, wire it after the last method";
    }
    __gmsa_plan_learn_fill(self, _planner, _state);
    var _out = gmsa_learn_space_predict(model, space, options);
    var _w = influence * _out.confidence;
    if (!(_w * 1000000000000 > 0)) return;
    var _best = 0;
    for (var _m = 0; _m < _nm; _m++) if (_scores[_m] * 1000000000000 > 0) _best = max(_best, _out.p[_m]);
    if (!(_best * 1000000000000 > 0)) return;
    for (var _m = 0; _m < _nm; _m++) {
        if (_scores[_m] * 1000000000000 > 0) _scores[@ _m] = _scores[_m] * max(0.0001, lerp(1, _out.p[_m] / _best, _w));
    }
}

function __gmsa_plan_learn_listen(_r) {
    if (_r.task != task) return;
    var _reward;
    switch (_r.kind) {
        case gmsa_plan_report.METHOD_SUCCESS: _reward = success; break;
        case gmsa_plan_report.METHOD_FAILURE: _reward = failure; break;
        case gmsa_plan_report.METHOD_REWARD: _reward = _r.reward; break;
        default: return; // step reports aren't about which method
    }
    __gmsa_plan_learn_fill(self, _r.planner, _r.state);
    gmsa_learn_space_outcome(model, space, options, _r.method, _r.chance, _reward);
}

function __gmsa_plan_learn_fill(_ctx, _planner, _state) {
    var _facts = _planner.domain.facts;
    for (var _j = 0; _j < array_length(_ctx.fact_index); _j++) {
        var _f = _ctx.fact_index[_j];
        var _fact = _facts[_f];
        var _v = _state[_f];
        if (_fact.min != undefined) {
            _v = clamp((_v - _fact.min) / (_fact.max - _fact.min), 0, 1);
        } else if (!_planner.__fact_bool[_f]) {
            throw "GMSA: plan fact '" + _fact.name + "' is a number, give it a min and max to learn from it, or leave it out of inputs";
        }
        _ctx.inputs[_j] = _v;
    }
    for (var _m = 0; _m < array_length(_ctx.options); _m++) _ctx.options[_m].inputs = _ctx.inputs;
}

/// @func gmsa_plan_learn_steps(domain, [params]) -> reliability
/// @desc Learns how often each step succeeds, per situation, from the plan's own step reports.
/// Methods whose steps keep failing are scored down, so plans route around them. Wire it after the facts it uses.
/// params: inputs (fact names that make up the situation, default none), bins (buckets for facts with a range, default 4),
/// half_life (reports until old evidence counts half, default 50), prior (how much success a step starts with, default 2)
function gmsa_plan_learn_steps(_domain, _params = {}) {
    if (!is_struct(_domain) || _domain[$ "built"] == undefined) throw "GMSA: plan learn steps needs a domain from gmsa_plan_domain_create";
    if (_domain.step_chance != undefined) throw "GMSA: plan domain '" + _domain.name + "' already has a step chance";
    var _bins = __gmsa_param(_params, "bins", 4);
    if (!is_numeric(_bins) || _bins < 2 || frac(_bins) != 0) throw "GMSA: plan learn steps bins must be a whole number of 2 or more";
    var _half = __gmsa_param(_params, "half_life", 50);
    if (!__gmsa_net_above_zero(_half)) throw "GMSA: plan learn steps half_life must be above 0";
    var _prior = __gmsa_param(_params, "prior", 2);
    if (!__gmsa_net_above_zero(_prior)) throw "GMSA: plan learn steps prior must be above 0";
    var _names = __gmsa_param(_params, "inputs", []);
    if (!is_array(_names)) throw "GMSA: plan learn steps inputs must be an array of fact names";

    var _fact_index = array_create(array_length(_names), -1);
    var _fact_bins = array_create(array_length(_names), 2);
    var _cells = 1;
    for (var _j = 0; _j < array_length(_names); _j++) {
        for (var _f = 0; _f < array_length(_domain.facts); _f++) {
            if (_domain.facts[_f].name == _names[_j]) {
                _fact_index[_j] = _f;
                break;
            }
        }
        if (_fact_index[_j] < 0) throw "GMSA: plan learn steps input '" + string(_names[_j]) + "' isn't a fact of domain '" + _domain.name + "'";
        _fact_bins[_j] = (_domain.facts[_fact_index[_j]].min != undefined) ? _bins : 2;
        _cells *= _fact_bins[_j];
    }
    if (_cells > 4096) throw "GMSA: plan learn steps would have " + string(_cells) + " situations per step, the limit is 4096. Use fewer inputs or bins";

    var _rel = {
        domain : _domain, names : _names, fact_index : _fact_index, bins : _fact_bins, cells : _cells,
        decay : power(0.5, 1 / _half), prior : _prior, clock : 0,
        steps : [],  // per step index: { s : [], n : [], last : [] }, one entry per situation
    };
    gmsa_plan_set_step_chance(_domain, method(_rel, __gmsa_plan_learn_steps_chance));
    gmsa_plan_add_listener(_domain, method(_rel, __gmsa_plan_learn_steps_listen));
    return _rel;
}

/// @func gmsa_plan_learn_step_chance(reliability, planner, step) -> real
/// @desc A step's learned chance of success in the facts the planner read last, for debugging and UI.
function gmsa_plan_learn_step_chance(_rel, _planner, _step) {
    var _lookup = _rel.domain.lookup;
    if (!is_string(_step) || !variable_struct_exists(_lookup, _step) || _lookup[$ _step].kind != 0) {
        throw "GMSA: plan domain '" + _rel.domain.name + "' has no step named '" + string(_step) + "'";
    }
    return __gmsa_plan_learn_steps_chance_of(_rel, _planner, _lookup[$ _step].index, _planner.__real);
}

/// @func gmsa_plan_learn_steps_reset(reliability)
function gmsa_plan_learn_steps_reset(_rel) {
    _rel.steps = [];
    _rel.clock = 0;
}

/// @func gmsa_plan_learn_steps_save(reliability) -> string
/// @desc Everything learned, as JSON, steps by name so it survives steps being added or reordered.
function gmsa_plan_learn_steps_save(_rel) {
    var _steps = {};
    var _domain_steps = _rel.domain.steps;
    for (var _i = 0; _i < array_length(_rel.steps); _i++) {
        if (_rel.steps[_i] == undefined) continue;
        _steps[$ _domain_steps[_i].name] = _rel.steps[_i];
    }
    return json_stringify({ format : "gmsa_plan_steps", version : 1, inputs : _rel.names, bins : _rel.bins, clock : _rel.clock, steps : _steps });
}

/// @func gmsa_plan_learn_steps_load(reliability, json) -> bool
/// @desc Loads a save made with the same inputs. Steps the domain no longer has are skipped. Nothing changes when it fails.
function gmsa_plan_learn_steps_load(_rel, _json) {
    var _s = json_parse(_json);
    if (!is_struct(_s) || __gmsa_param(_s, "format", "") != "gmsa_plan_steps") throw "GMSA: not a GMSA plan steps save";
    if (_s.version > 1) throw "GMSA: plan steps save version " + string(_s.version) + " is newer than this GMSmartAgent";
    if (array_length(_s.inputs) != array_length(_rel.names)) throw "GMSA: plan steps save uses other inputs";
    for (var _j = 0; _j < array_length(_rel.names); _j++) {
        if (_s.inputs[_j] != _rel.names[_j] || _s.bins[_j] != _rel.bins[_j]) throw "GMSA: plan steps save uses other inputs";
    }
    var _steps = [];
    var _lookup = _rel.domain.lookup;
    var _names = variable_struct_get_names(_s.steps);
    for (var _i = 0; _i < array_length(_names); _i++) {
        if (!variable_struct_exists(_lookup, _names[_i]) || _lookup[$ _names[_i]].kind != 0) continue;
        var _index = _lookup[$ _names[_i]].index;
        while (array_length(_steps) <= _index) array_push(_steps, undefined);
        _steps[_index] = _s.steps[$ _names[_i]];
    }
    _rel.steps = _steps;
    _rel.clock = _s.clock;
    return true;
}

// Internal, run with the reliability as self
function __gmsa_plan_learn_steps_chance(_planner, _step, _state) {
    return __gmsa_plan_learn_steps_chance_of(self, _planner, _step, _state);
}

function __gmsa_plan_learn_steps_listen(_r) {
    if (_r.kind != gmsa_plan_report.STEP_SUCCESS && _r.kind != gmsa_plan_report.STEP_FAILURE) return;
    var _cells = __gmsa_plan_learn_steps_cells(self, _r.step);
    var _c = __gmsa_plan_learn_steps_cell(self, _r.planner, _r.state);
    clock += 1;
    __gmsa_plan_learn_steps_age(self, _cells, _c);
    _cells.n[_c] += 1;
    if (_r.kind == gmsa_plan_report.STEP_SUCCESS) _cells.s[_c] += 1;
}

function __gmsa_plan_learn_steps_chance_of(_rel, _planner, _step, _state) {
    if (_step >= array_length(_rel.steps) || _rel.steps[_step] == undefined) return 1; // never tried: fully reliable
    var _cells = _rel.steps[_step];
    var _c = __gmsa_plan_learn_steps_cell(_rel, _planner, _state);
    __gmsa_plan_learn_steps_age(_rel, _cells, _c);
    return (_cells.s[_c] + _rel.prior) / (_cells.n[_c] + _rel.prior);
}

function __gmsa_plan_learn_steps_cell(_rel, _planner, _state) {
    var _facts = _planner.domain.facts;
    var _cell = 0;
    for (var _j = 0; _j < array_length(_rel.fact_index); _j++) {
        var _f = _rel.fact_index[_j];
        var _fact = _facts[_f];
        var _v = _state[_f];
        if (_fact.min != undefined) {
            _v = clamp((_v - _fact.min) / (_fact.max - _fact.min), 0, 1);
        } else if (!_planner.__fact_bool[_f]) {
            throw "GMSA: plan fact '" + _fact.name + "' is a number, give it a min and max to learn from it, or leave it out of inputs";
        }
        var _nb = _rel.bins[_j];
        _cell = _cell * _nb + min(_nb - 1, floor(_v * _nb));
    }
    return _cell;
}

function __gmsa_plan_learn_steps_cells(_rel, _step) {
    while (array_length(_rel.steps) <= _step) array_push(_rel.steps, undefined);
    if (_rel.steps[_step] == undefined) {
        _rel.steps[_step] = { s : array_create(_rel.cells, 0), n : array_create(_rel.cells, 0), last : array_create(_rel.cells, 0) };
    }
    return _rel.steps[_step];
}

function __gmsa_plan_learn_steps_age(_rel, _cells, _c) {
    var _age = _rel.clock - _cells.last[_c];
    if (_age <= 0) return;
    var _f = power(_rel.decay, _age);
    _cells.s[_c] *= _f;
    _cells.n[_c] *= _f;
    _cells.last[_c] = _rel.clock;
}