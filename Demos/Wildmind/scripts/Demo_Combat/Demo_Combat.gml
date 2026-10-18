function demo_swing_create(_owner, _team, _damage, _knock) { // one attack: it hits each fighter at most once
    return { owner : _owner, team : _team, damage : _damage, knock : _knock, hit : [] };
}

function demo_swing_hit_circle(_swing, _x, _y, _r) { // hits every fighter of another team touching the circle, returns how many it reached
    var _n = 0;
    with (o_fighter) {
        if (team == _swing.team || dead) continue;
        if (array_contains(_swing.hit, id)) continue;
        if (point_distance(x, y, _x, _y) > _r + radius) continue;
        array_push(_swing.hit, id);
        if (__demo_swing_land(_swing, id)) _n++;
    }
    return _n;
}

function demo_swing_hit_arc(_swing, _x, _y, _reach, _dir, _half) { // hits fighters inside a pie slice: reach from the point, half the angle on each side of dir
    var _n = 0;
    with (o_fighter) {
        if (team == _swing.team || dead) continue;
        if (array_contains(_swing.hit, id)) continue;
        if (point_distance(_x, _y, x, y) > _reach + radius) continue;
        if (abs(angle_difference(point_direction(_x, _y, x, y), _dir)) > _half) continue;
        array_push(_swing.hit, id);
        if (__demo_swing_land(_swing, id)) _n++;
    }
    return _n;
}

function __demo_swing_land(_swing, _f) { // true when the swing connected, as a hit or a block
    if (_f.blocks(point_direction(_f.x, _f.y, _swing.owner.x, _swing.owner.y))) return true;
    return fighter_take_hit(_f, _swing.damage, point_direction(_swing.owner.x, _swing.owner.y, _f.x, _f.y), _swing.knock);
}

function fighter_take_hit(_f, _damage, _dir, _knock) { // false when it couldn't be hit
    with (_f) {
        if (invuln > 0 || dead) return false;
        if (global.debug.god && object_index == o_player) return false;
        hp = max(0, hp - _damage);
        flash = 0.12;
        knock_x += lengthdir_x(_knock * knock_scale, _dir);
        knock_y += lengthdir_y(_knock * knock_scale, _dir);
        on_hurt(_damage);
        if (hp <= 0) {
            dead = true;
            on_death();
        }
    }
    return true;
}

function fighter_tick(_f, _dt) { // timers and knockback, once a step for every fighter
    with (_f) {
        invuln = max(0, invuln - _dt);
        flash = max(0, flash - _dt);
        x += knock_x * _dt;
        y += knock_y * _dt;
        var _fade = power(0.0001, _dt); // knockback loses most of its speed in a fraction of a second
        knock_x *= _fade;
        knock_y *= _fade;
    }
}

function fighter_draw(_sprite, _angle, _alpha = 1) { // the sprite, and a white flash over it right after a hit
    draw_sprite_ext(_sprite, 0, x, y, 1, 1, _angle, c_white, _alpha);
    if (flash > 0) {
        gpu_set_fog(true, c_white, 0, 0);
        draw_sprite_ext(_sprite, 0, x, y, 1, 1, _angle, c_white, _alpha);
        gpu_set_fog(false, c_white, 0, 0);
    }
}

function demo_draw_sector(_x, _y, _r, _dir, _half, _col, _alpha) { // a filled pie slice, for attack warnings
    var _steps = max(4, ceil(_half / 6));
    draw_set_colour(_col);
    draw_set_alpha(_alpha);
    draw_primitive_begin(pr_trianglefan);
    draw_vertex(_x, _y);
    for (var _i = -_steps; _i <= _steps; _i++) {
        var _a = _dir + _half * _i / _steps;
        draw_vertex(_x + lengthdir_x(_r, _a), _y + lengthdir_y(_r, _a));
    }
    draw_primitive_end();
    draw_set_alpha(1);
}

function demo_draw_lane(_x, _y, _dir, _len, _width, _col, _alpha) { // a filled strip ahead of a point, for charge warnings
    var _sx = lengthdir_x(_width / 2, _dir + 90);
    var _sy = lengthdir_y(_width / 2, _dir + 90);
    var _ex = _x + lengthdir_x(_len, _dir);
    var _ey = _y + lengthdir_y(_len, _dir);
    draw_set_colour(_col);
    draw_set_alpha(_alpha);
    draw_primitive_begin(pr_trianglestrip);
    draw_vertex(_x + _sx, _y + _sy);
    draw_vertex(_x - _sx, _y - _sy);
    draw_vertex(_ex + _sx, _ey + _sy);
    draw_vertex(_ex - _sx, _ey - _sy);
    draw_primitive_end();
    draw_set_alpha(1);
}

function fighter_overlaps(_f) { // true when _f stands inside another living fighter
    with (o_fighter) {
        if (id == _f || dead) continue;
        if (point_distance(x, y, _f.x, _f.y) < radius + _f.radius) return true;
    }
    return false;
}

function fighter_push_out(_f) { // moves _f out of every other living fighter, they don't move
    with (o_fighter) {
        if (id == _f || dead) continue;
        var _min = radius + _f.radius;
        var _d = point_distance(x, y, _f.x, _f.y);
        if (_d >= _min) continue;
        var _dir = (_d > 0.01) ? point_direction(x, y, _f.x, _f.y) : irandom(359);
        _f.x = x + lengthdir_x(_min, _dir);
        _f.y = y + lengthdir_y(_min, _dir);
    }
}