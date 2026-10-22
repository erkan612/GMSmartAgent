// the warning: a faint full shape, and a stronger one growing inside it until the hit. white while it hits
if (state == varn_state.WINDUP || state == varn_state.HOLD || state == varn_state.ACTIVE) {
    var _t = (state == varn_state.WINDUP) ? state_time / windup_time : 1;
    var _col = (state == varn_state.ACTIVE) ? c_white : make_color_rgb(220, 60, 40);
    switch (attack.shape) {
        case varn_shape.ARC:
            demo_draw_sector(x, y, attack.reach, facing, attack.half, _col, 0.15);
            demo_draw_sector(x, y, attack.reach * _t, facing, attack.half, _col, 0.3);
            break;
        case varn_shape.SIDE:
            demo_draw_sector(x, y, attack.reach, facing + sweep_side, attack.half, _col, 0.15);
            demo_draw_sector(x, y, attack.reach * _t, facing + sweep_side, attack.half, _col, 0.3);
            break;
        case varn_shape.CIRCLE:
            draw_set_colour(_col);
            draw_set_alpha(0.15);
            draw_circle(slam_x, slam_y, attack.radius, false);
            draw_set_alpha(0.3);
            draw_circle(slam_x, slam_y, attack.radius * _t, false);
            draw_set_alpha(1);
            break;
        case varn_shape.CHARGE:
            if (state != varn_state.ACTIVE) demo_draw_lane(x, y, facing, attack.speed * attack.active + radius, radius * 2, _col, 0.15 + 0.15 * _t);
            break;
        case varn_shape.VOLLEY:
            if (state != varn_state.ACTIVE) {
                for (var _i = 0; _i < attack.count; _i++) {
                    var _d = facing + (_i - (attack.count - 1) / 2) * attack.spread;
                    demo_draw_lane(x, y, _d, attack.speed * attack.active, 10, _col, 0.1 + 0.2 * _t);
                }
            }
            break;
    }
}
if (state == varn_state.GUARD) demo_draw_sector(x, y, radius + 14, facing, 60, make_color_rgb(120, 180, 255), 0.35);
if (state == varn_state.LEAP && state_time < VARN_LEAP_CROUCH) demo_draw_lane(x, y, leap_dir, VARN_LEAP_DIST, radius * 2, c_white, 0.15); // where he'll land

fighter_draw(demo_art("varn"), facing, dead ? 0.4 : 1);

var _follow = (following || state == varn_state.RECOVER) ? follow.sure : 0;
var _sure = max(using_read ? read.sure : 0, (tactic != "") ? timing.sure : 0, _follow);
if (_sure > 0) { // the visor burns brighter the surer he is
    gpu_set_blendmode(bm_add);
    draw_set_colour(make_color_rgb(255, 110, 40));
    draw_set_alpha(0.25 + 0.5 * _sure);
    draw_circle(x + lengthdir_x(radius * 0.6, facing), y + lengthdir_y(radius * 0.6, facing), 8 + 14 * _sure, false);
    draw_set_alpha(1);
    gpu_set_blendmode(bm_normal);
}

var _line = (thought != "") ? thought : doing;
if (_line != "") { // until the real thought lines
    draw_set_colour((using_read || tactic != "" || _follow > 0) ? make_color_rgb(255, 170, 90) : c_white);
    draw_set_halign(fa_center);
    draw_text(x, y - radius - 28, _line);
    draw_set_halign(fa_left);
}

if (speech_time > 0) {
    draw_set_halign(fa_center);
    var _w = string_width(speech) + 20;
    var _by = y - radius - 64;
    draw_set_colour(c_white);
    draw_roundrect_ext(x - _w / 2, _by - 12, x + _w / 2, _by + 14, 10, 10, false);
    draw_set_colour(c_black);
    draw_text(x, _by - 9, speech);
    draw_set_halign(fa_left);
}