draw_set_colour(merge_colour(c_red, c_lime, hp / 100));
draw_circle(x, y, 8, false);
draw_set_colour(c_white);
draw_set_halign(fa_center);
draw_text(x, y - 22, gmsa_kit_agent_doing(agent));
draw_set_halign(fa_left);