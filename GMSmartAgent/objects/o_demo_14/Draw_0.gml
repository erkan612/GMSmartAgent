// the street, the bank and its rooms
draw_set_colour(make_color_rgb(34, 36, 42));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_colour(make_color_rgb(58, 56, 66));
draw_rectangle(bank.l, bank.t, bank.r, bank.b, false);
draw_set_colour(c_gray);
draw_rectangle(bank.l, bank.t, bank.r, bank.b, true);
draw_line(area_w * 0.5, bank.t, area_w * 0.5, area_w * 0 + room_height * 0.4);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

var _label = function(_i, _text, _dy) {
    draw_set_colour(c_silver);
    draw_text(places[_i].x, places[_i].y + _dy, _text);
};
var _mark = function(_i, _colour, _size) {
    draw_set_colour(_colour);
    draw_rectangle(places[_i].x - _size, places[_i].y - _size, places[_i].x + _size, places[_i].y + _size, false);
};

// doors and the hatch
_mark(5, make_color_rgb(150, 100, 60), 10);
_mark(6, make_color_rgb(150, 100, 60), 10);
_mark(7, c_dkgray, 10);
_label(5, "front door", 24);
_label(6, "back door", -24);
_label(7, "roof hatch", -24);
_label(9, town.code ? "office, code" : "office", 22);
_mark(10, make_color_rgb(150, 150, 160), 14);
_label(10, "vault", 26);

// the town, gray when you changed it
_mark(0, c_dkgray, 10);
_label(0, "hideout", -22);
_mark(2, make_color_rgb(120, 90, 70), 16);
_label(2, "cafe", 30);
_mark(3, make_color_rgb(200, 160, 60), 14);
_label(3, town.ladder ? "building site, ladder" : "building site", 28);
_mark(4, make_color_rgb(80, 90, 110), 16);
_label(4, robber.has_drill ? "van" : "van, drill", 30);
_mark(11, town.car ? make_color_rgb(180, 60, 60) : c_dkgray, 16);
_label(11, town.car ? "car" : "car, towed", 30);
draw_set_colour(town.sewer ? c_gray : c_dkgray);
draw_circle(places[12].x, places[12].y, 14, !town.sewer);
_label(12, town.sewer ? "manhole" : "manhole, sealed", 28);
_mark(13, town.crowd ? make_color_rgb(90, 140, 90) : c_dkgray, 16);
_label(13, town.crowd ? "market, crowded" : "market, empty", 30);

// the guard, at the cafe or the front door
var _g = places[town.guard_at_cafe ? 2 : 5];
draw_set_colour(make_color_rgb(90, 130, 220));
draw_circle(_g.x + 22, _g.y, 9, false);

// the robber
var _r = robber;
if (!_r.away) {
    if (_r.doing != undefined && _r.leg < array_length(_r.path)) {
        draw_set_alpha(0.4);
        draw_set_colour(c_white);
        draw_line(_r.x, _r.y, _r.path[_r.leg].x, _r.path[_r.leg].y);
        draw_set_alpha(1);
    }
    draw_set_colour(make_color_rgb(230, 200, 150));
    draw_circle(_r.x, _r.y, 9, false);
    var _items = (_r.has_keycard ? "keycard " : "") + (_r.has_ladder ? "ladder " : "") + (_r.has_drill ? "drill " : "") + (_r.has_loot ? "loot" : "");
    if (_items != "") {
        draw_set_colour(c_yellow);
        draw_text(_r.x, _r.y - 20, _items);
    }
}