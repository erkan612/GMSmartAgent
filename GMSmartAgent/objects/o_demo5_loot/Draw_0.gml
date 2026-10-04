if (kind == demo5_loot.GEM) {
    draw_set_colour(c_aqua);
    draw_triangle(x, y - 8, x - 7, y, x + 7, y, false);
    draw_triangle(x, y + 8, x - 7, y, x + 7, y, false);
} else {
    draw_set_colour(c_yellow);
    draw_circle(x, y, 5, false);
}
draw_set_colour(c_white);