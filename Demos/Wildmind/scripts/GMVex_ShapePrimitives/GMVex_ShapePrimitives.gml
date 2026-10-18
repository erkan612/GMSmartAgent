function gmvex_path_add_rect(path, x, y, w, h) {
    gmvex_path_moveto(path, x, y);
    gmvex_path_lineto(path, x + w, y);
    gmvex_path_lineto(path, x + w, y + h);
    gmvex_path_lineto(path, x, y + h);
    gmvex_path_close(path);
}

function gmvex_path_add_rounded_rect(path, x, y, w, h, rx, ry = -1) {
    if (ry == -1) ry = rx;
    rx = min(rx, w / 2);
    ry = min(ry, h / 2);

    gmvex_path_moveto(path, x + rx, y);
    gmvex_path_lineto(path, x + w - rx, y);
    gmvex_path_arcto(path, rx, ry, 0, 0, 1, x + w, y + ry);
    gmvex_path_lineto(path, x + w, y + h - ry);
    gmvex_path_arcto(path, rx, ry, 0, 0, 1, x + w - rx, y + h);
    gmvex_path_lineto(path, x + rx, y + h);
    gmvex_path_arcto(path, rx, ry, 0, 0, 1, x, y + h - ry);
    gmvex_path_lineto(path, x, y + ry);
    gmvex_path_arcto(path, rx, ry, 0, 0, 1, x + rx, y);
    gmvex_path_close(path);
}

function gmvex_path_add_ellipse(path, cx, cy, rx, ry) {
    gmvex_path_moveto(path, cx + rx, cy);
    gmvex_path_arcto(path, rx, ry, 0, 0, 1, cx - rx, cy);
    gmvex_path_arcto(path, rx, ry, 0, 0, 1, cx + rx, cy);
    gmvex_path_close(path);
}

function gmvex_path_add_circle(path, cx, cy, r) {
    gmvex_path_add_ellipse(path, cx, cy, r, r);
}

function gmvex_path_add_line(path, x1, y1, x2, y2) {
    gmvex_path_moveto(path, x1, y1);
    gmvex_path_lineto(path, x2, y2);
	// intentionally not closed
}

function gmvex_path_add_polyline(path, points) {
    var n = array_length(points);
    if (n == 0) return;
    gmvex_path_moveto(path, points[0][0], points[0][1]);
    for (var i = 1; i < n; i++) {
        gmvex_path_lineto(path, points[i][0], points[i][1]);
    }
}

function gmvex_path_add_polygon(path, points) {
    gmvex_path_add_polyline(path, points);
    gmvex_path_close(path);
}