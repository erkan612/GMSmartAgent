draw_set_colour(make_colour_rgb(40, 40, 60));
draw_circle(x, y, DEMO5_SIGHT, true);
if (is_struct(goal) || instance_exists(goal)) {
    draw_set_colour(c_orange);
    draw_line(x, y, goal.x, goal.y);
}
draw_set_colour(c_orange);
draw_circle(x, y, 9, false);
draw_set_colour(c_white);