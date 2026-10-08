draw_set_colour(make_color_rgb(30, 30, 26));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

// two of the four measures: distance kept across, kills a minute up. Styles are found from all four
draw_set_colour(c_white);
draw_text(chart_l + chart_w / 2, chart_t - 16, "The crowd: distance kept from enemies (across), kills a minute (up)");
for (var _d = 0; _d <= 2000; _d += 500) {
    draw_set_colour(make_color_rgb(44, 44, 40));
    draw_line(cx(_d), chart_t, cx(_d), chart_t + chart_h);
    draw_set_colour(c_gray);
    draw_text(cx(_d), chart_t + chart_h + 14, string(_d));
}
for (var _k = 0; _k <= 4; _k += 1) {
    draw_set_colour(make_color_rgb(44, 44, 40));
    draw_line(chart_l, cy(_k), chart_l + chart_w, cy(_k));
    draw_set_halign(fa_right);
    draw_set_colour(c_gray);
    draw_text(chart_l - 6, cy(_k), string(_k));
    draw_set_halign(fa_center);
}
draw_set_colour(c_gray);
draw_rectangle(chart_l, chart_t, chart_l + chart_w, chart_t + chart_h, true);

// sessions, coloured by the style they fit best once there are styles
for (var _i = 0; _i < array_length(sessions); _i++) {
    var _s = session_style[_i];
    draw_set_colour((_s < 0 || fitting) ? c_gray : style_colours[_s mod array_length(style_colours)]);
    draw_circle(cx(sessions[_i].distance), cy(sessions[_i].kills), 3, false);
}

// each style: its typical values, and one spread either side
if (!fitting) {
    for (var _s = 0; _s < array_length(styles); _s++) {
        var _st = styles[_s];
        var _x = cx(_st.typical.distance);
        var _y = cy(_st.typical.kills);
        draw_set_colour(style_colours[_s mod array_length(style_colours)]);
        draw_ellipse(cx(_st.typical.distance - _st.spread.distance), cy(_st.typical.kills + _st.spread.kills),
            cx(_st.typical.distance + _st.spread.distance), cy(_st.typical.kills - _st.spread.kills), true);
        draw_circle(_x, _y, 6, false);
        draw_set_colour(c_white);
        draw_text(_x, _y - 18, _st.label);
    }
}

// the live player, where its tracker puts it now, and where it's been
for (var _i = 1; _i < array_length(trail); _i++) {
    draw_set_alpha(_i / array_length(trail));
    draw_set_colour(c_orange);
    draw_line_width(cx(trail[_i - 1].x), cy(trail[_i - 1].y), cx(trail[_i].x), cy(trail[_i].y), 2);
}
draw_set_alpha(1);
if (array_length(trail) > 0) {
    var _p = trail[array_length(trail) - 1];
    draw_set_colour(c_orange);
    draw_circle(cx(_p.x), cy(_p.y), 10, true);
    draw_circle(cx(_p.x), cy(_p.y), 5, false);
}

if (flash > 0) {
    draw_set_alpha(min(1, flash / 15));
    draw_set_colour(c_yellow);
    draw_text_transformed(area_w * 0.5, chart_t + 30, flash_text, 1.2, 1.2, 0);
    draw_set_alpha(1);
}
draw_set_halign(fa_left);
draw_set_valign(fa_top);