function gmvex_stroke_set_dash(path, dash_array, dash_offset = 0) {
    path.dash_array  = dash_array;
    path.dash_offset = dash_offset;
    path.stroke_dash_dirty = true;
}

function gmvex_dash_normalize_array(dash_array) {
    var n = array_length(dash_array);
    if (n == 0) return dash_array;
    if (n mod 2 == 1) {
        var doubled = array_create(n * 2);
        for (var i = 0; i < n; i++) { doubled[i] = dash_array[i]; doubled[i + n] = dash_array[i]; }
        return doubled;
    }
    return dash_array;
}

function gmvex_dash_build_intervals(total_len, dash_array, dash_offset) {
    var n = array_length(dash_array);
    if (n == 0) return [[0, total_len]];

    var pattern_len = 0;
    for (var i = 0; i < n; i++) pattern_len += dash_array[i];
    if (pattern_len <= 0) return [[0, total_len]];

    var offset = dash_offset mod pattern_len;
    if (offset < 0) offset += pattern_len;

    var intervals = [];
    var cursor = -offset;
    var pattern_idx = 0;

    while (cursor < total_len) {
        var seg_len   = dash_array[pattern_idx mod n];
        var seg_is_on = (pattern_idx mod 2) == 0;
        var start = cursor;
        var _end   = cursor + seg_len;

        if (seg_is_on && _end > 0 && start < total_len) {
            array_push(intervals, [max(start, 0), min(_end, total_len)]);
        }

        cursor = _end;
        pattern_idx++;

        if (seg_len <= 0) break;
    }
    return intervals;
}

function gmvex_stroke_extract_range(pts, closed, start_len, end_len) {
    var n = array_length(pts);
    var seg_count = closed ? n : n - 1;
    var out = [];
    var cursor = 0;
    var started = false;

    for (var i = 0; i < seg_count; i++) {
        var p0 = pts[i];
        var p1 = pts[(i + 1) mod n];
        var seg_len = point_distance(p0[0], p0[1], p1[0], p1[1]);
        var seg_start = cursor;
        var seg_end   = cursor + seg_len;

        if (!started && start_len >= seg_start && start_len <= seg_end) {
            var t = (seg_len > 0) ? (start_len - seg_start) / seg_len : 0;
            array_push(out, [lerp(p0[0], p1[0], t), lerp(p0[1], p1[1], t)]);
            started = true;
        }

        if (started) {
            if (end_len <= seg_end) {
                var t2 = (seg_len > 0) ? (end_len - seg_start) / seg_len : 0;
                array_push(out, [lerp(p0[0], p1[0], t2), lerp(p0[1], p1[1], t2)]);
                break;
            } else {
                array_push(out, [p1[0], p1[1]]);
            }
        }
        cursor = seg_end;
    }
    return out;
}