draw_set_halign(fa_left);
draw_set_valign(fa_top);
var _y = 10;

draw_set_colour(c_white);
draw_text(10, _y, "Demo 8: the foraging race. Each patch pays a secret amount, different by day and by night.");
_y += 20;
draw_text(10, _y, "Nobody can hand-tune for rules nobody knows: three teams learn them from what their trips bring back.");
_y += 20;
draw_text(10, _y, "S shuffles the secret rules. H reveals them. N skips to " + (is_day ? "night" : "day")
    + ". Mouse places the wolf, right click removes it. R resets.");
_y += 20;
draw_set_colour(is_day ? c_yellow : c_aqua);
draw_text(10, _y, "It's " + (is_day ? "day." : "night.") + ((shuffled_flash > 0) ? "   Rules shuffled!" : ""));
_y += 28;

for (var _t = 0; _t < 4; _t++) {
    var _team = teams[_t];
    draw_set_colour(_team.colour);
    draw_text(10, _y, _team.name + ":  " + string_format(_team.rate, 1, 1) + " food per minute,  caught " + string(_team.caught)
        + ((_team.training) ? "   retraining..." : ""));
    _y += 20;
}
draw_set_colour(c_gray);
draw_text(10, _y, "The designer's guess avoids the wolf, the one thing a designer can know here. It can't know the payoffs.");
_y += 18;
draw_text(10, _y, "Each learning team shares one model: every trip by any forager teaches the whole team.");

// the race: food per minute over the last two minutes
var _gx = 20, _gy = room_height - 30, _gw = 420, _gh = 170;
draw_set_colour(c_dkgray);
draw_rectangle(_gx, _gy - _gh, _gx + _gw, _gy, true);
var _top = 1, _bottom = 0;
for (var _t = 0; _t < 4; _t++) {
    var _h = teams[_t].history;
    for (var _i = 0; _i < array_length(_h); _i++) {
        _top = max(_top, _h[_i]);
        _bottom = min(_bottom, _h[_i]);
    }
}
var _span = _top - _bottom;
for (var _t = 0; _t < 4; _t++) {
    var _h = teams[_t].history;
    draw_set_colour(teams[_t].colour);
    for (var _i = 1; _i < array_length(_h); _i++) {
        draw_line_width(_gx + (_i - 1) / 119 * _gw, _gy - (_h[_i - 1] - _bottom) / _span * _gh,
                        _gx + _i / 119 * _gw,       _gy - (_h[_i] - _bottom) / _span * _gh, 2);
    }
}
draw_set_colour(c_gray);
draw_text(_gx, _gy - _gh - 18, "food per minute, last 2 minutes");
draw_set_colour(c_white);