function gmsa_learn_ranknet_create(_params = {}) {
    var _hidden = __gmsa_param(_params, "hidden", [8]);
    if (!is_array(_hidden)) throw "GMSA: ranknet hidden must be an array of layer sizes";
    var _lr = __gmsa_param(_params, "learn_rate", 0.02);
    if (!__gmsa_net_above_zero(_lr)) throw "GMSA: ranknet learn_rate must be above 0";

    var _model = __gmsa_learn_model_create(gmsa_learn_tier.RANKNET, "ranknet", {
        half_life    : __gmsa_param(_params, "half_life", 200),
        confidence_k : __gmsa_param(_params, "confidence_k", 40),
    });

    var _layers = [];
    for (var _i = 0; _i < array_length(_hidden); _i++) array_push(_layers, _hidden[_i]);
    array_push(_layers, 1);
    _model.ranknet = {
        layers     : _layers,
        activation : __gmsa_param(_params, "activation", gmsa_net_activation.TANH),
        optimizer  : __gmsa_param(_params, "optimizer", gmsa_net_optimizer.ADAM),
        learn_rate : _lr,
        momentum   : __gmsa_param(_params, "momentum", 0),
        seed       : __gmsa_param(_params, "seed", 1),
    };
    __gmsa_learn_ranknet_net(_model, 1); // validates the network settings now, not on first use

    _model.__x = [];  // encoded option, written through the struct
    _model.__s = [];  // scores of the last sample
    _model.__g = [];  // score gradients of the last observation
    _model.__p = [];  // softmax of the last sample
    _model.observe    = method(_model, __gmsa_learn_ranknet_observe);
    _model.predict    = method(_model, __gmsa_learn_ranknet_predict);
    _model.explain    = method(_model, __gmsa_learn_ranknet_explain);
    _model.save_data  = method(_model, __gmsa_learn_ranknet_save);
    _model.load_data  = method(_model, __gmsa_learn_ranknet_load);
    _model.reset_data = method(_model, __gmsa_learn_ranknet_reset);
    _model.reset_data();
    return _model;
}

// Methods, run with the model as self
function __gmsa_learn_ranknet_reset() {
    data = { net : undefined, slots : 0, input_slot : [], action_slot : [] };
}

function __gmsa_learn_ranknet_observe(_sample) {
    var _n = array_length(_sample.options);
    var _c = _sample.chosen;
    if (_n < 2 || _c < 0) return; // a single option teaches no preference
    __gmsa_learn_ranknet_grow(self);
    __gmsa_learn_ranknet_scores(self, _sample);

    var _sc = __s[_c];
    var _scale = _sample.weight / (_n - 1);
    var _sum = 0;
    for (var _i = 0; _i < _n; _i++) {
        if (_i == _c) continue;
        var _lambda = 1 / (1 + exp(_sc - __s[_i]));
        __g[_i] = _lambda * _scale;
        _sum += _lambda;
    }
    __g[_c] = -_sum * _scale;

    var _net = data.net;
    for (var _i = 0; _i < _n; _i++) {
        __gmsa_learn_slots_encode(self, _sample.options[_i]);
        gmsa_net_forward(_net, __x);
        gmsa_net_backward(_net, __g[_i]);
    }
    gmsa_net_step(_net); // one update per observation, weight decay applies the half-life
}

function __gmsa_learn_ranknet_predict(_sample, _out) {
    __gmsa_learn_ranknet_grow(self);
    var _n = array_length(_sample.options);
    __gmsa_learn_ranknet_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, _n);
    for (var _i = 0; _i < _n; _i++) _out.p[_i] = __p[_i];
    _out.confidence = gmsa_learn_confidence(self);
}

function __gmsa_learn_ranknet_explain(_sample, _index) {
    __gmsa_learn_ranknet_grow(self);
    __gmsa_learn_ranknet_scores(self, _sample);
    __gmsa_learn_softmax_scores(self, array_length(_sample.options));
    return __gmsa_learn_explain_line(self, _sample, _index, __gmsa_learn_ranknet_score_x);
}

function __gmsa_learn_ranknet_save() {
    return {
        slots       : data.slots,
        input_slot  : data.input_slot,
        action_slot : data.action_slot,
        net         : (data.net == undefined) ? 0 : gmsa_net_save(data.net),
    };
}

function __gmsa_learn_ranknet_load(_data) {
    if (!is_numeric(_data[$ "slots"]) || !is_array(_data[$ "input_slot"]) || !is_array(_data[$ "action_slot"])) {
        throw "GMSA: ranknet save is malformed";
    }
    var _net = undefined;
    if (is_struct(_data[$ "net"])) {
        _net = __gmsa_learn_ranknet_net(self, max(1, _data.slots));
        gmsa_net_load(_net, _data.net); // throws when the hidden layers differ
    }
    data = { net : _net, slots : _data.slots, input_slot : _data.input_slot, action_slot : _data.action_slot };
}

// Internal
function __gmsa_learn_ranknet_net(_model, _inputs) {
    var _r = _model.ranknet;
    return gmsa_net_create(_inputs, _r.layers, {
        activation   : _r.activation,
        output       : gmsa_net_activation.LINEAR,
        optimizer    : _r.optimizer,
        learn_rate   : _r.learn_rate,
        momentum     : _r.momentum,
        weight_decay : (1 - _model.decay) / _r.learn_rate, // weights shrink by decay every step
        seed         : _r.seed,
    });
}

function __gmsa_learn_ranknet_grow(_model) {
    __gmsa_learn_slots_grow(_model);
    var _d = _model.data;
    if (_d.slots == 0) return;
    if (_d.net == undefined) {
        _d.net = __gmsa_learn_ranknet_net(_model, _d.slots);
        // output weights start at 0: every option scores the same until something is learned
        var _last = _d.net.layers[array_length(_d.net.layers) - 1];
        for (var _k = 0; _k < array_length(_last.w); _k++) _last.w[_k] = 0;
    } else if (_d.net.inputs < _d.slots) {
        gmsa_net_grow_inputs(_d.net, _d.slots - _d.net.inputs);
    }
}

function __gmsa_learn_ranknet_scores(_model, _sample) {
    var _n = array_length(_sample.options);
    array_resize(_model.__s, _n);
    array_resize(_model.__g, _n);
    for (var _i = 0; _i < _n; _i++) {
        __gmsa_learn_slots_encode(_model, _sample.options[_i]);
        _model.__s[_i] = __gmsa_learn_ranknet_score_x(_model);
    }
}

function __gmsa_learn_ranknet_score_x(_model) {
    var _out = gmsa_net_forward(_model.data.net, _model.__x);
    return _out[0];
}