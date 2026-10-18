function gmvex_text_offset_contour(pts, amount) {
    var n = array_length(pts);
    if (n < 3) return pts;
    var out = array_create(n);

    for (var i = 0; i < n; i++) {
        var prev = pts[(i - 1 + n) mod n];
        var cur  = pts[i];
        var nxt  = pts[(i + 1) mod n];

        var in_dx = cur.x - prev.x, in_dy = cur.y - prev.y;
        var out_dx = nxt.x - cur.x, out_dy = nxt.y - cur.y;

        var in_len = sqrt(in_dx*in_dx + in_dy*in_dy);
        var out_len = sqrt(out_dx*out_dx + out_dy*out_dy);
        var in_nx = 0, in_ny = 0, out_nx = 0, out_ny = 0;
        if (in_len > 0.0001)  { in_nx  = -in_dy/in_len;   in_ny  = in_dx/in_len; }
        if (out_len > 0.0001) { out_nx = -out_dy/out_len; out_ny = out_dx/out_len; }

        var bx = in_nx + out_nx, by = in_ny + out_ny;
        var blen = sqrt(bx*bx + by*by);
        if (blen < 0.000001) { bx = in_nx; by = in_ny; }
        else { bx /= blen; by /= blen; }

        var dot = clamp(in_nx*out_nx + in_ny*out_ny, -1, 1);
        var half_angle = arccos(dot) / 2;
        var miter_scale = 1 / max(cos(half_angle), 0.3);
        var push = amount * miter_scale;

        out[i] = { x: cur.x + bx*push, y: cur.y + by*push, on_curve: true };
    }
    return out;
}

function gmvex_text_flatten_contour_points(contour) {
    var n = array_length(contour);
    var expanded = [];
    for (var i = 0; i < n; i++) {
        var cur = contour[i];
        var nxt = contour[(i + 1) mod n];
        array_push(expanded, cur);
        if (!cur.on_curve && !nxt.on_curve) {
            array_push(expanded, { x: (cur.x+nxt.x)/2, y: (cur.y+nxt.y)/2, on_curve: true });
        }
    }
    var m = array_length(expanded);
    var start_idx = -1;
    for (var i = 0; i < m; i++) { if (expanded[i].on_curve) { start_idx = i; break; } }
    if (start_idx == -1) {
        var p0 = expanded[0], p1 = expanded[m-1];
        var synth = { x: (p0.x+p1.x)/2, y: (p0.y+p1.y)/2, on_curve: true };
        var new_expanded = [synth];
        for (var i = 0; i < m; i++) array_push(new_expanded, expanded[i]);
        expanded = new_expanded;
        m = array_length(expanded);
        start_idx = 0;
    }

    var seq = [];
    for (var i = 0; i < m; i++) array_push(seq, expanded[(start_idx + i) mod m]);

    var flat = [{ x: seq[0].x, y: seq[0].y, on_curve: true }];
    var i = 1;
    var sn = array_length(seq);
    while (i < sn) {
        var pt = seq[i];
        if (pt.on_curve) {
            array_push(flat, { x: pt.x, y: pt.y, on_curve: true });
            i += 1;
        } else {
            var ctrl = pt;
            var _end = seq[(i + 1) mod sn];
            var steps = 16;
            for (var s = 1; s <= steps; s++) {
                var t = s / steps, mt = 1 - t;
                var px = mt*mt*flat[array_length(flat)-1].x + 2*mt*t*ctrl.x + t*t*_end.x;
                var py = mt*mt*flat[array_length(flat)-1].y + 2*mt*t*ctrl.y + t*t*_end.y;
                array_push(flat, { x: px, y: py, on_curve: true });
            }
            i += 2;
        }
    }
    return flat;
}

function gmvex_text_add_contour_to_path(path, contour, scale, origin_x, origin_y, bold_amount = 0, italic_shear = 0) {
    var work_contour = contour;
    if (bold_amount != 0) {
        var flat = gmvex_text_flatten_contour_points(contour);
        work_contour = gmvex_text_offset_contour(flat, bold_amount);
    }

    var n = array_length(work_contour);
    if (n < 2) return;

    var expanded = [];
    for (var i = 0; i < n; i++) {
        var cur = work_contour[i];
        var nxt = work_contour[(i + 1) mod n];
        array_push(expanded, cur);
        if (!cur.on_curve && !nxt.on_curve) {
            array_push(expanded, { x: (cur.x+nxt.x)/2, y: (cur.y+nxt.y)/2, on_curve: true });
        }
    }
    var m = array_length(expanded);
    var start_idx = -1;
    for (var i = 0; i < m; i++) { if (expanded[i].on_curve) { start_idx = i; break; } }
    if (start_idx == -1) {
        var p0 = expanded[0], p1 = expanded[m-1];
        var synth = { x: (p0.x+p1.x)/2, y: (p0.y+p1.y)/2, on_curve: true };
        var new_expanded = [synth];
        for (var i = 0; i < m; i++) array_push(new_expanded, expanded[i]);
        expanded = new_expanded;
        m = array_length(expanded);
        start_idx = 0;
    }

    var seq = [];
    for (var i = 0; i < m; i++) array_push(seq, expanded[(start_idx + i) mod m]);

    var p0x = seq[0].x + seq[0].y * italic_shear;
    gmvex_path_moveto(path, origin_x + p0x * scale, origin_y - seq[0].y * scale);

    var i = 1;
    var sn = array_length(seq);
    while (i < sn) {
        var pt = seq[i];
        if (pt.on_curve) {
            var px = pt.x + pt.y * italic_shear;
            gmvex_path_lineto(path, origin_x + px * scale, origin_y - pt.y * scale);
            i += 1;
        } else {
            var ctrl = pt;
            var _end = seq[(i + 1) mod sn];
            var cx = ctrl.x + ctrl.y * italic_shear;
            var ex = _end.x + _end.y * italic_shear;
            gmvex_path_quadto(
                path,
                origin_x + cx * scale, origin_y - ctrl.y * scale,
                origin_x + ex * scale, origin_y - _end.y * scale
            );
            i += 2;
        }
    }
    gmvex_path_close(path);
}