var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _y = 16;
var _title = "Demo 19: the map";
draw_set_colour(c_white);
draw_text(_x, _y, _title);
var _state = paused ? "PAUSED, Space or N: one stop" : (fast ? "FAST x4" : (slow ? "SLOW x1/4" : ""));
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width(_title) + 16, _y, _state);
}
_y += 24;
var _intro = "Where the wanderer stands decides what it does. Both learners get only x and y: neither alone says anything, only together they're a place. Naive Bayes multiplies what it saw at this x by what it saw at this y, so it can't draw a river. Nearest neighbor remembers the spots themselves, up to 1024 of them: its map gets as detailed as its memory. Watch the two maps under the land.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 10;

var _who = auto ? "Auto-wanderer: by the river it fishes, in a forest it hunts, elsewhere it rests. One stop in twenty does anything." : "You're wandering: click the map to walk there, then 1 fish, 2 hunt, 3 rest.";
draw_set_colour(c_orange);
draw_text_ext(_x, _y, _who, -1, _width);
_y += string_height_ext(_who, -1, _width) + 14;

// the next stop, as each learner sees it
draw_set_colour(c_white);
draw_text(_x, _y, "Next stop:            Naive Bayes     Nearest neighbor");
_y += 22;
var _bar = (_width - 130) / 2 - 10;
for (var _i = 0; _i < array_length(acts); _i++) {
    draw_set_colour(act_colour[_i]);
    draw_text(_x, _y, acts[_i]);
    var _cols = [_x + 130, _x + 130 + _bar + 20];
    var _ps = [bn_p[_i], nn_p[_i]];
    var _best = [bn_best, nn_best];
    var _colours = [make_color_rgb(90, 140, 230), make_color_rgb(110, 210, 120)];
    for (var _k = 0; _k < 2; _k++) {
        draw_set_colour(c_dkgray);
        draw_rectangle(_cols[_k], _y + 3, _cols[_k] + _bar, _y + 15, false);
        draw_set_colour(_colours[_k]);
        draw_rectangle(_cols[_k], _y + 3, _cols[_k] + _bar * _ps[_k], _y + 15, false);
        if (_best[_k] == _i) {
            draw_set_colour(c_white);
            draw_rectangle(_cols[_k] - 1, _y + 2, _cols[_k] + _bar + 1, _y + 16, true);
        }
    }
    _y += 20;
}
_y += 6;
draw_set_colour(c_white);
draw_text(_x, _y, "sure: Naive Bayes " + string_format(bn_sure, 1, 2) + ", nearest neighbor " + string_format(nn_sure, 1, 2));
_y += 22;
draw_set_colour(c_gray);
var _why = "Naive Bayes: " + bn_why + "\nNearest neighbor: " + nn_why;
draw_text_ext(_x, _y, _why, -1, _width);
_y += string_height_ext(_why, -1, _width) + 14;

// how each is doing: at the stops, and over the whole map against the habit
var _rate = function(_list) {
    if (array_length(_list) == 0) return "-";
    var _h = 0;
    for (var _i = 0; _i < array_length(_list); _i++) _h += _list[_i];
    return string(round(_h / array_length(_list) * 100)) + "%";
};
var _cells = 0;
var _rb = 0;
var _rn = 0;
for (var _c = 0; _c < heat_count; _c++) {
    if (heat_bn[_c] < 0) continue;
    var _z = zone((_c mod heat_w + 0.5) / heat_w, (_c div heat_w + 0.5) / heat_h);
    _cells += 1;
    _rb += (heat_bn[_c] == _z);
    _rn += (heat_nn[_c] == _z);
}
var _map = (_cells == 0) ? "-" : ("Naive Bayes " + string(round(_rb / _cells * 100)) + "%, nearest neighbor " + string(round(_rn / _cells * 100)) + "%");
var _stats = "Right overall, last " + string(array_length(nn_recent)) + ": Naive Bayes " + _rate(bn_recent) + ", nearest neighbor " + _rate(nn_recent)
    + "\nRight by the river or in a forest, last " + string(array_length(nn_place)) + ": Naive Bayes " + _rate(bn_place) + ", nearest neighbor " + _rate(nn_place)
    + "\nMap right, every spot against the habit: " + _map
    + "\nStops " + string(total) + ". Open fields are about 70% of the map, so a learner saying \"rest\" everywhere is right 70% of the time.";
draw_set_colour(c_white);
draw_text_ext(_x, _y, _stats, -1, _width);
_y += string_height_ext(_stats, -1, _width) + 14;

var _controls = "A: auto-wanderer on or off\n"
    + "Wandering yourself: left click the map to walk there, then 1 fish, 2 hunt, 3 rest\n"
    + "F: fast x4, D: slow x1/4, P: pause or resume\n"
    + "Space or N: one stop while paused\n"
    + "R: forget everything";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);