var _s = global.demo4_ai;
var _count = gmsa_scheduler_count(_s);
var _far_count = _count - near_count;
fps_avg   = lerp(fps_avg, fps_real, 0.05);
ai_avg    = lerp(ai_avg, _s.stats.time, 0.05);
near_rate = lerp(near_rate, global.demo4_near_thinks, 0.05);
far_rate  = lerp(far_rate, global.demo4_far_thinks, 0.05);

var _frame_us = 1000000 / max(1, fps_avg);
var _fastest  = 100000 / (1000000 / game_get_speed(gamespeed_fps));  // the bats' interval in frames
var _every = function(_bats, _rate, _fastest) {
    if (_bats <= 0 || _rate <= 0) return "-";
    return string(round(max(_fastest, _bats / _rate)));
};

// panel
draw_set_alpha(0.75);
draw_set_colour(c_black);
draw_rectangle(0, 0, 500, 300, false);
draw_set_alpha(1);

var _y = 10;
draw_set_colour(c_white);
draw_text(10, _y, "DEMO 4: many agents, one AI budget");                                 _y += 24;
draw_text(10, _y, string(_count) + " bats, each one deciding for itself with GMSmartAgent."); _y += 18;
draw_text(10, _y, "A white flash means that bat just made a decision.");                  _y += 26;

// legend
var _legend = [[c_red, "chasing the player"], [c_aqua, "flying home to rest"], [c_gray, "wandering"]];
for (var _i = 0; _i < 3; _i++) {
    draw_set_colour(_legend[_i][0]);
    draw_rectangle(10, _y + 5, 18, _y + 13, false);
    draw_set_colour(c_white);
    draw_text(26, _y, _legend[_i][1]);
    _y += 18;
}
_y += 10;

// AI time against its budget
var _scale = max(1, _s.budget * 1.5);
var _bar_x = 170, _bar_w = 310;
draw_text(10, _y, "AI time " + string_format(ai_avg / 1000, 1, 2) + " ms");
draw_set_colour(c_dkgray);
draw_rectangle(_bar_x, _y + 3, _bar_x + _bar_w, _y + 15, false);
draw_set_colour(c_lime);
draw_rectangle(_bar_x, _y + 3, _bar_x + _bar_w * min(1, ai_avg / _scale), _y + 15, false);
var _budget_x = _bar_x + _bar_w * (_s.budget / _scale);
draw_set_colour(c_yellow);
draw_line_width(_budget_x, _y, _budget_x, _y + 18, 2);
_y += 20;
draw_set_colour(c_white);
draw_text(10, _y, "budget " + string_format(_s.budget / 1000, 1, 1) + " ms (yellow line), the AI never goes past it"); _y += 18;
draw_text(10, _y, "whole frame " + string_format(_frame_us / 1000, 1, 2) + " ms, the rest is moving and drawing bats"); _y += 26;

// how fresh the decisions are
if (global.demo4_tiers) {
    draw_set_colour(c_yellow);
    draw_text(10, _y, "near bats decide every " + _every(near_count, near_rate, _fastest) + " frames"); _y += 18;
    draw_set_colour(c_white);
    draw_text(10, _y, "far bats decide every " + _every(_far_count, far_rate, _fastest) + " frames"); _y += 18;
} else {
    draw_text(10, _y, "tiers off: every bat decides every " + _every(_count, near_rate + far_rate, _fastest) + " frames"); _y += 36;
}
draw_set_colour(c_gray);
draw_text(10, _y, "fastest possible: every " + string(round(_fastest)) + " frames");

// controls
draw_set_colour(c_white);
draw_text(10, display_get_gui_height() - 24, "Up/Down: 250 more or fewer bats    Left/Right: AI budget    T: tiers on/off    R: restart");