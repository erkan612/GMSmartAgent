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