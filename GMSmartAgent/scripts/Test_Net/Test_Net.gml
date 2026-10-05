function test_net() {
    gmsa_test_suite("Net", function() {

        gmsa_test_case("create validates", function() {
            gmsa_test_assert_throws(function() { gmsa_net_create(0, [1]); }, "inputs 0");
            gmsa_test_assert_throws(function() { gmsa_net_create(1.5, [1]); }, "inputs 1.5");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, []); }, "no layers");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [0]); }, "layer size 0");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [{ size : 2, activation : 9 }]); }, "bad layer activation");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [1], { activation : -1 }); }, "bad activation");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [1], { optimizer : 5 }); }, "bad optimizer");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [1], { learn_rate : 0 }); }, "learn_rate 0");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [1], { momentum : 1 }); }, "momentum 1");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [1], { weight_decay : -1 }); }, "negative decay");
            gmsa_test_assert_throws(function() { gmsa_net_create(2, [1], { learn_rate : 0.5, weight_decay : 2 }); }, "decay too strong");
        });

        gmsa_test_case("shape", function() {
            var _net = gmsa_net_create(3, [4, { size : 2, activation : gmsa_net_activation.SIGMOID }]);
            gmsa_test_assert_equal(_net.outputs, 2, "outputs");
            gmsa_test_assert_equal(array_length(_net.layers), 2, "layers");
            gmsa_test_assert_equal(array_length(_net.layers[0].w), 12, "layer 0 weights");
            gmsa_test_assert_equal(array_length(_net.layers[1].w), 8, "layer 1 weights");
            gmsa_test_assert_equal(_net.layers[0].activation, gmsa_net_activation.TANH, "hidden default");
            gmsa_test_assert_equal(_net.layers[1].activation, gmsa_net_activation.SIGMOID, "per layer activation");
        });

        gmsa_test_case("forward computes known values", function() {
            var _net = gmsa_net_create(2, [1]);
            _net.layers[0].w[0] = 2;
            _net.layers[0].w[1] = 3;
            _net.layers[0].b[0] = 1;
            var _out = gmsa_net_forward(_net, [1, 2]);
            gmsa_test_assert_near(_out[0], 9, 0.000001, "linear");
            _out = gmsa_net_forward(_net, [1]);
            gmsa_test_assert_near(_out[0], 3, 0.000001, "short input padded with 0");
            gmsa_test_assert_throws(method({ net : _net }, function() { gmsa_net_forward(net, [1, 2, 3]); }), "input too long");
        });

        gmsa_test_case("activations", function() {
            var _acts = [gmsa_net_activation.LINEAR, gmsa_net_activation.TANH, gmsa_net_activation.RELU, gmsa_net_activation.LEAKY_RELU, gmsa_net_activation.SIGMOID];
            var _xs = [-0.8, 0.6];
            for (var _a = 0; _a < 5; _a++) {
                var _net = gmsa_net_create(1, [1], { output : _acts[_a] });
                _net.layers[0].w[0] = 1;
                for (var _j = 0; _j < 2; _j++) {
                    var _x = _xs[_j];
                    var _expect = _x;
                    switch (_acts[_a]) {
                        case gmsa_net_activation.TANH:       _expect = (exp(_x) - exp(-_x)) / (exp(_x) + exp(-_x)); break;
                        case gmsa_net_activation.RELU:       _expect = max(0, _x); break;
                        case gmsa_net_activation.LEAKY_RELU: _expect = (_x > 0) ? _x : 0.01 * _x; break;
                        case gmsa_net_activation.SIGMOID:    _expect = 1 / (1 + exp(-_x)); break;
                    }
                    var _out = gmsa_net_forward(_net, [_x]);
                    gmsa_test_assert_near(_out[0], _expect, 0.000001, "activation " + string(_a) + " at " + string(_x));
                }
            }
        });

        gmsa_test_case("gradient check, linear", function() { gmsa_test_assert_range(__test_net_gradcheck(gmsa_net_activation.LINEAR, [4, 2]), 0, 0.0001); });
        gmsa_test_case("gradient check, tanh", function() { gmsa_test_assert_range(__test_net_gradcheck(gmsa_net_activation.TANH, [4, 2]), 0, 0.0001); });
        gmsa_test_case("gradient check, relu", function() { gmsa_test_assert_range(__test_net_gradcheck(gmsa_net_activation.RELU, [4, 2]), 0, 0.0001); });
        gmsa_test_case("gradient check, leaky relu", function() { gmsa_test_assert_range(__test_net_gradcheck(gmsa_net_activation.LEAKY_RELU, [4, 2]), 0, 0.0001); });
        gmsa_test_case("gradient check, sigmoid", function() { gmsa_test_assert_range(__test_net_gradcheck(gmsa_net_activation.SIGMOID, [4, 2]), 0, 0.0001); });
        gmsa_test_case("gradient check, deep", function() { gmsa_test_assert_range(__test_net_gradcheck(gmsa_net_activation.TANH, [5, 4, 3, 2]), 0, 0.0001); });
        gmsa_test_case("gradient check, sigmoid output", function() {
            gmsa_test_assert_range(__test_net_gradcheck(gmsa_net_activation.TANH, [4, { size : 2, activation : gmsa_net_activation.SIGMOID }]), 0, 0.0001);
        });

        gmsa_test_case("gradients add up until step", function() {
            var _net = gmsa_net_create(2, [3, 1], { seed : 11 });
            gmsa_net_forward(_net, [0.4, -0.3]);
            gmsa_net_backward(_net, 0.7);
            var _once = _net.layers[0].gw[0];
            gmsa_net_backward(_net, 0.7);
            gmsa_test_assert_near(_net.layers[0].gw[0], _once * 2, 0.000001, "accumulated");
            gmsa_net_zero_grad(_net);
            gmsa_test_assert_equal(_net.layers[0].gw[0], 0, "zero_grad clears");
            gmsa_test_assert_throws(method({ net : _net }, function() { gmsa_net_backward(net, [1, 2]); }), "wrong gradient length");
        });

        gmsa_test_case("step only after backward", function() {
            var _net = gmsa_net_create(2, [1], { learn_rate : 0.1, weight_decay : 0.5, seed : 2 });
            var _w0 = _net.layers[0].w[0];
            gmsa_net_step(_net);
            gmsa_test_assert_equal(_net.layers[0].w[0], _w0, "no backward, no change");
            gmsa_net_forward(_net, [1, 1]);
            gmsa_net_backward(_net, 0);
            gmsa_net_step(_net);
            gmsa_test_assert_near(_net.layers[0].w[0], _w0 * 0.95, 0.000001, "decay only");
            gmsa_test_assert_equal(_net.steps, 1, "steps counted");
        });

        gmsa_test_case("SGD learns a linear function", function() {
            var _net = gmsa_net_create(2, [1], { learn_rate : 0.1, seed : 5 });
            var _rng = gmsa_rng_create(9);
            repeat (2000) {
                var _a = gmsa_rng_next(_rng) * 2 - 1;
                var _b = gmsa_rng_next(_rng) * 2 - 1;
                gmsa_net_train(_net, [_a, _b], 2 * _a - _b + 0.5);
            }
            gmsa_test_assert_near(_net.layers[0].w[0], 2, 0.01, "w0");
            gmsa_test_assert_near(_net.layers[0].w[1], -1, 0.01, "w1");
            gmsa_test_assert_near(_net.layers[0].b[0], 0.5, 0.01, "bias");
        });

        gmsa_test_case("SGD with momentum learns a linear function", function() {
            var _net = gmsa_net_create(2, [1], { learn_rate : 0.02, momentum : 0.9, seed : 5 });
            var _rng = gmsa_rng_create(9);
            repeat (2000) {
                var _a = gmsa_rng_next(_rng) * 2 - 1;
                var _b = gmsa_rng_next(_rng) * 2 - 1;
                gmsa_net_train(_net, [_a, _b], 2 * _a - _b + 0.5);
            }
            gmsa_test_assert_near(_net.layers[0].w[0], 2, 0.01, "w0");
            gmsa_test_assert_near(_net.layers[0].w[1], -1, 0.01, "w1");
        });

        gmsa_test_case("Adam learns XOR", function() {
            var _net = gmsa_net_create(2, [8, 1], { optimizer : gmsa_net_optimizer.ADAM, learn_rate : 0.05, seed : 3 });
            var _x = [[0, 0], [0, 1], [1, 0], [1, 1]];
            var _y = [0, 1, 1, 0];
            repeat (1500) {
                for (var _i = 0; _i < 4; _i++) gmsa_net_train(_net, _x[_i], _y[_i]);
            }
            for (var _i = 0; _i < 4; _i++) {
                var _out = gmsa_net_forward(_net, _x[_i]);
                gmsa_test_assert_near(_out[0], _y[_i], 0.15, "xor " + string(_i));
            }
        });

        gmsa_test_case("same seed, same net", function() {
            var _a = gmsa_net_create(3, [4, 1], { seed : 42 });
            var _b = gmsa_net_create(3, [4, 1], { seed : 42 });
            var _c = gmsa_net_create(3, [4, 1], { seed : 43 });
            var _oa = gmsa_net_forward(_a, [0.1, 0.5, -0.4])[0];
            var _ob = gmsa_net_forward(_b, [0.1, 0.5, -0.4])[0];
            var _oc = gmsa_net_forward(_c, [0.1, 0.5, -0.4])[0];
            gmsa_test_assert_equal(_oa, _ob, "same seed");
            gmsa_test_assert_true(_oa != _oc, "different seed");
            gmsa_net_train(_a, [0.1, 0.5, -0.4], 1);
            gmsa_net_reset(_a);
            gmsa_test_assert_equal(gmsa_net_forward(_a, [0.1, 0.5, -0.4])[0], _ob, "reset restores");
        });

        gmsa_test_case("grow keeps outputs", function() {
            var _net = gmsa_net_create(2, [3, 1], { seed : 4 });
            var _before = gmsa_net_forward(_net, [0.2, 0.6])[0];
            gmsa_net_grow_inputs(_net, 2);
            gmsa_test_assert_equal(_net.inputs, 4, "inputs");
            gmsa_test_assert_equal(array_length(_net.layers[0].w), 12, "weights");
            var _after = gmsa_net_forward(_net, [0.2, 0.6, 0.9, -0.4])[0];
            gmsa_test_assert_near(_after, _before, 0.000001, "new inputs start at 0");
            gmsa_net_train(_net, [0.2, 0.6, 0.9, -0.4], 1);
            gmsa_test_assert_true(_net.layers[0].w[2] != 0, "new inputs learn");
        });

        gmsa_test_case("save and load", function() {
            var _a = gmsa_net_create(3, [4, 2], { seed : 1 });
            repeat (20) gmsa_net_train(_a, [0.3, -0.2, 0.8], [0.5, -0.5]);
            var _save = gmsa_net_save(_a);
            var _kept = _save.layers[0].w[0];
            gmsa_net_train(_a, [0.3, -0.2, 0.8], [0.5, -0.5]);
            gmsa_test_assert_equal(_save.layers[0].w[0], _kept, "save is a copy");

            var _b = gmsa_net_create(3, [4, 2], { seed : 99 });
            gmsa_net_load(_b, json_stringify(_save));
            gmsa_net_load(_a, _save);
            var _oa = gmsa_net_forward(_a, [0.1, 0.2, 0.3]);
            var _a0 = _oa[0], _a1 = _oa[1];
            var _ob = gmsa_net_forward(_b, [0.1, 0.2, 0.3]);
            gmsa_test_assert_near(_ob[0], _a0, 0.000001, "output 0");
            gmsa_test_assert_near(_ob[1], _a1, 0.000001, "output 1");

            var _wide = gmsa_net_create(5, [4, 2], { seed : 7 });
            gmsa_net_load(_wide, _save);
            var _ow = gmsa_net_forward(_wide, [0.1, 0.2, 0.3, 0.9, 0.9]);
            gmsa_test_assert_near(_ow[0], _a0, 0.000001, "fewer saved inputs padded with 0");

            var _narrow = gmsa_net_create(2, [4, 2], { seed : 7 });
            gmsa_net_load(_narrow, _save);
            gmsa_test_assert_equal(_narrow.inputs, 3, "more saved inputs grow the net");

            gmsa_test_assert_throws(method({ save : _save }, function() { gmsa_net_load(gmsa_net_create(3, [5, 2]), save); }), "different shape");
            gmsa_test_assert_throws(method({ save : _save }, function() {
                gmsa_net_load(gmsa_net_create(3, [4, { size : 2, activation : gmsa_net_activation.SIGMOID }]), save);
            }), "different activation");
            gmsa_test_assert_throws(function() { gmsa_net_load(gmsa_net_create(3, [4, 2]), "{ broken"); }, "malformed");
            gmsa_test_assert_throws(function() { gmsa_net_load(gmsa_net_create(3, [4, 2]), { version : 99, inputs : 3, layers : [] }); }, "newer version");
        });
    });
}

function __test_net_gradcheck(_activation, _layers) {
    var _net = gmsa_net_create(3, _layers, { activation : _activation, seed : 7 });
    var _input = [0.3, -0.7, 0.9];
    var _target = array_create(_net.outputs, 0);
    for (var _i = 0; _i < _net.outputs; _i++) _target[_i] = 0.5 - 0.3 * _i;

    gmsa_net_zero_grad(_net);
    var _out = gmsa_net_forward(_net, _input);
    var _grad = array_create(_net.outputs, 0);
    for (var _i = 0; _i < _net.outputs; _i++) _grad[_i] = _out[_i] - _target[_i];
    gmsa_net_backward(_net, _grad);

    var _h = 0.000001;
    var _worst = 0;
    for (var _l = 0; _l < array_length(_net.layers); _l++) {
        var _layer = _net.layers[_l];
        for (var _k = 0; _k < array_length(_layer.w); _k++) {
            var _keep = _layer.w[_k];
            _layer.w[_k] = _keep + _h;
            var _up = __test_net_loss(_net, _input, _target);
            _layer.w[_k] = _keep - _h;
            var _down = __test_net_loss(_net, _input, _target);
            _layer.w[_k] = _keep;
            var _num = (_up - _down) / (2 * _h);
            _worst = max(_worst, abs(_num - _layer.gw[_k]) / max(1, abs(_num)));
        }
        for (var _o = 0; _o < _layer.size; _o++) {
            var _keep = _layer.b[_o];
            _layer.b[_o] = _keep + _h;
            var _up = __test_net_loss(_net, _input, _target);
            _layer.b[_o] = _keep - _h;
            var _down = __test_net_loss(_net, _input, _target);
            _layer.b[_o] = _keep;
            var _num = (_up - _down) / (2 * _h);
            _worst = max(_worst, abs(_num - _layer.gb[_o]) / max(1, abs(_num)));
        }
    }
    return _worst;
}

function __test_net_loss(_net, _input, _target) {
    var _out = gmsa_net_forward(_net, _input);
    var _loss = 0;
    for (var _i = 0; _i < array_length(_target); _i++) {
        var _e = _out[_i] - _target[_i];
        _loss += _e * _e;
    }
    return 0.5 * _loss;
}