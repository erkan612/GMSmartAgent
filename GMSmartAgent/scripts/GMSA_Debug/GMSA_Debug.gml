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
        var _designer = __gmsa_param(_o, "designer", _o.score);
        if (abs(_o.score - _designer) > 0.0005) _line += "  (designer " + string_format(_designer, 1, 3) + ")";
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

function gmsa_debug_draw_tree(_lines, _x, _y, _max = 40) {
    var _h = string_height("M");
    var _old = draw_get_colour();
    var _old_alpha = draw_get_alpha();
    var _total = array_length(_lines);
    var _n = min(_total, _max);
    var _yy = _y;
    for (var _i = 0; _i < _n; _i++) {
        var _line = _lines[_i];
        var _text = __gmsa_debug_tree_text(_line);
        if (__gmsa_param(_line, "repaired", false)) {
            // what the last repair put in
            draw_set_alpha(0.3);
            draw_set_colour(c_yellow);
            draw_rectangle(_x - 2, _yy, _x + string_width(_text) + 2, _yy + _h - 1, false);
            draw_set_alpha(_old_alpha);
        }
        draw_set_colour(__gmsa_debug_tree_colour(_line.kind));
        draw_text(_x, _yy, _text);
        _yy += _h;
        var _progress = __gmsa_param(_line, "progress", undefined);
        if (_progress != undefined) {
            var _w = max(120, string_width(_text));
            draw_set_colour(c_dkgray);
            draw_rectangle(_x, _yy + 2, _x + _w, _yy + 6, false);
            draw_set_colour(c_lime);
            draw_rectangle(_x, _yy + 2, _x + _w * clamp(_progress, 0, 1), _yy + 6, false);
            _yy += 10;
        }
    }
    if (_total > _n) {
        draw_set_colour(c_white);
        draw_text(_x, _yy, "  ... " + string(_total - _n) + " more");
        _yy += _h;
    }
    draw_set_colour(_old);
    draw_set_alpha(_old_alpha);
    return _yy - _y;
}

function __gmsa_debug_tree_text(_line) {
    var _indent = string_repeat("  ", _line.depth);
    switch (_line.kind) {
        case "title": case "note": return _line.text;
        case "current": return _indent + "> " + _line.text;
        case "done": return _indent + "  " + _line.text + ", done";
    }
    return _indent + "  " + _line.text;
}

function __gmsa_debug_tree_colour(_kind) {
    switch (_kind) {
        case "current": return c_lime;
        case "done": return c_gray;
        case "skipped": case "reason": return c_orange;
    }
    return c_white;
}