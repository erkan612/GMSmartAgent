function gmsa_learn_neighbor_create(_params = {}) {
    var _capacity = __gmsa_param(_params, "capacity", 256);
    if (!__gmsa_learn_neighbor_whole(_capacity)) throw "GMSA: neighbor capacity must be a whole number of 1 or more";
    var _k = __gmsa_param(_params, "k", 8);
    if (!__gmsa_learn_neighbor_whole(_k)) throw "GMSA: neighbor k must be a whole number of 1 or more";
    var _candidates = __gmsa_param(_params, "candidates", 24);
    if (!__gmsa_learn_neighbor_whole(_candidates)) throw "GMSA: neighbor candidates must be a whole number of 1 or more";
    var _weights = __gmsa_param(_params, "weights", {});
    if (!is_struct(_weights)) throw "GMSA: neighbor weights must be a struct of input names and weights";
    var _wn = variable_struct_get_names(_weights);
    for (var _i = 0; _i < array_length(_wn); _i++) {
        var _w = _weights[$ _wn[_i]];
        if (!is_numeric(_w) || _w < 0) throw "GMSA: neighbor weights." + _wn[_i] + " must be a number of 0 or more";
    }
    var _learn_weights = __gmsa_param(_params, "learn_weights", true);
    if (!is_bool(_learn_weights)) throw "GMSA: neighbor learn_weights must be true or false";
    var _importance = __gmsa_param(_params, "importance", 1);
    if (!is_numeric(_importance) || _importance < 0) throw "GMSA: neighbor importance must be a number of 0 or more";
    var _merge = __gmsa_param(_params, "merge", true);
    if (!is_bool(_merge)) throw "GMSA: neighbor merge must be true or false";
    var _similar = __gmsa_param(_params, "similar", 0.15);
    if (!__gmsa_net_above_zero(_similar)) throw "GMSA: neighbor similar must be above 0";
    var _reach = __gmsa_param(_params, "reach", 0.25);
    if (!__gmsa_net_above_zero(_reach)) throw "GMSA: neighbor reach must be above 0";
    var _names = __gmsa_param(_params, "inputs", undefined);
    if (_names != undefined && (!is_array(_names) || array_length(_names) == 0)) throw "GMSA: neighbor inputs must be a non-empty array of input names";

    var _model = __gmsa_learn_model_create(gmsa_learn_tier.NEIGHBOR, "neighbor", {
        half_life    : __gmsa_param(_params, "half_life", 200),
        confidence_k : __gmsa_param(_params, "confidence_k", 2),
        learns       : __gmsa_param(_params, "learns", gmsa_learn_target.CHOICES),
        temperature  : __gmsa_param(_params, "temperature", 0.1),
    });
    _model.neighbor = {
        capacity      : _capacity,
        k             : _k,
        candidates    : _candidates,     // with no situational inputs: moments kept by how close their pick is to what's on offer
        weights       : _weights,
        learn_weights : _learn_weights,
        importance    : _importance,
        merge         : _merge,
        similar       : _similar,        // how close an option's own inputs must be to count as the same kind of option
        reach         : _reach,          // how far a moment can be and still count fully toward confidence
        names         : _names,
        rate          : 0.05,            // how fast learned weights move
        eps           : 0.03,            // keeps a vote finite when a moment is an exact match
    };
    _model.__sid = []; _model.__oid = [];  // per key: the model input id, situational and own
    _model.__ws  = []; _model.__wo  = [];  // per key: its weight, situational (yours times learned) and own (yours)
    _model.__x   = []; _model.__a   = []; _model.__z = [];  // the moment asked about: situation, actions, own inputs
    _model.__nd  = []; _model.__ni  = []; _model.__nn = 0;  // the nearest moments: squared distance, index, count
    _model.__od  = []; _model.__oi  = []; _model.__oc = []; // outcomes, per option: its nearest tries
    _model.__num = []; _model.__den = []; _model.__ne = [];
    _model.__s   = []; _model.__p   = [];
    _model.observe    = method(_model, __gmsa_learn_neighbor_observe);
    _model.predict    = method(_model, __gmsa_learn_neighbor_predict);
    _model.explain    = method(_model, __gmsa_learn_neighbor_explain);
    _model.save_data  = method(_model, __gmsa_learn_neighbor_save);
    _model.load_data  = method(_model, __gmsa_learn_neighbor_load);
    _model.reset_data = method(_model, __gmsa_learn_neighbor_reset);
    _model.reset_data();
    return _model;
}

// Methods, run with the model as self
function __gmsa_learn_neighbor_reset() {
    data = { sk : undefined, ok : undefined, lw : [], clock : 0, mem : [] };
}

function __gmsa_learn_neighbor_observe(_sample) {
    var _nb = neighbor;
    var _outcomes = (learns == gmsa_learn_target.OUTCOMES);
    var _c = _sample.chosen;
    var _w = _sample.weight;
    __gmsa_learn_neighbor_vote(self, _sample); // also finds the nearest moments, used below
    var _imp = 1 + _nb.importance * (_outcomes ? abs(_sample.reward) : (1 - __p[_c]));
    var _ns = array_length(__x);
    var _no = array_length(__wo);
    var _mem = data.mem;

    // learned weights (Relief): inputs that differ where a different pick was made gain, where the same pick was made lose
    if (!_outcomes && _nb.learn_weights && _ns > 0 && __nn > 0 && __gmsa_learn_neighbor_sum(__ws) * 1000000000000 > 0) {
        var _hit = undefined;
        var _miss = undefined;
        for (var _t = 0; _t < __nn; _t++) {
            var _m = _mem[__ni[_t]];
            if (_m.a[_m.c] == __a[_c]) { if (_hit == undefined) _hit = _m; }
            else if (_miss == undefined) _miss = _m;
        }
        if (_hit != undefined && _miss != undefined) {
            var _lw = data.lw;
            var _total = 0;
            for (var _j = 0; _j < _ns; _j++) {
                _lw[@ _j] = max(0.02, _lw[_j] + _nb.rate * (abs(__x[_j] - _miss.x[_j]) - abs(__x[_j] - _hit.x[_j])));
                _total += _lw[_j];
            }
            for (var _j = 0; _j < _ns; _j++) _lw[@ _j] *= _ns / _total;
        }
    }

    data.clock += 1;
    var _note = _sample[$ "note"];
    _note = (_note == undefined) ? "" : _note;

    // the same moment again: merged into one, with a count
    if (_nb.merge) {
        var _count = _outcomes ? __oc[_c] : __nn;
        for (var _t = 0; _t < _count; _t++) {
            var _m = _mem[_outcomes ? __oi[_c * _nb.k + _t] : __ni[_t]];
            if (!__gmsa_learn_neighbor_same(self, _m, _c)) continue;
            var _f = power(decay, data.clock - _m.t);
            _m.n = _m.n * _f + _w;
            _m.imp = max(_m.imp * _f, _imp);
            if (_outcomes) _m.r += _w * (_sample.reward - _m.r) / _m.n;
            _m.t = data.clock;
            if (_note != "") _m.note = _note;
            return;
        }
    }

    var _n = array_length(__a);
    var _x = array_create(_ns, 0);
    var _a = array_create(_n, 0);
    var _z = array_create(_n * _no, 0);
    array_copy(_x, 0, __x, 0, _ns);
    array_copy(_a, 0, __a, 0, _n);
    array_copy(_z, 0, __z, 0, _n * _no);
    array_push(_mem, { x : _x, a : _a, z : _z, c : _c, n : _w, t : data.clock, imp : _imp,
                       r : _outcomes ? _sample.reward : 0, note : _note });

    // full: the least important goes, importance fading with age (importance 0: the oldest goes)
    if (array_length(_mem) > _nb.capacity) {
        var _drop = 0;
        var _low = infinity;
        for (var _i = 0; _i < array_length(_mem); _i++) {
            var _m = _mem[_i];
            var _v = (_nb.importance * 1000000000000 > 0) ? _m.imp * power(decay, data.clock - _m.t) : _m.t;
            if (_v < _low) {
                _low = _v;
                _drop = _i;
            }
        }
        _mem[@ _drop] = _mem[array_length(_mem) - 1];
        array_pop(_mem);
    }
}

function __gmsa_learn_neighbor_predict(_sample, _out) {
    var _confidence = __gmsa_learn_neighbor_vote(self, _sample);
    for (var _i = 0; _i < array_length(_sample.options); _i++) _out.p[_i] = __p[_i];
    _out.confidence = _confidence;
}

function __gmsa_learn_neighbor_explain(_sample, _index) {
    var _outcomes = (learns == gmsa_learn_target.OUTCOMES);
    __gmsa_learn_neighbor_vote(self, _sample);
    var _name = actions[_sample.options[_index].action];
    if (array_length(data.mem) == 0) return [_name + ": no data yet"];
    var _mem = data.mem;
    var _k = neighbor.k;

    if (_outcomes) {
        var _count = __oc[_index];
        if (_count == 0) return [_name + ": never tried in a similar moment, expected " + __gmsa_learn_signed(__s[_index])];
        var _top = undefined;
        var _top_w = -1;
        for (var _t = 0; _t < _count; _t++) {
            var _m = _mem[__oi[_index * _k + _t]];
            var _v = _m.n * power(decay, data.clock - _m.t) / (__od[_index * _k + _t] + sqr(neighbor.eps));
            if (_v > _top_w) {
                _top_w = _v;
                _top = _m;
            }
        }
        return [_name + ": like " + __gmsa_learn_neighbor_moment(self, _top) + ", " + string(_count)
            + " similar " + ((_count == 1) ? "moment" : "moments") + ", expected " + __gmsa_learn_signed(__s[_index])];
    }

    // among the similar moments: where an option like this was on offer, and where it was picked
    var _offered = 0;
    var _picked = 0;
    var _top = undefined;
    var _top_w = -1;
    var _nearest = undefined;
    for (var _t = 0; _t < __nn; _t++) {
        var _m = _mem[__ni[_t]];
        var _on = false;
        for (var _j = 0; _j < array_length(_m.a); _j++) {
            if (__gmsa_learn_neighbor_alike(self, _index, _m, _j) > 0.5) _on = true;
        }
        if (!_on) continue;
        _offered += 1;
        if (_nearest == undefined) _nearest = _m;
        var _s = __gmsa_learn_neighbor_alike(self, _index, _m, _m.c);
        if (_s > 0.5) _picked += 1;
        var _v = _s * _m.n * power(decay, data.clock - _m.t) / (__nd[_t] + sqr(neighbor.eps));
        if (_v > _top_w) {
            _top_w = _v;
            _top = _m;
        }
    }
    var _p = " (p " + string_format(__p[_index], 1, 2) + ")";
    if (_offered == 0) return [_name + ": not on offer in any similar moment" + _p];
    if (_picked == 0) {
        return [_name + ": 0 of " + string(_offered) + " similar moments picked it, the nearest " + __gmsa_learn_neighbor_moment(self, _nearest) + _p];
    }
    return [_name + ": like " + __gmsa_learn_neighbor_moment(self, _top) + ", " + string(_picked) + " of " + string(_offered)
        + " similar moments agree" + _p];
}

function __gmsa_learn_neighbor_save() {
    var _has = (data.sk != undefined);
    return { has_keys : _has, sk : _has ? data.sk : [], ok : _has ? data.ok : [], lw : data.lw, clock : data.clock, mem : data.mem };
}

function __gmsa_learn_neighbor_load(_data) {
    if (!is_array(_data[$ "mem"]) || !is_array(_data[$ "lw"]) || !is_array(_data[$ "sk"]) || !is_array(_data[$ "ok"])) throw "GMSA: neighbor save is malformed";
    if (_data.has_keys && array_length(_data.lw) != array_length(_data.sk)) throw "GMSA: neighbor save is malformed";
    data = { sk : _data.has_keys ? _data.sk : undefined, ok : _data.has_keys ? _data.ok : undefined, lw : _data.lw,
             clock : _data.clock, mem : _data.mem };
}

// Internal
function __gmsa_learn_neighbor_whole(_value) {
    return is_numeric(_value) && _value >= 1 && frac(_value) == 0;
}

function __gmsa_learn_neighbor_sum(_array) {
    var _s = 0;
    for (var _i = 0; _i < array_length(_array); _i++) _s += _array[_i];
    return _s;
}

function __gmsa_learn_neighbor_keys(_model) {
    var _d = _model.data;
    var _nb = _model.neighbor;
    if (_d.sk == undefined) {
        var _names = (_nb.names != undefined) ? _nb.names : _model.inputs;
        var _sk = [];
        var _ok = [];
        for (var _i = 0; _i < array_length(_names); _i++) {
            var _id = variable_struct_exists(_model.input_lookup, _names[_i]) ? _model.input_lookup[$ _names[_i]] : -1;
            if (_id < 0 || _model.situational[_id]) array_push(_sk, _names[_i]);
            else array_push(_ok, _names[_i]);
        }
        _d.sk = _sk;
        _d.ok = _ok;
        _d.lw = array_create(array_length(_sk), 1);
    }
    var _ns = array_length(_d.sk);
    var _no = array_length(_d.ok);
    array_resize(_model.__sid, _ns);
    array_resize(_model.__ws, _ns);
    array_resize(_model.__oid, _no);
    array_resize(_model.__wo, _no);
    for (var _j = 0; _j < _ns; _j++) {
        var _name = _d.sk[_j];
        _model.__sid[_j] = variable_struct_exists(_model.input_lookup, _name) ? _model.input_lookup[$ _name] : -1;
        var _user = variable_struct_exists(_nb.weights, _name) ? _nb.weights[$ _name] : 1;
        _model.__ws[_j] = _user * (_nb.learn_weights ? _d.lw[_j] : 1);
    }
    for (var _j = 0; _j < _no; _j++) {
        var _name = _d.ok[_j];
        _model.__oid[_j] = variable_struct_exists(_model.input_lookup, _name) ? _model.input_lookup[$ _name] : -1;
        _model.__wo[_j] = variable_struct_exists(_nb.weights, _name) ? _nb.weights[$ _name] : 1;
    }
}

function __gmsa_learn_neighbor_read(_model, _sample) {
    var _ns = array_length(_model.__sid);
    var _no = array_length(_model.__oid);
    var _n = array_length(_sample.options);
    array_resize(_model.__x, _ns);
    array_resize(_model.__a, _n);
    array_resize(_model.__z, _n * _no);
    for (var _j = 0; _j < _ns; _j++) {
        var _id = _model.__sid[_j];
        _model.__x[_j] = (_id >= 0 && _id < array_length(_sample.situation)) ? _sample.situation[_id] : 0;
    }
    for (var _i = 0; _i < _n; _i++) {
        var _o = _sample.options[_i];
        _model.__a[_i] = _o.action;
        for (var _j = 0; _j < _no; _j++) {
            var _id = _model.__oid[_j];
            _model.__z[_i * _no + _j] = (_id >= 0 && _id < array_length(_o.inputs)) ? _o.inputs[_id] : 0;
        }
    }
}

function __gmsa_learn_neighbor_insert(_dist, _idx, _base, _count, _size, _d2, _i) {
    if (_count == _size && _d2 >= _dist[_base + _count - 1]) return _count;
    var _at = min(_count, _size - 1);
    while (_at > 0 && _dist[_base + _at - 1] > _d2) {
        _dist[@ _base + _at] = _dist[_base + _at - 1];
        _idx[@ _base + _at] = _idx[_base + _at - 1];
        _at -= 1;
    }
    _dist[@ _base + _at] = _d2;
    _idx[@ _base + _at] = _i;
    return min(_count + 1, _size);
}

function __gmsa_learn_neighbor_near(_model) {
    var _nb = _model.neighbor;
    var _mem = _model.data.mem;
    var _N = array_length(_mem);
    var _ns = array_length(_model.__x);
    var _no = array_length(_model.__wo);
    var _x = _model.__x;
    var _ws = _model.__ws;
    var _W = __gmsa_learn_neighbor_sum(_ws);
    var _count = 0;
    if (_ns > 0 && _W * 1000000000000 > 0) {
        var _K = _nb.k;
        array_resize(_model.__nd, _K);
        array_resize(_model.__ni, _K);
        for (var _i = 0; _i < _N; _i++) {
            var _mx = _mem[_i].x;
            var _limit = (_count < _K) ? infinity : _model.__nd[_K - 1] * _W;
            var _s = 0;
            for (var _j = 0; _j < _ns; _j++) {
                _s += _ws[_j] * sqr(_x[_j] - _mx[_j]);
                if (_s > _limit) break;
            }
            if (_s > _limit) continue;
            _count = __gmsa_learn_neighbor_insert(_model.__nd, _model.__ni, 0, _count, _K, _s / _W, _i);
        }
    } else {
        var _K = _nb.candidates;
        array_resize(_model.__nd, _K);
        array_resize(_model.__ni, _K);
        var _a = _model.__a;
        var _z = _model.__z;
        var _wo = _model.__wo;
        var _n = array_length(_a);
        for (var _i = 0; _i < _N; _i++) {
            var _m = _mem[_i];
            var _ca = _m.a[_m.c];
            var _best = 1000000000;
            for (var _o = 0; _o < _n; _o++) {
                if (_a[_o] != _ca) continue;
                var _s = 0;
                for (var _j = 0; _j < _no; _j++) _s += _wo[_j] * sqr(_z[_o * _no + _j] - _m.z[_m.c * _no + _j]);
                _best = min(_best, _s);
            }
            _count = __gmsa_learn_neighbor_insert(_model.__nd, _model.__ni, 0, _count, _K, _best, _i);
        }
        // no situation: every kept moment is equally close
        for (var _t = 0; _t < _count; _t++) _model.__nd[_t] = 0;
    }
    _model.__nn = _count;
}

function __gmsa_learn_neighbor_near_tries(_model) {
    var _nb = _model.neighbor;
    var _K = _nb.k;
    var _mem = _model.data.mem;
    var _ns = array_length(_model.__x);
    var _no = array_length(_model.__wo);
    var _x = _model.__x;
    var _a = _model.__a;
    var _z = _model.__z;
    var _ws = _model.__ws;
    var _wo = _model.__wo;
    var _W = __gmsa_learn_neighbor_sum(_ws);
    var _Wo = __gmsa_learn_neighbor_sum(_wo);
    var _n = array_length(_a);
    array_resize(_model.__od, _n * _K);
    array_resize(_model.__oi, _n * _K);
    array_resize(_model.__oc, _n);
    for (var _o = 0; _o < _n; _o++) _model.__oc[_o] = 0;
    for (var _i = 0; _i < array_length(_mem); _i++) {
        var _m = _mem[_i];
        var _ca = _m.a[_m.c];
        var _ds = -1;
        for (var _o = 0; _o < _n; _o++) {
            if (_a[_o] != _ca) continue;
            if (_ds < 0) {
                _ds = 0;
                if (_W * 1000000000000 > 0) {
                    for (var _j = 0; _j < _ns; _j++) _ds += _ws[_j] * sqr(_x[_j] - _m.x[_j]);
                    _ds /= _W;
                }
            }
            var _dz = 0;
            if (_Wo * 1000000000000 > 0) {
                for (var _j = 0; _j < _no; _j++) _dz += _wo[_j] * sqr(_z[_o * _no + _j] - _m.z[_m.c * _no + _j]);
                _dz /= _Wo;
            }
            _model.__oc[_o] = __gmsa_learn_neighbor_insert(_model.__od, _model.__oi, _o * _K, _model.__oc[_o], _K, _ds + _dz, _i);
        }
    }
}

function __gmsa_learn_neighbor_alike(_model, _i, _m, _j) {
    if (_model.__a[_i] != _m.a[_j]) return 0;
    var _no = array_length(_model.__wo);
    if (_no == 0) return 1;
    var _s = 0;
    for (var _k = 0; _k < _no; _k++) _s += _model.__wo[_k] * sqr(_model.__z[_i * _no + _k] - _m.z[_j * _no + _k]);
    return exp(-_s / sqr(_model.neighbor.similar));
}

function __gmsa_learn_neighbor_same(_model, _m, _c) {
    var _n = array_length(_model.__a);
    if (_m.c != _c || array_length(_m.a) != _n) return false;
    for (var _j = 0; _j < array_length(_model.__x); _j++) if (_m.x[_j] != _model.__x[_j]) return false;
    for (var _i = 0; _i < _n; _i++) if (_m.a[_i] != _model.__a[_i]) return false;
    for (var _i = 0; _i < array_length(_model.__z); _i++) if (_m.z[_i] != _model.__z[_i]) return false;
    return true;
}

function __gmsa_learn_neighbor_vote(_model, _sample) {
    __gmsa_learn_neighbor_keys(_model);
    __gmsa_learn_neighbor_read(_model, _sample);
    var _nb = _model.neighbor;
    var _n = array_length(_sample.options);
    var _mem = _model.data.mem;
    var _clock = _model.data.clock;
    var _eps2 = sqr(_nb.eps);
    var _reach2 = sqr(_nb.reach);
    array_resize(_model.__p, _n);
    array_resize(_model.__s, _n);

    if (_model.learns == gmsa_learn_target.OUTCOMES) {
        // expected reward: the closeness-weighted average of the nearest tries; an option never tried counts as 0
        __gmsa_learn_neighbor_near_tries(_model);
        array_resize(_model.__ne, _n);
        for (var _o = 0; _o < _n; _o++) {
            var _val = 0;
            var _sum = 0;
            var _ne = 0;
            for (var _t = 0; _t < _model.__oc[_o]; _t++) {
                var _d2 = _model.__od[_o * _nb.k + _t];
                var _m = _mem[_model.__oi[_o * _nb.k + _t]];
                var _base = _m.n * power(_model.decay, _clock - _m.t);
                var _kw = _base / (_d2 + _eps2);
                _val += _kw * _m.r;
                _sum += _kw;
                _ne += _base * exp(-_d2 / _reach2);
            }
            _model.__s[_o] = (_sum * 1000000000000 > 0) ? _val / _sum : 0;
            _model.__ne[_o] = _ne;
        }
        __gmsa_learn_softmax_scores(_model, _n);
        var _best = 0;
        for (var _o = 1; _o < _n; _o++) if (_model.__p[_o] > _model.__p[_best]) _best = _o;
        return gmsa_learn_confidence(_model, _model.__ne[_best]);
    }

    // choices: in the nearest moments, how often an option like this one was picked when it was on offer
    __gmsa_learn_neighbor_near(_model);
    if (_model.__nn == 0) {
        for (var _o = 0; _o < _n; _o++) _model.__p[_o] = 1 / _n;
        return 0;
    }
    array_resize(_model.__num, _n);
    array_resize(_model.__den, _n);
    for (var _o = 0; _o < _n; _o++) {
        _model.__num[_o] = 0;
        _model.__den[_o] = 0;
    }
    var _neff = 0;
    for (var _t = 0; _t < _model.__nn; _t++) {
        var _d2 = _model.__nd[_t];
        var _m = _mem[_model.__ni[_t]];
        var _base = _m.n * power(_model.decay, _clock - _m.t);
        var _kw = _base / (_d2 + _eps2);
        _neff += _base * exp(-_d2 / _reach2);
        for (var _o = 0; _o < _n; _o++) {
            _model.__num[_o] += _kw * __gmsa_learn_neighbor_alike(_model, _o, _m, _m.c);
            var _offered = 0;
            for (var _j = 0; _j < array_length(_m.a); _j++) _offered += __gmsa_learn_neighbor_alike(_model, _o, _m, _j);
            _model.__den[_o] += _kw * _offered;
        }
    }
    // pulled toward an even split, harder when the nearest moments are few or far
    var _top = 0.000000001;
    for (var _o = 0; _o < _n; _o++) _top = max(_top, _model.__den[_o]);
    var _prior = _top / max(1, _neff * 50);
    var _total = 0;
    for (var _o = 0; _o < _n; _o++) {
        _model.__p[_o] = (_model.__num[_o] + _prior / _n) / (_model.__den[_o] + _prior);
        _total += _model.__p[_o];
    }
    for (var _o = 0; _o < _n; _o++) _model.__p[_o] /= _total;
    return gmsa_learn_confidence(_model, _neff);
}

function __gmsa_learn_neighbor_moment(_model, _m) {
    var _d = _model.data;
    var _outcomes = (_model.learns == gmsa_learn_target.OUTCOMES);
    var _ago = _d.clock - _m.t + 1;
    var _text = string(_ago) + " " + (_outcomes ? ((_ago == 1) ? "outcome" : "outcomes") : ((_ago == 1) ? "choice" : "choices")) + " ago";
    if (_m.note != "") _text += ", " + _m.note;
    var _ns = array_length(_d.sk);
    var _no = array_length(_d.ok);
    var _used = array_create(_ns, false);
    var _parts = "";
    var _shown = 0;
    while (_shown < 3) {
        var _top = -1;
        for (var _j = 0; _j < _ns; _j++) {
            if (!_used[_j] && _model.__ws[_j] * 1000000000000 > 0 && (_top < 0 || _model.__ws[_j] > _model.__ws[_top])) _top = _j;
        }
        if (_top < 0) break;
        _used[_top] = true;
        _parts += ((_shown > 0) ? ", " : "") + _d.sk[_top] + " " + string(round(_m.x[_top] * 100)) + "%";
        _shown += 1;
    }
    for (var _j = 0; _j < _no && _shown < 3; _j++) {
        if (_model.__wo[_j] * 1000000000000 <= 0) continue;
        _parts += ((_shown > 0) ? ", " : "") + _d.ok[_j] + " " + string(round(_m.z[_m.c * _no + _j] * 100)) + "%";
        _shown += 1;
    }
    _parts += ((_shown > 0) ? ", " : "") + _model.actions[_m.a[_m.c]];
    if (_outcomes) _parts += ", " + __gmsa_learn_signed(_m.r);
    return _text + " (" + _parts + ")";
}