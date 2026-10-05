draw_set_halign(fa_left);
draw_set_valign(fa_top);
var _y = 10;

draw_set_colour(c_white);
draw_text(10, _y, "Demo 6: what you like. Click items by a rule of your own, three models learn which kinds you pick.");
_y += 20;
draw_text(10, _y, "Rules to try: only red. Big blue and small red. Small ones, nearest first. R resets.");
_y += 20;
draw_text(10, _y, "Rings: each model's favorite. 1 2 3 pick whose opinion lights the items, brighter means more likely.");
_y += 20;
draw_set_colour(c_gray);
draw_text(10, _y, "They learn taste, not order: alternating between two kinds looks like liking both.");
_y += 30;

for (var _m = 0; _m < array_length(models); _m++) {
    var _e = models[_m];
    var _n = array_length(_e.ranks);
    var _rank = "-";
    if (_n > 0) {
        var _sum = 0;
        for (var _i = 0; _i < _n; _i++) _sum += _e.ranks[_i];
        _rank = string(round(100 * _sum / _n)) + "%";
    }
    draw_set_colour(_e.colour);
    draw_text(10, _y, ((view == _m) ? "> " : "  ") + string(_m + 1) + " " + _e.name
        + "   your picks ranked " + _rank + " (last " + string(_n) + ")"
        + "   confidence " + string(round(100 * _e.confidence)) + "%");
    _y += 18;
    draw_set_colour(c_ltgray);
    draw_text(28, _y, _e.line);
    _y += 26;
}

draw_set_colour(c_gray);
draw_text(10, _y, "Ranked: 100% means your pick was the model's favorite, about 50% is a random guess.");
_y += 20;
draw_set_colour(c_white);
draw_text(10, _y, "Picks: " + string(picks) + (training
    ? "   LambdaMART training... " + string(train_frames) + " frames"
    : "   LambdaMART retrains every 10 picks"));
_y += 20;
draw_set_colour(c_gray);
draw_text(10, _y, "Count isn't here: it learns from the situation only, and every item here shares the same situation.");
draw_set_colour(c_white);