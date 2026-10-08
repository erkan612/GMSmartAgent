var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;
var _pct = function(_v) { return string(round(_v * 100)) + "%"; };

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _y = 16;
var _title = "Demo 21: the right fight";
draw_set_colour(c_white);
draw_text(_x, _y, _title);
var _state = paused ? "PAUSED, Space or N: one fight" : (fast ? "FAST x4" : (slow ? "SLOW x1/4" : ""));
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width(_title) + 16, _y, _state);
}
_y += 24;

var _watch = "What to watch: the lower chart. Green should stay near the dashed line for every kind of player. Blue only fits the average player it was tuned for. Press S to change the player.";
draw_set_colour(c_yellow);
draw_text_ext(_x, _y, _watch, -1, _width);
_y += string_height_ext(_watch, -1, _width) + 10;

var _intro = "The same player fights in two lanes. Green: GMSmartAgent rates the player from its wins and losses and picks the monster that gives it a " + _pct(targets[target_i]) + " chance. Blue: a fixed difficulty curve, the monster a designer would pick for the average player at this point. The player is " + kinds[kind] + ".";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 10;

var _stats = "Fight " + string(fights) + " of " + string(fights_max)
    + "\nWins in the last 20: picked by rating " + _pct(last20(won_r)) + ", fixed curve " + _pct(last20(won_f))
    + "\nToo easy or too hard (last 20 outside 40 to 80%): picked by rating " + ((scored == 0) ? "-" : _pct(outside_r / scored)) + " of the time, fixed curve " + ((scored == 0) ? "-" : _pct(outside_f / scored));
draw_set_colour(c_white);
draw_text_ext(_x, _y, _stats, -1, _width);
_y += string_height_ext(_stats, -1, _width) + 10;

var _why = gmsa_rating_explain(pool, "player");
draw_set_colour(c_gray);
draw_text_ext(_x, _y, _why, -1, _width);
_y += string_height_ext(_why, -1, _width) + 10;

var _note = "The pool is made with drift 20: how fast it expects a skill to change. The default, 2.5, suits a ladder of settled players. A player who keeps getting better needs more, or its rating lags behind and the fights grow too easy.";
draw_set_colour(c_gray);
draw_text_ext(_x, _y, _note, -1, _width);
_y += string_height_ext(_note, -1, _width) + 10;

if (fights >= fights_max) {
    draw_set_colour(c_orange);
    draw_text_ext(_x, _y, "The run is over. S: another player, T: another target, R: again.", -1, _width);
}

var _controls = "S: the next kind of player (starts over)\n"
    + "T: the target chance, 50 to 80% (starts over)\n"
    + "A: fights on their own, on or off\n"
    + "Space or N: one fight while paused or with A off\n"
    + "F: fast x4, D: slow x1/4, P: pause or resume\n"
    + "R: start over";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);