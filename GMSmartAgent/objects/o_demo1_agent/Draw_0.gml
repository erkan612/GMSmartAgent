draw_set_colour(c_dkgray);
draw_circle(x, y, sight, true);
if (is_struct(goal) || instance_exists(goal)) {
    draw_set_colour(c_lime);
    draw_line(x, y, goal.x, goal.y);
}
draw_set_colour(c_aqua);
draw_circle(x, y, 10, false);

// hp bar
draw_set_colour(c_black);
draw_rectangle(x - 20, y - 22, x + 20, y - 18, false);
draw_set_colour(c_lime);
draw_rectangle(x - 20, y - 22, x - 20 + 40 * (hp / hp_max), y - 18, false);
draw_set_colour(c_white);