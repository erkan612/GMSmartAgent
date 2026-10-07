function gmsa_learn_bayes_create(_params = {}) {
    var _bins = __gmsa_param(_params, "bins", 8);
    if (!__gmsa_learn_bayes_whole(_bins)) throw "GMSA: bayes bins must be a whole number of 1 or more";
    var _per = __gmsa_param(_params, "input_bins", {});
    if (!is_struct(_per)) throw "GMSA: bayes input_bins must be a struct of input names and bin counts";
    var _pn = variable_struct_get_names(_per);
    for (var _i = 0; _i < array_length(_pn); _i++) {
        if (!__gmsa_learn_bayes_whole(_per[$ _pn[_i]])) throw "GMSA: bayes input_bins." + _pn[_i] + " must be a whole number of 1 or more";
    }
    var _smoothing = __gmsa_param(_params, "smoothing", 4);
    if (!__gmsa_net_above_zero(_smoothing)) throw "GMSA: bayes smoothing must be above 0";
    var _temper = __gmsa_param(_params, "temper", "auto");
    if (!((is_string(_temper) && _temper == "auto") || __gmsa_net_above_zero(_temper))) throw "GMSA: bayes temper must be \"auto\" or a number above 0";
    var _names = __gmsa_param(_params, "inputs", undefined);
    if (_names != undefined && (!is_array(_names) || array_length(_names) == 0)) throw "GMSA: bayes inputs must be a non-empty array of input names";

    var _model = __gmsa_learn_model_create(gmsa_learn_tier.BAYES, "bayes", {
        half_life    : __gmsa_param(_params, "half_life", 50),
        confidence_k : __gmsa_param(_params, "confidence_k", 5),
        learns       : __gmsa_param(_params, "learns", gmsa_learn_target.CHOICES),
        temperature  : __gmsa_param(_params, "temperature", 0.1),
    });
    _model.bayes = {
        bins       : _bins,
        input_bins : _per,
        smoothing  : _smoothing,
        temper     : _temper,
        names      : _names,
        tempers    : [1, 0.75, 0.5, 0.35, 0.25],  // the exponents "auto" chooses from
        margin     : 0.05,                        // a softer exponent must predict this much better to be used
    };
    _model.__kid  = [];  // per key: the model input id
    _model.__cell = [];  // per action, per key: its counts
    _model.__b    = [];  // per option: its action's base (chosen rate or average reward)
    _model.__sum  = [];  // per option: its inputs' evidence, added up
    _model.__ev   = [];  // per option: how much data its bins have
    _model.__s    = [];  // scores
    _model.__p    = [];  // softmax of the scores
    _model.observe    = method(_model, __gmsa_learn_bayes_observe);
    _model.predict    = method(_model, __gmsa_learn_bayes_predict);
    _model.explain    = method(_model, __gmsa_learn_bayes_explain);
    _model.save_data  = method(_model, __gmsa_learn_bayes_save);
    _model.load_data  = method(_model, __gmsa_learn_bayes_load);
    _model.reset_data = method(_model, __gmsa_learn_bayes_reset);
    _model.reset_data();
    return _model;
}

// Methods, run with the model as self
function __gmsa_learn_bayes_reset() {
    data = { keys : bayes.names, clock : 0, acts : {}, cells : {}, loss : array_create(array_length(bayes.tempers), 0) };
    array_resize(__cell, 0);
}

function __gmsa_learn_bayes_observe(_sample) {
    var _outcomes = (learns == gmsa_learn_target.OUTCOMES);
    var _keys = __gmsa_learn_bayes_keys(self);
    var _n = array_length(_sample.options);
    var _c = _sample.chosen;
    var _w = _sample.weight;

    // which softening would have predicted this best
    if (is_string(bayes.temper)) {
        __gmsa_learn_bayes_evidence(self, _sample);
        var _t = bayes.tempers;
        for (var _k = 0; _k < array_length(_t); _k++) {
            var _loss;
            if (_outcomes) {
                _loss = sqr(__b[_c] + _t[_k] * __sum[_c] - _sample.reward);
            } else {
                var _max = -infinity;
                for (var _i = 0; _i < _n; _i++) _max = max(_max, ln(__b[_i]) + _t[_k] * __sum[_i]);
                var _total = 0;
                for (var _i = 0; _i < _n; _i++) _total += exp(ln(__b[_i]) + _t[_k] * __sum[_i] - _max);
                _loss = -(ln(__b[_c]) + _t[_k] * __sum[_c] - _max - ln(_total));
            }
            data.loss[_k] = data.loss[_k] * decay + _loss;
        }
    }

    data.clock += 1;
    // choices: every option on offer counts as offered, the chosen one as chosen. Outcomes: the chosen one and its reward
    for (var _i = 0; _i < _n; _i++) {
        if (_outcomes && _i != _c) continue;
        var _o = _sample.options[_i];
        var _gain = _outcomes ? _w * _sample.reward : ((_i == _c) ? _w : 0);
        var _act = __gmsa_learn_bayes_act(self, _o.action);
        _act.o += _w;
        _act.c += _gain;
        for (var _j = 0; _j < array_length(_keys); _j++) {
            var _cell = __gmsa_learn_bayes_cell(self, _o.action, _j);
            var _v = __gmsa_learn_bayes_value(self, _o, _j);
            var _lv = _cell.levels;
            var _off = 0;
            for (var _r = 0; _r < array_length(_lv); _r++) {
                var _at = _off + min(_lv[_r] - 1, floor(clamp(_v, 0, 1) * _lv[_r]));
                _cell.O[_at] += _w;
                _cell.C[_at] += _gain;
                _off += _lv[_r];
            }
        }
    }
}

function __gmsa_learn_bayes_predict(_sample, _out) {
    var _n = array_length(_sample.options);
    __gmsa_learn_bayes_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, _n);
    var _best = 0;
    for (var _i = 0; _i < _n; _i++) {
        _out.p[_i] = __p[_i];
        if (__p[_i] > __p[_best]) _best = _i;
    }
    _out.confidence = gmsa_learn_confidence(self, __ev[_best]);
}

function __gmsa_learn_bayes_explain(_sample, _index) {
    var _outcomes = (learns == gmsa_learn_target.OUTCOMES);
    var _keys = __gmsa_learn_bayes_keys(self);
    __gmsa_learn_bayes_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, array_length(_sample.options));
    var _o = _sample.options[_index];
    var _act = __gmsa_learn_bayes_act(self, _o.action);
    if (_act.o <= 0) return [actions[_o.action] + ": no data yet"];

    // each input's own say: a factor on the odds (choices) or an effect on the reward (outcomes)
    var _tau = __gmsa_learn_bayes_tau(self);
    var _base = __b[_index];
    var _k = array_length(_keys);
    var _say = array_create(_k, 0);
    var _where = array_create(_k, "");
    for (var _j = 0; _j < _k; _j++) {
        var _r = __gmsa_learn_bayes_chain(self, _o, _j, _base);
        _say[_j] = _outcomes ? _tau * (_r.rate - _base) : power(max(0.000000001, _r.rate) / max(0.000000001, _base), _tau);
        _where[_j] = _keys[_j] + " " + _r.range;
    }
    var _used = array_create(_k, false);
    var _parts = "";
    for (var _n = 0; _n < min(3, _k); _n++) {
        var _top = -1;
        var _top_size = 0;
        for (var _j = 0; _j < _k; _j++) {
            if (_used[_j]) continue;
            var _size = _outcomes ? abs(_say[_j]) : abs(ln(max(0.000000001, _say[_j])));
            if (_size > _top_size) {
                _top_size = _size;
                _top = _j;
            }
        }
        if (_top < 0) break;
        _used[_top] = true;
        _parts += ", " + _where[_top] + " " + (_outcomes ? __gmsa_learn_signed(_say[_top]) : "x" + string_format(_say[_top], 1, 2));
    }
    if (_outcomes) {
        return [actions[_o.action] + ": base " + __gmsa_learn_signed(_base) + _parts + ", expected " + __gmsa_learn_signed(_base + _tau * __sum[_index])];
    }
    return [actions[_o.action] + ": picked " + string(round(_base * 100)) + "% of the time" + _parts + " (p " + string_format(__p[_index], 1, 2) + ")"];
}

function __gmsa_learn_bayes_save() {
    return { has_keys : (data.keys != undefined), keys : (data.keys != undefined) ? data.keys : [],
             clock : data.clock, acts : data.acts, cells : data.cells, loss : data.loss };
}

function __gmsa_learn_bayes_load(_data) {
    if (!is_struct(_data[$ "acts"]) || !is_struct(_data[$ "cells"]) || !is_array(_data[$ "loss"])) throw "GMSA: bayes save is malformed";
    // every input must be cut the same way as when it was saved
    var _names = variable_struct_get_names(_data.cells);
    for (var _i = 0; _i < array_length(_names); _i++) {
        var _input = string_copy(_names[_i], string_pos("|", _names[_i]) + 1, string_length(_names[_i]));
        var _want = __gmsa_learn_bayes_levels(self, _input);
        var _have = _data.cells[$ _names[_i]].levels;
        if (_have[array_length(_have) - 1] != _want[array_length(_want) - 1]) {
            throw "GMSA: bayes save cuts " + _input + " into " + string(_have[array_length(_have) - 1]) + " bins, the model into " + string(_want[array_length(_want) - 1]);
        }
    }
    var _loss = array_create(array_length(bayes.tempers), 0);
    array_copy(_loss, 0, _data.loss, 0, min(array_length(_loss), array_length(_data.loss)));
    data = { keys : _data.has_keys ? _data.keys : bayes.names, clock : _data.clock, acts : _data.acts, cells : _data.cells, loss : _loss };
    array_resize(__cell, 0);
}

// Internal
function __gmsa_learn_bayes_whole(_value) {
    return is_numeric(_value) && _value >= 1 && frac(_value) == 0;
}

function __gmsa_learn_bayes_keys(_model) {
    var _d = _model.data;
    if (_d.keys == undefined) {
        var _keys = [];
        for (var _i = 0; _i < array_length(_model.inputs); _i++) array_push(_keys, _model.inputs[_i]);
        _d.keys = _keys;
    }
    var _k = array_length(_d.keys);
    array_resize(_model.__kid, _k);
    for (var _j = 0; _j < _k; _j++) {
        _model.__kid[_j] = variable_struct_exists(_model.input_lookup, _d.keys[_j]) ? _model.input_lookup[$ _d.keys[_j]] : -1;
    }
    return _d.keys;
}

function __gmsa_learn_bayes_levels(_model, _name) {
    var _b = variable_struct_exists(_model.bayes.input_bins, _name) ? _model.bayes.input_bins[$ _name] : _model.bayes.bins;
    var _levels = [];
    if (_b <= 2) {
        array_push(_levels, _b);
        return _levels;
    }
    var _c = 2;
    while (_c < _b) {
        array_push(_levels, _c);
        _c *= 2;
    }
    array_push(_levels, _b);
    return _levels;
}

function __gmsa_learn_bayes_value(_model, _option, _j) {
    var _id = _model.__kid[_j];
    return (_id >= 0 && _id < array_length(_option.inputs)) ? _option.inputs[_id] : 0;
}

function __gmsa_learn_bayes_act(_model, _a) {
    var _d = _model.data;
    var _name = _model.actions[_a];
    var _t = _d.acts[$ _name];
    if (_t == undefined) {
        _t = { o : 0, c : 0, last : _d.clock };
        _d.acts[$ _name] = _t;
        return _t;
    }
    var _age = _d.clock - _t.last;
    if (_age > 0) {
        var _f = power(_model.decay, _age);
        _t.o *= _f;
        _t.c *= _f;
        _t.last = _d.clock;
    }
    return _t;
}

function __gmsa_learn_bayes_cell(_model, _a, _j) {
    while (array_length(_model.__cell) <= _a) array_push(_model.__cell, []);
    var _row = _model.__cell[_a];
    while (array_length(_row) <= _j) array_push(_row, undefined);
    var _d = _model.data;
    var _cell = _row[_j];
    if (_cell == undefined) {
        var _key = _model.actions[_a] + "|" + _d.keys[_j];
        _cell = _d.cells[$ _key];
        if (_cell == undefined) {
            var _levels = __gmsa_learn_bayes_levels(_model, _d.keys[_j]);
            var _size = 0;
            for (var _r = 0; _r < array_length(_levels); _r++) _size += _levels[_r];
            _cell = { levels : _levels, O : array_create(_size, 0), C : array_create(_size, 0), last : _d.clock };
            _d.cells[$ _key] = _cell;
        }
        _row[@ _j] = _cell;
    }
    var _age = _d.clock - _cell.last;
    if (_age > 0) {
        var _f = power(_model.decay, _age);
        for (var _i = 0; _i < array_length(_cell.O); _i++) {
            _cell.O[_i] *= _f;
            _cell.C[_i] *= _f;
        }
        _cell.last = _d.clock;
    }
    return _cell;
}

function __gmsa_learn_bayes_chain(_model, _option, _j, _base) {
    static _r = { rate : 0, evidence : 0, range : "" };
    var _outcomes = (_model.learns == gmsa_learn_target.OUTCOMES);
    var _cell = __gmsa_learn_bayes_cell(_model, _option.action, _j);
    var _v = clamp(__gmsa_learn_bayes_value(_model, _option, _j), 0, 1);
    var _lv = _cell.levels;
    var _m = _model.bayes.smoothing;
    var _rate = _base;
    var _off = 0;
    var _ev = 0;
    var _shown = -1;
    for (var _i = 0; _i < array_length(_lv); _i++) {
        var _b = min(_lv[_i] - 1, floor(_v * _lv[_i]));
        var _O = _cell.O[_off + _b];
        var _C = _cell.C[_off + _b];
        if (!_outcomes) _rate = (_C + _m * _rate) / (_O + _m);
        else if (_O * 1000000000000 > 0) _rate = (_C + _m * _rate) / (_O + _m);
        _ev = _O;
        if (_O >= 1 || _shown < 0) _shown = _i;
        _off += _lv[_i];
    }
    var _n = _lv[_shown];
    var _bin = min(_n - 1, floor(_v * _n));
    _r.rate = _rate;
    _r.evidence = _ev;
    _r.range = string(round(_bin / _n * 100)) + "-" + string(round((_bin + 1) / _n * 100)) + "%";
    return _r;
}

function __gmsa_learn_bayes_evidence(_model, _sample) {
    var _outcomes = (_model.learns == gmsa_learn_target.OUTCOMES);
    var _keys = __gmsa_learn_bayes_keys(_model);
    var _k = array_length(_keys);
    var _n = array_length(_sample.options);
    array_resize(_model.__b, _n);
    array_resize(_model.__sum, _n);
    array_resize(_model.__ev, _n);
    for (var _i = 0; _i < _n; _i++) {
        var _o = _sample.options[_i];
        var _act = __gmsa_learn_bayes_act(_model, _o.action);
        var _base = _outcomes ? ((_act.o * 1000000000000 > 0) ? _act.c / _act.o : 0) : (_act.c + 1) / (_act.o + 2);
        var _sum = 0;
        var _ev = 0;
        for (var _j = 0; _j < _k; _j++) {
            var _r = __gmsa_learn_bayes_chain(_model, _o, _j, _base);
            _sum += _outcomes ? (_r.rate - _base) : ln(max(0.000000001, _r.rate) / max(0.000000001, _base));
            _ev += _r.evidence;
        }
        _model.__b[_i] = _base;
        _model.__sum[_i] = _sum;
        _model.__ev[_i] = (_k > 0) ? _ev / _k : _act.o;
    }
}

function __gmsa_learn_bayes_scores(_model, _sample) {
    __gmsa_learn_bayes_evidence(_model, _sample);
    var _tau = __gmsa_learn_bayes_tau(_model);
    var _n = array_length(_sample.options);
    var _outcomes = (_model.learns == gmsa_learn_target.OUTCOMES);
    array_resize(_model.__s, _n);
    for (var _i = 0; _i < _n; _i++) {
        _model.__s[_i] = _outcomes ? _model.__b[_i] + _tau * _model.__sum[_i] : ln(_model.__b[_i]) + _tau * _model.__sum[_i];
    }
}

function __gmsa_learn_bayes_tau(_model) {
    var _b = _model.bayes;
    if (!is_string(_b.temper)) return _b.temper;
    var _loss = _model.data.loss;
    var _best = 0;
    for (var _i = 1; _i < array_length(_b.tempers); _i++) {
        if (_loss[_i] < _loss[_best] * (1 - _b.margin)) _best = _i;
    }
    return _b.tempers[_best];
}