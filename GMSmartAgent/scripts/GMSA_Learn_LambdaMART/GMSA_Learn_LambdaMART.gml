enum __gmsa_lambdamart_phase { ROWS, CUTS, BINS, LAMBDAS, CLEAR, HIST, SPLIT, APPLY, DONE }

#macro GMSA_LAMBDAMART_CUT_SAMPLE 256 // rows sampled per input to place bin edges

function gmsa_learn_lambdamart_create(_params = {}) {
    var _trees    = __gmsa_param(_params, "trees", 100);
    var _depth    = __gmsa_param(_params, "depth", 3);
    var _rate     = __gmsa_param(_params, "learn_rate", 0.1);
    var _reg      = __gmsa_param(_params, "reg", 0.1);
    var _bins     = __gmsa_param(_params, "bins", 16);
    var _min_leaf = __gmsa_param(_params, "min_leaf", 5);
    var _buffer   = __gmsa_param(_params, "buffer", 500);
    if (!__gmsa_net_whole(_trees)) throw "GMSA: lambdamart trees must be a whole number of 1 or more";
    if (!__gmsa_net_whole(_depth) || _depth > 8) throw "GMSA: lambdamart depth must be a whole number from 1 to 8";
    if (!__gmsa_net_above_zero(_rate)) throw "GMSA: lambdamart learn_rate must be above 0";
    if (!is_numeric(_reg) || _reg < 0) throw "GMSA: lambdamart reg must be 0 or more";
    if (!__gmsa_net_whole(_bins) || _bins < 2 || _bins > 256) throw "GMSA: lambdamart bins must be a whole number from 2 to 256";
    if (!__gmsa_net_whole(_min_leaf)) throw "GMSA: lambdamart min_leaf must be a whole number of 1 or more";
    if (!__gmsa_net_whole(_buffer)) throw "GMSA: lambdamart buffer must be a whole number of 1 or more";

    var _model = __gmsa_learn_model_create(gmsa_learn_tier.LAMBDAMART, "lambdamart", {
        half_life    : __gmsa_param(_params, "half_life", 200),
        confidence_k : __gmsa_param(_params, "confidence_k", 40),
        learns       : __gmsa_param(_params, "learns", gmsa_learn_target.CHOICES),
        temperature  : __gmsa_param(_params, "temperature", 0.1),
    });
    _model.lambdamart = {
        trees : _trees, depth : _depth, learn_rate : _rate, reg : _reg,
        bins : _bins, min_leaf : _min_leaf, buffer : _buffer,
    };
    _model.__x = [];
    _model.__x_action = -1;
    _model.__s = [];
    _model.__p = [];
    _model.__job = undefined; // training in progress
    _model.observe    = method(_model, __gmsa_learn_lambdamart_observe);
    _model.predict    = method(_model, __gmsa_learn_lambdamart_predict);
    _model.explain    = method(_model, __gmsa_learn_lambdamart_explain);
    _model.save_data  = method(_model, __gmsa_learn_lambdamart_save);
    _model.load_data  = method(_model, __gmsa_learn_lambdamart_load);
    _model.reset_data = method(_model, __gmsa_learn_lambdamart_reset);
    _model.train      = method(_model, __gmsa_learn_lambdamart_train);
    _model.reset_data();
    return _model;
}

// Methods, run with the model as self
function __gmsa_learn_lambdamart_reset() {
    data = {
        slots : 0, input_slot : [], action_slot : [],
        // every tree in flat arrays, tree_nodes entries each, heap layout, feature -1 is a leaf
        tree_count : 0, tree_nodes : 0, feature : [], threshold : [], value : [],
        buffer : [],  // stored observations, oldest at head once full
        head   : 0,
        count  : 0,   // observations seen, ages the buffer
    };
    __job = undefined;
}

function __gmsa_learn_lambdamart_observe(_sample) {
    var _outcome = (learns == gmsa_learn_target.OUTCOMES);
    var _n = array_length(_sample.options);
    if (_sample.chosen < 0 || (!_outcome && _n < 2)) return; // a single option teaches no preference

    var _first = _outcome ? _sample.chosen : 0;
    var _count = _outcome ? 1 : _n;
    var _k = array_length(inputs);
    var _actions = array_create(_count, 0);
    var _values = array_create(_count * _k, 0);
    for (var _i = 0; _i < _count; _i++) {
        var _o = _sample.options[_first + _i];
        _actions[_i] = _o.action;
        var _m = min(_k, array_length(_o.inputs));
        for (var _j = 0; _j < _m; _j++) _values[_i * _k + _j] = _o.inputs[_j];
    }
    var _record = {
        k : _k, actions : _actions, inputs : _values,
        chosen : _outcome ? 0 : _sample.chosen,
        weight : _sample.weight,
        reward : _outcome ? _sample.reward : 0,
        stamp  : data.count,
    };
    data.count += 1;
    if (array_length(data.buffer) < lambdamart.buffer) {
        array_push(data.buffer, _record);
    } else {
        data.buffer[data.head] = _record;
        data.head = (data.head + 1) mod lambdamart.buffer;
    }
}

function __gmsa_learn_lambdamart_predict(_sample, _out) {
    __gmsa_learn_slots_grow(self);
    var _n = array_length(_sample.options);
    __gmsa_learn_lambdamart_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, _n);
    for (var _i = 0; _i < _n; _i++) _out.p[_i] = __p[_i];
    _out.confidence = (data.tree_count > 0) ? gmsa_learn_confidence(self) : 0;
}

function __gmsa_learn_lambdamart_explain(_sample, _index) {
    __gmsa_learn_slots_grow(self);
    __gmsa_learn_lambdamart_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, array_length(_sample.options));
    return __gmsa_learn_explain_line(self, _sample, _index, __gmsa_learn_lambdamart_score_x);
}

function __gmsa_learn_lambdamart_save() {
    return {
        slots : data.slots, input_slot : data.input_slot, action_slot : data.action_slot,
        tree_count : data.tree_count, tree_nodes : data.tree_nodes,
        feature : data.feature, threshold : data.threshold, value : data.value,
        buffer : data.buffer, count : data.count,
    };
}

function __gmsa_learn_lambdamart_load(_data) {
    if (!is_numeric(_data[$ "slots"]) || !is_numeric(_data[$ "count"])
        || !is_numeric(_data[$ "tree_count"]) || !is_numeric(_data[$ "tree_nodes"])
        || !is_array(_data[$ "input_slot"]) || !is_array(_data[$ "action_slot"])
        || !is_array(_data[$ "feature"]) || !is_array(_data[$ "threshold"]) || !is_array(_data[$ "value"])
        || !is_array(_data[$ "buffer"])) {
        throw "GMSA: lambdamart save is malformed";
    }
    var _size = _data.tree_count * _data.tree_nodes;
    if (array_length(_data.feature) != _size || array_length(_data.threshold) != _size || array_length(_data.value) != _size) {
        throw "GMSA: lambdamart save is malformed";
    }
    var _count = array_length(_data.buffer);
    var _buffer = array_create(_count, undefined);
    for (var _i = 0; _i < _count; _i++) {
        var _r = _data.buffer[_i];
        if (!is_struct(_r) || !is_array(_r[$ "actions"]) || !is_array(_r[$ "inputs"]) || !is_numeric(_r[$ "stamp"])) {
            throw "GMSA: lambdamart save is malformed";
        }
        _buffer[_i] = _r;
    }
    // oldest first, keep the newest that fit this model's buffer
    array_sort(_buffer, function(_a, _b) { return _a.stamp - _b.stamp; });
    var _cap = lambdamart.buffer;
    if (_count > _cap) array_delete(_buffer, 0, _count - _cap);

    data = {
        slots : _data.slots, input_slot : _data.input_slot, action_slot : _data.action_slot,
        tree_count : _data.tree_count, tree_nodes : _data.tree_nodes,
        feature : _data.feature, threshold : _data.threshold, value : _data.value,
        buffer : _buffer, head : 0, count : _data.count,
    };
    __job = undefined;
}

function __gmsa_learn_lambdamart_train(_budget) {
    var _limit = (_budget == undefined) ? infinity : get_timer() + _budget;
    if (__job == undefined) {
        __job = __gmsa_learn_lambdamart_job(self);
        if (__job == undefined) return true; // nothing to learn from
    }
    if (!__gmsa_learn_lambdamart_work(self, __job, _limit)) return false;
    data.tree_count = lambdamart.trees;
    data.tree_nodes = __job.nodes;
    data.feature    = __job.feature;
    data.threshold  = __job.threshold;
    data.value      = __job.value;
    __job = undefined;
    return true;
}

// Internal
function __gmsa_learn_lambdamart_scores(_model, _sample) {
    var _n = array_length(_sample.options);
    array_resize(_model.__s, _n);
    for (var _i = 0; _i < _n; _i++) {
        __gmsa_learn_slots_encode(_model, _sample.options[_i]);
        _model.__s[_i] = __gmsa_learn_lambdamart_score_x(_model);
    }
}

function __gmsa_learn_lambdamart_score_x(_model) {
    var _d = _model.data;
    var _count = _d.tree_count;
    var _nodes = _d.tree_nodes;
    var _feature = _d.feature;
    var _threshold = _d.threshold;
    var _value = _d.value;
    var _x = _model.__x;
    var _s = 0;
    var _base = 0;
    for (var _t = 0; _t < _count; _t++) {
        var _nd = 0;
        var _f = _feature[_base];
        while (_f >= 0) {
            _nd = (_x[_f] <= _threshold[_base + _nd]) ? 2 * _nd + 1 : 2 * _nd + 2;
            _f = _feature[_base + _nd];
        }
        _s += _value[_base + _nd];
        _base += _nodes;
    }
    return _s;
}

function __gmsa_learn_lambdamart_job(_model) {
    var _d = _model.data;
    var _count = array_length(_d.buffer);
    if (_count == 0) return undefined;
    __gmsa_learn_slots_grow(_model);

    var _lists = array_create(_count, undefined);
    array_copy(_lists, 0, _d.buffer, 0, _count);
    var _rows = 0;
    for (var _l = 0; _l < _count; _l++) _rows += array_length(_lists[_l].actions);

    var _lm = _model.lambdamart;
    var _k = array_length(_d.input_slot);
    var _a = array_length(_d.action_slot);
    var _stride = _k * _lm.bins + _a;              // histogram entries per node
    var _nodes = power(2, _lm.depth + 1) - 1;
    var _width = power(2, _lm.depth - 1);          // most nodes on a level that gets a histogram
    var _total = _lm.trees * _nodes;
    return {
        phase : __gmsa_lambdamart_phase.ROWS, cursor : 0, row : 0, tree : 0, level : 0, any : false,
        lists : _lists, list_count : _count, rows : _rows,
        inputs : _k, actions : _a, stride : _stride, nodes : _nodes,
        outcome : (_model.learns == gmsa_learn_target.OUTCOMES),
        input_slot : _d.input_slot, action_slot : _d.action_slot, // only ever grow, the job reads its own range
        newest      : _d.count - 1,
        list_start  : array_create(_count, 0),
        list_weight : array_create(_count, 0),
        values     : array_create(_rows * _k, 0),  // raw input values, row major by input id
        bins       : array_create(_rows * _k, 0),
        row_action : array_create(_rows, 0),
        cuts       : array_create(_k, undefined),  // per input, sorted bin edges
        score  : array_create(_rows, 0),
        lambda : array_create(_rows, 0),
        hess   : array_create(_rows, 0),
        node   : array_create(_rows, 0),
        hist_g : array_create(_width * _stride, 0),
        hist_h : array_create(_width * _stride, 0),
        hist_c : array_create(_width * _stride, 0),
        node_g : array_create(_width, 0), node_h : array_create(_width, 0), node_c : array_create(_width, 0),
        split_kind  : array_create(_nodes, 0),     // 0 input, 1 action
        split_index : array_create(_nodes, 0),
        split_bin   : array_create(_nodes, 0),
        feature   : array_create(_total, -1),
        threshold : array_create(_total, 0),
        value     : array_create(_total, 0),
    };
}

function __gmsa_learn_lambdamart_work(_model, _job, _limit) {
    var _lm = _model.lambdamart;
    while (true) {
        switch (_job.phase) {

            case __gmsa_lambdamart_phase.ROWS: // raw values, one list per unit
                while (_job.cursor < _job.list_count) {
                    __gmsa_learn_lambdamart_rows(_model, _job, _job.cursor);
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                _job.phase = __gmsa_lambdamart_phase.CUTS;
                _job.cursor = 0;
                break;

            case __gmsa_lambdamart_phase.CUTS: // bin edges, one input per unit
                while (_job.cursor < _job.inputs) {
                    __gmsa_learn_lambdamart_cuts(_model, _job, _job.cursor);
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                _job.phase = __gmsa_lambdamart_phase.BINS;
                _job.cursor = 0;
                break;

            case __gmsa_lambdamart_phase.BINS: // bin indices, one row per unit
                while (_job.cursor < _job.rows) {
                    __gmsa_learn_lambdamart_bin_row(_job, _job.cursor);
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                _job.phase = __gmsa_lambdamart_phase.LAMBDAS;
                _job.cursor = 0;
                break;

            case __gmsa_lambdamart_phase.LAMBDAS: // gradients, one list per unit
                while (_job.cursor < _job.list_count) {
                    __gmsa_learn_lambdamart_lambdas(_job, _job.cursor);
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                __gmsa_learn_lambdamart_level_begin(_job, 0);
                break;

            case __gmsa_lambdamart_phase.CLEAR: // empty histograms, one node per unit
                while (_job.cursor < power(2, _job.level)) {
                    __gmsa_learn_lambdamart_clear_node(_job, _job.cursor);
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                _job.phase = __gmsa_lambdamart_phase.HIST;
                _job.cursor = 0;
                break;

            case __gmsa_lambdamart_phase.HIST: // histograms of one level, one row per unit
                while (_job.cursor < _job.rows) {
                    __gmsa_learn_lambdamart_hist_row(_model, _job, _job.cursor);
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                _job.phase = __gmsa_lambdamart_phase.SPLIT;
                _job.cursor = 0;
                break;

            case __gmsa_lambdamart_phase.SPLIT: // best splits, one node per unit
                while (_job.cursor < power(2, _job.level)) {
                    if (__gmsa_learn_lambdamart_split_node(_model, _job, _job.cursor)) _job.any = true;
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                if (_job.any && _job.level + 1 < _lm.depth) {
                    __gmsa_learn_lambdamart_level_begin(_job, _job.level + 1);
                } else {
                    _job.phase = __gmsa_lambdamart_phase.APPLY;
                    _job.cursor = 0;
                }
                break;

            case __gmsa_lambdamart_phase.APPLY: // add the tree to every row's score, one row per unit
                var _base = _job.tree * _job.nodes;
                while (_job.cursor < _job.rows) {
                    var _nd = __gmsa_learn_lambdamart_route(_job, _job.cursor);
                    _job.score[_job.cursor] += _job.value[_base + _nd];
                    _job.cursor += 1;
                    if (get_timer() >= _limit) return false;
                }
                _job.tree += 1;
                _job.cursor = 0;
                _job.phase = (_job.tree < _lm.trees) ? __gmsa_lambdamart_phase.LAMBDAS : __gmsa_lambdamart_phase.DONE;
                break;

            case __gmsa_lambdamart_phase.DONE:
                return true;
        }
    }
}

function __gmsa_learn_lambdamart_rows(_model, _job, _l) {
    var _record = _job.lists[_l];
    var _n = array_length(_record.actions);
    var _k = _record.k;
    var _inputs = _job.inputs;
    var _m = min(_k, _inputs);
    var _start = _job.row;
    _job.list_start[_l] = _start;
    _job.list_weight[_l] = _record.weight * power(_model.decay, _job.newest - _record.stamp);
    for (var _i = 0; _i < _n; _i++) {
        var _r = _start + _i;
        _job.row_action[_r] = _record.actions[_i];
        var _base = _r * _inputs;
        for (var _j = 0; _j < _m; _j++) _job.values[_base + _j] = _record.inputs[_i * _k + _j];
    }
    _job.row = _start + _n;
}

function __gmsa_learn_lambdamart_cuts(_model, _job, _input) {
    var _rows = _job.rows;
    var _k = _job.inputs;
    var _bins = _model.lambdamart.bins;
    var _step = max(1, floor(_rows / GMSA_LAMBDAMART_CUT_SAMPLE));
    var _col = [];
    for (var _r = 0; _r < _rows; _r += _step) array_push(_col, _job.values[_r * _k + _input]);
    array_sort(_col, true);
    var _n = array_length(_col);

    // few distinct values: every value but the largest is an edge
    var _distinct = [];
    for (var _r = 0; _r < _n && array_length(_distinct) <= _bins; _r++) {
        if (array_length(_distinct) == 0 || _col[_r] > _distinct[array_length(_distinct) - 1]) array_push(_distinct, _col[_r]);
    }
    var _cuts = [];
    if (array_length(_distinct) <= _bins) {
        for (var _i = 0; _i < array_length(_distinct) - 1; _i++) array_push(_cuts, _distinct[_i]);
    } else {
        // many: edges at quantiles
        var _top = _col[_n - 1];
        for (var _b = 1; _b < _bins; _b++) {
            var _q = _col[floor(_b * _n / _bins)];
            if (_q < _top && (array_length(_cuts) == 0 || _q > _cuts[array_length(_cuts) - 1])) array_push(_cuts, _q);
        }
    }
    _job.cuts[_input] = _cuts;
}

function __gmsa_learn_lambdamart_bin_row(_job, _r) {
    var _k = _job.inputs;
    var _base = _r * _k;
    for (var _j = 0; _j < _k; _j++) {
        var _v = _job.values[_base + _j];
        var _cuts = _job.cuts[_j];
        var _lo = 0, _hi = array_length(_cuts); // first edge with v <= edge, or the edge count
        while (_lo < _hi) {
            var _mid = (_lo + _hi) div 2;
            if (_v <= _cuts[_mid]) _hi = _mid; else _lo = _mid + 1;
        }
        _job.bins[_base + _j] = _lo;
    }
}

function __gmsa_learn_lambdamart_lambdas(_job, _l) {
    var _record = _job.lists[_l];
    var _n = array_length(_record.actions);
    var _st = _job.list_start[_l];
    var _w = _job.list_weight[_l];
    var _c = _record.chosen;
    for (var _i = 0; _i < _n; _i++) {
        _job.lambda[_st + _i] = 0;
        _job.hess[_st + _i] = 0;
        _job.node[_st + _i] = 0;
    }
    if (_job.outcome) {
        _job.lambda[_st] = _w * (_record.reward - _job.score[_st]);
        _job.hess[_st] = _w;
        return;
    }
    var _sc = _job.score[_st + _c];
    var _gain_c = 1 / log2(1 + __gmsa_learn_lambdamart_rank(_job, _st, _n, _c));
    for (var _j = 0; _j < _n; _j++) {
        if (_j == _c) continue;
        var _delta = abs(_gain_c - 1 / log2(1 + __gmsa_learn_lambdamart_rank(_job, _st, _n, _j)));
        var _rho = 1 / (1 + exp(_sc - _job.score[_st + _j]));
        var _push = _rho * _delta * _w;
        var _curve = _rho * (1 - _rho) * _delta * _w;
        _job.lambda[_st + _c] += _push;
        _job.lambda[_st + _j] -= _push;
        _job.hess[_st + _c] += _curve;
        _job.hess[_st + _j] += _curve;
    }
}

function __gmsa_learn_lambdamart_rank(_job, _st, _n, _i) {
    var _s = _job.score[_st + _i];
    var _rank = 1;
    for (var _k = 0; _k < _n; _k++) {
        if (_k == _i) continue;
        var _o = _job.score[_st + _k];
        if (_o > _s || (_o == _s && _k < _i)) _rank += 1;
    }
    return _rank;
}

function __gmsa_learn_lambdamart_level_begin(_job, _level) {
    _job.level = _level;
    _job.any = false;
    _job.phase = __gmsa_lambdamart_phase.CLEAR;
    _job.cursor = 0;
}

function __gmsa_learn_lambdamart_clear_node(_job, _li) {
    var _stride = _job.stride;
    var _base = _li * _stride;
    for (var _e = 0; _e < _stride; _e++) {
        _job.hist_g[_base + _e] = 0;
        _job.hist_h[_base + _e] = 0;
        _job.hist_c[_base + _e] = 0;
    }
    _job.node_g[_li] = 0;
    _job.node_h[_li] = 0;
    _job.node_c[_li] = 0;
}

function __gmsa_learn_lambdamart_route(_job, _r) {
    var _nd = _job.node[_r];
    if (_job.feature[_job.tree * _job.nodes + _nd] < 0) return _nd;
    var _right = (_job.split_kind[_nd] == 0)
        ? (_job.bins[_r * _job.inputs + _job.split_index[_nd]] > _job.split_bin[_nd])
        : (_job.row_action[_r] == _job.split_index[_nd]);
    _nd = _right ? 2 * _nd + 2 : 2 * _nd + 1;
    _job.node[_r] = _nd;
    return _nd;
}

function __gmsa_learn_lambdamart_hist_row(_model, _job, _r) {
    var _nd = __gmsa_learn_lambdamart_route(_job, _r);
    var _first = power(2, _job.level) - 1;
    if (_nd < _first) return; // settled in a leaf on an earlier level
    var _li = _nd - _first;
    var _g = _job.lambda[_r];
    var _h = _job.hess[_r];
    _job.node_g[_li] += _g;
    _job.node_h[_li] += _h;
    _job.node_c[_li] += 1;

    var _k = _job.inputs;
    var _bins = _model.lambdamart.bins;
    var _hb = _li * _job.stride;
    var _rb = _r * _k;
    for (var _j = 0; _j < _k; _j++) {
        var _i = _hb + _j * _bins + _job.bins[_rb + _j];
        _job.hist_g[_i] += _g;
        _job.hist_h[_i] += _h;
        _job.hist_c[_i] += 1;
    }
    var _ai = _hb + _k * _bins + _job.row_action[_r];
    _job.hist_g[_ai] += _g;
    _job.hist_h[_ai] += _h;
    _job.hist_c[_ai] += 1;
}

function __gmsa_learn_lambdamart_split_node(_model, _job, _li) {
    var _count = _job.node_c[_li];
    if (_count == 0) return false;
    var _lm = _model.lambdamart;
    var _reg = _lm.reg;
    var _rate = _lm.learn_rate;
    var _min = _lm.min_leaf;
    var _bins = _lm.bins;
    var _k = _job.inputs;
    var _nd = power(2, _job.level) - 1 + _li;
    var _tb = _job.tree * _job.nodes;
    var _G = _job.node_g[_li];
    var _H = _job.node_h[_li];
    _job.value[_tb + _nd] = _rate * __gmsa_learn_lambdamart_ratio(_G, _H + _reg);
    if (_count < 2 * _min) return false;

    var _parent = __gmsa_learn_lambdamart_ratio(_G * _G, _H + _reg);
    var _best = 0, _kind = -1, _index = 0, _bin = 0, _left_g = 0, _left_h = 0;
    var _hb = _li * _job.stride;

    // inputs: bins 0..b go left
    for (var _j = 0; _j < _k; _j++) {
        var _nb = array_length(_job.cuts[_j]) + 1;
        var _i0 = _hb + _j * _bins;
        var _gl = 0, _hl = 0, _cl = 0;
        for (var _b = 0; _b < _nb - 1; _b++) {
            _gl += _job.hist_g[_i0 + _b];
            _hl += _job.hist_h[_i0 + _b];
            _cl += _job.hist_c[_i0 + _b];
            if (_cl < _min) continue;
            if (_count - _cl < _min) break;
            var _gain = __gmsa_learn_lambdamart_ratio(_gl * _gl, _hl + _reg)
                      + __gmsa_learn_lambdamart_ratio((_G - _gl) * (_G - _gl), _H - _hl + _reg)
                      - _parent;
            if (_gain > _best) {
                _best = _gain; _kind = 0; _index = _j; _bin = _b; _left_g = _gl; _left_h = _hl;
            }
        }
    }

    // actions: rows with the action go right
    var _a0 = _hb + _k * _bins;
    for (var _a = 0; _a < _job.actions; _a++) {
        var _cr = _job.hist_c[_a0 + _a];
        if (_cr < _min || _count - _cr < _min) continue;
        var _gr = _job.hist_g[_a0 + _a];
        var _hr = _job.hist_h[_a0 + _a];
        var _gl = _G - _gr, _hl = _H - _hr;
        var _gain = __gmsa_learn_lambdamart_ratio(_gl * _gl, _hl + _reg)
                  + __gmsa_learn_lambdamart_ratio(_gr * _gr, _hr + _reg)
                  - _parent;
        if (_gain > _best) {
            _best = _gain; _kind = 1; _index = _a; _left_g = _gl; _left_h = _hl;
        }
    }
    if (_kind < 0) return false;

    _job.feature[_tb + _nd] = (_kind == 0) ? _job.input_slot[_index] : _job.action_slot[_index];
    _job.threshold[_tb + _nd] = (_kind == 0) ? _job.cuts[_index][_bin] : 0; // an action's slot is 0 or 1
    _job.split_kind[_nd] = _kind;
    _job.split_index[_nd] = _index;
    _job.split_bin[_nd] = _bin;
    _job.value[_tb + 2 * _nd + 1] = _rate * __gmsa_learn_lambdamart_ratio(_left_g, _left_h + _reg);
    _job.value[_tb + 2 * _nd + 2] = _rate * __gmsa_learn_lambdamart_ratio(_G - _left_g, _H - _left_h + _reg);
    return true;
}

function __gmsa_learn_lambdamart_ratio(_top, _bottom) {
    return (_bottom <= 0) ? 0 : _top / _bottom;
}