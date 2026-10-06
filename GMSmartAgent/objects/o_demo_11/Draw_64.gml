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
draw_text(_x, _y, "Demo 11: secret entrances");
if (paused) {
    draw_set_colour(c_orange);
    draw_text(_x + string_width("Demo 11: secret entrances") + 16, _y, "PAUSED, Space steps one frame");
}
_y += 24;
var _intro = "Every vault has secret rules about which entrance works, by day and by night. The grey crew follows the designer's plan. The coloured crew learns which entrances fail where, and which is best.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 12;

draw_set_colour(night ? make_color_rgb(150, 160, 230) : c_yellow);
draw_text(_x, _y, night ? "Night" : "Day");
if (shuffled_flash > 0) {
    draw_set_colour(c_orange);
    draw_text(_x + 80, _y, "new secret rules!");
}
_y += 28;

// the race: loot and failed raids in the last minute
for (var _t = 0; _t < 2; _t++) {
    var _team = teams[_t];
    draw_set_colour(_team.colour);
    draw_text(_x, _y, _team.name + ": " + string(per_minute(_team.loots)) + " loot, " + string(per_minute(_team.fails)) + " failed raids a minute");
    _y += 22;
}
_y += 12;

// the selected goblin: what it plans, and for a learner, what it learned about entrances at its vault right now
var _team = teams[selected.team];
draw_set_colour(_team.colour);
draw_text(_x, _y, _team.name + ", goblin " + string(selected.index + 1) + ", vault " + string(selected.vault + 1));
_y += 22;
if (selected.team == 1) {
    var _line = "learned chance:";
    for (var _e = 0; _e < 3; _e++) {
        _line += "  " + entrance_names[_e] + " " + string(round(gmsa_plan_learn_step_chance(reliability, selected.planner, entrance_steps[_e]) * 100)) + "%";
    }
    draw_set_colour(c_silver);
    draw_text(_x, _y, _line);
    _y += 22;
}
_y += gmsa_debug_draw_tree(gmsa_plan_lines(selected.planner), _x, _y) + 16;

var _controls = "Left click a goblin: show its plan\n"
    + "S: new secret rules, H: reveal them\n"
    + "N: day or night\n"
    + "P: pause or resume, Space: one frame while paused\n"
    + "R: start over, forgetting everything";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);