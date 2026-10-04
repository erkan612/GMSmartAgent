function gmsa_debug_lines(_decision, _max = 8, _namer = undefined) {
    var _lines = [];
    var _options = _decision.options;
    var _total = array_length(_options);
    if (_total == 0) {
        array_push(_lines, "no selectable options");
        return _lines;
    }
    var _count = min(_total, _max);
    for (var _i = 0; _i < _count; _i++) {
        var _o = _options[_i];
        var _line = ((_i == _decision.chosen) ? "> " : "  ")
            + string_format(_o.score, 1, 3) + "  p" + string_format(_o.probability, 1, 2) + "  " + _o.action.name;
        if (_o.target != undefined) _line += " @ " + __gmsa_debug_target_text(_o.target, _namer);
        var _cons = _o.action.considerations;
        if (array_length(_cons) > 0) {
            _line += "  [";
            for (var _c = 0; _c < array_length(_cons); _c++) {
                if (_c > 0) _line += ", ";
                _line += _cons[_c].input + " " + string_format(_o.features[_c], 1, 2);
            }
            _line += "]";
        }
        array_push(_lines, _line);
    }
    if (_total > _count) array_push(_lines, "  ... " + string(_total - _count) + " more");
    return _lines;
}

function gmsa_debug_explain(_decision, _max = 8, _namer = undefined) {
    var _lines = gmsa_debug_lines(_decision, _max, _namer);
    var _text = "";
    for (var _i = 0; _i < array_length(_lines); _i++) {
        if (_i > 0) _text += "\n";
        _text += _lines[_i];
    }
    return _text;
}

function gmsa_debug_draw(_decision, _x, _y, _max = 8, _namer = undefined) {
    var _lines = gmsa_debug_lines(_decision, _max, _namer);
    var _problems = gmsa_test_decision_problems(_decision);
    var _h = string_height("M");
    var _old = draw_get_colour();
    var _n = array_length(_lines);
    for (var _i = 0; _i < _n; _i++) {
        draw_set_colour((string_char_at(_lines[_i], 1) == ">") ? c_lime : c_white);
        draw_text(_x, _y + _i * _h, _lines[_i]);
    }
    draw_set_colour(c_red);
    for (var _i = 0; _i < array_length(_problems); _i++) {
        draw_text(_x, _y + (_n + _i) * _h, "! " + _problems[_i]);
    }
    draw_set_colour(_old);
    return (_n + array_length(_problems)) * _h;
}

function __gmsa_debug_target_text(_target, _namer) {
    if (_namer != undefined) return string(_namer(_target));
    return is_struct(_target) ? "struct" : string(_target);
}