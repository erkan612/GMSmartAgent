if (flash > 0) {
    draw_set_colour(c_white);
    draw_rectangle(x - 2, y - 2, x + 2, y + 2, false);
} else {
    switch (state) {
        case "chase": draw_set_colour(c_red);  break;
        case "roost": draw_set_colour(c_aqua); break;
        default:      draw_set_colour(c_gray); break;
    }
    draw_rectangle(x - 1, y - 1, x + 1, y + 1, false);
}