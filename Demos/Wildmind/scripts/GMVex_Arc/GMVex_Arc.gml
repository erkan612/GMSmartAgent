function gmvex_path_arcto(path, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y) {
    if (path.current < 0) { gmvex_path_moveto(path, x, y); return; }

    var sp = path.subpaths[path.current];
    var last = sp.commands[array_length(sp.commands) - 1];
    var x0 = last.x, y0 = last.y;

    if (rx == 0 || ry == 0) {
        gmvex_path_lineto(path, x, y);
        return;
    }
    if (x0 == x && y0 == y) {
        return;
    }

    rx = abs(rx);
    ry = abs(ry);

    var phi = degtorad(x_axis_rotation);
    var cos_phi = cos(phi);
    var sin_phi = sin(phi);

    var dx2 = (x0 - x) / 2;
    var dy2 = (y0 - y) / 2;
    var x1p =  cos_phi * dx2 + sin_phi * dy2;
    var y1p = -sin_phi * dx2 + cos_phi * dy2;

    var lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
    if (lambda > 1) {
        var scale = sqrt(lambda);
        rx *= scale;
        ry *= scale;
    }

    var rx_sq = rx * rx, ry_sq = ry * ry;
    var x1p_sq = x1p * x1p, y1p_sq = y1p * y1p;

    var num = rx_sq * ry_sq - rx_sq * y1p_sq - ry_sq * x1p_sq;
    var den = rx_sq * y1p_sq + ry_sq * x1p_sq;
    var co = (den != 0) ? max(0, num / den) : 0;
    co = sqrt(co);
    if (large_arc_flag == sweep_flag) co = -co;

    var cxp =  co * (rx * y1p / ry);
    var cyp = -co * (ry * x1p / rx);

    var cx = cos_phi * cxp - sin_phi * cyp + (x0 + x) / 2;
    var cy = sin_phi * cxp + cos_phi * cyp + (y0 + y) / 2;

    var ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry;
    var vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry;

    var theta1 = gmvex_arc_angle(1, 0, ux, uy);
    var delta_theta = gmvex_arc_angle(ux, uy, vx, vy);

    if (sweep_flag == 0 && delta_theta > 0) delta_theta -= 360;
    if (sweep_flag == 1 && delta_theta < 0) delta_theta += 360;

    var num_segs = ceil(abs(delta_theta) / 90);
    var seg_sweep = delta_theta / num_segs;

    var theta = theta1;
    for (var i = 0; i < num_segs; i++) {
        gmvex_arc_segment_to_cubic(path, cx, cy, rx, ry, phi, theta, seg_sweep);
        theta += seg_sweep;
    }
}

function gmvex_arc_angle(ux, uy, vx, vy) {
    var ulen = sqrt(ux*ux + uy*uy);
    var vlen = sqrt(vx*vx + vy*vy);
    if (ulen == 0 || vlen == 0) return 0;

    var dot = clamp((ux*vx + uy*vy) / (ulen * vlen), -1, 1);
    var ang = radtodeg(arccos(dot));

    var cross = ux*vy - uy*vx;
    if (cross < 0) ang = -ang;
    return ang;
}

function gmvex_arc_segment_to_cubic(path, cx, cy, rx, ry, phi, theta1, delta_theta) {
    var t0 = degtorad(theta1);
    var t1 = degtorad(theta1 + delta_theta);

    var alpha = tan((t1 - t0) / 4) * (4 / 3);

    var cos_phi = cos(phi), sin_phi = sin(phi);

    var cos_t0 = cos(t0), sin_t0 = sin(t0);
    var cos_t1 = cos(t1), sin_t1 = sin(t1);

    var p0x = cos_t0,            p0y = sin_t0;
    var p1x = cos_t1,            p1y = sin_t1;
    var d0x = -sin_t0,           d0y = cos_t0;   // dP/dt at t0
    var d1x = -sin_t1,           d1y = cos_t1;   // dP/dt at t1

    var c0x = p0x + alpha * d0x, c0y = p0y + alpha * d0y;
    var c1x = p1x - alpha * d1x, c1y = p1y - alpha * d1y;

    var end_x  = cx + cos_phi * (rx * p1x) - sin_phi * (ry * p1y);
    var end_y  = cy + sin_phi * (rx * p1x) + cos_phi * (ry * p1y);
    var c0_wx  = cx + cos_phi * (rx * c0x) - sin_phi * (ry * c0y);
    var c0_wy  = cy + sin_phi * (rx * c0x) + cos_phi * (ry * c0y);
    var c1_wx  = cx + cos_phi * (rx * c1x) - sin_phi * (ry * c1y);
    var c1_wy  = cy + sin_phi * (rx * c1x) + cos_phi * (ry * c1y);

    gmvex_path_cubicto(path, c0_wx, c0_wy, c1_wx, c1_wy, end_x, end_y);
}