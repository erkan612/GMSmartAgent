// floor and walls
draw_set_colour(make_color_rgb(18, 18, 22));
draw_rectangle(0, 0, area_w, room_height, false);
draw_set_colour(make_color_rgb(44, 40, 48));
draw_rectangle(wall.l, wall.t, wall.r, wall.b, false);
draw_set_colour(c_gray);
draw_rectangle(wall.l, wall.t, wall.r, wall.b, true);
draw_set_halign(fa_center);
draw_set_valign(fa_middle);

var _label = function(_p, _text, _dy) {
    draw_set_colour(c_silver);
    draw_text(_p.x, _p.y + _dy, _text);
};

// window, door, vent
var _win = places[6];
draw_set_colour(cell.glass_broken ? make_color_rgb(40, 60, 80) : make_color_rgb(140, 190, 230));
draw_rectangle(_win.x - 40, wall.t - 6, _win.x + 40, wall.t + 6, false);
_label(_win, cell.glass_broken ? "window, smashed" : "window", 20);
var _door = places[7];
draw_set_colour(make_color_rgb(150, 100, 60));
draw_rectangle(wall.r - 6, _door.y - 34, wall.r + 6, _door.y + 34, false);
_label(_door, "door", -50);
var _vent = places[8];
draw_set_colour(cell.vent_open ? c_black : c_dkgray);
draw_rectangle(wall.l - 6, _vent.y - 18, wall.l + 6, _vent.y + 18, false);
_label(_vent, cell.vent_open ? "vent, open" : "vent", -36);

// the furniture and what's in it, gray when you took the item away
var _bed = places[1];
draw_set_colour(make_color_rgb(90, 90, 140));
draw_rectangle(_bed.x - 40, _bed.y - 24, _bed.x + 40, _bed.y + 24, false);
_label(_bed, cell.code_exists ? "bed, code under it" : "bed", 40);
var _box = places[2];
draw_set_colour(cell.box_open ? make_color_rgb(120, 90, 40) : make_color_rgb(170, 130, 50));
draw_rectangle(_box.x - 20, _box.y - 14, _box.x + 20, _box.y + 14, false);
_label(_box, "box" + (cell.key_in_box ? ", key inside" : "") + (cell.box_open ? ", open" : ""), 30);
var _cab = places[3];
draw_set_colour(make_color_rgb(100, 80, 60));
draw_rectangle(_cab.x - 22, _cab.y - 34, _cab.x + 22, _cab.y + 34, false);
_label(_cab, cell.crowbar_exists ? "cabinet, crowbar" : "cabinet", 50);
var _drawer = places[4];
draw_set_colour(make_color_rgb(110, 90, 70));
draw_rectangle(_drawer.x - 26, _drawer.y - 14, _drawer.x + 26, _drawer.y + 14, false);
_label(_drawer, cell.screwdriver_exists ? "drawer, screwdriver" : "drawer", 30);
if (cell.chair_exists) {
    var _chair = cell.chair_at_window ? places[6] : places[5];
    draw_set_colour(make_color_rgb(160, 120, 80));
    draw_rectangle(_chair.x - 12, _chair.y - 12, _chair.x + 12, _chair.y + 12, false);
    if (!cell.chair_at_window) _label(_chair, "chair", 26);
}

// the agent, what it carries, and where it's heading
var _a = agent;
if (!_a.out) {
    if (_a.doing != undefined && _a.leg < array_length(_a.path)) {
        draw_set_alpha(0.4);
        draw_set_colour(c_white);
        draw_line(_a.x, _a.y, _a.path[_a.leg].x, _a.path[_a.leg].y);
        draw_set_alpha(1);
    }
    draw_set_colour(make_color_rgb(230, 200, 150));
    draw_circle(_a.x, _a.y, 10, false);
    var _items = (_a.has_code ? "code " : "") + (_a.has_key ? "key " : "") + (_a.has_crowbar ? "crowbar " : "") + (_a.has_screwdriver ? "screwdriver" : "");
    if (_items != "") _label(_a, _items, -22);
}