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

function varn_taunt_follow(_v) { // he starts a follow-up he planned while recovering
    var _set = ["Arrows again?"];
    if (_v.doing == "counter") _set = ["I knew you'd come.", "Greedy."];
    if (_v.doing == "ward") _set = ["Not this time.", "I know that combo."];
    if (_v.doing == "chase") _set = (_v.follow.answer == "drink") ? ["No time to drink."] : ["Running again?", "You always back off."];
    varn_say(_v, _set[irandom(array_length(_set) - 1)]);
    _v.taunt_wait = 8;
}

function varn_taunt_miss(_v) { // his guess was wrong: the player changed
    static _lines = ["Hm.", "Clever.", "You learn too."];
    if (_v.taunt_wait > 0) return;
    varn_say(_v, _lines[irandom(array_length(_lines) - 1)]);
    _v.taunt_wait = 8;
}

function duel_habits_draw(_x, _y) { // what Varn knows about the player, for the player to see. long lines wrap
    static _kinds = ["cleave", "sweep", "slam", "charge"];
    static _names = ["Cleave", "Sweep", "Slam", "Charge"];
    static _on = make_color_rgb(255, 120, 40);   // a bar he acts on
    static _off = make_color_rgb(110, 110, 110);
    var _w = 380;
    var _tw = _w - 20;
    var _rows = [{ text : "What Varn knows about you", col : make_color_rgb(255, 170, 90), bar : -1 }];
    if (!global.duel_learning) {
        array_push(_rows, { text : "Nothing. He isn't learning.", col : c_ltgray, bar : -1 });
    } else {
        var _reads = o_duel.reads;
        var _s = duel_situation(o_duel.varn, o_duel.player);
        array_push(_rows, { text : "He sees: " + duel_situation_words(_s), col : c_ltgray, bar : -1 });
        var _t = duel_timing_read();
        var _when = "no idea yet";
        if (_t.sure > 0.05) _when = "you dodge " + string_replace(_t.timing, "_", " ") + ", " + string_format(_reads.timing_avg, 1, 2) + " s before the hit";
        array_push(_rows, { text : "Timing: " + _when + "  (" + string(_reads.timing_seen) + " seen)", col : c_white, bar : _t.sure, bar_col : (_t.sure >= DUEL_READ_SURE && _t.timing != "on_time") ? _on : _off });
        var _ctx = _reads.after_ctx;
        var _then = "no idea yet";
        var _f = { answer : "wait", sure : 0 };
        if (_ctx != undefined) {
            _f = duel_after_read(_ctx.attack, _ctx.landed, _ctx.close);
            var _words = { punish : "you punish", shoot : "you shoot", drink : "you drink", back_off : "you back off", wait : "you wait" };
            if (_f.sure > 0.05) _then = "after my " + _ctx.attack + (_ctx.landed ? " hits" : " misses") + ", " + _words[$ _f.answer];
        }
        array_push(_rows, { text : "Then: " + _then + "  (" + string(_reads.after_seen) + " seen)", col : c_white, bar : _f.sure, bar_col : (_f.sure >= DUEL_READ_SURE && _f.answer != "wait") ? _on : _off });
        for (var _i = 0; _i < 4; _i++) { // his guess for each attack, if it started right now
            var _r = duel_read(_kinds[_i], _s);
            var _what = "no idea yet";
            if (_r.sure > 0.05) _what = (_r.dodge == "stay") ? "you stand still" : "you dodge " + duel_dodge_words(_r.dodge);
            array_push(_rows, { text : _names[_i] + ": " + _what + "  (" + string(o_duel.seen[$ _kinds[_i]]) + " seen)", col : c_white, bar : _r.sure, bar_col : (_r.sure >= DUEL_READ_SURE) ? _on : _off });
        }
    }

    var _h = 8; // measured first, so the background fits the wrapped lines
    for (var _i = 0; _i < array_length(_rows); _i++) _h += string_height_ext(_rows[_i].text, -1, _tw) + ((_rows[_i].bar >= 0) ? 12 : 6);
    draw_set_alpha(0.6);
    draw_set_colour(c_black);
    draw_rectangle(_x, _y, _x + _w, _y + _h, false);
    draw_set_alpha(1);

    var _cy = _y + 8;
    for (var _i = 0; _i < array_length(_rows); _i++) {
        var _row = _rows[_i];
        draw_set_colour(_row.col);
        draw_text_ext(_x + 10, _cy, _row.text, -1, _tw);
        _cy += string_height_ext(_row.text, -1, _tw);
        if (_row.bar >= 0) {
            __hud_bar(_x + 10, _cy + 2, _tw, 5, _row.bar, _row.bar_col);
            _cy += 12;
        } else {
            _cy += 6;
        }
    }
}