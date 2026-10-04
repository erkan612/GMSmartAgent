#macro GMSA_LEARN_COUNT_MAX_BUCKETS 4096

function gmsa_learn_count_create(_params = {}) {
    var _bins = __gmsa_param(_params, "bins", 4);
    if (!is_numeric(_bins) || _bins < 1 || frac(_bins) != 0) throw "GMSA: count bins must be a whole number of 1 or more";
    var _smoothing = __gmsa_param(_params, "smoothing", 1);
    if (!is_numeric(_smoothing) || _smoothing <= 0) throw "GMSA: count smoothing must be above 0";
    var _names = __gmsa_param(_params, "inputs", undefined);
    if (_names != undefined) {
        if (!is_array(_names) || array_length(_names) == 0) throw "GMSA: count inputs must be a non-empty array of input names";
        __gmsa_learn_count_check_size(_bins, array_length(_names));
    }
    var _model = __gmsa_learn_model_create(gmsa_learn_tier.COUNT, "count", {
        half_life    : __gmsa_param(_params, "half_life", 50),
        confidence_k : __gmsa_param(_params, "confidence_k", 5),
    });
    _model.count      = { bins : _bins, smoothing : _smoothing, names : _names };
    _model.observe    = method(_model, __gmsa_learn_count_observe);
    _model.predict    = method(_model, __gmsa_learn_count_predict);
    _model.explain    = method(_model, __gmsa_learn_count_explain);
    _model.save_data  = method(_model, __gmsa_learn_count_save);
    _model.load_data  = method(_model, __gmsa_learn_count_load);
    _model.reset_data = method(_model, __gmsa_learn_count_reset);
    _model.reset_data();
    return _model;
}

// Methods, run with the model as self
function __gmsa_learn_count_reset() {
    data = { keys : count.names, clock : 0, buckets : {} };
}

function __gmsa_learn_count_observe(_sample) {
    static _bins = [];
    var _key = __gmsa_learn_count_key(self, _sample, _bins);
    data.clock += 1;
    var _bucket = data.buckets[$ _key];
    if (_bucket == undefined) {
        _bucket = { counts : [], total : 0, last : data.clock };
        data.buckets[$ _key] = _bucket;
    } else {
        __gmsa_learn_count_age(self, _bucket);
    }
    var _a = _sample.options[_sample.chosen].action;
    while (array_length(_bucket.counts) <= _a) array_push(_bucket.counts, 0);
    _bucket.counts[_a] += _sample.weight;
    _bucket.total += _sample.weight;
}

function __gmsa_learn_count_predict(_sample, _out) {
    static _bins = [];
    static _per = [];
    var _key = __gmsa_learn_count_key(self, _sample, _bins);
    var _bucket = data.buckets[$ _key];
    if (_bucket != undefined) __gmsa_learn_count_age(self, _bucket);

    var _n = array_length(_sample.options);
    array_resize(_per, array_length(actions));
    for (var _i = 0; _i < array_length(_per); _i++) _per[_i] = 0;
    for (var _i = 0; _i < _n; _i++) _per[_sample.options[_i].action]++;

    for (var _i = 0; _i < _n; _i++) {
        var _a = _sample.options[_i].action;
        var _c = (_bucket != undefined && _a < array_length(_bucket.counts)) ? _bucket.counts[_a] : 0;
        _out.p[_i] = (_c + count.smoothing) / _per[_a];
    }
    _out.confidence = (_bucket != undefined) ? gmsa_learn_confidence(self, _bucket.total) : 0;
}

function __gmsa_learn_count_explain(_sample, _index) {
    static _bins = [];
    var _key = __gmsa_learn_count_key(self, _sample, _bins);
    var _bucket = data.buckets[$ _key];
    if (_bucket != undefined) __gmsa_learn_count_age(self, _bucket);

    var _where = "";
    var _nb = count.bins;
    for (var _i = 0; _i < array_length(data.keys); _i++) {
        if (_i > 0) _where += ", ";
        _where += data.keys[_i] + " " + string(round(_bins[_i] / _nb * 100)) + "-" + string(round((_bins[_i] + 1) / _nb * 100)) + "%";
    }
    if (_where == "") _where = "any situation";

    var _a = _sample.options[_index].action;
    if (_bucket == undefined || _bucket.total <= 0) return [_where + ": no data yet for " + actions[_a]];

    var _seen = {};
    var _sum = 0;
    for (var _i = 0; _i < array_length(_sample.options); _i++) {
        var _oa = _sample.options[_i].action;
        if (variable_struct_exists(_seen, string(_oa))) continue;
        _seen[$ string(_oa)] = true;
        _sum += ((_oa < array_length(_bucket.counts)) ? _bucket.counts[_oa] : 0) + count.smoothing;
    }
    var _c = (_a < array_length(_bucket.counts)) ? _bucket.counts[_a] : 0;
    var _share = (_c + count.smoothing) / _sum;
    return [_where + ": " + actions[_a] + " " + string_format(_c, 1, 1) + " of " + string_format(_bucket.total, 1, 1)
        + " (" + string_format(_share, 1, 2) + ")"];
}

function __gmsa_learn_count_save() {
    return { bins : count.bins, has_keys : (data.keys != undefined), keys : (data.keys != undefined) ? data.keys : [],
             clock : data.clock, buckets : data.buckets };
}

function __gmsa_learn_count_load(_data) {
    if (_data.bins != count.bins) throw "GMSA: count save uses " + string(_data.bins) + " bins, the model uses " + string(count.bins);
    data.keys    = _data.has_keys ? _data.keys : count.names;
    data.clock   = _data.clock;
    data.buckets = _data.buckets;
}

// Internal
function __gmsa_learn_count_check_size(_bins, _n) {
    var _size = power(_bins, _n);
    if (_size > GMSA_LEARN_COUNT_MAX_BUCKETS) {
        throw "GMSA: count model would have " + string(_size) + " situation buckets, the limit is "
            + string(GMSA_LEARN_COUNT_MAX_BUCKETS) + ". Use fewer inputs or fewer bins";
    }
}

function __gmsa_learn_count_keys(_model) {
    var _data = _model.data;
    if (_data.keys == undefined) {
        var _keys = [];
        for (var _i = 0; _i < array_length(_model.inputs); _i++) {
            if (_model.situational[_i]) array_push(_keys, _model.inputs[_i]);
        }
        __gmsa_learn_count_check_size(_model.count.bins, array_length(_keys));
        _data.keys = _keys;
    }
    return _data.keys;
}

function __gmsa_learn_count_key(_model, _sample, _bins_out) {
    var _keys = __gmsa_learn_count_keys(_model);
    var _nb = _model.count.bins;
    var _key = "";
    array_resize(_bins_out, array_length(_keys));
    for (var _i = 0; _i < array_length(_keys); _i++) {
        var _id = variable_struct_exists(_model.input_lookup, _keys[_i]) ? _model.input_lookup[$ _keys[_i]] : -1;
        var _v = (_id >= 0 && _id < array_length(_sample.situation)) ? _sample.situation[_id] : 0;
        var _b = min(_nb - 1, floor(clamp(_v, 0, 1) * _nb));
        _bins_out[_i] = _b;
        _key += ((_i > 0) ? "_" : "") + string(_b);
    }
    return _key;
}

function __gmsa_learn_count_age(_model, _bucket) {
    var _age = _model.data.clock - _bucket.last;
    if (_age <= 0) return;
    var _f = power(_model.decay, _age);
    for (var _i = 0; _i < array_length(_bucket.counts); _i++) _bucket.counts[_i] *= _f;
    _bucket.total *= _f;
    _bucket.last = _model.data.clock;
}