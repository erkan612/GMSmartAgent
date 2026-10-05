// loot: gold squares, potion circles, gem diamonds
for (var _i = 0; _i < array_length(items); _i++) {
    var _it = items[_i];
    draw_set_colour(kind_colour[_it.kind]);
    switch (_it.kind) {
        case 0: draw_rectangle(_it.x - 9, _it.y - 9, _it.x + 9, _it.y + 9, false); break;
        case 1: draw_circle(_it.x, _it.y, 10, false); break;
        case 2:
            draw_triangle(_it.x, _it.y - 12, _it.x - 10, _it.y, _it.x + 10, _it.y, false);
            draw_triangle(_it.x - 10, _it.y, _it.x + 10, _it.y, _it.x, _it.y + 12, false);
            break;
    }
}

// you, and where you're heading
draw_set_colour(c_white);
if (me.target != undefined) draw_line(me.x, me.y, me.target.x, me.target.y);
draw_circle(me.x, me.y, 10, false);

// the guard, and where it's heading
draw_set_colour(merge_colour(c_orange, c_black, 0.5));
if (guard.goal != undefined) draw_line(guard.x, guard.y, guard.goal.x, guard.goal.y);
draw_set_colour(c_orange);
draw_circle(guard.x, guard.y, 14, false);
draw_set_colour(c_white);