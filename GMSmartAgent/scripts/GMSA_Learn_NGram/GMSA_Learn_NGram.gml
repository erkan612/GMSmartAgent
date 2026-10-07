function gmsa_learn_ngram_create(_params = {}) {
    static _next_id = 0;
    var _length = __gmsa_param(_params, "length", 3);
    if (!is_numeric(_length) || _length < 1 || frac(_length) != 0) throw "GMSA: n-gram length must be a whole number of 1 or more";
    var _bins = __gmsa_param(_params, "bins", 8);
    if (!is_numeric(_bins) || _bins < 1 || frac(_bins) != 0) throw "GMSA: n-gram bins must be a whole number of 1 or more";
    var _capacity = __gmsa_param(_params, "capacity", 4096);
    if (!is_numeric(_capacity) || _capacity < 1 || frac(_capacity) != 0) throw "GMSA: n-gram capacity must be a whole number of 1 or more";
    var _blend = __gmsa_param(_params, "blend_k", 3);
    if (!is_numeric(_blend) || _blend < 0) throw "GMSA: n-gram blend_k must be a number of 0 or more";
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
    _model.ngram = { id : _next_id, gen : 0, length : _length, bins : _bins, capacity : _capacity, blend_k : _blend, names : _names, levels : _levels };
    _next_id += 1;
    _model.__sitkey = [];  // the situation at each resolution, as part of a key
    _model.__histkey = []; // the history at each length, as part of a key
    _model.__ids = [];     // the history in use, oldest first
    _model.__K = 0;
    _model.__R = 0;
    _model.__lp = [];      // per context in the lattice: its estimate per action
    _model.__lc = [];      // its confidence
    _model.__lown = [];    // how much of its estimate is its own data
    _model.__lw = [];      // the share it took from the shorter history (the rest from the coarser situation)
    _model.__lkey = [];    // its key
    _model.__ls = [];      // explain: each context's share of the final estimate
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
    array_push(_h.ids, -1);  // the start: what comes first is a habit too
    var _tracker = _agent[$ "__history"];
    if (_tracker != undefined) _h.cut = _tracker.clock(); // tracked decisions from before now no longer count
}

// Methods, run with the model as self
function __gmsa_learn_ngram_reset() {
    // shared: per place in the lattice (history length, resolution), the blend its contexts use until they have their own
    data = { keys : ngram.names, clock : 0, contexts : {}, count : 0,
             shared : array_create(2 * (ngram.length + 1) * array_length(ngram.levels), 1) };
    ngram.gen += 1; // every agent's history for this model starts over
}

function __gmsa_learn_ngram_observe(_sample) {
    var _outcomes = (learns == gmsa_learn_target.OUTCOMES);
    var _h = __gmsa_learn_ngram_history(self, _sample.agent);
    if (_outcomes) __gmsa_learn_ngram_tracked(self, _sample.agent, _h, _sample.from);
    else __gmsa_learn_ngram_use(self, _h.ids);
    __gmsa_learn_ngram_prepare(self, _sample);
    var _A = array_length(actions);
    var _a = _sample.options[_sample.chosen].action;

    // estimate first, so every context's blend learns which parent foresaw this
    __gmsa_learn_ngram_lattice(self, _A, true, _a, _outcomes ? _sample.reward : 0);

    // count it in every context, each fading only when it comes up again
    data.clock += 1;
    var _N = (__K + 1) * (__R + 1);
    for (var _i = 0; _i < _N; _i++) {
        var _ctx = __gmsa_learn_ngram_get(self, __lkey[_i]);
        for (var _j = 0; _j < array_length(_ctx.c); _j++) _ctx.c[_j] *= decay;
        for (var _j = 0; _j < array_length(_ctx.r); _j++) _ctx.r[_j] *= decay;
        _ctx.n *= decay;
        while (array_length(_ctx.c) <= _a) array_push(_ctx.c, 0);
        _ctx.c[_a] += _sample.weight;
        _ctx.n += _sample.weight;
        if (_outcomes) {
            while (array_length(_ctx.r) <= _a) array_push(_ctx.r, 0);
            _ctx.r[_a] += _sample.weight * _sample.reward;
        }
        _ctx.last = data.clock;
    }
    __gmsa_learn_ngram_trim(self);

    if (!_outcomes) { // choices keep their own history, outcomes read the tracker's
        array_push(_h.ids, _a);
        if (array_length(_h.ids) > ngram.length) array_delete(_h.ids, 0, 1);
    }
}

function __gmsa_learn_ngram_predict(_sample, _out) {
    var _h = __gmsa_learn_ngram_history(self, _sample.agent);
    if (learns == gmsa_learn_target.OUTCOMES) __gmsa_learn_ngram_tracked(self, _sample.agent, _h, undefined);
    else __gmsa_learn_ngram_use(self, _h.ids);
    __gmsa_learn_ngram_prepare(self, _sample);
    var _A = array_length(actions);
    __gmsa_learn_ngram_lattice(self, _A, false, -1, 0);
    var _last = (__K + 1) * (__R + 1) - 1;
    var _P = __lp[_last];
    var _n = array_length(_sample.options);

    if (learns == gmsa_learn_target.OUTCOMES) {
        // expected rewards become preferences through the temperature
        var _max = -infinity;
        for (var _i = 0; _i < _n; _i++) _max = max(_max, _P[_sample.options[_i].action]);
        for (var _i = 0; _i < _n; _i++) _out.p[_i] = exp((_P[_sample.options[_i].action] - _max) / temperature);
    } else {
        // options with the same action share its prediction
        array_resize(__per, _A);
        for (var _a = 0; _a < _A; _a++) __per[_a] = 0;
        for (var _i = 0; _i < _n; _i++) __per[_sample.options[_i].action] += 1;
        for (var _i = 0; _i < _n; _i++) {
            var _a = _sample.options[_i].action;
            _out.p[_i] = _P[_a] / __per[_a];
        }
    }
    _out.confidence = __lc[_last];
}

function __gmsa_learn_ngram_explain(_sample, _index) {
    var _outcomes = (learns == gmsa_learn_target.OUTCOMES);
    var _h = __gmsa_learn_ngram_history(self, _sample.agent);
    if (_outcomes) __gmsa_learn_ngram_tracked(self, _sample.agent, _h, undefined);
    else __gmsa_learn_ngram_use(self, _h.ids);
    __gmsa_learn_ngram_prepare(self, _sample);
    var _A = array_length(actions);
    __gmsa_learn_ngram_lattice(self, _A, false, -1, 0);
    var _a = _sample.options[_index].action;

    // each context's share of the final estimate: its own data, the rest passed on to its parents by its blend
    var _RR = __R + 1;
    var _N = (__K + 1) * _RR;
    array_resize(__ls, _N);
    for (var _i = 0; _i < _N; _i++) __ls[_i] = 0;
    __ls[_N - 1] = 1;
    var _best = -1;
    var _best_w = 0;
    for (var _i = _N - 1; _i >= 0; _i--) {
        var _w = __ls[_i] * __lown[_i];
        if (_w > _best_w) {
            _best_w = _w;
            _best = _i;
        }
        var _rest = __ls[_i] * (1 - __lown[_i]);
        if (_i div _RR > 0) __ls[_i - _RR] += _rest * __lw[_i];
        if (_i mod _RR > 0) __ls[_i - 1] += _rest * (1 - __lw[_i]);
    }
    if (_best < 0) return [actions[_a] + ": nothing learned yet for this moment"];

    var _ctx = data.contexts[$ __lkey[_best]];
    var _where = __gmsa_learn_ngram_where(self, _sample, _best div _RR, _best mod _RR);
    var _c = (_a < array_length(_ctx.c)) ? _ctx.c[_a] : 0;
    if (_outcomes) {
        if (_c <= 0) return [_where + ": " + actions[_a] + " not tried here yet"];
        return [_where + ": " + actions[_a] + " averages " + __gmsa_learn_signed(_ctx.r[_a] / _c) + " from " + string_format(_c, 1, 1) + " outcomes"];
    }
    // does the whole prediction favour what this context favours?
    var _P = __lp[_N - 1];
    var _fav = 0;
    for (var _i = 1; _i < array_length(_ctx.c); _i++) if (_ctx.c[_i] > _ctx.c[_fav]) _fav = _i;
    var _top = 0;
    for (var _i = 1; _i < _A; _i++) if (_P[_i] > _P[_top]) _top = _i;
    return [_where + ": " + actions[_a] + " " + string_format(_c, 1, 1) + " of " + string_format(_ctx.n, 1, 1)
        + ((_fav == _top) ? ", the rest agree" : ", the rest disagree") + " (p " + string_format(_P[_a], 1, 2) + ")"];
}

function __gmsa_learn_ngram_save() {
    return { bins : ngram.bins, has_keys : (data.keys != undefined), keys : (data.keys != undefined) ? data.keys : [],
             clock : data.clock, shared : data.shared, contexts : data.contexts };
}

function __gmsa_learn_ngram_load(_data) {
    if (_data.bins != ngram.bins) throw "GMSA: n-gram save uses " + string(_data.bins) + " bins, the model uses " + string(ngram.bins);
    data.keys = _data.has_keys ? _data.keys : ngram.names;
    data.clock = _data.clock;
    data.contexts = _data.contexts;
    data.count = array_length(variable_struct_get_names(_data.contexts));
    // a save from a different length keeps the blends both lengths have
    var _size = 2 * (ngram.length + 1) * array_length(ngram.levels);
    var _shared = array_create(_size, 1);
    array_copy(_shared, 0, _data.shared, 0, min(_size, array_length(_data.shared)));
    data.shared = _shared;
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
        _h = { gen : _model.ngram.gen, ids : [-1], cut : -infinity }; // -1 marks the start of a history
        _all[$ _key] = _h;
    }
    return _h;
}

function __gmsa_learn_ngram_use(_model, _ids) {
    array_resize(_model.__ids, array_length(_ids));
    array_copy(_model.__ids, 0, _ids, 0, array_length(_ids));
}

function __gmsa_learn_ngram_tracked(_model, _agent, _h, _upto) {
    var _tracker = _agent[$ "__history"];
    if (_tracker == undefined) throw "GMSA: an n-gram learner from outcomes needs a tracked agent, start with gmsa_learn_track";
    if (_tracker.size <= _model.ngram.length) {
        throw "GMSA: the n-gram length is " + string(_model.ngram.length) + ", track the agent with a size of at least "
            + string(_model.ngram.length + 1) + " (gmsa_learn_track(agent, { size : " + string(_model.ngram.length + 1) + " }))";
    }
    var _entries = _tracker.entries;
    var _end = array_length(_entries);
    if (_upto != undefined) {
        for (var _i = 0; _i < array_length(_entries); _i++) {
            if (_entries[_i] == _upto) {
                _end = _i;
                break;
            }
        }
    }
    var _first = 0;
    while (_first < _end && _entries[_first].start < _h.cut) _first += 1;
    // the start is known after a break, or while the tracker hasn't dropped anything yet
    var _known = (_h.cut > -infinity) || (array_length(_entries) < _tracker.size);
    var _binding = __gmsa_learn_bind(_model, _agent.profile);
    array_resize(_model.__ids, 0);
    if (_known) array_push(_model.__ids, -1);
    for (var _i = _first; _i < _end; _i++) {
        var _en = _entries[_i];
        array_push(_model.__ids, _binding.actions[_en.options[_en.chosen].action.index]);
    }
    var _extra = array_length(_model.__ids) - _model.ngram.length;
    if (_extra > 0) array_delete(_model.__ids, 0, _extra);
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

function __gmsa_learn_ngram_prepare(_model, _sample) {
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
    var _ids = _model.__ids;
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

function __gmsa_learn_ngram_lattice(_model, _A, _update, _a, _reward) {
    var _outcomes = (_model.learns == gmsa_learn_target.OUTCOMES);
    var _K = _model.__K;
    var _R = _model.__R;
    var _RR = _R + 1;
    var _N = (_K + 1) * _RR;
    var _RL = array_length(_model.ngram.levels);
    var _bk = _model.ngram.blend_k;
    var _m = _K + _R + 1;
    var _contexts = _model.data.contexts;
    while (array_length(_model.__lp) < _N) array_push(_model.__lp, []);
    array_resize(_model.__lc, _N);
    array_resize(_model.__lown, _N);
    array_resize(_model.__lw, _N);
    array_resize(_model.__lkey, _N);

    for (var _k = 0; _k <= _K; _k++) {
        for (var _r = 0; _r <= _R; _r++) {
            var _i = _k * _RR + _r;
            var _key = _model.__histkey[_k] + "|" + _model.__sitkey[_r];
            _model.__lkey[_i] = _key;
            var _ctx = _contexts[$ _key];
            var _p = _model.__lp[_i];
            array_resize(_p, _A);
            var _pconf = 0;
            var _w0 = 1;

            if (_k == 0 && _r == 0) {
                for (var _j = 0; _j < _A; _j++) _p[@ _j] = _outcomes ? 0 : 1 / _A;
            } else if (_k == 0 || _r == 0) {
                var _par = (_k > 0) ? _i - _RR : _i - 1;
                _w0 = (_k > 0) ? 1 : 0;
                array_copy(_p, 0, _model.__lp[_par], 0, _A);
                _pconf = _model.__lc[_par];
            } else {
                var _p0 = _model.__lp[_i - _RR];  // one choice less of history
                var _p1 = _model.__lp[_i - 1];    // one step coarser situation
                var _s = 2 * (_k * _RL + _r);
                var _g0 = _model.data.shared[_s];
                var _g1 = _model.data.shared[_s + 1];
                var _gn = _g0 / (_g0 + _g1);
                var _n = 0;
                var _ln = _gn;
                if (_ctx != undefined) {
                    _n = _ctx.n;
                    if (array_length(_ctx.w) == 2) _ln = _ctx.w[0] / (_ctx.w[0] + _ctx.w[1]);
                }
                _w0 = (_n + _bk > 0) ? (_n * _ln + _bk * _gn) / (_n + _bk) : _gn;
                for (var _j = 0; _j < _A; _j++) _p[@ _j] = _w0 * _p0[_j] + (1 - _w0) * _p1[_j];
                _pconf = _w0 * _model.__lc[_i - _RR] + (1 - _w0) * _model.__lc[_i - 1];

                if (_update) {
                    var _f0 = max(0.000001, _outcomes ? exp(-sqr(_p0[_a] - _reward)) : _p0[_a]);
                    var _f1 = max(0.000001, _outcomes ? exp(-sqr(_p1[_a] - _reward)) : _p1[_a]);
                    var _d = _model.decay;
                    if (_ctx != undefined) {
                        if (array_length(_ctx.w) != 2) _ctx.w = [1, 1];
                        var _x0 = power(_ctx.w[0], _d) * _f0;
                        var _x1 = power(_ctx.w[1], _d) * _f1;
                        var _top = max(_x0, _x1);
                        _ctx.w[0] = _x0 / _top;
                        _ctx.w[1] = _x1 / _top;
                    }
                    var _y0 = power(_g0, _d) * _f0;
                    var _y1 = power(_g1, _d) * _f1;
                    var _top2 = max(_y0, _y1);
                    _model.data.shared[_s] = _y0 / _top2;
                    _model.data.shared[_s + 1] = _y1 / _top2;
                }
            }

            var _own = 0;
            if (_ctx != undefined && _ctx.n * 1000000000000 > 0) {
                var _t = 0;
                for (var _j = 0; _j < array_length(_ctx.c); _j++) if (_ctx.c[_j] > 0.05) _t += 1;
                _own = _ctx.n / (_ctx.n + max(_t, 1) + _k);
                for (var _j = 0; _j < _A; _j++) {
                    var _c = (_j < array_length(_ctx.c)) ? _ctx.c[_j] : 0;
                    if (_outcomes) {
                        if (!(_c * 1000000000000 > 0)) continue;
                        var _oa = _c / (_c + 1 + _k);
                        _p[@ _j] = _oa * _ctx.r[_j] / _c + (1 - _oa) * _p[_j];
                    } else {
                        _p[@ _j] = _own * _c / _ctx.n + (1 - _own) * _p[_j];
                    }
                }
            }
            _model.__lown[_i] = _own;
            _model.__lw[_i] = _w0;
            // confidence: its own share, the more specific counting more, plus what it took from its parents
            _model.__lc[_i] = _own * sqrt((_k + _r + 1) / _m) + (1 - _own) * _pconf;
        }
    }
}

function __gmsa_learn_ngram_get(_model, _key) {
    var _d = _model.data;
    var _ctx = _d.contexts[$ _key];
    if (_ctx == undefined) {
        _ctx = { c : [], r : [], n : 0, w : [], last : _d.clock };
        _d.contexts[$ _key] = _ctx;
        _d.count += 1;
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

function __gmsa_learn_ngram_where(_model, _sample, _k, _r) {
    var _parts = [];
    var _lvl = _model.ngram.levels[_r];
    var _keys = _model.data.keys;
    for (var _j = 0; _j < array_length(_keys) && _lvl > 0; _j++) {
        var _id = variable_struct_exists(_model.input_lookup, _keys[_j]) ? _model.input_lookup[$ _keys[_j]] : -1;
        var _v = (_id >= 0 && _id < array_length(_sample.situation)) ? _sample.situation[_id] : 0;
        var _b = min(_lvl - 1, floor(clamp(_v, 0, 1) * _lvl));
        array_push(_parts, _keys[_j] + " " + string(round(_b / _lvl * 100)) + "-" + string(round((_b + 1) / _lvl * 100)) + "%");
    }
    if (_k > 0) {
        var _ids = _model.__ids;
        var _from_start = false;
        var _names = "";
        for (var _i = _k; _i >= 1; _i--) {
            var _id = _ids[array_length(_ids) - _i];
            if (_id < 0) {
                _from_start = true;
                continue;
            }
            _names += ((_names == "") ? "" : " then ") + _model.actions[_id];
        }
        if (_names == "") array_push(_parts, "at the start");
        else array_push(_parts, (_from_start ? "from the start, after " : "after ") + _names);
    }
    if (array_length(_parts) == 0) return "any moment";
    var _text = _parts[0];
    for (var _i = 1; _i < array_length(_parts); _i++) _text += ", " + _parts[_i];
    return _text;
}