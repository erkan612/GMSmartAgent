var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _y = 16;
var _title = "Demo 20: the ladder";
draw_set_colour(c_white);
draw_text(_x, _y, _title);
var _state = paused ? "PAUSED, Space or N: one match" : (fast ? "FAST x4" : (slow ? "SLOW x1/4" : ""));
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width(_title) + 16, _y, _state);
}
_y += 24;
var _intro = "Eight bots with hidden skills play matches of every shape: 1 v 1, 2 v 2, 4 v 4, free for alls, three teams of two. GMSmartAgent's rating (Weng-Lin, green) and Elo (blue) learn from the same results. Weng-Lin knows how unsure it is about each bot, the bar around its dot, so it moves fast while unsure and settles as it learns. At match " + string(join_at) + " a newcomer joins, stronger than everyone.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 10;

if (show_true) {
    var _note = "White lines: the hidden skills. Weng-Lin's numbers spread wider than the skills while it's still unsure, Elo's sit narrower. Neither number is the skill itself: what counts is the order, and the chances they predict.";
    draw_set_colour(c_orange);
    draw_text_ext(_x, _y, _note, -1, _width);
    _y += string_height_ext(_note, -1, _width) + 10;
}

draw_set_colour(c_white);
var _last = (last_text == "") ? "No matches yet." : ("Match " + string(matches) + ", " + last_text);
draw_text_ext(_x, _y, _last, -1, _width);
_y += string_height_ext(_last, -1, _width) + 4;
if (last_odds != "") {
    draw_set_colour(c_gray);
    draw_text_ext(_x, _y, last_odds, -1, _width);
    _y += string_height_ext(last_odds, -1, _width) + 10;
}

var _newcomer;
if (joined_at < 0) _newcomer = "The newcomer joins at match " + string(join_at) + ", or now with J.";
else {
    var _w = (top_wl < 0) ? "not yet" : ("after " + string(top_wl) + " matches");
    var _e = (top_elo < 0) ? "not yet" : ("after " + string(top_elo) + " matches");
    _newcomer = "rowan joined " + string(matches - joined_at) + " matches ago. Ranked top by Weng-Lin " + _w + ", by Elo " + _e + ".";
}
var _stats = "Chance off by, last " + string(array_length(off_wl)) + " two-sided matches: Weng-Lin " + string_format(avg(off_wl), 1, 3) + ", Elo " + string_format(avg(off_elo), 1, 3)
    + "\nPairs of bots in the true order: Weng-Lin " + pairs_right(false) + ", Elo " + pairs_right(true)
    + "\n" + _newcomer;
draw_set_colour(c_white);
draw_text_ext(_x, _y, _stats, -1, _width);
_y += string_height_ext(_stats, -1, _width) + 10;

if (fair_text != "") {
    draw_set_colour(c_lime);
    draw_text_ext(_x, _y, fair_text, -1, _width);
    _y += string_height_ext(fair_text, -1, _width) + 10;
}

if (selected != "") {
    var _b = bot_of(selected);
    var _info = gmsa_rating_explain(pool, selected) + "\nElo " + string(round(_b.elo)) + (show_true ? ", hidden skill " + string(_b.skill) : "");
    draw_set_colour(c_yellow);
    draw_text_ext(_x, _y, _info, -1, _width);
    _y += string_height_ext(_info, -1, _width) + 10;
}

var _controls = "A: matches on their own, on or off\n"
    + "Space or N: one match while paused or with A off\n"
    + "B: fair teams from 8 bots, played at once\n"
    + "J: the newcomer joins now\n"
    + "H: show the hidden skills\n"
    + "Click a bot: its explanation\n"
    + "F: fast x4, D: slow x1/4, P: pause or resume\n"
    + "R: start over";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);