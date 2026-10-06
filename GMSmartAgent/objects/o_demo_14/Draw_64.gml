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
draw_text(_x, _y, "Demo 14: the bank job");
var _state = paused ? "PAUSED, Space steps one frame" : (fast ? "FAST x4" : "");
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width("Demo 14: the bank job") + 16, _y, _state);
}
_y += 24;
var _intro = "The job is a recipe the designer wrote. Getting inside and getting away are goals: the robber works out how from what the town offers right now. Change the town and only those parts change.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 12;

var _town = "Guard at the " + (town.guard_at_cafe ? "cafe" : "front door")
    + ", ladder " + (town.ladder ? "on site" : "gone")
    + ", code " + (town.code ? "in the office" : "gone")
    + ", car " + (town.car ? "parked" : "towed")
    + ", sewer " + (town.sewer ? "open" : "sealed")
    + ", market " + (town.crowd ? "crowded" : "empty");
draw_set_colour(c_orange);
draw_text_ext(_x, _y, _town, -1, _width);
_y += string_height_ext(_town, -1, _width) + 8;

var _log = "Jobs: ";
if (array_length(jobs) == 0) _log += "none yet";
for (var _i = 0; _i < array_length(jobs); _i++) {
    var _j = jobs[_i];
    _log += ((_i > 0) ? "; " : "") + _j.entry + ", " + _j.crack + ", " + _j.away + " (" + string_format(_j.time, 0, 0) + " s)";
}
draw_set_colour(c_white);
draw_text_ext(_x, _y, _log, -1, _width);
_y += string_height_ext(_log, -1, _width) + 16;

_y += gmsa_debug_draw_tree(gmsa_plan_lines(robber.planner), _x, _y) + 16;

var _controls = "Left click the cafe or front door: move the guard\n"
    + "Left click the building site, office, car, manhole or market: change it\n"
    + "F: fast forward x4\n"
    + "P: pause or resume, Space: one frame while paused\n"
    + "R: start over";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);