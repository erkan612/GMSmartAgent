draw_set_halign(fa_left);
draw_set_valign(fa_top);
var _y = 10;

draw_set_colour(c_white);
draw_text(10, _y, "Demo 7: the guard who reads you. Click loot to walk there. Your health drains, potions heal.");
_y += 20;
draw_text(10, _y, "The guard (orange) learns which kind you go for and tries to get there first. R resets what it learned.");
_y += 28;

// health
draw_text(10, _y, "Health");
draw_set_colour(c_dkgray);
draw_rectangle(80, _y + 3, 280, _y + 13, false);
draw_set_colour(make_colour_rgb(230, 60, 90));
draw_rectangle(80, _y + 3, 80 + 2 * me.hp, _y + 13, false);
_y += 24;

// the predictor, read exactly as the guard reads it
draw_set_colour(c_white);
draw_text(10, _y, "What the guard reads you'll go for next" + (trained ? ":" : " (untrained, every kind reads 1/3):"));
_y += 20;
for (var _k = 0; _k < 3; _k++) {
    var _v = reads[_k](guard_agent, undefined);
    draw_set_colour(c_white);
    draw_text(24, _y, kinds[_k]);
    draw_set_colour(c_dkgray);
    draw_rectangle(100, _y + 3, 300, _y + 13, false);
    draw_set_colour(kind_colour[_k]);
    draw_rectangle(100, _y + 3, 100 + 200 * _v, _y + 13, false);
    draw_set_colour(c_white);
    draw_text(310, _y, string_format(_v, 1, 2));
    _y += 18;
}
_y += 8;

var _n = array_length(outcomes);
var _blocked = 0;
for (var _i = 0; _i < _n; _i++) _blocked += outcomes[_i];
draw_text(10, _y, "Guard: " + guard.doing + "    Blocked " + string(_blocked) + " of your last " + string(_n) + " picks");
_y += 20;
draw_set_colour(c_gray);
draw_text(10, _y, "Picks: " + string(picks) + (training
    ? "   learning... " + string(train_frames) + " frames"
    : "   it retrains every 10 picks"));
draw_set_colour(c_white);