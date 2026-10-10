draw_set_colour(c_yellow);
draw_circle(x, y, 4, false);
draw_set_colour(c_white);
if (instance_exists(claimed)) draw_circle(x, y, 9, true);