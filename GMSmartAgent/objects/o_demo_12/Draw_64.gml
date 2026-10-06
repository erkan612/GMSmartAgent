var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _y = 16;
draw_set_colour(c_white);
draw_text(_x, _y, "Demo 12: the night watch");
if (paused) {
    draw_set_colour(c_orange);
    draw_text(_x + string_width("Demo 12: the night watch") + 16, _y, "PAUSED, Space steps one frame");
}
if (fast && !paused) {
    draw_set_colour(c_lime);
    draw_text(_x + string_width("Demo 12: the night watch") + 16, _y, "FAST x4");
}
_y += 24;
var _intro = "You are the guard. At every bell you take a post, and goblins at that vault are caught. Both crews see your lantern. The coloured crew also learns where you go next, and raids where you won't be.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 12;

// the guard's habit and the time to the next bell
draw_set_colour(make_color_rgb(255, 200, 120));
var _habit = "Guard: " + habit_names[guard.habit];
if (guard.habit == 0) _habit += ", next post vault " + string(guard.queued + 1);
draw_text(_x, _y, _habit);
_y += 22;
draw_set_colour(c_dkgray);
draw_rectangle(_x, _y, _x + 200, _y + 6, false);
draw_set_colour(c_yellow);
draw_rectangle(_x, _y, _x + 200 * watch_time / watch_length, _y + 6, false);
_y += 18;

// the prediction, read the same way the crew reads it
draw_set_colour(c_silver);
draw_text(_x, _y, "Where the guard goes at the next bell, as the coloured crew reads it:");
_y += 22;
for (var _k = 0; _k < 3; _k++) {
    var _v = next_read[_k](undefined, undefined);
    var _avoid = (_v >= 0.4);
    draw_set_colour(c_dkgray);
    draw_rectangle(_x + 70, _y + 4, _x + 230, _y + 14, false);
    draw_set_colour(_avoid ? c_orange : make_color_rgb(110, 200, 110));
    draw_rectangle(_x + 70, _y + 4, _x + 70 + 160 * _v, _y + 14, false);
    draw_set_colour(c_silver);
    draw_text(_x, _y, "vault " + string(_k + 1));
    draw_text(_x + 240, _y, string(round(_v * 100)) + "%" + (_avoid ? "  avoid" : ""));
    _y += 20;
}
draw_set_colour(c_gray);
draw_text(_x, _y, "confidence " + string(round(gmsa_learn_confidence(habits) * 100)) + "%");
_y += 30;

// the race: how many of each crew's last 20 raids ended in the cells
for (var _t = 0; _t < 2; _t++) {
    var _team = teams[_t];
    var _n = array_length(_team.results);
    var _c = caught_count(_t);
    draw_set_colour(_team.colour);
    draw_text(_x, _y, _team.name + ": caught in " + string(_c) + " of the last " + string(_n) + " raids");
    _y += 20;
    draw_set_colour(c_dkgray);
    draw_rectangle(_x, _y, _x + 200, _y + 8, false);
    if (_n > 0) {
        draw_set_colour(c_red);
        draw_rectangle(_x, _y, _x + 200 * _c / _n, _y + 8, false);
    }
    _y += 18;
}
_y += 12;

// the selected goblin's plan
var _team = teams[selected.team];
draw_set_colour(_team.colour);
draw_text(_x, _y, _team.name + ", goblin " + string(selected.index + 1));
_y += 22;
_y += gmsa_debug_draw_tree(gmsa_plan_lines(selected.planner), _x, _y) + 16;

var _controls = "A: change the guard's habit\n"
    + "1, 2, 3: guard yourself, picks your next post\n"
    + "F: fast forward x4\n"
    + "Left click a goblin: show its plan\n"
    + "P: pause or resume, Space: one frame while paused\n"
    + "R: start over, forgetting everything";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);