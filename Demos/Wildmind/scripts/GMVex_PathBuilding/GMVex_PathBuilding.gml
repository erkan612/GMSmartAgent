function gmvex_path_set_winding(path, mode) {
    path.winding = mode;
    path.dirty = true;
}

function gmvex_signed_area(pts) {
    var n = array_length(pts);
    var area = 0;
    for (var i = 0; i < n; i++) {
        var p0 = pts[i];
        var p1 = pts[(i + 1) mod n];
        area += (p0[0] * p1[1]) - (p1[0] * p0[1]);
    }
    return area / 2;
}

function gmvex_path_moveto(path, x, y) {
    array_push(path.subpaths, { commands: [{ type: gmvex_cmd.MOVETO, x: x, y: y }], closed: false });
    path.current = array_length(path.subpaths) - 1;
    path.dirty = true;
}

function gmvex_path_lineto(path, x, y) {
    if (path.current < 0) { gmvex_path_moveto(path, x, y); return; }
    array_push(path.subpaths[path.current].commands, { type: gmvex_cmd.LINETO, x: x, y: y });
    path.dirty = true;
}

function gmvex_path_quadto(path, cx, cy, x, y, easing_fn = -1) {
    if (path.current < 0) { gmvex_path_moveto(path, x, y); return; }
    array_push(path.subpaths[path.current].commands, {
        type: gmvex_cmd.QUADTO, cx: cx, cy: cy, x: x, y: y, easing: easing_fn
    });
    path.dirty = true;
}

function gmvex_path_cubicto(path, c1x, c1y, c2x, c2y, x, y, easing_fn = -1) {
    if (path.current < 0) { gmvex_path_moveto(path, x, y); return; }
    array_push(path.subpaths[path.current].commands, {
        type: gmvex_cmd.CUBICTO, c1x: c1x, c1y: c1y, c2x: c2x, c2y: c2y, x: x, y: y, easing: easing_fn
    });
    path.dirty = true;
}

function gmvex_path_splineto(path, x, y) { // catmull rom same as gmmt
    if (path.current < 0) { gmvex_path_moveto(path, x, y); return; }
    var sp = path.subpaths[path.current];
    if (!variable_struct_exists(sp, "splinepts")) sp.splinepts = [[sp.commands[0].x, sp.commands[0].y]];
    array_push(sp.splinepts, [x, y]);
    path.dirty = true;
}

function gmvex_path_close(path) {
    if (path.current < 0) return;
    path.subpaths[path.current].closed = true;
    path.dirty = true;
}