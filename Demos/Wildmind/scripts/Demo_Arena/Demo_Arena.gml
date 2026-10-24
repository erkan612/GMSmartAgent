function demo_arena_create(_cx, _cy, _r) { // a round floor inside a wall
    return { cx : _cx, cy : _cy, r : _r, pillars : [] };
}

function demo_arena_add_pillar(_arena, _x, _y, _r) {
    array_push(_arena.pillars, { x : _x, y : _y, r : _r, broken : false, cracks : 0 });
}

function demo_arena_fits(_arena, _x, _y, _r) { // false when a circle there would touch a pillar or the wall
    if (point_distance(_arena.cx, _arena.cy, _x, _y) > _arena.r - _r) return false;
    for (var _i = 0; _i < array_length(_arena.pillars); _i++) {
        var _p = _arena.pillars[_i];
        if (!_p.broken && point_distance(_p.x, _p.y, _x, _y) < _p.r + _r) return false;
    }
    return true;
}

function demo_arena_collide(_arena, _inst) { // pushes a fighter out of the pillars and back inside the wall
    with (_inst) {
        for (var _i = 0; _i < array_length(_arena.pillars); _i++) {
            var _p = _arena.pillars[_i];
            if (_p.broken) continue;
            var _d = point_distance(_p.x, _p.y, x, y);
            var _min = _p.r + radius;
            if (_d < _min && _d > 0) {
                x = _p.x + (x - _p.x) / _d * _min;
                y = _p.y + (y - _p.y) / _d * _min;
            }
        }
        var _dw = point_distance(_arena.cx, _arena.cy, x, y);
        var _max = _arena.r - radius;
        if (_dw > _max) {
            x = _arena.cx + (x - _arena.cx) / _dw * _max;
            y = _arena.cy + (y - _arena.cy) / _dw * _max;
        }
    }
}

function demo_arena_nav_grid(_arena, _tile) { // a GMNav grid of the arena: cells touching a pillar or the wall are blocked, body size is left to clearance
    var _cols = room_width div _tile;
    var _rows = room_height div _tile;
    var _grid = gmnav_grid_create(_cols, _rows, gmnav_layout_create(gmnav_layout.ORTHO, _tile, _tile));
    for (var _c = 0; _c < _cols; _c++) {
        for (var _r = 0; _r < _rows; _r++) {
            if (!demo_arena_fits(_arena, (_c + 0.5) * _tile, (_r + 0.5) * _tile, _tile * 0.5)) gmnav_grid_set_blocked(_grid, _c, _r, true);
        }
    }
    gmnav_clearance_build(_grid);
    return _grid;
}

function demo_nav_goto(_agent, _grid, _x, _y) { // sends an agent toward a point, moved to the nearest spot its body fits
    var _node = gmnav_clearance_nearest(_grid, gmnav_grid_world_to_node(_grid, _x, _y), _agent.need_clear);
    if (_node == GMNAV_NO_NODE) return false;
    var _at = gmnav_grid_node_to_world(_grid, _node);
    gmnav_agent_goto(_agent, _at[0], _at[1]);
    return true;
}

function demo_arena_line_clear(_arena, _x1, _y1, _x2, _y2, _pad) { // false when a pillar stands within pad of the line between two points
    var _dx = _x2 - _x1;
    var _dy = _y2 - _y1;
    var _len2 = _dx * _dx + _dy * _dy;
    for (var _i = 0; _i < array_length(_arena.pillars); _i++) {
        var _p = _arena.pillars[_i];
        if (_p.broken) continue;
        var _t = (_len2 > 0) ? clamp(((_p.x - _x1) * _dx + (_p.y - _y1) * _dy) / _len2, 0, 1) : 0;
        if (point_distance(_p.x, _p.y, _x1 + _dx * _t, _y1 + _dy * _t) < _p.r + _pad) return false;
    }
    return true;
}

function demo_arena_break_pillar(_arena, _grid, _i, _tile) { // a pillar falls: its cells open up and the clearance map is rebuilt, so paths change with it
    var _p = _arena.pillars[_i];
    if (_p.broken) return;
    _p.broken = true;
    var _c1 = floor((_p.x - _p.r) / _tile) - 1;
    var _c2 = floor((_p.x + _p.r) / _tile) + 1;
    var _r1 = floor((_p.y - _p.r) / _tile) - 1;
    var _r2 = floor((_p.y + _p.r) / _tile) + 1;
    for (var _c = _c1; _c <= _c2; _c++) {
        for (var _r = _r1; _r <= _r2; _r++) {
            if (!gmnav_grid_in_bounds(_grid, _c, _r)) continue;
            gmnav_grid_set_blocked(_grid, _c, _r, !demo_arena_fits(_arena, (_c + 0.5) * _tile, (_r + 0.5) * _tile, _tile * 0.5));
        }
    }
    gmnav_clearance_build(_grid);
}