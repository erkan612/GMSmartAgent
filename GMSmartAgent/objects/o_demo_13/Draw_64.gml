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
draw_text(_x, _y, "Demo 13: the escape room");
var _state = paused ? "PAUSED, Space steps one frame" : (fast ? "FAST x4" : "");
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width("Demo 13: the escape room") + 16, _y, _state);
}
_y += 24;
var _intro = "Nobody wrote a recipe here. The agent knows only what each action needs, does and costs, and works out the quickest way out. A hidden flaw makes one action fail, and it learns which.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 12;

draw_set_colour(c_orange);
draw_text(_x, _y, "Hidden flaw (the agent can't see it): " + flaw_names[flaw]);
_y += 22;

// how it's going: escapes, failures, what it learned about the risky actions
var _line = "Escapes: ";
if (array_length(escapes) == 0) _line += "none yet";
for (var _i = 0; _i < array_length(escapes); _i++) {
    _line += ((_i > 0) ? ", " : "") + escapes[_i].route + " " + string_format(escapes[_i].time, 0, 1) + " s";
}
draw_set_colour(c_white);
draw_text_ext(_x, _y, _line, -1, _width);
_y += string_height_ext(_line, -1, _width) + 4;
var _risky = ["smash_window", "open_vent", "open_box_code"];
var _learned = "Failed actions: " + string(failures) + ". Learned chances:";
for (var _i = 0; _i < 3; _i++) {
    _learned += " " + _risky[_i] + " " + string(round(gmsa_plan_learn_step_chance(reliability, agent.planner, _risky[_i]) * 100)) + "%";
}
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _learned, -1, _width);
_y += string_height_ext(_learned, -1, _width) + 16;

_y += gmsa_debug_draw_tree(gmsa_plan_lines(agent.planner), _x, _y) + 16;

var _controls = "Left click the bed, box, cabinet, drawer or chair: take its item away, or put it back\n"
    + "H: change the hidden flaw\n"
    + "F: fast forward x4\n"
    + "P: pause or resume, Space: one frame while paused\n"
    + "R: start over, forgetting what it learned";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);