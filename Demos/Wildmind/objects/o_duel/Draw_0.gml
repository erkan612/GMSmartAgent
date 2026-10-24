draw_sprite(demo_art("floor"), 0, arena.cx, arena.cy);
for (var _i = 0; _i < array_length(arena.pillars); _i++) {
    var _p = arena.pillars[_i];
    if (_p.broken) { // rubble, it doesn't block anything
        draw_set_colour(make_color_rgb(90, 85, 80));
        draw_circle(_p.x - 14, _p.y + 6, 12, false);
        draw_circle(_p.x + 12, _p.y - 8, 10, false);
        draw_circle(_p.x + 4, _p.y + 14, 8, false);
    } else {
        draw_sprite_ext(demo_art("pillar"), 0, _p.x, _p.y, 1, 1, 0, (_p.cracks > 0) ? c_gray : c_white, 1);
    }
}

if (global.debug.nav) {
    if (!surface_exists(nav_overlay) || nav_overlay_version != nav_grid.version) {
        if (!surface_exists(nav_overlay)) nav_overlay = surface_create(room_width, room_height);
        var _cfg = gmnav_debug_config();
        _cfg.cull = false; // the whole grid goes on the surface, not just what the camera sees
        _cfg.alpha = 1;
        surface_set_target(nav_overlay);
        draw_clear_alpha(c_black, 0);
        gmnav_debug_draw_clearance(nav_grid, _cfg);
        surface_reset_target();
        nav_overlay_version = nav_grid.version;
    }
    draw_surface_ext(nav_overlay, 0, 0, 1, 1, 0, c_white, 0.45);
    gmnav_debug_draw_agent(varn.nav);
}