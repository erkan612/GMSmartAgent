var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;
var _controls = "Left click the key: take it or put it back\n"
    + "Left click the door: lock or unlock it\n"
    + "Right click: drop a coin, or take one\n"
    + "L: give or take the lockpick\n"
    + "R: plan again from scratch\n"
    + "Space: a new heist";

draw_set_color(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// each section starts below the one before it
var _y = 16;
draw_set_color(c_white);
draw_text(_x, _y, "Demo 9: the goblin heist");
_y += 24;
var _intro = "The goblin's plan, as gmsa_plan_explain sees it. Change the room and watch it repair.";
draw_set_color(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 16;

var _plan = gmsa_plan_explain(planner);
draw_set_color(c_white);
draw_text_ext(_x, _y, _plan, -1, _width);
_y += string_height_ext(_plan, -1, _width) + 24;

draw_text(_x, _y, "What happened");
_y += 22;
draw_set_color(c_silver);
for (var _i = 0; _i < array_length(events); _i++) {
    draw_text_ext(_x, _y, events[_i], -1, _width);
    _y += string_height_ext(events[_i], -1, _width);
}

// controls at the bottom, pushed down if the panel is full
draw_set_color(c_gray);
draw_text_ext(_x, max(_y + 24, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);