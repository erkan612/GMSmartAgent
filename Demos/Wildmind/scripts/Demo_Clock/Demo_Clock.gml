function demo_clock_init() {
    global.demo_clock = { paused : false, paused_at : 0, lost : 0 };
}

function demo_now() { // microseconds of game time, for every scheduler, learner and cooldown
    var _c = global.demo_clock;
    return (_c.paused ? _c.paused_at : get_timer()) - _c.lost;
}

function demo_dt() { // seconds this frame, 0 while paused
    return global.demo_clock.paused ? 0 : delta_time / 1000000;
}

function demo_paused() {
    return global.demo_clock.paused;
}

function demo_pause(_on) {
    var _c = global.demo_clock;
    if (_on == _c.paused) return;
    if (_on) _c.paused_at = get_timer();
    else _c.lost += get_timer() - _c.paused_at;
    _c.paused = _on;
}