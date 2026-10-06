var _gw = display_get_gui_width();
var _gh = display_get_gui_height();
var _x = _gw * 0.6 + 20;
var _width = _gw * 0.4 - 40;
var _budget = budgets[budget_index];
var _stats = sched.stats;

draw_set_colour(make_color_rgb(22, 22, 26));
draw_rectangle(_gw * 0.6, 0, _gw, _gh, false);
draw_set_halign(fa_left);
draw_set_valign(fa_top);

// each section starts below the one before it
var _y = 16;
draw_set_colour(c_white);
draw_text(_x, _y, "Demo 10: the goblin crew");
if (paused) {
    draw_set_colour(c_orange);
    draw_text(_x + string_width("Demo 10: the goblin crew") + 16, _y, "PAUSED, N steps one frame");
}
_y += 24;
var _intro = "Twelve goblins plan heists on one scheduler budget. Lower it and plans arrive over several frames, while the time per frame stays the same.";
draw_set_colour(c_silver);
draw_text_ext(_x, _y, _intro, -1, _width);
_y += string_height_ext(_intro, -1, _width) + 16;

// the budget and what this frame used of it
draw_set_colour(c_white);
draw_text(_x, _y, "Budget " + string(_budget) + " us, used " + string(round(_stats.time)) + " us, " + string(_stats.works) + " work turns");
_y += 22;
draw_set_colour(c_dkgray);
draw_rectangle(_x, _y, _x + _width, _y + 8, false);
draw_set_colour((_stats.time > _budget) ? c_orange : c_lime);
draw_rectangle(_x, _y, _x + _width * min(1, _stats.time / max(1, _budget)), _y + 8, false);
_y += 20;

var _planning = 0;
for (var _i = 0; _i < array_length(goblins); _i++) {
    if (gmsa_plan_get_status(goblins[_i].planner) == gmsa_plan_status.PLANNING) _planning++;
}
draw_set_colour(c_silver);
draw_text(_x, _y, "Waiting for a plan: " + string(_planning) + " of 12 goblins");
_y += 20;
draw_text(_x, _y, "Plans asked for: " + string(made) + ", repaired: " + string(repairs));
_y += 20;
for (var _i = 0; _i < 3; _i++) {
    draw_set_colour(vault_colours[_i]);
    draw_text(_x + _i * 110, _y, "vault " + string(_i + 1) + ": " + string(vaults[_i].loots));
}
_y += 32;

// the selected goblin's plan, drawn by Debug from Plan's lines
draw_set_colour(vault_colours[selected.vault]);
draw_text(_x, _y, "Goblin " + string(selected.index + 1) + ", " + string(selected.gold) + " gold" + (selected.has_pick ? ", has a lockpick" : ""));
_y += 22;
_y += gmsa_debug_draw_tree(gmsa_plan_lines(selected.planner), _x, _y) + 16;

// controls at the bottom, pushed down if the panel is full
var _controls = "Up / Down: scheduler budget\n"
    + "Left click a goblin: show its plan\n"
    + "Left click a key: take it or put it back\n"
    + "Left click a door: lock or unlock it\n"
    + "Right click: drop a coin, or take one\n"
    + "Space: a new room, all twelve plan at once\n"
    + "P: pause or resume, N: one frame while paused\n"
    + "R: the same room every time";
draw_set_colour(c_gray);
draw_text_ext(_x, max(_y, _gh - string_height_ext(_controls, -1, _width) - 16), _controls, -1, _width);