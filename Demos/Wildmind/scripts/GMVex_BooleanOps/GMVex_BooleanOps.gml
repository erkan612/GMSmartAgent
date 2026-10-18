function gmvex_seg_intersect(p1x, p1y, p2x, p2y, p3x, p3y, p4x, p4y, out) {
    var d1x = p2x - p1x, d1y = p2y - p1y;
    var d2x = p4x - p3x, d2y = p4y - p3y;
    var denom = d1x * d2y - d1y * d2x;
    if (abs(denom) < 0.000000000001) return false; // parallel/collinear - not a proper crossing

    var dx = p3x - p1x, dy = p3y - p1y;
    var t = (dx * d2y - dy * d2x) / denom;
    var u = (dx * d1y - dy * d1x) / denom;

    var eps = 0.000000001;
    if (t < eps || t > 1-eps || u < eps || u > 1-eps) return false;

    out[0] = t;
    out[1] = u;
    out[2] = p1x + t * d1x;
    out[3] = p1y + t * d1y;
    return true;
}

function gmvex_bool_point_in_loop(px, py, pts) {
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
                var cross2 = (xi - xj) * (py - yj) - (px - xj) * (yi - yj);
                if (cross2 < 0) wn--;
            }
        }
        j = i;
    }
    return wn != 0;
}

function gmvex_bool_signed_area(pts) {
    var n = array_length(pts);
    var a = 0;
    for (var i = 0; i < n; i++) {
        var p0 = pts[i];
        var p1 = pts[(i + 1) mod n];
        a += p0[0] * p1[1] - p1[0] * p0[1];
    }
    return a / 2;
}

function gmvex_bool_normalize_winding(pts) {
    if (gmvex_bool_signed_area(pts) >= 0) return pts;
    var n = array_length(pts);
    var rev = array_create(n);
    for (var i = 0; i < n; i++) rev[i] = pts[n - 1 - i];
    return rev;
}

function gmvex_bool_reverse_loop(pts) {
    var n = array_length(pts);
    var rev = array_create(n);
    for (var i = 0; i < n; i++) rev[i] = pts[n - 1 - i];
    return rev;
}

function gmvex_bool_build_ring(pts, hits, is_subject_side) {
    var n = array_length(pts);
    var by_edge = array_create(n);
    for (var i = 0; i < n; i++) by_edge[i] = [];

    for (var h = 0; h < array_length(hits); h++) {
        var hit = hits[h];
        var edge_idx = is_subject_side ? hit.edgeA : hit.edgeC;
        var param    = is_subject_side ? hit.t : hit.u;
        array_push(by_edge[edge_idx], { param: param, x: hit.x, y: hit.y, ref: hit });
    }
    for (var i = 0; i < n; i++) {
        var lst = by_edge[i];
        var m = array_length(lst);
        for (var a = 1; a < m; a++) {
            var key = lst[a];
            var b = a - 1;
            while (b >= 0 && lst[b].param > key.param) { lst[b+1] = lst[b]; b--; }
            lst[b+1] = key;
        }
    }

    var ring = [];
    for (var i = 0; i < n; i++) {
        array_push(ring, { x: pts[i][0], y: pts[i][1], isect: false, ref: -1 });
        var lst = by_edge[i];
        for (var k = 0; k < array_length(lst); k++) {
            array_push(ring, { x: lst[k].x, y: lst[k].y, isect: true, ref: lst[k].ref });
        }
    }
    return ring;
}

function gmvex_bool_split_arcs(ring, other_pts) {
    var n = array_length(ring);
    var isect_indices = [];
    for (var i = 0; i < n; i++) if (ring[i].isect) array_push(isect_indices, i);

    var isect_count = array_length(isect_indices);
    if (isect_count == 0) return undefined;

    var arcs = [];
    for (var k = 0; k < isect_count; k++) {
        var start_idx = isect_indices[k];
        var end_idx   = isect_indices[(k + 1) mod isect_count];

        var arc_pts = [];
        var i = start_idx;
        while (true) {
            array_push(arc_pts, ring[i]);
            if (i == end_idx) break;
            i = (i + 1) mod n;
        }

        var mid_x, mid_y;
        if (array_length(arc_pts) >= 3) {
            mid_x = arc_pts[1].x; mid_y = arc_pts[1].y;
        } else {
            mid_x = (arc_pts[0].x + arc_pts[1].x) / 2;
            mid_y = (arc_pts[0].y + arc_pts[1].y) / 2;
        }

        array_push(arcs, {
            pts: arc_pts,
            start_ref: ring[start_idx].ref,
            end_ref: ring[end_idx].ref,
            inside_other: gmvex_bool_point_in_loop(mid_x, mid_y, other_pts)
        });
    }
    return arcs;
}

function gmvex_bool_reverse_arc(arc) {
    var n = array_length(arc.pts);
    var rev_pts = array_create(n);
    for (var i = 0; i < n; i++) rev_pts[i] = arc.pts[n - 1 - i];
    return {
        pts: rev_pts,
        start_ref: arc.end_ref,
        end_ref: arc.start_ref,
        inside_other: arc.inside_other
    };
}

function gmvex_bool_stitch_arcs(arcs_a, arcs_c) {
    var na = array_length(arcs_a);
    var nc = array_length(arcs_c);
    for (var i = 0; i < na; i++) arcs_a[i].tag = "A";
    for (var i = 0; i < nc; i++) arcs_c[i].tag = "C";

    var all_arcs = [];
    for (var i = 0; i < na; i++) array_push(all_arcs, arcs_a[i]);
    for (var i = 0; i < nc; i++) array_push(all_arcs, arcs_c[i]);
    var total = array_length(all_arcs);

    var by_key = ds_map_create();
    for (var i = 0; i < total; i++) {
        var arc = all_arcs[i];
        by_key[? string(arc.start_ref.id) + "|" + arc.tag] = i;
    }

    var used = array_create(total, false);
    var loops = [];

    for (var s = 0; s < total; s++) {
        if (used[s]) continue;
        var loop_pts = [];
        var current_idx = s;
        var guard = 0;

        do {
            guard++;
            if (guard > 10000) {
                ds_map_destroy(by_key);
                show_debug_message("gmvex_bool_stitch_arcs: guard tripped, arc selection inconsistent");
                return [];
            }
            used[current_idx] = true;
            var cur = all_arcs[current_idx];
            var cn = array_length(cur.pts);
            for (var i = 0; i < cn - 1; i++) array_push(loop_pts, [cur.pts[i].x, cur.pts[i].y]);

            var other_tag = (cur.tag == "A") ? "C" : "A";
            var key = string(cur.end_ref.id) + "|" + other_tag;

            var next_idx;
            if (ds_map_exists(by_key, key)) {
                next_idx = by_key[? key];
            } else {
                var same_key = string(cur.end_ref.id) + "|" + cur.tag;
                if (ds_map_exists(by_key, same_key)) {
                    next_idx = by_key[? same_key];
                } else {
                    ds_map_destroy(by_key);
                    show_debug_message("gmvex_bool_stitch_arcs: dangling arc end, no matching start");
                    return [];
                }
            }
            current_idx = next_idx;
        } until (current_idx == s);

        array_push(loops, loop_pts);
    }

    ds_map_destroy(by_key);
    return loops;
}

function gmvex_bool_classify_degenerate(loop_a, loop_c) {
    if (array_length(loop_a) == 0 || array_length(loop_c) == 0) return "disjoint";
    var a_in_c = gmvex_bool_point_in_loop(loop_a[0][0], loop_a[0][1], loop_c);
    var c_in_a = gmvex_bool_point_in_loop(loop_c[0][0], loop_c[0][1], loop_a);
    if (a_in_c) return "a_inside_c";
    if (c_in_a) return "c_inside_a";
    return "disjoint";
}

function gmvex_bool_degenerate_result(loop_a, loop_c, op) {
    var rel = gmvex_bool_classify_degenerate(loop_a, loop_c);

    if (rel == "disjoint") {
        switch (op) {
            case "union":        return [loop_a, loop_c];
            case "intersection": return [];
            case "a_not_c":      return [loop_a];
            case "c_not_a":      return [loop_c];
        }
    }
    if (rel == "a_inside_c") {
        switch (op) {
            case "union":        return [loop_c];
            case "intersection": return [loop_a];
            case "a_not_c":      return [];
            case "c_not_a":      return [loop_c, gmvex_bool_reverse_loop(loop_a)];
        }
    }
    if (rel == "c_inside_a") {
        switch (op) {
            case "union":        return [loop_a];
            case "intersection": return [loop_c];
            case "a_not_c":      return [loop_a, gmvex_bool_reverse_loop(loop_c)];
            case "c_not_a":      return [];
        }
    }
    return [];
}

function gmvex_bool_loop_pair(loop_a_raw, loop_c_raw, op) {
    var loop_a = gmvex_bool_normalize_winding(loop_a_raw);
    var loop_c = gmvex_bool_normalize_winding(loop_c_raw);

    var na = array_length(loop_a), nc = array_length(loop_c);
    var hits = [];
    var scratch = array_create(4);
    var next_hit_id = 0;
    for (var i = 0; i < na; i++) {
        var a1 = loop_a[i], a2 = loop_a[(i + 1) mod na];
        for (var j = 0; j < nc; j++) {
            var c1 = loop_c[j], c2 = loop_c[(j + 1) mod nc];
            if (gmvex_seg_intersect(a1[0],a1[1], a2[0],a2[1], c1[0],c1[1], c2[0],c2[1], scratch)) {
                array_push(hits, { edgeA: i, edgeC: j, t: scratch[0], u: scratch[1], x: scratch[2], y: scratch[3], id: next_hit_id });
                next_hit_id++;
            }
        }
    }

    if (array_length(hits) == 0) {
        return gmvex_bool_degenerate_result(loop_a, loop_c, op);
    }

    var ring_a = gmvex_bool_build_ring(loop_a, hits, true);
    var ring_c = gmvex_bool_build_ring(loop_c, hits, false);
    var arcs_a = gmvex_bool_split_arcs(ring_a, loop_c);
    var arcs_c = gmvex_bool_split_arcs(ring_c, loop_a);

    if (is_undefined(arcs_a) || is_undefined(arcs_c)) return []; // this shouldnt happen

    var sel_a = [], sel_c = [];
    switch (op) {
        case "union":
            for (var i = 0; i < array_length(arcs_a); i++) if (!arcs_a[i].inside_other) array_push(sel_a, arcs_a[i]);
            for (var i = 0; i < array_length(arcs_c); i++) if (!arcs_c[i].inside_other) array_push(sel_c, arcs_c[i]);
            break;
        case "intersection":
            for (var i = 0; i < array_length(arcs_a); i++) if (arcs_a[i].inside_other) array_push(sel_a, arcs_a[i]);
            for (var i = 0; i < array_length(arcs_c); i++) if (arcs_c[i].inside_other) array_push(sel_c, arcs_c[i]);
            break;
        case "a_not_c":
            for (var i = 0; i < array_length(arcs_a); i++) if (!arcs_a[i].inside_other) array_push(sel_a, arcs_a[i]);
            for (var i = 0; i < array_length(arcs_c); i++) if (arcs_c[i].inside_other) array_push(sel_c, gmvex_bool_reverse_arc(arcs_c[i]));
            break;
        case "c_not_a":
            for (var i = 0; i < array_length(arcs_c); i++) if (!arcs_c[i].inside_other) array_push(sel_c, arcs_c[i]);
            for (var i = 0; i < array_length(arcs_a); i++) if (arcs_a[i].inside_other) array_push(sel_a, gmvex_bool_reverse_arc(arcs_a[i]));
            break;
    }

    if (array_length(sel_a) == 0 && array_length(sel_c) == 0) return [];
    return gmvex_bool_stitch_arcs(sel_a, sel_c);
}

function gmvex_bool_op_name(op) {
    switch (op) {
        case gmvex_bool.UNION:        return "union";
        case gmvex_bool.INTERSECTION: return "intersection";
        case gmvex_bool.A_NOT_C:      return "a_not_c";
        case gmvex_bool.C_NOT_A:      return "c_not_a";
    }
    return "union";
}

function gmvex_path_boolean(path_a, path_c, op) {
    if (path_a.dirty) gmvex_path_rebuild(path_a);
    if (path_c.dirty) gmvex_path_rebuild(path_c);
	
	var baked_a = gmvex_path_clone(path_a);
    gmvex_path_apply_transform_all(baked_a);
	if (baked_a.dirty) gmvex_path_rebuild(baked_a);
    var baked_c = gmvex_path_clone(path_c);
    gmvex_path_apply_transform_all(baked_c);
	if (baked_c.dirty) gmvex_path_rebuild(baked_c);

    var op_name = gmvex_bool_op_name(op);
    var loops_a = baked_a.flat_subpaths;
    var loops_c = baked_c.flat_subpaths;

    var na = array_length(loops_a);
    var nc = array_length(loops_c);

    var result_loops = [];

    for (var i = 0; i < na; i++) {
        for (var j = 0; j < nc; j++) {
            var pair_result = gmvex_bool_loop_pair(loops_a[i].points, loops_c[j].points, op_name);
            for (var k = 0; k < array_length(pair_result); k++) {
                array_push(result_loops, pair_result[k]);
            }
        }
    }

    if (na == 0 || nc == 0) {
        if (op_name == "a_not_c") { for (var i=0;i<na;i++) array_push(result_loops, loops_a[i].points); }
        if (op_name == "c_not_a") { for (var j=0;j<nc;j++) array_push(result_loops, loops_c[j].points); }
        if (op_name == "union") {
            for (var i=0;i<na;i++) array_push(result_loops, loops_a[i].points);
            for (var j=0;j<nc;j++) array_push(result_loops, loops_c[j].points);
        }
        // nothing to add
    }

    var result = gmvex_path_create();
    result.subpaths = [];
    result.flat_subpaths = [];

    var minx = infinity, miny = infinity, maxx = -infinity, maxy = -infinity;
    var rn = array_length(result_loops);
    for (var i = 0; i < rn; i++) {
        var loop = result_loops[i];
        if (array_length(loop) < 3) continue; // not filleble
        array_push(result.flat_subpaths, { points: loop, closed: true });
        for (var p = 0; p < array_length(loop); p++) {
            minx = min(minx, loop[p][0]); maxx = max(maxx, loop[p][0]);
            miny = min(miny, loop[p][1]); maxy = max(maxy, loop[p][1]);
        }
    }
    if (rn == 0 || array_length(result.flat_subpaths) == 0) { minx=0; miny=0; maxx=0; maxy=0; }

    result.bbox  = [minx, miny, maxx, maxy];
    result.dirty = false;

    gmvex_bool_rebuild_vbuff_from_flat(result);

	gmvex_path_destroy(baked_a);
    gmvex_path_destroy(baked_c);

    return result;
}

function gmvex_bool_rebuild_vbuff_from_flat(path) {
    var vb_ccw = vertex_create_buffer();
    var vb_cw  = vertex_create_buffer();
    vertex_begin(vb_ccw, global.gmvex_vformat_pos);
    vertex_begin(vb_cw,  global.gmvex_vformat_pos);

    var sn = array_length(path.flat_subpaths);
    for (var s = 0; s < sn; s++) {
        var pts = path.flat_subpaths[s].points;
        var n = array_length(pts);
        if (n < 3) continue;

        var x0 = pts[0][0], y0 = pts[0][1];
        for (var i = 1; i < n - 1; i++) {
            var tx1 = pts[i][0],   ty1 = pts[i][1];
            var tx2 = pts[i+1][0], ty2 = pts[i+1][1];
            var tri_area = (x0*ty1 - tx1*y0) + (tx1*ty2 - tx2*ty1) + (tx2*y0 - x0*ty2);
            var target_vb = (tri_area < 0) ? vb_cw : vb_ccw;
            vertex_position_3d(target_vb, x0, y0, 0);
            vertex_position_3d(target_vb, tx1, ty1, 0);
            vertex_position_3d(target_vb, tx2, ty2, 0);
        }
    }

    vertex_end(vb_ccw);
    vertex_end(vb_cw);

    var ccw_count = vertex_get_number(vb_ccw);
    var cw_count  = vertex_get_number(vb_cw);

    if (ccw_count > 0) { vertex_freeze(vb_ccw); } else { vertex_delete_buffer(vb_ccw); vb_ccw = -1; }
    if (cw_count  > 0) { vertex_freeze(vb_cw);  } else { vertex_delete_buffer(vb_cw);  vb_cw  = -1; }

    path.vbuff    = vb_ccw;
    path.vbuff_cw = vb_cw;
    path.winding  = gmvex_winding.NONZERO;
}