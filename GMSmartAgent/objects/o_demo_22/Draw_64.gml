var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _y = 16;
var _title = "Demo 22: the crowd";
draw_set_colour(c_white);
draw_text(_x, _y, _title);
var _state = paused ? "PAUSED, Space or N: one minute" : (fast ? "FAST x4" : (slow ? "SLOW x1/4" : ""));
if (_state != "") {
    draw_set_colour(paused ? c_orange : c_lime);
    draw_text(_x + string_width(_title) + 16, _y, _state);
}
_y += 24;

var _watch = "What to watch: first the grey crowd splits into coloured styles nobody told it about. Then the orange player: its shares below, and how sure the match is. Switch its style with 1 to 5 and watch the match follow.";
draw_set_colour(c_yellow);
draw_text_ext(_x, _y, _watch, -1, _width);
_y += string_height_ext(_watch, -1, _width) + 10;

var _intro = string(sessions_count) + " sessions from players of four styles, in proportions nobody gives the fit, four measures each. The chart shows two of them. The fit tries 1 to 6 styles and keeps the number that explains the crowd best (BIC). The demo names the styles it recognizes: in a game you name them yourself.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 10;

draw_set_colour(c_white);
if (fitting) {
    var _trying = min(job.k, job.kmax);
    var _so_far = (job.top_k > 0) ? ", best so far " + string(job.top_k) : "";
    draw_text_ext(_x, _y, "Fitting, a few milliseconds a frame: trying " + string(_trying) + " styles" + _so_far + "...", -1, _width);
    _y += 22;
} else {
    draw_text_ext(_x, _y, found_text, -1, _width);
    _y += string_height_ext(found_text, -1, _width) + 4;
    var _list = "";
    for (var _s = 0; _s < array_length(styles); _s++) _list += ((_s > 0) ? ", " : "") + styles[_s].label + " " + string(round(styles[_s].share * 100)) + "%";
    draw_set_colour(c_gray);
    draw_text_ext(_x, _y, _list, -1, _width);
    _y += string_height_ext(_list, -1, _width) + 12;
}

draw_set_colour(c_orange);
var _live = "The live player plays like " + ((live_kind < 4) ? "a " : "") + live_names[live_kind] + ", " + string(ticks) + " minutes so far.";
draw_text_ext(_x, _y, _live, -1, _width);
_y += string_height_ext(_live, -1, _width) + 6;

if (live_match != undefined) {
    var _bar = _width - 130;
    for (var _s = 0; _s < array_length(live_match.p); _s++) {
        draw_set_colour(style_colours[_s mod array_length(style_colours)]);
        draw_text(_x, _y, live_match.names[_s]);
        draw_set_colour(c_dkgray);
        draw_rectangle(_x + 120, _y + 3, _x + 120 + _bar, _y + 15, false);
        draw_set_colour(style_colours[_s mod array_length(style_colours)]);
        draw_rectangle(_x + 120, _y + 3, _x + 120 + _bar * live_match.p[_s], _y + 15, false);
        _y += 20;
    }
    _y += 4;
    var _how = "How well it fits its best style " + string_format(live_match.fit, 1, 2) + ", how sure " + string_format(live_match.confidence, 1, 2);
    draw_set_colour(c_white);
    draw_text_ext(_x, _y, _how, -1, _width);
    _y += string_height_ext(_how, -1, _width) + 4;
    draw_set_colour(c_gray);
    draw_text_ext(_x, _y, live_why, -1, _width);
    _y += string_height_ext(live_why, -1, _width) + 10;
}

var _controls = "1 to 4: the live player plays like a rusher, sniper, support or explorer\n"
    + "5: a mix nobody in the crowd plays\n"
    + "A: the live player changes style on its own, on or off\n"
    + "G: a new crowd, fitted again (names are kept)\n"
    + "F: fast x4, D: slow x1/4, P: pause or resume\n"
    + "Space or N: one minute while paused\n"
    + "R: start over";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);