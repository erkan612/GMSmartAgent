var _model = global.demo5_model;
var _gems = 0;
for (var _i = 0; _i < array_length(companion.recent); _i++) if (companion.recent[_i] == demo5_loot.GEM) _gems++;

var _lines = [
    "WASD move, click loot inside your circle to take it. Keep picking gems over coins.",
    "Q/E influence " + string_format(influence, 1, 2) + "    R forget what was learned",
    "",
    "your picks recorded: " + string(player.taken) + "    model confidence " + string_format(gmsa_learn_confidence(_model), 1, 2),
    "companion's last " + string(array_length(companion.recent)) + " pickups: " + string(_gems) + " gems",
];
draw_set_colour(c_white);
for (var _i = 0; _i < array_length(_lines); _i++) draw_text(10, 10 + _i * 18, _lines[_i]);

// the companion's current decision, with designer notes where the model changed a score
var _d = companion.agent.decision;
var _y = 10 + array_length(_lines) * 18 + 10;
_y += gmsa_debug_draw(_d, 10, _y, 6, demo5_target_name);

// and the model's own reason for the chosen option
if (_d.chosen >= 0 && _d.options[_d.chosen].action.name == "take") {
    draw_set_colour(c_ltgray);
    draw_text(10, _y + 6, "model: " + gmsa_learn_explain(_model, _d, _d.chosen)[0]);
    draw_set_colour(c_white);
}