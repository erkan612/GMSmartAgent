draw_set_colour(c_red);
draw_rectangle(x - 4, y - 6, x + 4, y + 6, false);
draw_set_colour(c_white);
if (instance_exists(claimed)) draw_circle(x, y, 9, true);