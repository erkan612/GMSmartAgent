enum gmsa_curve { LINEAR, POWER, LOGISTIC, STEP, CUSTOM }

function gmsa_curve_make(_type, _params = {}) {
    var _m = 1, _k = 1, _b = 0, _c = 0;
    switch (_type) {
        case gmsa_curve.LINEAR:   break;
        case gmsa_curve.POWER:    _k = 2; break;
        case gmsa_curve.LOGISTIC: _k = 10; _c = 0.5; break;
        case gmsa_curve.STEP:     _c = 0.5; break;
        case gmsa_curve.CUSTOM:   break;
        default: throw "GMSA: unknown curve type " + string(_type);
    }

    var _curve = {
        type    : _type,
        m       : __gmsa_param(_params, "m", _m),
        k       : __gmsa_param(_params, "k", _k),
        b       : __gmsa_param(_params, "b", _b),
        c       : __gmsa_param(_params, "c", _c),
        invert  : __gmsa_param(_params, "invert", false),
        func    : __gmsa_param(_params, "func", undefined),
        channel : undefined,
    };

    if (_type == gmsa_curve.CUSTOM) {
        var _asset = __gmsa_param(_params, "animcurve", undefined);
        if (_asset != undefined) {
            if (!animcurve_exists(_asset)) throw "GMSA: CUSTOM curve animcurve does not exist";
            _curve.channel = animcurve_get_channel(_asset, __gmsa_param(_params, "channel", 0));
        } else if (!is_callable(_curve.func)) {
            throw "GMSA: CUSTOM curve needs func or animcurve";
        }
    }
    return _curve;
}

function gmsa_curve_eval(_curve, _x) {
    _x = clamp(_x, 0, 1);
    var _y;
    switch (_curve.type) {
        case gmsa_curve.LINEAR:
            _y = _curve.m * (_x - _curve.c) + _curve.b;
            break;
        case gmsa_curve.POWER:
            var _base = _x - _curve.c;
            // fractional exponents of negative numbers are NaN, best to keep the sign instead
            if (_base < 0 && frac(_curve.k) != 0) _y = -power(-_base, _curve.k);
            else _y = power(_base, _curve.k);
            _y = _curve.m * _y + _curve.b;
            break;
        case gmsa_curve.LOGISTIC:
            _y = _curve.m / (1 + exp(-_curve.k * (_x - _curve.c))) + _curve.b;
            break;
        case gmsa_curve.STEP:
            _y = ((_x >= _curve.c) ? _curve.m : 0) + _curve.b;
            break;
        case gmsa_curve.CUSTOM:
            _y = (_curve.channel != undefined) ? animcurve_channel_evaluate(_curve.channel, _x) : _curve.func(_x);
            break;
        default:
            _y = 0;
    }
    if (!is_numeric(_y) || is_nan(_y)) return 0;
    _y = clamp(_y, 0, 1);
    return _curve.invert ? (1 - _y) : _y;
}

//function __gmsa_param(_params, _name, _default) {
//    if (is_struct(_params) && variable_struct_exists(_params, _name)) return _params[$ _name];
//    return _default;
//}