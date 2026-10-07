function gmsa_learn_ngram_create(_params = {}) {
    static _next_id = 0;
    var _length = __gmsa_param(_params, "length", 3);
    if (!is_numeric(_length) || _length < 1 || frac(_length) != 0) throw "GMSA: n-gram length must be a whole number of 1 or more";
    var _bins = __gmsa_param(_params, "bins", 8);
    if (!is_numeric(_bins) || _bins < 1 || frac(_bins) != 0) throw "GMSA: n-gram bins must be a whole number of 1 or more";
    var _capacity = __gmsa_param(_params, "capacity", 4096);
    if (!is_numeric(_capacity) || _capacity < 1 || frac(_capacity) != 0) throw "GMSA: n-gram capacity must be a whole number of 1 or more";
    var _names = __gmsa_param(_params, "inputs", undefined);
    if (_names != undefined && !is_array(_names)) throw "GMSA: n-gram inputs must be an array of input names";

    var _model = __gmsa_learn_model_create(gmsa_learn_tier.NGRAM, "ngram", {
        half_life    : __gmsa_param(_params, "half_life", 50),
        confidence_k : __gmsa_param(_params, "confidence_k", 5),
        learns       : __gmsa_param(_params, "learns", gmsa_learn_target.CHOICES),
        temperature  : __gmsa_param(_params, "temperature", 0.1),
    });
    // resolutions of the situation: none, halves, quarters, eighths ... up to bins
    var _levels = [0];
    if (_bins > 1) {
        var _b = 2;
        while (_b < _bins) {
            array_push(_levels, _b);
            _b *= 2;
        }
        array_push(_levels, _bins);
    }
    _model.ngram = { id : _next_id, gen : 0, length : _length, bins : _bins, capacity : _capacity, names : _names, levels : _levels };
    _next_id += 1;
    _model.__chains = [];  // per history length: the three chains through the contexts
    _model.__sitkey = [];  // the situation at each resolution, as part of a key
    _model.__histkey = []; // the history at each length, as part of a key
    _model.__K = 0;
    _model.__R = 0;
    _model.__pc = [[], [], []];
    _model.__cc = [0, 0, 0];
    _model.__own = [];
    _model.__mixp = [];
    _model.__mixc = 0;
    _model.__per = [];
    _model.observe    = method(_model, __gmsa_learn_ngram_observe);
    _model.predict    = method(_model, __gmsa_learn_ngram_predict);
    _model.explain    = method(_model, __gmsa_learn_ngram_explain);
    _model.save_data  = method(_model, __gmsa_learn_ngram_save);
    _model.load_data  = method(_model, __gmsa_learn_ngram_load);
    _model.reset_data = method(_model, __gmsa_learn_ngram_reset);
    _model.reset_data();
    return _model;
}

function gmsa_learn_ngram_break(_model, _agent) {
    if (!is_struct(_model) || _model[$ "ngram"] == undefined) throw "GMSA: n-gram break needs a model from gmsa_learn_ngram_create";
    var _h = __gmsa_learn_ngram_history(_model, _agent);
    array_resize(_h.ids, 0);
    array_push(_h.ids, -1); // the start: what comes first is a habit too
}

// Methods, run with the model as self
function __gmsa_learn_ngram_reset() {
    data = { keys : ngram.names, clock : 0, contexts : {}, count : 0, mix : [1, 1, 1] };
    ngram.gen += 1;  // every agent's history for this model starts over
}

function __gmsa_learn_ngram_observe(_sample) {
    if (learns == gmsa_learn_target.OUTCOMES) throw "GMSA: n-gram learning from outcomes isn't ready yet";
    var _h = __gmsa_learn_ngram_history(self, _sample.agent);
    __gmsa_learn_ngram_prepare(self, _sample, _h.ids);
    var _A = array_length(actions);
    var _a = _sample.options[_sample.chosen].action;

    // which chain predicted it best: the mix learns whether this player's habits follow order, the situation or both
    __gmsa_learn_ngram_mix(self, _A);
    var _top = 0;
    for (var _e = 0; _e < 3; _e++) {
        data.mix[_e] = power(data.mix[_e], decay) * max(0.000001, __pc[_e][_a]);
        _top = max(_top, data.mix[_e]);
    }
    for (var _e = 0; _e < 3; _e++) data.mix[_e] /= _top;

    // count the choice in every context on the three chains
    data.clock += 1;
    var _union = __gmsa_learn_ngram_chains(self).union;
    for (var _i = 0; _i < array_length(_union); _i += 2) {
        var _ctx = __gmsa_learn_ngram_get(self, __histkey[_union[_i]] + "|" + __sitkey[_union[_i + 1]], true);
        while (array_length(_ctx.c) <= _a) array_push(_ctx.c, 0);
        _ctx.c[_a] += _sample.weight;
        _ctx.n += _sample.weight;
    }
    __gmsa_learn_ngram_trim(self);

    array_push(_h.ids, _a);
    if (array_length(_h.ids) > ngram.length) array_delete(_h.ids, 0, 1);
}

function __gmsa_learn_ngram_predict(_sample, _out) {
    if (learns == gmsa_learn_target.OUTCOMES) throw "GMSA: n-gram learning from outcomes isn't ready yet";
    var _h = __gmsa_learn_ngram_history(self, _sample.agent);
    __gmsa_learn_ngram_prepare(self, _sample, _h.ids);
    var _A = array_length(actions);
    __gmsa_learn_ngram_mix(self, _A);

    // options with the same action share its prediction
    var _n = array_length(_sample.options);
    array_resize(__per, _A);
    for (var _a = 0; _a < _A; _a++) __per[_a] = 0;
    for (var _i = 0; _i < _n; _i++) __per[_sample.options[_i].action] += 1;
    for (var _i = 0; _i < _n; _i++) {
        var _a = _sample.options[_i].action;
        _out.p[_i] = __mixp[_a] / __per[_a];
    }
    _out.confidence = __mixc;
}

function __gmsa_learn_ngram_explain(_sample, _index) {
    var _h = __gmsa_learn_ngram_history(self, _sample.agent);
    __gmsa_learn_ngram_prepare(self, _sample, _h.ids);
    var _A = array_length(actions);
    __gmsa_learn_ngram_mix(self, _A);
    var _a = _sample.options[_index].action;

    // the chain this player's habits follow best, and its node with the most weight in the prediction
    var _e = 0;
    for (var _i = 1; _i < 3; _i++) if (data.mix[_i] > data.mix[_e]) _e = _i;
    var _chain = __gmsa_learn_ngram_chains(self).chains[_e];
    __gmsa_learn_ngram_chain(self, _e, _chain, _A);
    var _m = array_length(_chain) div 2;
    var _best = -1;
    var _best_w = 0;
    var _rest = 1;
    for (var _i = _m - 1; _i >= 0; _i--) {
        var _w = _rest * __own[_i];
        if (_w > _best_w) {
            _best_w = _w;
            _best = _i;
        }
        _rest *= 1 - __own[_i];
    }
    if (_best < 0) return [actions[_a] + ": nothing learned yet for this moment"];

    var _k = _chain[_best * 2];
    var _r = _chain[_best * 2 + 1];
    var _ctx = __gmsa_learn_ngram_get(self, __histkey[_k] + "|" + __sitkey[_r], false);
    var _where = __gmsa_learn_ngram_where(self, _sample, _h.ids, _k, _r);
    var _c = (_a < array_length(_ctx.c)) ? _ctx.c[_a] : 0;

    // does the whole prediction favour what this context favours?
    var _fav = 0;
    for (var _i = 1; _i < array_length(_ctx.c); _i++) if (_ctx.c[_i] > _ctx.c[_fav]) _fav = _i;
    var _top = 0;
    for (var _i = 1; _i < _A; _i++) if (__mixp[_i] > __mixp[_top]) _top = _i;
    return [_where + ": " + actions[_a] + " " + string_format(_c, 1, 1) + " of " + string_format(_ctx.n, 1, 1)
        + ((_fav == _top) ? ", the rest agree" : ", the rest disagree") + " (p " + string_format(__mixp[_a], 1, 2) + ")"];
}

function __gmsa_learn_ngram_save() {
    return { bins : ngram.bins, has_keys : (data.keys != undefined), keys : (data.keys != undefined) ? data.keys : [],
             clock : data.clock, mix : data.mix, contexts : data.contexts };
}

function __gmsa_learn_ngram_load(_data) {
    if (_data.bins != ngram.bins) throw "GMSA: n-gram save uses " + string(_data.bins) + " bins, the model uses " + string(ngram.bins);
    data.keys = _data.has_keys ? _data.keys : ngram.names;
    data.clock = _data.clock;
    data.mix = _data.mix;
    data.contexts = _data.contexts;
    data.count = array_length(variable_struct_get_names(_data.contexts));
    ngram.gen += 1; // histories aren't saved, the next choices start fresh
}

// Internal
function __gmsa_learn_ngram_history(_model, _agent) {
    if (!is_struct(_agent) || !is_struct(_agent[$ "profile"]) || _agent.profile[$ "__decision"] != undefined) {
        throw "GMSA: the n-gram learner needs an agent's history, learn spaces have none";
    }
    var _all = _agent[$ "__ngram"];
    if (_all == undefined) {
        _all = {};
        _agent.__ngram = _all;
    }
    var _key = string(_model.ngram.id);
    var _h = _all[$ _key];
    if (_h == undefined || _h.gen != _model.ngram.gen) {
        _h = { gen : _model.ngram.gen, ids : [-1] }; // -1 marks the start of a history
        _all[$ _key] = _h;
    }
    return _h;
}

function __gmsa_learn_ngram_keys(_model) {
    var _d = _model.data;
    if (_d.keys == undefined) {
        var _keys = [];
        for (var _i = 0; _i < array_length(_model.inputs); _i++) {
            if (_model.situational[_i]) array_push(_keys, _model.inputs[_i]);
        }
        _d.keys = _keys;
    }
    return _d.keys;
}

function __gmsa_learn_ngram_prepare(_model, _sample, _ids) {
    var _keys = __gmsa_learn_ngram_keys(_model);
    var _levels = _model.ngram.levels;
    var _R = (array_length(_keys) == 0) ? 0 : array_length(_levels) - 1;
    for (var _r = 0; _r <= _R; _r++) {
        var _lvl = _levels[_r];
        var _s = string(_r);
        for (var _j = 0; _j < array_length(_keys) && _lvl > 0; _j++) {
            var _id = variable_struct_exists(_model.input_lookup, _keys[_j]) ? _model.input_lookup[$ _keys[_j]] : -1;
            var _v = (_id >= 0 && _id < array_length(_sample.situation)) ? _sample.situation[_id] : 0;
            _s += ":" + string(min(_lvl - 1, floor(clamp(_v, 0, 1) * _lvl)));
        }
        _model.__sitkey[_r] = _s;
    }
    var _K = min(_model.ngram.length, array_length(_ids));
    var _hk = "";
    _model.__histkey[0] = "";
    for (var _k = 1; _k <= _K; _k++) {
        _hk += "," + string(_ids[array_length(_ids) - _k]); // most recent first
        _model.__histkey[_k] = _hk;
    }
    _model.__K = _K;
    _model.__R = _R;
}

function __gmsa_learn_ngram_chains(_model) {
    var _K = _model.__K;
    var _R = _model.__R;
    if (_K < array_length(_model.__chains) && _model.__chains[_K] != undefined && _model.__chains[_K].r == _R) return _model.__chains[_K];
    var _sit = [];
    var _his = [];
    var _alt = [];
    for (var _r = 0; _r <= _R; _r++) array_push(_sit, 0, _r);
    for (var _k = 1; _k <= _K; _k++) array_push(_sit, _k, _R);
    for (var _k = 0; _k <= _K; _k++) array_push(_his, _k, 0);
    for (var _r = 1; _r <= _R; _r++) array_push(_his, _K, _r);
    var _k = 0;
    var _r = 0;
    array_push(_alt, 0, 0);
    while (_k < _K || _r < _R) {
        if ((_k <= _r && _k < _K) || _r >= _R) _k += 1;
        else _r += 1;
        array_push(_alt, _k, _r);
    }
    // every node once, for counting
    var _union = [];
    var _seen = {};
    var _chains = [_sit, _his, _alt];
    for (var _c = 0; _c < 3; _c++) {
        var _ch = _chains[_c];
        for (var _i = 0; _i < array_length(_ch); _i += 2) {
            var _id = string(_ch[_i]) + "_" + string(_ch[_i + 1]);
            if (variable_struct_exists(_seen, _id)) continue;
            _seen[$ _id] = true;
            array_push(_union, _ch[_i], _ch[_i + 1]);
        }
    }
    while (array_length(_model.__chains) <= _K) array_push(_model.__chains, undefined);
    _model.__chains[_K] = { r : _R, chains : _chains, union : _union };
    return _model.__chains[_K];
}

function __gmsa_learn_ngram_chain(_model, _e, _chain, _A) {
    array_resize(_model.__pc[_e], _A);
    for (var _a = 0; _a < _A; _a++) _model.__pc[_e][_a] = 1 / _A;
    var _m = array_length(_chain) div 2;
    array_resize(_model.__own, _m);
    for (var _i = 0; _i < _m; _i++) {
        var _k = _chain[_i * 2];
        var _ctx = __gmsa_learn_ngram_get(_model, _model.__histkey[_k] + "|" + _model.__sitkey[_chain[_i * 2 + 1]], false);
        if (_ctx == undefined || !(_ctx.n * 1000000000000 > 0)) {
            _model.__own[_i] = 0;
            continue;
        }
        var _t = 0;
        for (var _a = 0; _a < array_length(_ctx.c); _a++) if (_ctx.c[_a] > 0.05) _t += 1;
        var _own = _ctx.n / (_ctx.n + max(_t, 1) + _k);
        for (var _a = 0; _a < _A; _a++) {
            var _c = (_a < array_length(_ctx.c)) ? _ctx.c[_a] : 0;
            _model.__pc[_e][_a] = _own * _c / _ctx.n + (1 - _own) * _model.__pc[_e][_a];
        }
        _model.__own[_i] = _own;
    }
    // confidence: each context's share of the final prediction, the more specific counting more
    var _conf = 0;
    var _rest = 1;
    for (var _i = _m - 1; _i >= 0; _i--) {
        var _own = _model.__own[_i];
        _conf += _rest * _own * sqrt((_i + 1) / _m);
        _rest *= 1 - _own;
    }
    _model.__cc[_e] = _conf;
}

function __gmsa_learn_ngram_mix(_model, _A) {
    var _entry = __gmsa_learn_ngram_chains(_model);
    var _w = _model.data.mix;
    var _tw = _w[0] + _w[1] + _w[2];
    for (var _e = 0; _e < 3; _e++) __gmsa_learn_ngram_chain(_model, _e, _entry.chains[_e], _A);
    array_resize(_model.__mixp, _A);
    for (var _a = 0; _a < _A; _a++) {
        _model.__mixp[_a] = (_w[0] * _model.__pc[0][_a] + _w[1] * _model.__pc[1][_a] + _w[2] * _model.__pc[2][_a]) / _tw;
    }
    _model.__mixc = (_w[0] * _model.__cc[0] + _w[1] * _model.__cc[1] + _w[2] * _model.__cc[2]) / _tw;
}

function __gmsa_learn_ngram_get(_model, _key, _create) {
    var _d = _model.data;
    var _ctx = _d.contexts[$ _key];
    if (_ctx == undefined) {
        if (!_create) return undefined;
        _ctx = { c : [], n : 0, last : _d.clock };
        _d.contexts[$ _key] = _ctx;
        _d.count += 1;
        return _ctx;
    }
    var _age = _d.clock - _ctx.last;
    if (_age > 0) {
        var _f = power(_model.decay, _age);
        for (var _a = 0; _a < array_length(_ctx.c); _a++) _ctx.c[_a] *= _f;
        _ctx.n *= _f;
        _ctx.last = _d.clock;
    }
    return _ctx;
}

function __gmsa_learn_ngram_trim(_model) {
    var _d = _model.data;
    var _cap = _model.ngram.capacity;
    if (_d.count <= _cap) return;
    var _names = variable_struct_get_names(_d.contexts);
    var _n = array_length(_names);
    var _list = array_create(_n, undefined);
    for (var _i = 0; _i < _n; _i++) _list[_i] = { k : _names[_i], last : _d.contexts[$ _names[_i]].last };
    array_sort(_list, function(_x, _y) { return _x.last - _y.last; });
    var _drop = min(_n, _n - _cap + max(1, _cap div 10));
    for (var _i = 0; _i < _drop; _i++) variable_struct_remove(_d.contexts, _list[_i].k);
    _d.count = _n - _drop;
}

function __gmsa_learn_ngram_where(_model, _sample, _ids, _k, _r) {
    var _parts = "";
    var _lvl = _model.ngram.levels[_r];
    var _keys = _model.data.keys;
    for (var _j = 0; _j < array_length(_keys) && _lvl > 0; _j++) {
        var _id = variable_struct_exists(_model.input_lookup, _keys[_j]) ? _model.input_lookup[$ _keys[_j]] : -1;
        var _v = (_id >= 0 && _id < array_length(_sample.situation)) ? _sample.situation[_id] : 0;
        var _b = min(_lvl - 1, floor(clamp(_v, 0, 1) * _lvl));
        _parts += ((_parts == "") ? "" : ", ") + _keys[_j] + " " + string(round(_b / _lvl * 100)) + "-" + string(round((_b + 1) / _lvl * 100)) + "%";
    }
    if (_k > 0) {
        var _h = "";
        for (var _i = _k; _i >= 1; _i--) {
            var _id = _ids[array_length(_ids) - _i];
            if (_id < 0) {
                _h += (_i == 1) ? "at the start" : "from the start, ";
                continue;
            }
            _h += ((_h == "" || string_char_at(_h, string_length(_h)) == " ") ? ((_h == "") ? "after " : "after ") : " then ") + _model.actions[_id];
        }
        _parts += ((_parts == "") ? "" : ", ") + _h;
    }
    return (_parts == "") ? "any moment" : _parts;
}