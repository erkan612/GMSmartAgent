function gmvex_path_rebuild(path) {
    if (path.vbuff != -1) vertex_delete_buffer(path.vbuff);
    if (variable_struct_exists(path, "vbuff_cw") && path.vbuff_cw != -1) vertex_delete_buffer(path.vbuff_cw);

    var vb_ccw = vertex_create_buffer();
    var vb_cw  = vertex_create_buffer();
    vertex_begin(vb_ccw, global.gmvex_vformat_pos);
    vertex_begin(vb_cw,  global.gmvex_vformat_pos);

    var minx = infinity, miny = infinity, maxx = -infinity, maxy = -infinity;

    var flat_only = (array_length(path.subpaths) == 0)
        && variable_struct_exists(path, "flat_subpaths")
        && array_length(path.flat_subpaths) > 0;

    if (!flat_only) {
        path.flat_subpaths = [];

        for (var s = 0; s < array_length(path.subpaths); s++) {
            var sp = path.subpaths[s];
            var out_pts = [];

            if (variable_struct_exists(sp, "splinepts")) {
                var spts = sp.splinepts;
                var n = array_length(spts);
                var closed = sp.closed;

                var get_pt = function(i, pts, n, closed) {
                    if (closed) {
                        return pts[(i + n) mod n];
                    } else {
                        return pts[clamp(i, 0, n - 1)];
                    }
                };

                if (!closed) array_push(out_pts, spts[0]);

                var limit = closed ? n : n - 1;
                for (var i = 0; i < limit; i++) {
                    var p0 = get_pt(i - 1, spts, n, closed);
                    var p1 = spts[i];
                    var p2 = spts[(i + 1) mod n];
                    var p3 = get_pt(i + 2, spts, n, closed);

                    var b1x = p1[0] + (p2[0]-p0[0])/6, b1y = p1[1] + (p2[1]-p0[1])/6;
                    var b2x = p2[0] - (p3[0]-p1[0])/6, b2y = p2[1] - (p3[1]-p1[1])/6;

                    gmvex_flatten_cubic(p1[0], p1[1], b1x, b1y, b2x, b2y, p2[0], p2[1], 0, out_pts);
                }
            } else {
                var cx = 0, cy = 0;
                for (var i = 0; i < array_length(sp.commands); i++) {
                    var c = sp.commands[i];
                    switch (c.type) {
                        case gmvex_cmd.MOVETO:
                            cx = c.x; cy = c.y;
                            array_push(out_pts, [cx, cy]);
                            break;
                        case gmvex_cmd.LINETO:
                            cx = c.x; cy = c.y;
                            array_push(out_pts, [cx, cy]);
                            break;
                        case gmvex_cmd.QUADTO: {
                            var c1x = cx + (2/3)*(c.cx-cx),   c1y = cy + (2/3)*(c.cy-cy);
                            var c2x = c.x + (2/3)*(c.cx-c.x), c2y = c.y + (2/3)*(c.cy-c.y);
                            if (c.easing != -1)
                                gmvex_flatten_cubic_eased(cx,cy, c1x,c1y, c2x,c2y, c.x,c.y, c.easing, out_pts);
                            else
                                gmvex_flatten_cubic(cx,cy, c1x,c1y, c2x,c2y, c.x,c.y, 0, out_pts);
                            cx = c.x; cy = c.y;
                            break;
                        }
                        case gmvex_cmd.CUBICTO:
                            if (c.easing != -1)
                                gmvex_flatten_cubic_eased(cx,cy, c.c1x,c.c1y, c.c2x,c.c2y, c.x,c.y, c.easing, out_pts);
                            else
                                gmvex_flatten_cubic(cx,cy, c.c1x,c.c1y, c.c2x,c.c2y, c.x,c.y, 0, out_pts);
                            cx = c.x; cy = c.y;
                            break;
                    }
                }
            }

            var n = array_length(out_pts);
            for (var i = 0; i < n; i++) {
                minx = min(minx, out_pts[i][0]); maxx = max(maxx, out_pts[i][0]);
                miny = min(miny, out_pts[i][1]); maxy = max(maxy, out_pts[i][1]);
            }

            if (n < 2) continue;

            array_push(path.flat_subpaths, { points: out_pts, closed: sp.closed });

            var can_fill = (n >= 3);
            if (can_fill) {
                var x0 = out_pts[0][0], y0 = out_pts[0][1];
                for (var i = 1; i < n - 1; i++) {
                    var tx1 = out_pts[i][0],   ty1 = out_pts[i][1];
                    var tx2 = out_pts[i+1][0], ty2 = out_pts[i+1][1];
                    var target_vb = vb_ccw;
                    if (path.winding == gmvex_winding.NONZERO) {
                        var tri_area = (x0*ty1 - tx1*y0) + (tx1*ty2 - tx2*ty1) + (tx2*y0 - x0*ty2);
                        target_vb = (tri_area < 0) ? vb_cw : vb_ccw;
                    }
                    vertex_position_3d(target_vb, x0, y0, 0);
                    vertex_position_3d(target_vb, tx1, ty1, 0);
                    vertex_position_3d(target_vb, tx2, ty2, 0);
                }
            }
        }
    } else {
        for (var s = 0; s < array_length(path.flat_subpaths); s++) {
            var pts = path.flat_subpaths[s].points;
            var n = array_length(pts);

            for (var i = 0; i < n; i++) {
                minx = min(minx, pts[i][0]); maxx = max(maxx, pts[i][0]);
                miny = min(miny, pts[i][1]); maxy = max(maxy, pts[i][1]);
            }

            var can_fill = (n >= 3);
            if (can_fill) {
                var x0 = pts[0][0], y0 = pts[0][1];
                for (var i = 1; i < n - 1; i++) {
                    var tx1 = pts[i][0],   ty1 = pts[i][1];
                    var tx2 = pts[i+1][0], ty2 = pts[i+1][1];
                    var target_vb = vb_ccw;
                    if (path.winding == gmvex_winding.NONZERO) {
                        var tri_area = (x0*ty1 - tx1*y0) + (tx1*ty2 - tx2*ty1) + (tx2*y0 - x0*ty2);
                        target_vb = (tri_area < 0) ? vb_cw : vb_ccw;
                    }
                    vertex_position_3d(target_vb, x0, y0, 0);
                    vertex_position_3d(target_vb, tx1, ty1, 0);
                    vertex_position_3d(target_vb, tx2, ty2, 0);
                }
            }
        }
    }

    vertex_end(vb_ccw);
    vertex_end(vb_cw);

    var ccw_count = vertex_get_number(vb_ccw);
    var cw_count  = vertex_get_number(vb_cw);

    if (ccw_count > 0) {
        vertex_freeze(vb_ccw);
    } else {
        vertex_delete_buffer(vb_ccw);
        vb_ccw = -1;
    }

    if (cw_count > 0) {
        vertex_freeze(vb_cw);
    } else {
        vertex_delete_buffer(vb_cw);
        vb_cw = -1;
    }

    path.vbuff				= vb_ccw;
    path.vbuff_cw			= vb_cw;
    path.bbox				= [minx, miny, maxx, maxy];
	path.rebuilt_tolerance  = global.gmvex_tolerance;
    path.dirty				= false;
}

function gmvex_cubic_flatness(x0,y0,x1,y1,x2,y2,x3,y3) {
    var ux = 3*x1 - 2*x0 - x3; ux *= ux;
    var uy = 3*y1 - 2*y0 - y3; uy *= uy;
    var vx = 3*x2 - 2*x3 - x0; vx *= vx;
    var vy = 3*y2 - 2*y3 - y0; vy *= vy;
    if (ux < vx) ux = vx;
    if (uy < vy) uy = vy;
    return ux + uy;
}

function gmvex_subdivide_cubic(x0,y0,x1,y1,x2,y2,x3,y3, out_l, out_r) {
    var x01=(x0+x1)/2,  y01=(y0+y1)/2;
    var x12=(x1+x2)/2,  y12=(y1+y2)/2;
    var x23=(x2+x3)/2,  y23=(y2+y3)/2;
    var x012=(x01+x12)/2, y012=(y01+y12)/2;
    var x123=(x12+x23)/2, y123=(y12+y23)/2;
    var x0123=(x012+x123)/2, y0123=(y012+y123)/2;

    out_l[@0]=x0; out_l[@1]=y0; out_l[@2]=x01;  out_l[@3]=y01;
    out_l[@4]=x012; out_l[@5]=y012; out_l[@6]=x0123; out_l[@7]=y0123;

    out_r[@0]=x0123; out_r[@1]=y0123; out_r[@2]=x123; out_r[@3]=y123;
    out_r[@4]=x23;  out_r[@5]=y23;  out_r[@6]=x3;    out_r[@7]=y3;
}

function gmvex_flatten_cubic(x0,y0,x1,y1,x2,y2,x3,y3, depth, out_pts) {
    if (depth >= 24 || gmvex_cubic_flatness(x0,y0,x1,y1,x2,y2,x3,y3) <= 16 * sqr(global.gmvex_tolerance)) {
        array_push(out_pts, [x3, y3]);
        return;
    }
    var l = array_create(8), r = array_create(8);
    gmvex_subdivide_cubic(x0,y0,x1,y1,x2,y2,x3,y3, l, r);
    gmvex_flatten_cubic(l[0],l[1],l[2],l[3],l[4],l[5],l[6],l[7], depth+1, out_pts);
    gmvex_flatten_cubic(r[0],r[1],r[2],r[3],r[4],r[5],r[6],r[7], depth+1, out_pts);
}

function gmvex_flatten_cubic_eased(x0,y0,x1,y1,x2,y2,x3,y3, easing_fn, out_pts) {
    var steps = 24;
    for (var i = 1; i <= steps; i++) {
        var t = easing_fn(i / steps);
        var mt = 1 - t;
        var px = mt*mt*mt*x0 + 3*mt*mt*t*x1 + 3*mt*t*t*x2 + t*t*t*x3;
        var py = mt*mt*mt*y0 + 3*mt*mt*t*y1 + 3*mt*t*t*y2 + t*t*t*y3;
        array_push(out_pts, [px, py]);
    }
}

function gmvex_path_check_tolerance_dirty(path) {
    if (!variable_struct_exists(path, "rebuilt_tolerance") || path.rebuilt_tolerance != global.gmvex_tolerance) {
        path.dirty = true;
    }
}