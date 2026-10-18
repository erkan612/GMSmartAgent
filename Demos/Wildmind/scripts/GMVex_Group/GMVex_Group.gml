function gmvex_group_create() {
    return {
        members: [],
        gtmatrix: [1, 0, 0, 1, 0, 0]
    };
}

function gmvex_group_add_path(group, path) {
    array_push(group.members, { kind: "path", ref: path });
}

function gmvex_group_add_group(group, child_group) {
    array_push(group.members, { kind: "group", ref: child_group });
}

function gmvex_group_set_transform(group, x, y, rot = 0, xscale = 1, yscale = 1, origin_x = 0, origin_y = 0, shear_x = 0, shear_y = 0) {
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

    group.gtmatrix = m;
}

function gmvex_group_compose_point(acc, px, py) {
    var m = acc.gtmatrix;
    return [m[0]*px + m[2]*py + m[4], m[1]*px + m[3]*py + m[5]];
}

function gmvex_group_compose_accumulated(acc, group) {
    return {
        gtmatrix: gmvex_svg_matrix_multiply(acc.gtmatrix, group.gtmatrix)
    };
}

function gmvex_group_resolve_transforms(group, ancestor_acc = undefined) {
    if (is_undefined(ancestor_acc)) {
        ancestor_acc = { gtmatrix: [1, 0, 0, 1, 0, 0] };
    }
    var acc = gmvex_group_compose_accumulated(ancestor_acc, group);
    var n = array_length(group.members);
    for (var i = 0; i < n; i++) {
        var member = group.members[i];
        if (member.kind == "group") {
            gmvex_group_resolve_transforms(member.ref, acc);
        } else {
            var path = member.ref;
            if (!variable_struct_exists(path, "group_orig_tmatrix")) {
                path.group_orig_tmatrix = variable_struct_exists(path, "tmatrix") ? path.tmatrix : [1, 0, 0, 1, 0, 0];
            }
            path.tmatrix = gmvex_svg_matrix_multiply(acc.gtmatrix, path.group_orig_tmatrix);
        }
    }
}