draw_set_colour(demo1_item_colour(kind));
draw_circle(x, y, 8, false);
draw_set_colour(c_white);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);
draw_text(x, y - 18, demo1_item_name(kind));
draw_set_halign(fa_left);
draw_set_valign(fa_top);