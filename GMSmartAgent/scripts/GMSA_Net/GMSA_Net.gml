#macro GMSA_NET_VERSION 1

enum gmsa_net_activation { LINEAR, TANH, RELU, LEAKY_RELU, SIGMOID }
enum gmsa_net_optimizer { SGD, ADAM }

function gmsa_net_create(_inputs, _layers, _params = undefined) {
    if (!__gmsa_net_whole(_inputs)) throw "GMSA: net inputs must be a whole number of 1 or more";
    if (!is_array(_layers) || array_length(_layers) == 0) throw "GMSA: net layers must be a non-empty array";

    var _hidden    = __gmsa_param(_params, "activation", gmsa_net_activation.TANH);
    var _output    = __gmsa_param(_params, "output", gmsa_net_activation.LINEAR);
    var _optimizer = __gmsa_param(_params, "optimizer", gmsa_net_optimizer.SGD);
    var _rate      = __gmsa_param(_params, "learn_rate", (_optimizer == gmsa_net_optimizer.ADAM) ? 0.001 : 0.01);
    var _momentum  = __gmsa_param(_params, "momentum", 0);
    var _decay     = __gmsa_param(_params, "weight_decay", 0);
    var _beta1     = __gmsa_param(_params, "beta1", 0.9);
    var _beta2     = __gmsa_param(_params, "beta2", 0.999);
    var _epsilon   = __gmsa_param(_params, "epsilon", 0.00000001);
    var _seed      = __gmsa_param(_params, "seed", 1);
    var _sparse    = __gmsa_param(_params, "sparse", false);

    if (!__gmsa_net_valid_activation(_hidden)) throw "GMSA: net activation is unknown";
    if (!__gmsa_net_valid_activation(_output)) throw "GMSA: net output activation is unknown";
    if (_optimizer != gmsa_net_optimizer.SGD && _optimizer != gmsa_net_optimizer.ADAM) throw "GMSA: net optimizer is unknown";
    if (!__gmsa_net_above_zero(_rate)) throw "GMSA: net learn_rate must be above 0";
    if (!is_numeric(_momentum) || _momentum < 0 || _momentum >= 1) throw "GMSA: net momentum must be 0 or more and below 1";
    if (!is_numeric(_decay) || _decay < 0) throw "GMSA: net weight_decay must be 0 or more";
    if (_rate * _decay >= 1) throw "GMSA: net weight_decay times learn_rate must be below 1";
    if (!is_numeric(_beta1) || _beta1 < 0 || _beta1 >= 1) throw "GMSA: net beta1 must be 0 or more and below 1";
    if (!is_numeric(_beta2) || _beta2 < 0 || _beta2 >= 1) throw "GMSA: net beta2 must be 0 or more and below 1";
    if (!__gmsa_net_above_zero(_epsilon)) throw "GMSA: net epsilon must be above 0";

    var _count = array_length(_layers);
    var _sizes = array_create(_count, 0);
    var _acts  = array_create(_count, 0);
    for (var _l = 0; _l < _count; _l++) {
        var _spec = _layers[_l];
        var _size = _spec;
        var _act  = (_l == _count - 1) ? _output : _hidden;
        if (is_struct(_spec)) {
            _size = _spec[$ "size"];
            if (_spec[$ "activation"] != undefined) _act = _spec.activation;
        }
        if (!__gmsa_net_whole(_size)) throw "GMSA: net layer " + string(_l) + " size must be a whole number of 1 or more";
        if (!__gmsa_net_valid_activation(_act)) throw "GMSA: net layer " + string(_l) + " activation is unknown";
        _sizes[_l] = _size;
        _acts[_l]  = _act;
    }

    var _net = {
        inputs       : _inputs,
        outputs      : _sizes[_count - 1],
        layers       : array_create(_count, undefined),
        optimizer    : _optimizer,
        learn_rate   : _rate,
        momentum     : _momentum,
        weight_decay : _decay,
        beta1        : _beta1,
        beta2        : _beta2,
        epsilon      : _epsilon,
        seed         : _seed,
        sparse       : (_sparse == true), // first layer skips zero inputs: faster for one-hot, slower for dense
        steps        : 0,
        rng          : gmsa_rng_create(_seed),
        __x          : array_create(_inputs, 0),
        __g          : array_create(_sizes[_count - 1], 0),
        __nz         : array_create(_inputs, 0), // nonzero inputs of the last forward
        __nzn        : 0,
        __pending    : false,
    };

    var _in = _inputs;
    for (var _l = 0; _l < _count; _l++) {
        _net.layers[_l] = __gmsa_net_layer(_in, _sizes[_l], _acts[_l]);
        _in = _sizes[_l];
    }
    __gmsa_net_init(_net);
    return _net;
}

function gmsa_net_forward(_net, _input) {
    if (!is_array(_input)) throw "GMSA: net input must be an array";
    var _n = _net.inputs;
    var _len = array_length(_input);
    if (_len > _n) throw "GMSA: net input has " + string(_len) + " values, the net takes " + string(_n) + ", grow it with gmsa_net_grow_inputs";

    var _sparse = _net.sparse;
    var _nzn = 0;
    if (_sparse) {
        for (var _i = 0; _i < _n; _i++) {
            var _v = (_i < _len) ? _input[_i] : 0;
            _net.__x[_i] = _v;
            if (_v * 1000000000000 != 0) {
                _net.__nz[_nzn] = _i;
                _nzn += 1;
            }
        }
    } else {
        for (var _i = 0; _i < _n; _i++) _net.__x[_i] = (_i < _len) ? _input[_i] : 0;
    }
    _net.__nzn = _nzn;
    var _nz = _net.__nz;

    var _prev = _net.__x;
    var _layers = _net.layers;
    var _count = array_length(_layers);
    for (var _l = 0; _l < _count; _l++) {
        var _layer = _layers[_l];
        var _in = _layer.inputs;
        var _size = _layer.size;
        var _w = _layer.w;
        var _b = _layer.b;
        var _act = _layer.activation;
        for (var _o = 0; _o < _size; _o++) {
            var _s = _b[_o];
            var _k = _o * _in;
            if (_l == 0 && _sparse) {
                for (var _t = 0; _t < _nzn; _t++) {
                    var _i = _nz[_t];
                    _s += _w[_k + _i] * _prev[_i];
                }
            } else {
                for (var _i = 0; _i < _in; _i++) _s += _w[_k + _i] * _prev[_i];
            }
            _layer.z[_o] = _s;
            switch (_act) {
                case gmsa_net_activation.TANH:
                    _s = (_s > 20) ? 1 : ((_s < -20) ? -1 : 1 - 2 / (exp(2 * _s) + 1));
                    break;
                case gmsa_net_activation.RELU:
                    if (_s < 0) _s = 0;
                    break;
                case gmsa_net_activation.LEAKY_RELU:
                    if (_s < 0) _s *= 0.01;
                    break;
                case gmsa_net_activation.SIGMOID:
                    _s = (_s > 40) ? 1 : ((_s < -40) ? 0 : 1 / (1 + exp(-_s)));
                    break;
            }
            _layer.a[_o] = _s;
        }
        _prev = _layer.a;
    }
    return _prev;
}

function gmsa_net_backward(_net, _gradient) {
    var _layers = _net.layers;
    var _last = array_length(_layers) - 1;
    var _out = _layers[_last];

    if (is_numeric(_gradient)) {
        if (_out.size != 1) throw "GMSA: net has " + string(_out.size) + " outputs, pass an array gradient";
        _out.d[0] = _gradient * __gmsa_net_slope(_out.activation, _out.z[0], _out.a[0]);
    } else {
        if (!is_array(_gradient) || array_length(_gradient) != _out.size) throw "GMSA: net gradient needs one value per output";
        for (var _o = 0; _o < _out.size; _o++) _out.d[_o] = _gradient[_o] * __gmsa_net_slope(_out.activation, _out.z[_o], _out.a[_o]);
    }

    for (var _l = _last; _l >= 0; _l--) {
        var _layer = _layers[_l];
        var _in = _layer.inputs;
        var _size = _layer.size;
        var _w = _layer.w;
        var _d = _layer.d;

        if (_l > 0) {
            var _prev = _layers[_l - 1].a;
            var _below = _layers[_l - 1];
            for (var _i = 0; _i < _in; _i++) _below.d[_i] = 0;
            for (var _o = 0; _o < _size; _o++) {
                var _do = _d[_o];
                _layer.gb[_o] += _do;
                var _k = _o * _in;
                for (var _i = 0; _i < _in; _i++) {
                    _layer.gw[_k + _i] += _do * _prev[_i];
                    _below.d[_i] += _w[_k + _i] * _do;
                }
            }
            var _bact = _below.activation;
            for (var _i = 0; _i < _in; _i++) _below.d[_i] *= __gmsa_net_slope(_bact, _below.z[_i], _below.a[_i]);
        } else if (_net.sparse) {
            var _x = _net.__x;
            var _nz = _net.__nz;
            var _nzn = _net.__nzn;
            for (var _o = 0; _o < _size; _o++) {
                var _do = _d[_o];
                _layer.gb[_o] += _do;
                var _k = _o * _in;
                for (var _t = 0; _t < _nzn; _t++) {
                    var _i = _nz[_t];
                    _layer.gw[_k + _i] += _do * _x[_i];
                }
            }
        } else {
            var _x = _net.__x;
            for (var _o = 0; _o < _size; _o++) {
                var _do = _d[_o];
                _layer.gb[_o] += _do;
                var _k = _o * _in;
                for (var _i = 0; _i < _in; _i++) _layer.gw[_k + _i] += _do * _x[_i];
            }
        }
    }
    _net.__pending = true;
}

function gmsa_net_step(_net) {
    if (!_net.__pending) return;
    _net.steps += 1;

    var _rate = _net.learn_rate;
    var _keep = 1 - _rate * _net.weight_decay;
    var _adam = (_net.optimizer == gmsa_net_optimizer.ADAM);
    var _mom = _net.momentum;
    var _b1 = _net.beta1, _b2 = _net.beta2, _eps = _net.epsilon;
    var _c1 = 1, _c2 = 1;
    if (_adam) {
        _c1 = 1 - power(_b1, _net.steps);
        _c2 = 1 - power(_b2, _net.steps);
    }

    var _layers = _net.layers;
    var _count = array_length(_layers);
    for (var _l = 0; _l < _count; _l++) {
        var _layer = _layers[_l];
        var _n = _layer.inputs * _layer.size;

        // weights, with decay
        for (var _k = 0; _k < _n; _k++) {
            var _g = _layer.gw[_k];
            if (_adam) {
                var _m = _b1 * _layer.mw[_k] + (1 - _b1) * _g;
                var _v = _b2 * _layer.vw[_k] + (1 - _b2) * _g * _g;
                _layer.mw[_k] = _m;
                _layer.vw[_k] = _v;
                _layer.w[_k] = _layer.w[_k] * _keep - _rate * (_m / _c1) / (sqrt(_v / _c2) + _eps);
            } else if (_mom > 0) {
                var _m = _mom * _layer.mw[_k] + _g;
                _layer.mw[_k] = _m;
                _layer.w[_k] = _layer.w[_k] * _keep - _rate * _m;
            } else {
                _layer.w[_k] = _layer.w[_k] * _keep - _rate * _g;
            }
            _layer.gw[_k] = 0;
        }

        // biases, no decay
        for (var _o = 0; _o < _layer.size; _o++) {
            var _g = _layer.gb[_o];
            if (_adam) {
                var _m = _b1 * _layer.mb[_o] + (1 - _b1) * _g;
                var _v = _b2 * _layer.vb[_o] + (1 - _b2) * _g * _g;
                _layer.mb[_o] = _m;
                _layer.vb[_o] = _v;
                _layer.b[_o] -= _rate * (_m / _c1) / (sqrt(_v / _c2) + _eps);
            } else if (_mom > 0) {
                var _m = _mom * _layer.mb[_o] + _g;
                _layer.mb[_o] = _m;
                _layer.b[_o] -= _rate * _m;
            } else {
                _layer.b[_o] -= _rate * _g;
            }
            _layer.gb[_o] = 0;
        }
    }
    _net.__pending = false;
}

function gmsa_net_zero_grad(_net) {
    var _layers = _net.layers;
    for (var _l = 0; _l < array_length(_layers); _l++) {
        var _layer = _layers[_l];
        var _n = _layer.inputs * _layer.size;
        for (var _k = 0; _k < _n; _k++) _layer.gw[_k] = 0;
        for (var _o = 0; _o < _layer.size; _o++) _layer.gb[_o] = 0;
    }
    _net.__pending = false;
}

function gmsa_net_train(_net, _input, _target) {
    var _out = gmsa_net_forward(_net, _input);
    var _size = _net.outputs;
    var _loss = 0;
    if (is_numeric(_target)) {
        if (_size != 1) throw "GMSA: net has " + string(_size) + " outputs, pass an array target";
        var _e = _out[0] - _target;
        _loss = _e * _e;
        _net.__g[0] = _e;
    } else {
        if (!is_array(_target) || array_length(_target) != _size) throw "GMSA: net target needs one value per output";
        for (var _o = 0; _o < _size; _o++) {
            var _e = _out[_o] - _target[_o];
            _loss += _e * _e;
            _net.__g[_o] = _e;
        }
    }
    gmsa_net_backward(_net, _net.__g);
    gmsa_net_step(_net);
    return 0.5 * _loss;
}

function gmsa_net_reset(_net, _seed = undefined) {
    if (_seed != undefined) _net.seed = _seed;
    __gmsa_net_init(_net);
}

function gmsa_net_grow_inputs(_net, _count) {
    if (!__gmsa_net_whole(_count)) throw "GMSA: net grow count must be a whole number of 1 or more";
    var _layer = _net.layers[0];
    var _old = _layer.inputs;
    var _new = _old + _count;
    var _size = _layer.size;
    var _fields = ["w", "gw", "mw", "vw"];
    for (var _f = 0; _f < 4; _f++) {
        var _src = _layer[$ _fields[_f]];
        var _dst = array_create(_size * _new, 0);
        for (var _o = 0; _o < _size; _o++) {
            for (var _i = 0; _i < _old; _i++) _dst[_o * _new + _i] = _src[_o * _old + _i];
        }
        _layer[$ _fields[_f]] = _dst;
    }
    _layer.inputs = _new;
    _net.inputs = _new;
    _net.__x = array_create(_new, 0);
    _net.__nz = array_create(_new, 0);
}

function gmsa_net_save(_net) {
    var _count = array_length(_net.layers);
    var _layers = array_create(_count, undefined);
    for (var _l = 0; _l < _count; _l++) {
        var _layer = _net.layers[_l];
        var _n = _layer.inputs * _layer.size;
        var _w = array_create(_n, 0);
        var _b = array_create(_layer.size, 0);
        array_copy(_w, 0, _layer.w, 0, _n);
        array_copy(_b, 0, _layer.b, 0, _layer.size);
        _layers[_l] = { size : _layer.size, activation : _layer.activation, w : _w, b : _b };
    }
    return { version : GMSA_NET_VERSION, inputs : _net.inputs, layers : _layers };
}

function gmsa_net_load(_net, _data) {
    if (is_string(_data)) {
        try { _data = json_parse(_data); }
        catch (_e) { throw "GMSA: net save is malformed"; }
    }
    if (!is_struct(_data) || !is_numeric(_data[$ "version"]) || !is_array(_data[$ "layers"])) throw "GMSA: net save is malformed";
    if (_data.version > GMSA_NET_VERSION) throw "GMSA: net save is from a newer version";
    if (!__gmsa_net_whole(_data[$ "inputs"])) throw "GMSA: net save is malformed";

    var _saved = _data.layers;
    var _count = array_length(_net.layers);
    if (array_length(_saved) != _count) throw "GMSA: net save has a different number of layers";
    var _in = _data.inputs;
    for (var _l = 0; _l < _count; _l++) {
        var _s = _saved[_l];
        var _layer = _net.layers[_l];
        if (!is_struct(_s) || !is_array(_s[$ "w"]) || !is_array(_s[$ "b"])) throw "GMSA: net save is malformed";
        if (_s[$ "size"] != _layer.size || _s[$ "activation"] != _layer.activation) throw "GMSA: net save layer " + string(_l) + " has a different shape";
        if (array_length(_s.w) != _in * _layer.size || array_length(_s.b) != _layer.size) throw "GMSA: net save is malformed";
        _in = _layer.size;
    }

    var _from0 = _data.inputs;
    if (_from0 > _net.inputs) gmsa_net_grow_inputs(_net, _from0 - _net.inputs);

    for (var _l = 0; _l < _count; _l++) {
        var _s = _saved[_l];
        var _layer = _net.layers[_l];
        var _to = _layer.inputs;
        var _from = (_l == 0) ? _from0 : _to;
        for (var _o = 0; _o < _layer.size; _o++) {
            _layer.b[_o] = _s.b[_o];
            for (var _i = 0; _i < _to; _i++) _layer.w[_o * _to + _i] = (_i < _from) ? _s.w[_o * _from + _i] : 0;
        }
    }
    __gmsa_net_clear_state(_net);
    return true;
}

// internals
function __gmsa_net_layer(_inputs, _size, _activation) {
    var _n = _inputs * _size;
    return {
        inputs : _inputs, size : _size, activation : _activation,
        w  : array_create(_n, 0),     b  : array_create(_size, 0),
        gw : array_create(_n, 0),     gb : array_create(_size, 0),
        mw : array_create(_n, 0),     mb : array_create(_size, 0),
        vw : array_create(_n, 0),     vb : array_create(_size, 0),
        z  : array_create(_size, 0),  a  : array_create(_size, 0),
        d  : array_create(_size, 0),
    };
}

function __gmsa_net_init(_net) {
    gmsa_rng_seed(_net.rng, _net.seed);
    var _layers = _net.layers;
    for (var _l = 0; _l < array_length(_layers); _l++) {
        var _layer = _layers[_l];
        var _in = _layer.inputs;
        var _act = _layer.activation;
        var _relu = (_act == gmsa_net_activation.RELU || _act == gmsa_net_activation.LEAKY_RELU);
        var _limit = _relu ? sqrt(6 / _in) : sqrt(6 / (_in + _layer.size));  // He or Xavier
        var _n = _in * _layer.size;
        for (var _k = 0; _k < _n; _k++) _layer.w[_k] = (gmsa_rng_next(_net.rng) * 2 - 1) * _limit;
        for (var _o = 0; _o < _layer.size; _o++) _layer.b[_o] = 0;
    }
    __gmsa_net_clear_state(_net);
}

function __gmsa_net_clear_state(_net) {
    var _layers = _net.layers;
    for (var _l = 0; _l < array_length(_layers); _l++) {
        var _layer = _layers[_l];
        var _n = _layer.inputs * _layer.size;
        for (var _k = 0; _k < _n; _k++) {
            _layer.gw[_k] = 0;
            _layer.mw[_k] = 0;
            _layer.vw[_k] = 0;
        }
        for (var _o = 0; _o < _layer.size; _o++) {
            _layer.gb[_o] = 0;
            _layer.mb[_o] = 0;
            _layer.vb[_o] = 0;
        }
    }
    _net.steps = 0;
    _net.__pending = false;
}

function __gmsa_net_slope(_act, _z, _a) {
    switch (_act) {
        case gmsa_net_activation.TANH:       return 1 - _a * _a;
        case gmsa_net_activation.RELU:       return (_z > 0) ? 1 : 0;
        case gmsa_net_activation.LEAKY_RELU: return (_z > 0) ? 1 : 0.01;
        case gmsa_net_activation.SIGMOID:    return _a * (1 - _a);
    }
    return 1;
}

function __gmsa_net_whole(_value) {
    return is_numeric(_value) && _value >= 1 && _value == floor(_value);
}

function __gmsa_net_above_zero(_value) {
    return is_numeric(_value) && _value * 1000000000000 > 0;
}

function __gmsa_net_valid_activation(_act) {
    return is_numeric(_act) && _act == floor(_act) && _act >= gmsa_net_activation.LINEAR && _act <= gmsa_net_activation.SIGMOID;
}