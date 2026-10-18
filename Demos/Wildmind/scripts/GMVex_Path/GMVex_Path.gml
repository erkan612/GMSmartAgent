function gmvex_path_create() {
    return {
        subpaths : [],
        current  : -1,
        dirty    : true,
        vbuff    : -1,
        bbox     : [0, 0, 0, 0],
        winding  : gmvex_winding.NONZERO,
    };
}

function gmvex_path_destroy(path) {
    if (path.vbuff != -1) vertex_delete_buffer(path.vbuff);
    path.vbuff = -1;
    if (variable_struct_exists(path, "vbuff_cw") && path.vbuff_cw != -1) vertex_delete_buffer(path.vbuff_cw);
    path.vbuff_cw = -1;
    if (variable_struct_exists(path, "stroke_vbuff") && path.stroke_vbuff != -1) {
        vertex_delete_buffer(path.stroke_vbuff);
    }

    if (variable_struct_exists(path, "mask_surface") && surface_exists(path.mask_surface)) {
        surface_free(path.mask_surface);
    }
    path.mask_surface = -1;
    if (variable_struct_exists(path, "mask_path") && !is_undefined(path.mask_path)) {
        gmvex_path_destroy(path.mask_path);
    }
	if (variable_struct_exists(path, "gradmask_surf") && surface_exists(path.gradmask_surf)) surface_free(path.gradmask_surf);
}

function gmvex_path_set_mask(path, mask_path) {
    path.mask_path = mask_path;
    path.mask_dirty = true;
    if (!variable_struct_exists(path, "mask_surface")) {
        path.mask_surface = -1;
        path.mask_surface_w = 0;
        path.mask_surface_h = 0;
    }
}

function gmvex_path_mark_mask_dirty(path) {
    if (variable_struct_exists(path, "mask_dirty")) path.mask_dirty = true;
}

function gmvex_path_clone(path) {
    var clone = gmvex_path_create();
    clone.winding = path.winding;

    for (var s = 0; s < array_length(path.subpaths); s++) {
        var sp = path.subpaths[s];
        var new_commands = [];
        for (var c = 0; c < array_length(sp.commands); c++) {
            new_commands[c] = variable_clone(sp.commands[c]);
        }
        var new_sp = { commands: new_commands, closed: sp.closed };
        if (variable_struct_exists(sp, "splinepts")) {
            var new_splinepts = [];
            for (var p = 0; p < array_length(sp.splinepts); p++) {
                new_splinepts[p] = [sp.splinepts[p][0], sp.splinepts[p][1]];
            }
            new_sp.splinepts = new_splinepts;
        }
        array_push(clone.subpaths, new_sp);
    }
    clone.current = path.current;

    if (variable_struct_exists(path, "tmatrix")) {
        clone.tmatrix = [path.tmatrix[0], path.tmatrix[1], path.tmatrix[2], path.tmatrix[3], path.tmatrix[4], path.tmatrix[5]];
        clone.tox = variable_struct_exists(path, "tox") ? path.tox : 0;
        clone.toy = variable_struct_exists(path, "toy") ? path.toy : 0;
    }

    if (variable_struct_exists(path, "flat_subpaths")) {
        var new_flat = [];
        for (var s = 0; s < array_length(path.flat_subpaths); s++) {
            var fsp = path.flat_subpaths[s];
            var new_pts = array_create(array_length(fsp.points));
            for (var p = 0; p < array_length(fsp.points); p++) {
                new_pts[p] = [fsp.points[p][0], fsp.points[p][1]];
            }
            array_push(new_flat, { points: new_pts, closed: fsp.closed });
        }
        clone.flat_subpaths = new_flat;
    }
    if (variable_struct_exists(path, "bbox")) {
        clone.bbox = [path.bbox[0], path.bbox[1], path.bbox[2], path.bbox[3]];
    }

    return clone;
}

function gmvex_mask_ensure_surface(path) {
    if (!variable_struct_exists(path, "mask_path") || is_undefined(path.mask_path)) return -1;

    if (path.dirty) gmvex_path_rebuild(path);
    var bbox = path.bbox;
    var needed_w = ceil(max(bbox[2] - bbox[0], 1));
    var needed_h = ceil(max(bbox[3] - bbox[1], 1));

    var needs_rebuild = !surface_exists(path.mask_surface)
        || path.mask_dirty
        || path.mask_surface_w != needed_w
        || path.mask_surface_h != needed_h;

    if (needs_rebuild) {
        if (surface_exists(path.mask_surface)) surface_free(path.mask_surface);
        path.mask_surface = surface_create(needed_w, needed_h);
        path.mask_surface_w = needed_w;
        path.mask_surface_h = needed_h;

        var mp = path.mask_path;

        if (!variable_struct_exists(mp, "mask_orig_tmatrix")) {
            mp.mask_orig_tmatrix = variable_struct_exists(mp, "tmatrix") ? mp.tmatrix : [1, 0, 0, 1, 0, 0];
            mp.mask_orig_tox = variable_struct_exists(mp, "tox") ? mp.tox : 0;
            mp.mask_orig_toy = variable_struct_exists(mp, "toy") ? mp.toy : 0;
        }
        var orig_m = mp.mask_orig_tmatrix;
        mp.tmatrix = [orig_m[0], orig_m[1], orig_m[2], orig_m[3], orig_m[4] - bbox[0], orig_m[5] - bbox[1]];

        surface_set_target(path.mask_surface);
        draw_clear_alpha(c_black, 1);
        if (mp.dirty) gmvex_path_rebuild(mp);
        gmvex_fill_draw(mp, c_white, 1);
        surface_reset_target();

        mp.tmatrix = orig_m;

        path.mask_dirty = false;
    }

    return path.mask_surface;
}

function gmvex_path_merge(paths) {
    var combined = gmvex_path_create();
    combined.subpaths = [];
    combined.flat_subpaths = [];
    var minx = infinity, miny = infinity, maxx = -infinity, maxy = -infinity;
    var any = false;

    for (var i = 0; i < array_length(paths); i++) {
        var baked = gmvex_path_clone(paths[i]);
        gmvex_path_apply_transform_all(baked);
        if (baked.dirty) gmvex_path_rebuild(baked);

        for (var s = 0; s < array_length(baked.flat_subpaths); s++) {
            var src_pts = baked.flat_subpaths[s].points;
            var pts_copy = array_create(array_length(src_pts));
            for (var p = 0; p < array_length(src_pts); p++) {
                pts_copy[p] = [src_pts[p][0], src_pts[p][1]];
            }
            array_push(combined.flat_subpaths, { points: pts_copy, closed: baked.flat_subpaths[s].closed });
            any = true;
            for (var p = 0; p < array_length(pts_copy); p++) {
                minx = min(minx, pts_copy[p][0]); maxx = max(maxx, pts_copy[p][0]);
                miny = min(miny, pts_copy[p][1]); maxy = max(maxy, pts_copy[p][1]);
            }
        }

        gmvex_path_destroy(baked);
    }
    if (!any) return undefined;

    combined.bbox = [minx, miny, maxx, maxy];
    combined.dirty = false;
    gmvex_bool_rebuild_vbuff_from_flat(combined);
    return combined;
}