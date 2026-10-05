
function gmsa_learn_linear_create(_params = {}) {
    var _lr = __gmsa_param(_params, "learn_rate", 0.3);
    if (!is_numeric(_lr) || _lr <= 0) throw "GMSA: linear learn_rate must be above 0";
    var _model = __gmsa_learn_model_create(gmsa_learn_tier.LINEAR, "linear", {
        half_life    : __gmsa_param(_params, "half_life", 50),
        confidence_k : __gmsa_param(_params, "confidence_k", 20),
    });
    _model.linear     = { learn_rate : _lr };
    _model.__p        = []; // softmax of the last sample, written through the struct
    _model.observe    = method(_model, __gmsa_learn_linear_observe);
    _model.predict    = method(_model, __gmsa_learn_linear_predict);
    _model.explain    = method(_model, __gmsa_learn_linear_explain);
    _model.save_data  = method(_model, __gmsa_learn_linear_save);
    _model.load_data  = method(_model, __gmsa_learn_linear_load);
    _model.reset_data = method(_model, __gmsa_learn_linear_reset);
    _model.reset_data();
    return _model;
}

// Methods, run with the model as self
function __gmsa_learn_linear_reset() {
    data = { w : [], b : [] }; // w[action][input], b[action]
}

function __gmsa_learn_linear_observe(_sample) {
    __gmsa_learn_linear_grow(self);
    var _k = array_length(inputs);

    // old evidence fades
    for (var _a = 0; _a < array_length(data.b); _a++) {
        data.b[_a] *= decay;
        for (var _j = 0; _j < _k; _j++) data.w[_a][_j] *= decay;
    }

    // move toward the chosen option, away from the rest, by how surprised the model was
    __gmsa_learn_linear_softmax(self, _sample);
    var _step = linear.learn_rate * _sample.weight;
    for (var _i = 0; _i < array_length(_sample.options); _i++) {
        var _o = _sample.options[_i];
        var _g = (((_i == _sample.chosen) ? 1 : 0) - __p[_i]) * _step;
        //if (_g == 0) continue;
        var _a = _o.action;
        data.b[_a] += _g;
        for (var _j = 0; _j < _k; _j++) data.w[_a][_j] += _g * _o.inputs[_j];
    }
}

function __gmsa_learn_linear_predict(_sample, _out) {
    __gmsa_learn_linear_grow(self);
    __gmsa_learn_linear_softmax(self, _sample);
    for (var _i = 0; _i < array_length(_sample.options); _i++) _out.p[_i] = __p[_i];
    _out.confidence = gmsa_learn_confidence(self);
}

function __gmsa_learn_linear_explain(_sample, _index) {
    __gmsa_learn_linear_grow(self);
    __gmsa_learn_linear_softmax(self, _sample);
    var _o = _sample.options[_index];
    var _a = _o.action;
    var _k = array_length(inputs);

    var _used = array_create(_k, false);
    var _parts = "";
    for (var _r = 0; _r < min(3, _k); _r++) {
        var _best = -1, _best_abs = 0;
        for (var _j = 0; _j < _k; _j++) {
            if (_used[_j]) continue;
            var _c = abs(data.w[_a][_j] * _o.inputs[_j]);
            if (_c > _best_abs) { _best_abs = _c; _best = _j; }
        }
        if (_best < 0) break;
        _used[_best] = true;
        _parts += inputs[_best] + " " + __gmsa_learn_signed(data.w[_a][_best] * _o.inputs[_best]) + ", ";
    }
    return [actions[_a] + ": " + _parts + "bias " + __gmsa_learn_signed(data.b[_a])
        + " (p " + string_format(__p[_index], 1, 2) + ")"];
}

function __gmsa_learn_linear_save() {
    return { w : data.w, b : data.b };
}

function __gmsa_learn_linear_load(_data) {
    data.w = _data.w;
    data.b = _data.b;
}

// Internal
function __gmsa_learn_linear_grow(_model) {
    var _k = array_length(_model.inputs);
    while (array_length(_model.data.b) < array_length(_model.actions)) {
        array_push(_model.data.w, array_create(_k, 0));
        array_push(_model.data.b, 0);
    }
    for (var _a = 0; _a < array_length(_model.data.w); _a++) {
        var _n = array_length(_model.data.w[_a]);
        if (_n >= _k) continue;
        array_resize(_model.data.w[_a], _k);
        for (var _j = _n; _j < _k; _j++) _model.data.w[_a][_j] = 0;
    }
}

function __gmsa_learn_linear_softmax(_model, _sample) {
    var _n = array_length(_sample.options);
    var _k = array_length(_model.inputs);
    array_resize(_model.__p, _n);
    var _max = -infinity;
    for (var _i = 0; _i < _n; _i++) {
        var _o = _sample.options[_i];
        var _a = _o.action;
        var _s = _model.data.b[_a];
        for (var _j = 0; _j < _k; _j++) _s += _model.data.w[_a][_j] * _o.inputs[_j];
        _model.__p[_i] = _s;
        if (_s > _max) _max = _s;
    }
    var _sum = 0;
    for (var _i = 0; _i < _n; _i++) {
        _model.__p[_i] = exp(_model.__p[_i] - _max);
        _sum += _model.__p[_i];
    }
    for (var _i = 0; _i < _n; _i++) _model.__p[_i] /= _sum;
}

function __gmsa_learn_signed(_v) {
    return ((_v >= 0) ? "+" : "") + string_format(_v, 1, 2);
}