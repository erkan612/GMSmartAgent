var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _y = 16;
var _title = "Demo 17: the scout";
draw_set_colour(c_white);
draw_text(_x, _y, _title);
var _state = paused ? "PAUSED, Space or N: one attack" : (fast ? "FAST x4" : (slow ? "SLOW x1/4" : ""));
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width(_title) + 16, _y, _state);
}
_y += 24;
var _intro = "Eight scout reports, two of them decide the attack. Count learns whole situations: with 8 inputs it can only cut each in two, and still has to see every one of 256 situations. Naive Bayes learns each report on its own, so a few dozen attacks are enough.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 10;

var _who = auto ? ("Auto-attacker, habits " + ((habits == 0) ? "A" : "B") + ": " + habit_text[habits]) : "You're attacking: read the report, click a lane.";
draw_set_colour(c_orange);
draw_text_ext(_x, _y, _who, -1, _width);
_y += string_height_ext(_who, -1, _width) + 14;

// each lane, as each learner sees it
draw_set_colour(c_white);
draw_text(_x, _y, "Next attack:          Count           Naive Bayes");
_y += 22;
var _bar = (_width - 130) / 2 - 10;
for (var _i = 0; _i < array_length(lanes); _i++) {
    draw_set_colour(c_silver);
    draw_text(_x, _y, lanes[_i]);
    var _cols = [_x + 130, _x + 130 + _bar + 20];
    var _ps = [ct_p[_i], by_p[_i]];
    var _best = [ct_best, by_best];
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
draw_text(_x, _y, "sure: Count " + string_format(ct_sure, 1, 2) + ", Naive Bayes " + string_format(by_sure, 1, 2));
_y += 22;
draw_set_colour(c_gray);
var _why = "Count: " + ct_why + "\nNaive Bayes: " + by_why;
draw_text_ext(_x, _y, _why, -1, _width);
_y += string_height_ext(_why, -1, _width) + 14;

// how each is doing
var _rate = function(_list) {
    if (array_length(_list) == 0) return "-";
    var _h = 0;
    for (var _i = 0; _i < array_length(_list); _i++) _h += _list[_i];
    return string(round(_h / array_length(_list) * 100)) + "%";
};
var _stats = "Right about the lane, last " + string(array_length(by_recent)) + ": Count " + _rate(ct_recent) + ", Naive Bayes " + _rate(by_recent)
    + "\nAttacks " + string(total) + ". One in ten goes anywhere, so about 93% is the best possible.";
draw_set_colour(c_white);
draw_text_ext(_x, _y, _stats, -1, _width);
_y += string_height_ext(_stats, -1, _width) + 14;

var _controls = "Left click a lane: attack it\n"
    + "A: auto-attacker on or off, S: switch its habits\n"
    + "F: fast x4, D: slow x1/4, P: pause or resume\n"
    + "Space or N: one attack while paused\n"
    + "R: forget everything";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);