function gmvex_stroke_emit_polyline(vb, pts, closed, col, alpha, join_mode, cap_mode, miter_limit, hw) {
    var n = array_length(pts);
    if (n < 2) return;

    var seg_count = closed ? n : n - 1;
    var offsets = array_create(seg_count);

    var total_len = 0;
    for (var i = 0; i < seg_count; i++) {
        var p0 = pts[i]; var p1 = pts[(i + 1) mod n];
        total_len += point_distance(p0[0], p0[1], p1[0], p1[1]);
    }
    if (total_len == 0) total_len = 1;

    var accum_len = 0;

    for (var i = 0; i < seg_count; i++) {
        var p0 = pts[i];
        var p1 = pts[(i + 1) mod n];
        var dx = p1[0] - p0[0];
        var dy = p1[1] - p0[1];
        var len = sqrt(dx*dx + dy*dy);
        if (len < 0.01) { offsets[i] = -1; continue; }

        var dirx = dx/len, diry = dy/len;
        var nx = -diry * hw;
        var ny =  dirx * hw;

        var ax = p0[0]+nx, ay = p0[1]+ny;
        var bx = p0[0]-nx, by = p0[1]-ny;
        var cx = p1[0]+nx, cy = p1[1]+ny;
        var ddx = p1[0]-nx, ddy = p1[1]-ny;

        var u0 = accum_len / total_len;
        accum_len += len;
        var u1 = accum_len / total_len;

        offsets[i] = [ax, ay, bx, by, cx, cy, ddx, ddy, u0, u1, dirx, diry];

        gmvex_stroke_vertex(vb, ax, ay, col, alpha, u0, 0);
        gmvex_stroke_vertex(vb, bx, by, col, alpha, u0, 1);
        gmvex_stroke_vertex(vb, cx, cy, col, alpha, u1, 0);

        gmvex_stroke_vertex(vb, bx, by, col, alpha, u0, 1);
        gmvex_stroke_vertex(vb, ddx, ddy, col, alpha, u1, 1);
        gmvex_stroke_vertex(vb, cx, cy, col, alpha, u1, 0);
    }

    var join_count = closed ? seg_count : seg_count - 1;
    for (var i = 0; i < join_count; i++) {
        var segA = offsets[i];
        var segB = offsets[(i + 1) mod seg_count];
        if (segA == -1 || segB == -1) continue;

        var shared = pts[(i + 1) mod n];
        var u_join = segA[9];
        var mode = join_mode;

        if (mode == gmvex_join.MITER) {
            var miter_result = gmvex_miter_point(segA, segB, shared, hw, miter_limit);
            if (is_undefined(miter_result)) {
                mode = gmvex_join.BEVEL;
            } else {
                gmvex_stroke_vertex(vb, shared[0], shared[1], col, alpha, u_join, 0);
                gmvex_stroke_vertex(vb, segA[4], segA[5], col, alpha, u_join, 0);
                gmvex_stroke_vertex(vb, miter_result[0], miter_result[1], col, alpha, u_join, 0);

                gmvex_stroke_vertex(vb, shared[0], shared[1], col, alpha, u_join, 0);
                gmvex_stroke_vertex(vb, miter_result[0], miter_result[1], col, alpha, u_join, 0);
                gmvex_stroke_vertex(vb, segB[0], segB[1], col, alpha, u_join, 0);

                var miter_result2 = gmvex_miter_point_side2(segA, segB, shared, hw, miter_limit);
                gmvex_stroke_vertex(vb, shared[0], shared[1], col, alpha, u_join, 1);
                gmvex_stroke_vertex(vb, segA[6], segA[7], col, alpha, u_join, 1);
                gmvex_stroke_vertex(vb, miter_result2[0], miter_result2[1], col, alpha, u_join, 1);

                gmvex_stroke_vertex(vb, shared[0], shared[1], col, alpha, u_join, 1);
                gmvex_stroke_vertex(vb, miter_result2[0], miter_result2[1], col, alpha, u_join, 1);
                gmvex_stroke_vertex(vb, segB[2], segB[3], col, alpha, u_join, 1);
            }
        }

        if (mode == gmvex_join.ROUND) {
            gmvex_round_join(vb, shared, segA, segB, hw, col, alpha, u_join);
        }

        if (mode == gmvex_join.BEVEL) {
            gmvex_stroke_vertex(vb, shared[0], shared[1], col, alpha, u_join, 0);
            gmvex_stroke_vertex(vb, segA[4], segA[5], col, alpha, u_join, 0);
            gmvex_stroke_vertex(vb, segB[0], segB[1], col, alpha, u_join, 0);

            gmvex_stroke_vertex(vb, shared[0], shared[1], col, alpha, u_join, 1);
            gmvex_stroke_vertex(vb, segA[6], segA[7], col, alpha, u_join, 1);
            gmvex_stroke_vertex(vb, segB[2], segB[3], col, alpha, u_join, 1);
        }
    }

    if (!closed && cap_mode != gmvex_cap.BUTT) {
        var first = offsets[0];
        var last  = offsets[seg_count - 1];

        if (first != -1) gmvex_draw_cap(vb, pts[0], first[10]*-1, first[11]*-1, hw, col, alpha, cap_mode, first[8], first[0], first[1], first[2], first[3]);
        if (last  != -1) gmvex_draw_cap(vb, pts[n-1], last[10], last[11], hw, col, alpha, cap_mode, last[9], last[4], last[5], last[6], last[7]);
    }
}

function gmvex_stroke_dedupe_points(pts, eps = 0.75) {
    var out = [];
    var n = array_length(pts);
    for (var i = 0; i < n; i++) {
        if (i == 0 || point_distance(pts[i][0], pts[i][1], out[array_length(out)-1][0], out[array_length(out)-1][1]) > eps) {
            array_push(out, pts[i]);
        }
    }
    return out;
}