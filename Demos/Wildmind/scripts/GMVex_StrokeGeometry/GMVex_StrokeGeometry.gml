function gmvex_miter_point(segA, segB, shared, hw, miter_limit) {
    var dot = segA[10]*segB[10] + segA[11]*segB[11];
    dot = clamp(dot, -1, 1);
    var angle = arccos(dot);
    if (angle == 0) return undefined;

    var half_angle = angle / 2;
    var miter_len = hw / max(cos(half_angle), 0.0001);
    if (miter_len / hw > miter_limit) return undefined;

    var e1x = segA[4]-shared[0], e1y = segA[5]-shared[1];
    var e1len = sqrt(e1x*e1x+e1y*e1y); if (e1len>0){e1x/=e1len; e1y/=e1len;}
    var e2x = segB[0]-shared[0], e2y = segB[1]-shared[1];
    var e2len = sqrt(e2x*e2x+e2y*e2y); if (e2len>0){e2x/=e2len; e2y/=e2len;}

    var bisx = e1x+e2x, bisy = e1y+e2y;
    var bislen = sqrt(bisx*bisx+bisy*bisy);
    if (bislen < 0.0001) return undefined;
    bisx/=bislen; bisy/=bislen;

    return [shared[0] + bisx*miter_len, shared[1] + bisy*miter_len];
}

function gmvex_miter_point_side2(segA, segB, shared, hw, miter_limit) {
    var dot = segA[10]*segB[10] + segA[11]*segB[11];
    dot = clamp(dot, -1, 1);
    var angle = arccos(dot);
    if (angle == 0) return [shared[0], shared[1]];

    var half_angle = angle / 2;
    var miter_len = hw / max(cos(half_angle), 0.0001);

    var e1x = segA[6]-shared[0], e1y = segA[7]-shared[1];
    var e1len = sqrt(e1x*e1x+e1y*e1y); if (e1len>0){e1x/=e1len; e1y/=e1len;}
    var e2x = segB[2]-shared[0], e2y = segB[3]-shared[1];
    var e2len = sqrt(e2x*e2x+e2y*e2y); if (e2len>0){e2x/=e2len; e2y/=e2len;}

    var bisx = e1x+e2x, bisy = e1y+e2y;
    var bislen = sqrt(bisx*bisx+bisy*bisy);
    if (bislen < 0.0001) return [shared[0], shared[1]];
    bisx/=bislen; bisy/=bislen;

    return [shared[0] + bisx*miter_len, shared[1] + bisy*miter_len];
}

function gmvex_round_join(vb, shared, segA, segB, hw, col, alpha, u_join) {
    gmvex_round_fan(vb, shared[0], shared[1], segA[4], segA[5], segB[0], segB[1], hw, col, alpha, u_join, 0); // side v=0
    gmvex_round_fan(vb, shared[0], shared[1], segA[6], segA[7], segB[2], segB[3], hw, col, alpha, u_join, 1); // side v=1
}

function gmvex_round_fan(vb, cx, cy, x0, y0, x1, y1, radius, col, alpha, u_join, v_val) {
    var a0 = point_direction(cx, cy, x0, y0);
    var a1 = point_direction(cx, cy, x1, y1);

    var diff = angle_difference(a1, a0);
    var steps = gmvex_round_step_count(radius, diff);

    var prev_x = x0, prev_y = y0;
    for (var i = 1; i <= steps; i++) {
        var t = i / steps;
        var ang = a0 + diff * t;
        var nx = cx + lengthdir_x(radius, ang);
        var ny = cy + lengthdir_y(radius, ang);

        gmvex_stroke_vertex(vb, cx, cy, col, alpha, u_join, v_val);
        gmvex_stroke_vertex(vb, prev_x, prev_y, col, alpha, u_join, v_val);
        gmvex_stroke_vertex(vb, nx, ny, col, alpha, u_join, v_val);

        prev_x = nx; prev_y = ny;
    }
}

function gmvex_draw_cap(vb, endpoint, dirx, diry, hw, col, alpha, cap_mode, u_val, ax, ay, bx, by) {
    if (cap_mode == gmvex_cap.SQUARE) {
        var ex = ax + dirx*hw, ey = ay + diry*hw;
        var fx = bx + dirx*hw, fy = by + diry*hw;

        gmvex_stroke_vertex(vb, ax, ay, col, alpha, u_val, 0);
        gmvex_stroke_vertex(vb, bx, by, col, alpha, u_val, 1);
        gmvex_stroke_vertex(vb, fx, fy, col, alpha, u_val, 1);

        gmvex_stroke_vertex(vb, ax, ay, col, alpha, u_val, 0);
        gmvex_stroke_vertex(vb, fx, fy, col, alpha, u_val, 1);
        gmvex_stroke_vertex(vb, ex, ey, col, alpha, u_val, 0);
    }

    if (cap_mode == gmvex_cap.ROUND) {
        var a0 = point_direction(endpoint[0], endpoint[1], ax, ay);
        var a1 = point_direction(endpoint[0], endpoint[1], bx, by);
        var outward_angle = point_direction(0, 0, dirx, diry);

        var diff = angle_difference(a1, a0);
        var diff_alt = (diff >= 0) ? diff - 360 : diff + 360;

        var mid = a0 + diff/2;
        var mid_alt = a0 + diff_alt/2;

        if (abs(angle_difference(mid_alt, outward_angle)) < abs(angle_difference(mid, outward_angle))) {
            diff = diff_alt;
        }

        var steps = gmvex_round_step_count(hw, diff);
        var prev_x = ax, prev_y = ay;
        for (var i = 1; i <= steps; i++) {
            var t = i / steps;
            var ang = a0 + diff * t;
            var nx = endpoint[0] + lengthdir_x(hw, ang);
            var ny = endpoint[1] + lengthdir_y(hw, ang);

            gmvex_stroke_vertex(vb, endpoint[0], endpoint[1], col, alpha, u_val, 0.5);
            gmvex_stroke_vertex(vb, prev_x, prev_y, col, alpha, u_val, 0);
            gmvex_stroke_vertex(vb, nx, ny, col, alpha, u_val, 1);

            prev_x = nx; prev_y = ny;
        }
    }
}

function gmvex_round_step_count(radius, angle_diff_degrees) {
    var tol = global.gmvex_tolerance;
    var step_deg;
    if (radius <= tol) {
        step_deg = 360;
    } else {
        var cos_half = clamp(1 - (tol / radius), -1, 1);
        step_deg = max(2 * radtodeg(arccos(cos_half)), 1);
    }
    return max(1, ceil(abs(angle_diff_degrees) / step_deg));
}