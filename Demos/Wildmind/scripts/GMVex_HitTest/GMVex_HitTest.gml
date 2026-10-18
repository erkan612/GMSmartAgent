function gmvex_point_in_polygon_evenodd(px, py, pts) {
    var n = array_length(pts);
    var inside = false;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
        var xi = pts[i][0], yi = pts[i][1];
        var xj = pts[j][0], yj = pts[j][1];
        if (((yi > py) != (yj > py)) &&
            (px < (xj - xi) * (py - yi) / (yj - yi) + xi)) {
            inside = !inside;
        }
        j = i;
    }
    return inside;
}

function gmvex_point_in_polygon_winding_number(px, py, pts) {
    var n = array_length(pts);
    var wn = 0;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
        var xi = pts[i][0], yi = pts[i][1];
        var xj = pts[j][0], yj = pts[j][1];
        if (yj <= py) {
            if (yi > py) {
                var cross = (xi - xj) * (py - yj) - (px - xj) * (yi - yj);
                if (cross > 0) wn++;
            }
        } else {
            if (yi <= py) {
                var cross = (xi - xj) * (py - yj) - (px - xj) * (yi - yj);
                if (cross < 0) wn--;
            }
        }
        j = i;
    }
    return wn != 0;
}

function gmvex_path_hit_test_fill(path, px, py) {
    if (path.dirty) gmvex_path_rebuild(path);

    if (px < path.bbox[0] || px > path.bbox[2] || py < path.bbox[1] || py > path.bbox[3]) {
        return false;
    }

    var local = gmvex_transform_point_inverse(path, px, py);
    px = local[0];
    py = local[1];

    if (path.winding == gmvex_winding.EVENODD) {
        var hit_count = 0;
        for (var s = 0; s < array_length(path.flat_subpaths); s++) {
            if (gmvex_point_in_polygon_evenodd(px, py, path.flat_subpaths[s].points)) {
                hit_count++;
            }
        }
        return (hit_count mod 2) == 1;
    } else {
        var wn_sum = 0;
        for (var s = 0; s < array_length(path.flat_subpaths); s++) {
            wn_sum += gmvex_winding_number_contribution(px, py, path.flat_subpaths[s].points);
        }
        return wn_sum != 0;
    }
}

function gmvex_winding_number_contribution(px, py, pts) {
    var n = array_length(pts);
    var wn = 0;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
        var xi = pts[i][0], yi = pts[i][1];
        var xj = pts[j][0], yj = pts[j][1];
        if (yj <= py) {
            if (yi > py) {
                var cross = (xi - xj) * (py - yj) - (px - xj) * (yi - yj);
                if (cross > 0) wn++;
            }
        } else {
            if (yi <= py) {
                var cross = (xi - xj) * (py - yj) - (px - xj) * (yi - yj);
                if (cross < 0) wn--;
            }
        }
        j = i;
    }
    return wn;
}

function gmvex_transform_point_inverse(path, wx, wy) {
    if (!variable_struct_exists(path, "tmatrix")) return [wx, wy];
    var m = path.tmatrix;

    var det = m[0]*m[3] - m[1]*m[2];
    if (det == 0) return [wx, wy];

    var dx = wx - m[4];
    var dy = wy - m[5];

    var lx = (m[3]*dx - m[2]*dy) / det;
    var ly = (-m[1]*dx + m[0]*dy) / det;

    var tox = variable_struct_exists(path, "tox") ? path.tox : 0;
    var toy = variable_struct_exists(path, "toy") ? path.toy : 0;

    return [lx + tox, ly + toy];
}

function gmvex_point_segment_distance(px, py, x0, y0, x1, y1) {
    var dx = x1 - x0, dy = y1 - y0;
    var len_sq = dx*dx + dy*dy;
    if (len_sq < 0.0001) return point_distance(px, py, x0, y0);

    var t = clamp(((px-x0)*dx + (py-y0)*dy) / len_sq, 0, 1);
    var projx = x0 + t*dx;
    var projy = y0 + t*dy;
    return point_distance(px, py, projx, projy);
}

function gmvex_path_hit_test_stroke(path, px, py, stroke_width, tolerance = 4) {
    if (path.dirty) gmvex_path_rebuild(path);

    var local = gmvex_transform_point_inverse(path, px, py);
    px = local[0];
    py = local[1];

    var threshold = (stroke_width / 2) + tolerance;

    for (var s = 0; s < array_length(path.flat_subpaths); s++) {
        var sub = path.flat_subpaths[s];
        var pts = sub.points;
        var n = array_length(pts);
        var seg_count = sub.closed ? n : n - 1;

        for (var i = 0; i < seg_count; i++) {
            var p0 = pts[i];
            var p1 = pts[(i + 1) mod n];
            if (gmvex_point_segment_distance(px, py, p0[0], p0[1], p1[0], p1[1]) <= threshold) {
                return true;
            }
        }
    }
    return false;
}