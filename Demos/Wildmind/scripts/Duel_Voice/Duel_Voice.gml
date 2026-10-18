function varn_say(_v, _text) {
    _v.speech = _text;
    _v.speech_time = 2.2;
}

function varn_taunt_read(_v) { // now and then, when he acts on a guess
    static _lines = {
        dodge_left  : ["Left again.", "You favor my left."],
        dodge_right : ["Right again.", "Always to my right."],
        dodge_back  : ["Running won't save you.", "Always away."],
        dodge_in    : ["Through me again?", "Bold. And predictable."],
    };
    if (_v.first_read) {
        _v.first_read = false;
        varn_say(_v, "I see you now.");
        _v.taunt_wait = 6;
        return;
    }
    if (!_v.using_read || _v.taunt_wait > 0 || _v.read.sure < 0.45) return;
    var _set = _lines[$ _v.read.dodge];
    if (_set == undefined) return;
    varn_say(_v, _set[irandom(array_length(_set) - 1)]);
    _v.taunt_wait = 8;
}

function varn_taunt_timing(_v) { // a held or quick swing caught the player
    static _hold = ["Too soon.", "Patience."];
    static _quick = ["Too slow.", "You wait too long."];
    var _set = (_v.tactic == "hold") ? _hold : _quick;
    varn_say(_v, _set[irandom(array_length(_set) - 1)]);
    _v.taunt_wait = 8;
}

function varn_taunt_miss(_v) { // his guess was wrong: the player changed
    static _lines = ["Hm.", "Clever.", "You learn too."];
    if (_v.taunt_wait > 0) return;
    varn_say(_v, _lines[irandom(array_length(_lines) - 1)]);
    _v.taunt_wait = 8;
}

function duel_habits_draw(_x, _y) { // what Varn knows about the player, for the player to see
    static _kinds = ["cleave", "sweep", "slam", "charge"];
    static _names = ["Cleave", "Sweep", "Slam", "Charge"];
    var _w = 360;
    draw_set_alpha(0.6);
    draw_set_colour(c_black);
    draw_rectangle(_x, _y, _x + _w, _y + 36 + 34 * 5, false);
    draw_set_alpha(1);
    draw_set_colour(make_color_rgb(255, 170, 90));
    draw_text(_x + 10, _y + 8, "What Varn knows about you");
    if (!global.duel_learning) {
        draw_set_colour(c_ltgray);
        draw_text(_x + 10, _y + 40, "Nothing. He isn't learning.");
        return;
    }
    var _reads = o_duel.reads;
    var _t = duel_timing_read();
    var _when = "no idea yet";
    if (_t.sure > 0.05) _when = "you dodge " + string_replace(_t.timing, "_", " ") + ", " + string_format(_reads.timing_avg, 1, 2) + " s before the hit";
    draw_set_colour(c_white);
    draw_text(_x + 10, _y + 36, "Timing: " + _when + "  (" + string(_reads.timing_seen) + " seen)");
    __hud_bar(_x + 10, _y + 56, _w - 20, 5, _t.sure, (_t.sure >= DUEL_READ_SURE && _t.timing != "on_time") ? make_color_rgb(255, 120, 40) : make_color_rgb(110, 110, 110));
    for (var _i = 0; _i < 4; _i++) {
        var _r = duel_read(_kinds[_i]);
        var _ry = _y + 70 + _i * 34;
        var _what = "no idea yet";
        if (_r.sure > 0.05) _what = (_r.dodge == "stay") ? "you stand still" : "you dodge " + duel_dodge_words(_r.dodge);
        draw_set_colour(c_white);
        draw_text(_x + 10, _ry, _names[_i] + ": " + _what + "  (" + string(o_duel.seen[$ _kinds[_i]]) + " seen)");
        __hud_bar(_x + 10, _ry + 20, _w - 20, 5, _r.sure, (_r.sure >= DUEL_READ_SURE) ? make_color_rgb(255, 120, 40) : make_color_rgb(110, 110, 110));
    }
}