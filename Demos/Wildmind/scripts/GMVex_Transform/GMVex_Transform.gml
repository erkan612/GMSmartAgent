function gmvex_path_set_transform(path, x, y, rot = 0, xscale = 1, yscale = 1, origin_x = 0, origin_y = 0, shear_x = 0, shear_y = 0) {
    path.tox = origin_x;
    path.toy = origin_y;

    var srt_matrix = matrix_build(x, y, 0, 0, 0, rot, xscale, yscale, 1);
    var full_matrix = srt_matrix;
    if (origin_x != 0 || origin_y != 0) {
        var pivot_matrix = matrix_build(-origin_x, -origin_y, 0, 0, 0, 0, 1, 1, 1);
        full_matrix = matrix_multiply(pivot_matrix, srt_matrix);
    }

    var m = [full_matrix[0], full_matrix[4], full_matrix[1], full_matrix[5], full_matrix[12], full_matrix[13]];

    if (shear_x != 0 || shear_y != 0) {
        var skew_x_m = [1, 0, tan(degtorad(shear_x)), 1, 0, 0];
        var skew_y_m = [1, tan(degtorad(shear_y)), 0, 1, 0, 0];
        var shear_matrix = gmvex_svg_matrix_multiply(skew_x_m, skew_y_m);
        m = gmvex_svg_matrix_multiply(m, shear_matrix);
    }

    path.tmatrix = m;
}

function gmvex_path_get_matrix(path) {
    if (!variable_struct_exists(path, "tmatrix")) return matrix_build_identity();
    var m = path.tmatrix;
    return [
        m[0], m[1], 0, 0,
        m[2], m[3], 0, 0,
        0,    0,    1, 0,
        m[4], m[5], 0, 1
    ];
}

function gmvex_apply_transform_offset_command(cmd, dx, dy) {
    if (cmd.type == gmvex_cmd.MOVETO || cmd.type == gmvex_cmd.LINETO) {
        cmd.x += dx; cmd.y += dy;
    } else if (cmd.type == gmvex_cmd.QUADTO) {
        cmd.cx += dx; cmd.cy += dy;
        cmd.x += dx; cmd.y += dy;
    } else if (cmd.type == gmvex_cmd.CUBICTO) {
        cmd.c1x += dx; cmd.c1y += dy;
        cmd.c2x += dx; cmd.c2y += dy;
        cmd.x += dx; cmd.y += dy;
    }
}

function gmvex_apply_transform_scale_command(cmd, scale_x, scale_y) {
    if (cmd.type == gmvex_cmd.MOVETO || cmd.type == gmvex_cmd.LINETO) {
        cmd.x *= scale_x; cmd.y *= scale_y;
    } else if (cmd.type == gmvex_cmd.QUADTO) {
        cmd.cx *= scale_x; cmd.cy *= scale_y;
        cmd.x *= scale_x; cmd.y *= scale_y;
    } else if (cmd.type == gmvex_cmd.CUBICTO) {
        cmd.c1x *= scale_x; cmd.c1y *= scale_y;
        cmd.c2x *= scale_x; cmd.c2y *= scale_y;
        cmd.x *= scale_x; cmd.y *= scale_y;
    }
}

function gmvex_apply_transform_rotate_command(cmd, deg) {
    var rad = degtorad(deg);
    var cs = cos(rad), sn = sin(rad);
    if (cmd.type == gmvex_cmd.MOVETO || cmd.type == gmvex_cmd.LINETO) {
        var nx = cmd.x*cs - cmd.y*sn;
        var ny = cmd.x*sn + cmd.y*cs;
        cmd.x = nx; cmd.y = ny;
    } else if (cmd.type == gmvex_cmd.QUADTO) {
        var ncx = cmd.cx*cs - cmd.cy*sn;
        var ncy = cmd.cx*sn + cmd.cy*cs;
        var nx = cmd.x*cs - cmd.y*sn;
        var ny = cmd.x*sn + cmd.y*cs;
        cmd.cx = ncx; cmd.cy = ncy;
        cmd.x = nx; cmd.y = ny;
    } else if (cmd.type == gmvex_cmd.CUBICTO) {
        var nc1x = cmd.c1x*cs - cmd.c1y*sn;
        var nc1y = cmd.c1x*sn + cmd.c1y*cs;
        var nc2x = cmd.c2x*cs - cmd.c2y*sn;
        var nc2y = cmd.c2x*sn + cmd.c2y*cs;
        var nx = cmd.x*cs - cmd.y*sn;
        var ny = cmd.x*sn + cmd.y*cs;
        cmd.c1x = nc1x; cmd.c1y = nc1y;
        cmd.c2x = nc2x; cmd.c2y = nc2y;
        cmd.x = nx; cmd.y = ny;
    }
}

function gmvex_apply_transform_walk(path, offset_fn, scale_fn, rotate_fn) {
    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            var cmd = sp.commands[c];
            if (!is_undefined(offset_fn)) offset_fn(cmd);
            if (!is_undefined(scale_fn)) scale_fn(cmd);
            if (!is_undefined(rotate_fn)) rotate_fn(cmd);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                var pt = sp.splinepts[p];
                if (!is_undefined(offset_fn)) offset_fn({x: pt[0], y: pt[1]});
            }
        }
    }
}

function gmvex_path_apply_position(path) {
    if (!variable_struct_exists(path, "tmatrix")) return;
    var m = path.tmatrix;
    if (m[4] == 0 && m[5] == 0) return;

    var det = m[0]*m[3] - m[1]*m[2];
    if (det == 0) return;
    var dx = (m[3]*m[4] - m[1]*m[5]) / det;
    var dy = (m[0]*m[5] - m[2]*m[4]) / det;

    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            gmvex_apply_transform_offset_command(sp.commands[c], dx, dy);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                sp.splinepts[p][0] += dx;
                sp.splinepts[p][1] += dy;
            }
        }
    }

    path.tmatrix = [m[0], m[1], m[2], m[3], 0, 0];
    path.dirty = true;
    if (variable_struct_exists(path, "stroke_vbuff")) path.stroke_dash_dirty = true;
}

function gmvex_path_apply_rotation(path) {
    if (!variable_struct_exists(path, "tmatrix")) return;
    var m = path.tmatrix;
    var rot = radtodeg(arctan2(m[1], m[0]));
    if (rot == 0) return;

    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            gmvex_apply_transform_rotate_command(sp.commands[c], -rot);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            var rad = degtorad(-rot);
            var cs = cos(rad), sn = sin(rad);
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                var px = sp.splinepts[p][0], py = sp.splinepts[p][1];
                sp.splinepts[p][0] = px*cs - py*sn;
                sp.splinepts[p][1] = px*sn + py*cs;
            }
        }
    }

    var scale_h = sqrt(m[0]*m[0] + m[1]*m[1]);
    var det = m[0]*m[3] - m[1]*m[2];
    var scale_v = (scale_h == 0) ? 0 : det / scale_h; // signed, negative means reflection
    path.tmatrix = [scale_h, 0, 0, scale_v, m[4], m[5]];
    path.dirty = true;
    if (variable_struct_exists(path, "stroke_vbuff")) path.stroke_dash_dirty = true;
}

function gmvex_apply_transform_sandwich_scale_command(cmd, sandwich_xx, sandwich_xy, sandwich_yx, sandwich_yy) {
    if (cmd.type == gmvex_cmd.MOVETO || cmd.type == gmvex_cmd.LINETO) {
        var nx = sandwich_xx*cmd.x + sandwich_xy*cmd.y;
        var ny = sandwich_yx*cmd.x + sandwich_yy*cmd.y;
        cmd.x = nx; cmd.y = ny;
    } else if (cmd.type == gmvex_cmd.QUADTO) {
        var ncx = sandwich_xx*cmd.cx + sandwich_xy*cmd.cy;
        var ncy = sandwich_yx*cmd.cx + sandwich_yy*cmd.cy;
        var nx = sandwich_xx*cmd.x + sandwich_xy*cmd.y;
        var ny = sandwich_yx*cmd.x + sandwich_yy*cmd.y;
        cmd.cx = ncx; cmd.cy = ncy;
        cmd.x = nx; cmd.y = ny;
    } else if (cmd.type == gmvex_cmd.CUBICTO) {
        var nc1x = sandwich_xx*cmd.c1x + sandwich_xy*cmd.c1y;
        var nc1y = sandwich_yx*cmd.c1x + sandwich_yy*cmd.c1y;
        var nc2x = sandwich_xx*cmd.c2x + sandwich_xy*cmd.c2y;
        var nc2y = sandwich_yx*cmd.c2x + sandwich_yy*cmd.c2y;
        var nx = sandwich_xx*cmd.x + sandwich_xy*cmd.y;
        var ny = sandwich_yx*cmd.x + sandwich_yy*cmd.y;
        cmd.c1x = nc1x; cmd.c1y = nc1y;
        cmd.c2x = nc2x; cmd.c2y = nc2y;
        cmd.x = nx; cmd.y = ny;
    }
}

function gmvex_path_apply_scale(path) {
    if (!variable_struct_exists(path, "tmatrix")) return;
    var m = path.tmatrix;
    var scale_h = sqrt(m[0]*m[0] + m[1]*m[1]);
    if (scale_h == 0) return;
    var det = m[0]*m[3] - m[1]*m[2];
    var scale_v = det / scale_h; // signed, negative means reflection
    if (scale_h == 1 && scale_v == 1) return;

    var rot = radtodeg(arctan2(m[1], m[0]));
    var rad = degtorad(rot);
    var cs = cos(rad), sn = sin(rad);
    var sandwich_xx = scale_h*cs*cs + scale_v*sn*sn;
    var sandwich_xy = (scale_h - scale_v)*sn*cs;
    var sandwich_yx = (scale_h - scale_v)*sn*cs;
    var sandwich_yy = scale_h*sn*sn + scale_v*cs*cs;

    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        for (var c = 0; c < array_length(sp.commands); c++) {
            gmvex_apply_transform_sandwich_scale_command(sp.commands[c], sandwich_xx, sandwich_xy, sandwich_yx, sandwich_yy);
        }
        if (variable_struct_exists(sp, "splinepts")) {
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                var px = sp.splinepts[p][0], py = sp.splinepts[p][1];
                sp.splinepts[p][0] = sandwich_xx*px + sandwich_xy*py;
                sp.splinepts[p][1] = sandwich_yx*px + sandwich_yy*py;
            }
        }
    }

    path.tmatrix = [cs, sn, -sn, cs, m[4], m[5]];
    path.dirty = true;
    if (variable_struct_exists(path, "stroke_vbuff")) path.stroke_dash_dirty = true;
}

function gmvex_path_apply_transform_all(path) {
    gmvex_path_apply_scale(path);
    gmvex_path_apply_rotation(path);
    gmvex_path_apply_position(path);
}