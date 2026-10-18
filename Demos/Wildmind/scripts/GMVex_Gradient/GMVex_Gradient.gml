function gmvex_fill_draw_gradient(path, type, p0x, p0y, p1x, p1y, stops) {
    if (path.dirty) gmvex_path_rebuild(path);
    if (path.vbuff == -1 && path.vbuff_cw == -1) return;

    var mat = gmvex_path_get_matrix(path);
    var prev_mat = matrix_get(matrix_world);
    matrix_set(matrix_world, mat);

    var old_stencil = gpu_get_stencil_enable();
    var old_colorwrite = gpu_get_colourwriteenable();
    var old_zwrite = gpu_get_zwriteenable();
    var old_stencilfunc = gpu_get_stencil_func();
    var old_stencilref = gpu_get_stencil_ref();
    var old_stencilfail = gpu_get_stencil_fail();
    var old_stencildepthfail = gpu_get_stencil_depth_fail();
    var old_stencilpass = gpu_get_stencil_pass();

    gpu_set_stencil_enable(true);
    gpu_set_colorwriteenable(false, false, false, false);
    gpu_set_zwriteenable(false);
    gpu_set_stencil_func(cmpfunc_always);
    gpu_set_stencil_ref(0);

    if (path.winding == gmvex_winding.EVENODD) {
        gpu_set_stencil_fail(stencilop_keep);
        gpu_set_stencil_depth_fail(stencilop_keep);
        gpu_set_stencil_pass(stencilop_invert);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
    } else {
        gpu_set_stencil_fail(stencilop_keep);
        gpu_set_stencil_depth_fail(stencilop_keep);
        gpu_set_stencil_pass(stencilop_incr);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
        gpu_set_stencil_pass(stencilop_decr);
        if (path.vbuff_cw != -1) vertex_submit(path.vbuff_cw, pr_trianglelist, -1);
    }

    gpu_set_colorwriteenable(true, true, true, true);
    gpu_set_stencil_func(cmpfunc_notequal);
    gpu_set_stencil_ref(0);
    gpu_set_stencil_fail(stencilop_zero);
    gpu_set_stencil_depth_fail(stencilop_zero);
    gpu_set_stencil_pass(stencilop_zero);

    var shd = (type == gmvex_gradient.LINEAR) ? GMVEX_GRADIENT_LINEAR : GMVEX_GRADIENT_RADIAL;
    shader_set(shd);
    if (type == gmvex_gradient.LINEAR) {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradStart"), p0x, p0y);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradEnd"), p1x, p1y);
    } else {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradCenter"), p0x, p0y);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradRadius"), p1x);
    }
    var stop_count = min(array_length(stops), 32);
    var pos_arr = array_create(32, 0);
    var col_arr = array_create(32 * 4, 0);
    for (var i = 0; i < stop_count; i++) {
        pos_arr[i] = stops[i][0];
        col_arr[i*4+0] = color_get_red(stops[i][1]) / 255;
        col_arr[i*4+1] = color_get_green(stops[i][1]) / 255;
        col_arr[i*4+2] = color_get_blue(stops[i][1]) / 255;
        col_arr[i*4+3] = stops[i][2];
    }
    shader_set_uniform_i(shader_get_uniform(shd, "u_stopCount"), stop_count);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopPos"), pos_arr);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopColor"), col_arr);

    draw_rectangle(path.bbox[0], path.bbox[1], path.bbox[2], path.bbox[3], false);
    shader_reset();

    gpu_set_stencil_fail(old_stencilfail);
    gpu_set_stencil_depth_fail(old_stencildepthfail);
    gpu_set_stencil_pass(old_stencilpass);
    gpu_set_stencil_func(old_stencilfunc);
    gpu_set_stencil_ref(old_stencilref);
    gpu_set_colorwriteenable(old_colorwrite[0], old_colorwrite[1], old_colorwrite[2], old_colorwrite[3]);
    gpu_set_stencil_enable(old_stencil);
    gpu_set_zwriteenable(old_zwrite);
    matrix_set(matrix_world, prev_mat);
}

function gmvex_fill_draw_gradient_masked(path, grad_type, p0x, p0y, p1x, p1y, stops) {
    var mask_surf = gmvex_mask_ensure_surface(path);
    if (mask_surf == -1) { gmvex_fill_draw_gradient(path, grad_type, p0x, p0y, p1x, p1y, stops); return; }
    if (path.dirty) gmvex_path_rebuild(path);

    var bbox = path.bbox;
    var w = ceil(max(bbox[2]-bbox[0], 1)), h = ceil(max(bbox[3]-bbox[1], 1));

    if (!variable_struct_exists(path, "gradmask_orig_tmatrix")) {
        path.gradmask_orig_tmatrix = variable_struct_exists(path,"tmatrix") ? path.tmatrix : [1, 0, 0, 1, 0, 0];
    }
    var grad_orig_m = path.gradmask_orig_tmatrix;

    if (!variable_struct_exists(path,"gradmask_surf") || !surface_exists(path.gradmask_surf) || path.gradmask_surf_w != w || path.gradmask_surf_h != h) {
        if (variable_struct_exists(path,"gradmask_surf") && surface_exists(path.gradmask_surf)) surface_free(path.gradmask_surf);
        path.gradmask_surf = surface_create(w, h); path.gradmask_surf_w = w; path.gradmask_surf_h = h;
    }

    surface_set_target(path.gradmask_surf);
    draw_clear_alpha(c_black, 0);
    path.tmatrix = [grad_orig_m[0], grad_orig_m[1], grad_orig_m[2], grad_orig_m[3], -bbox[0], -bbox[1]];
    gmvex_fill_draw_gradient(path, grad_type, p0x, p0y, p1x, p1y, stops);
    surface_reset_target();
    path.tmatrix = grad_orig_m;

    if (path.vbuff == -1 && path.vbuff_cw == -1) return;
    var mat = gmvex_path_get_matrix(path);
    var prev_mat = matrix_get(matrix_world);
    matrix_set(matrix_world, mat);

    var old_stencil = gpu_get_stencil_enable();
    var old_colorwrite = gpu_get_colourwriteenable();
    var old_zwrite = gpu_get_zwriteenable();
    var old_stencilfunc = gpu_get_stencil_func();
    var old_stencilref = gpu_get_stencil_ref();
    var old_stencilfail = gpu_get_stencil_fail();
    var old_stencildepthfail = gpu_get_stencil_depth_fail();
    var old_stencilpass = gpu_get_stencil_pass();

    gpu_set_stencil_enable(true); gpu_set_colorwriteenable(false,false,false,false); gpu_set_zwriteenable(false);
    gpu_set_stencil_func(cmpfunc_always); gpu_set_stencil_ref(0);
    if (path.winding == gmvex_winding.EVENODD) {
        gpu_set_stencil_fail(stencilop_keep); gpu_set_stencil_depth_fail(stencilop_keep); gpu_set_stencil_pass(stencilop_invert);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
    } else {
        gpu_set_stencil_fail(stencilop_keep); gpu_set_stencil_depth_fail(stencilop_keep); gpu_set_stencil_pass(stencilop_incr);
        if (path.vbuff != -1) vertex_submit(path.vbuff, pr_trianglelist, -1);
        gpu_set_stencil_pass(stencilop_decr);
        if (path.vbuff_cw != -1) vertex_submit(path.vbuff_cw, pr_trianglelist, -1);
    }
    gpu_set_colorwriteenable(true,true,true,true); gpu_set_stencil_func(cmpfunc_notequal); gpu_set_stencil_ref(0);
    gpu_set_stencil_fail(stencilop_zero); gpu_set_stencil_depth_fail(stencilop_zero); gpu_set_stencil_pass(stencilop_zero);

    shader_set(GMVEX_MASK_LUMINANCE_COLORTEX);
    shader_set_uniform_f(shader_get_uniform(GMVEX_MASK_LUMINANCE_COLORTEX, "u_bbox"), bbox[0], bbox[1], bbox[2], bbox[3]);
    texture_set_stage(shader_get_sampler_index(GMVEX_MASK_LUMINANCE_COLORTEX, "u_mask"), surface_get_texture(mask_surf));
    texture_set_stage(shader_get_sampler_index(GMVEX_MASK_LUMINANCE_COLORTEX, "u_colortex"), surface_get_texture(path.gradmask_surf));
    draw_rectangle(bbox[0], bbox[1], bbox[2], bbox[3], false);
    shader_reset();

    gpu_set_stencil_fail(old_stencilfail);
    gpu_set_stencil_depth_fail(old_stencildepthfail);
    gpu_set_stencil_pass(old_stencilpass);
    gpu_set_stencil_func(old_stencilfunc);
    gpu_set_stencil_ref(old_stencilref);
    gpu_set_colorwriteenable(old_colorwrite[0], old_colorwrite[1], old_colorwrite[2], old_colorwrite[3]);
    gpu_set_stencil_enable(old_stencil);
    gpu_set_zwriteenable(old_zwrite);
    matrix_set(matrix_world, prev_mat);
}

function gmvex_stroke_draw_gradient(path, width, grad_type, p0x, p0y, p1x, p1y, stops, join_mode = gmvex_join.BEVEL, cap_mode = gmvex_cap.BUTT, miter_limit = 4) {
    if (path.dirty) gmvex_path_rebuild(path);

    var needs_rebuild = !variable_struct_exists(path, "stroke_vbuff") || path.stroke_vbuff == -1
        || !variable_struct_exists(path, "stroke_width") || path.stroke_width != width
        || !variable_struct_exists(path, "stroke_join")  || path.stroke_join != join_mode
        || !variable_struct_exists(path, "stroke_cap")   || path.stroke_cap != cap_mode
        || (variable_struct_exists(path, "stroke_dash_dirty") && path.stroke_dash_dirty);

    if (needs_rebuild) {
        if (variable_struct_exists(path, "stroke_vbuff") && path.stroke_vbuff != -1) vertex_delete_buffer(path.stroke_vbuff);
        var hw = width / 2;
        var vb = vertex_create_buffer();
        vertex_begin(vb, global.gmvex_vformat_full);
        var has_dash = variable_struct_exists(path, "dash_array") && array_length(path.dash_array) > 0;
        var dash_norm = has_dash ? gmvex_dash_normalize_array(path.dash_array) : [];
        var dash_offset = variable_struct_exists(path, "dash_offset") ? path.dash_offset : 0;
        for (var s = 0; s < array_length(path.flat_subpaths); s++) {
            var sub = path.flat_subpaths[s]; var pts = sub.points; var closed = sub.closed;
            if (array_length(pts) < 2) continue;
            if (!has_dash) {
                gmvex_stroke_emit_polyline(vb, pts, closed, c_white, 1, join_mode, cap_mode, miter_limit, hw);
            } else {
                var seg_count = closed ? array_length(pts) : array_length(pts) - 1;
                var total_len = 0;
                for (var i = 0; i < seg_count; i++) { var p0=pts[i]; var p1=pts[(i+1) mod array_length(pts)]; total_len += point_distance(p0[0],p0[1],p1[0],p1[1]); }
                var intervals = gmvex_dash_build_intervals(total_len, dash_norm, dash_offset);
                for (var iv = 0; iv < array_length(intervals); iv++) {
                    var chunk = gmvex_stroke_dedupe_points(gmvex_stroke_extract_range(pts, closed, intervals[iv][0], intervals[iv][1]));
                    if (array_length(chunk) >= 2) gmvex_stroke_emit_polyline(vb, chunk, false, c_white, 1, join_mode, cap_mode, miter_limit, hw);
                }
            }
        }
        vertex_end(vb); vertex_freeze(vb);
        path.stroke_vbuff = vb; path.stroke_width = width; path.stroke_join = join_mode; path.stroke_cap = cap_mode; path.stroke_dash_dirty = false;
    }

    var mat = gmvex_path_get_matrix(path);
    var prev_mat = matrix_get(matrix_world);
    matrix_set(matrix_world, mat);

    var old_zwrite = gpu_get_zwriteenable();

    var shd = (grad_type == gmvex_gradient.LINEAR) ? GMVEX_GRADIENT_LINEAR : GMVEX_GRADIENT_RADIAL;
    shader_set(shd);
    if (grad_type == gmvex_gradient.LINEAR) {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradStart"), p0x, p0y);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradEnd"), p1x, p1y);
    } else {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradCenter"), p0x, p0y);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradRadius"), p1x);
    }
    var stop_count = min(array_length(stops), 8);
    var pos_arr = array_create(8, 0);
    var col_arr = array_create(32, 0);
    for (var i = 0; i < stop_count; i++) {
        pos_arr[i] = stops[i][0];
        col_arr[i*4+0] = color_get_red(stops[i][1]) / 255;
        col_arr[i*4+1] = color_get_green(stops[i][1]) / 255;
        col_arr[i*4+2] = color_get_blue(stops[i][1]) / 255;
        col_arr[i*4+3] = stops[i][2];
    }
    shader_set_uniform_i(shader_get_uniform(shd, "u_stopCount"), stop_count);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopPos"), pos_arr);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopColor"), col_arr);

    gpu_set_zwriteenable(false);
    vertex_submit(path.stroke_vbuff, pr_trianglelist, -1);

    shader_reset();
    gpu_set_zwriteenable(old_zwrite);
    matrix_set(matrix_world, prev_mat);
}

function gmvex_stroke_draw_gradient_masked(path, width, grad_type, p0x, p0y, p1x, p1y, stops, join_mode = gmvex_join.BEVEL, cap_mode = gmvex_cap.BUTT, miter_limit = 4) {
    var mask_surf = gmvex_mask_ensure_surface(path);
    if (mask_surf == -1) { gmvex_stroke_draw_gradient(path, width, grad_type, p0x, p0y, p1x, p1y, stops, join_mode, cap_mode, miter_limit); return; }
    if (path.dirty) gmvex_path_rebuild(path);

    var true_prev_mat = matrix_get(matrix_world);

    var needs_rebuild = !variable_struct_exists(path, "stroke_vbuff") || path.stroke_vbuff == -1
        || !variable_struct_exists(path, "stroke_width") || path.stroke_width != width
        || !variable_struct_exists(path, "stroke_join")  || path.stroke_join != join_mode
        || !variable_struct_exists(path, "stroke_cap")   || path.stroke_cap != cap_mode
        || (variable_struct_exists(path, "stroke_dash_dirty") && path.stroke_dash_dirty);

    if (needs_rebuild) {
        if (variable_struct_exists(path, "stroke_vbuff") && path.stroke_vbuff != -1) vertex_delete_buffer(path.stroke_vbuff);
        var hw = width / 2;
        var vb = vertex_create_buffer();
        vertex_begin(vb, global.gmvex_vformat_full);
        var has_dash = variable_struct_exists(path, "dash_array") && array_length(path.dash_array) > 0;
        var dash_norm = has_dash ? gmvex_dash_normalize_array(path.dash_array) : [];
        var dash_offset = variable_struct_exists(path, "dash_offset") ? path.dash_offset : 0;
        for (var s = 0; s < array_length(path.flat_subpaths); s++) {
            var sub = path.flat_subpaths[s]; var pts = sub.points; var closed = sub.closed;
            if (array_length(pts) < 2) continue;
            if (!has_dash) {
                gmvex_stroke_emit_polyline(vb, pts, closed, c_white, 1, join_mode, cap_mode, miter_limit, hw);
            } else {
                var seg_count = closed ? array_length(pts) : array_length(pts) - 1;
                var total_len = 0;
                for (var i = 0; i < seg_count; i++) { var p0=pts[i]; var p1=pts[(i+1) mod array_length(pts)]; total_len += point_distance(p0[0],p0[1],p1[0],p1[1]); }
                var intervals = gmvex_dash_build_intervals(total_len, dash_norm, dash_offset);
                for (var iv = 0; iv < array_length(intervals); iv++) {
                    var chunk = gmvex_stroke_dedupe_points(gmvex_stroke_extract_range(pts, closed, intervals[iv][0], intervals[iv][1]));
                    if (array_length(chunk) >= 2) gmvex_stroke_emit_polyline(vb, chunk, false, c_white, 1, join_mode, cap_mode, miter_limit, hw);
                }
            }
        }
        vertex_end(vb); vertex_freeze(vb);
        path.stroke_vbuff = vb; path.stroke_width = width; path.stroke_join = join_mode; path.stroke_cap = cap_mode; path.stroke_dash_dirty = false;
    }

    var bbox = path.bbox;
    var w = ceil(max(bbox[2]-bbox[0], 1)), h = ceil(max(bbox[3]-bbox[1], 1));

    if (!variable_struct_exists(path,"gradmask_surf") || !surface_exists(path.gradmask_surf) || path.gradmask_surf_w != w || path.gradmask_surf_h != h) {
        if (variable_struct_exists(path,"gradmask_surf") && surface_exists(path.gradmask_surf)) surface_free(path.gradmask_surf);
        path.gradmask_surf = surface_create(w, h); path.gradmask_surf_w = w; path.gradmask_surf_h = h;
    }

    surface_set_target(path.gradmask_surf);
    draw_clear_alpha(c_black, 1);
    matrix_set(matrix_world, matrix_build_identity());

    var shd = (grad_type == gmvex_gradient.LINEAR) ? GMVEX_GRADIENT_LINEAR : GMVEX_GRADIENT_RADIAL;
    shader_set(shd);
    if (grad_type == gmvex_gradient.LINEAR) {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradStart"), p0x - bbox[0], p0y - bbox[1]);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradEnd"), p1x - bbox[0], p1y - bbox[1]);
    } else {
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradCenter"), p0x - bbox[0], p0y - bbox[1]);
        shader_set_uniform_f(shader_get_uniform(shd, "u_gradRadius"), p1x);
    }
    var stop_count = min(array_length(stops), 8);
    var pos_arr = array_create(8, 0);
    var col_arr = array_create(32, 0);
    for (var i = 0; i < stop_count; i++) {
        pos_arr[i] = stops[i][0];
        col_arr[i*4+0] = color_get_red(stops[i][1]) / 255;
        col_arr[i*4+1] = color_get_green(stops[i][1]) / 255;
        col_arr[i*4+2] = color_get_blue(stops[i][1]) / 255;
        col_arr[i*4+3] = stops[i][2];
    }
    shader_set_uniform_i(shader_get_uniform(shd, "u_stopCount"), stop_count);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopPos"), pos_arr);
    shader_set_uniform_f_array(shader_get_uniform(shd, "u_stopColor"), col_arr);
    draw_rectangle(0, 0, w, h, false);
    shader_reset();
    surface_reset_target();

    var mat = gmvex_path_get_matrix(path);
    matrix_set(matrix_world, mat);

    var old_zwrite = gpu_get_zwriteenable();

    shader_set(GMVEX_MASK_LUMINANCE_COLORTEX);
    shader_set_uniform_f(shader_get_uniform(GMVEX_MASK_LUMINANCE_COLORTEX, "u_bbox"), bbox[0], bbox[1], bbox[2], bbox[3]);
    texture_set_stage(shader_get_sampler_index(GMVEX_MASK_LUMINANCE_COLORTEX, "u_mask"), surface_get_texture(mask_surf));
    texture_set_stage(shader_get_sampler_index(GMVEX_MASK_LUMINANCE_COLORTEX, "u_colortex"), surface_get_texture(path.gradmask_surf));

    gpu_set_zwriteenable(false);
    vertex_submit(path.stroke_vbuff, pr_trianglelist, -1);

    shader_reset();
    gpu_set_zwriteenable(old_zwrite);
    matrix_set(matrix_world, true_prev_mat);
}