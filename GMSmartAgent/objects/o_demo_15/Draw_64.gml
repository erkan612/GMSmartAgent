var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _y = 16;
var _title = "Demo 15: the sparring partner";
draw_set_colour(c_white);
draw_text(_x, _y, _title);
var _state = paused ? "PAUSED, Space or N: one move" : (fast ? "FAST x4" : (slow ? "SLOW x1/4" : ""));
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width(_title) + 16, _y, _state);
}
_y += 24;
var _intro = "One n-gram learner watches every move and learns all the habits at once: what follows what, combos, what you do when hurt, near or far. It speaks only when it's sure enough.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 10;

var _who = auto ? ("Auto-player, habits " + ((habits == 0) ? "A" : "B") + ": " + habit_text[habits]) : "You're fighting: keys 1 to 6. Let the learner find your habits.";
draw_set_colour(c_orange);
draw_text_ext(_x, _y, _who, -1, _width);
_y += string_height_ext(_who, -1, _width) + 14;

// what it expects next
draw_set_colour(c_white);
draw_text(_x, _y, "Next move, as the learner sees it (" + (far ? "far" : "near") + ", hp " + string(hp) + ")");
_y += 22;
var _bar = _width - 150;
for (var _i = 0; _i < 6; _i++) {
    draw_set_colour((_i == pred_best) ? c_white : c_gray);
    draw_text(_x, _y, string(_i + 1) + " " + move_names[_i]);
    draw_set_colour(c_dkgray);
    draw_rectangle(_x + 100, _y + 3, _x + 100 + _bar, _y + 15, false);
    draw_set_colour(move_colours[_i]);
    draw_rectangle(_x + 100, _y + 3, _x + 100 + _bar * pred[_i], _y + 15, false);
    draw_set_colour(c_silver);
    draw_text(_x + 108 + _bar, _y, string(round(pred[_i] * 100)) + "%");
    _y += 20;
}
_y += 8;

// sure, against the threshold
var _t = thresholds[threshold_i];
draw_set_colour(c_white);
draw_text(_x, _y, "sure " + string_format(pred_sure, 1, 2) + " (confidence " + string_format(pred_conf, 1, 2) + " x its favourite's chance)");
_y += 22;
draw_set_colour(c_dkgray);
draw_rectangle(_x, _y, _x + _width, _y + 14, false);
draw_set_colour(speaking ? c_yellow : c_gray);
draw_rectangle(_x, _y, _x + _width * pred_sure, _y + 14, false);
draw_set_colour(c_red);
draw_line_width(_x + _width * _t, _y - 4, _x + _width * _t, _y + 18, 2);
_y += 22;
draw_set_colour(c_silver);
draw_text(_x, _y, "speaks at " + string_format(_t, 1, 1) + (speaking ? ": speaking" : ": quiet, not sure enough"));
_y += 22;
draw_set_colour(c_gray);
draw_text_ext(_x, _y, "Leaning on: " + why, -1, _width);
_y += string_height_ext("Leaning on: " + why, -1, _width) + 14;

// how it's doing
var _hits = 0;
for (var _i = 0; _i < array_length(recent); _i++) _hits += recent[_i];
var _stats = "Right about the next move, last " + string(array_length(recent)) + ": "
    + ((array_length(recent) > 0) ? string(round(_hits / array_length(recent) * 100)) + "%" : "-")
    + "\nSpoke " + string(spoke) + " times, right " + string(spoke_right)
    + ((spoke > 0) ? " (" + string(round(spoke_right / spoke * 100)) + "%)" : "")
    + "\nMoves " + string(total) + ", rounds " + string(rounds);
draw_set_colour(c_white);
draw_text_ext(_x, _y, _stats, -1, _width);
_y += string_height_ext(_stats, -1, _width) + 14;

var _controls = "1 to 6: your move. Left and Right: back off, step in\n"
    + "A: auto-player on or off, S: switch its habits\n"
    + "T: threshold 0.4, 0.6, 0.8\n"
    + "F: fast x4, D: slow x1/4, P: pause or resume\n"
    + "Space or N: one move while paused\n"
    + "R: forget everything";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);