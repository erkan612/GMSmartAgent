randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
luck_c = sqrt(2) * 125;  // a fight's luck, the same amount the rating pool assumes
fights_max = 300;
monster_names = ["rat", "imp", "goblin", "wolf", "orc", "troll", "ogre", "wraith", "giant", "demon", "dragon"];
monster_rating = [1000, 1120, 1240, 1360, 1480, 1600, 1720, 1840, 1960, 2080, 2200];
targets = [0.5, 0.6, 0.7, 0.8];
target_i = 1;
kinds = ["the average player", "a fast learner", "a slow learner", "a player who takes a break"];
kind = 0;
rating_colour = make_color_rgb(110, 210, 120);
fixed_colour = make_color_rgb(90, 140, 230);

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = true;

// the player's hidden skill after t fights, for each kind of player
skill_at = function(_kind, _t) {
    switch (_kind) {
        case 0: return 1150 + 600 * min(1, _t / 300);
        case 1: return 1150 + 800 * min(1, _t / 120);
        case 2: return 1150 + 300 * min(1, _t / 300);
        case 3: return 1150 + 600 * min(1, _t / 150) - ((_t >= 200 && _t < 260) ? 350 : 0);
    }
    return 1150;
};

true_chance = function(_skill, _monster) { return 1 / (1 + exp(-(_skill - _monster) / luck_c)); };

// the fixed curve: the monster that gives the average player the target chance, whoever is playing
fixed_pick = function(_t) {
    var _p = targets[target_i];
    var _goal = skill_at(0, _t) - luck_c * ln(_p / (1 - _p));
    var _best = 0;
    for (var _i = 1; _i < array_length(monster_rating); _i++) {
        if (abs(monster_rating[_i] - _goal) < abs(monster_rating[_best] - _goal)) _best = _i;
    }
    return _best;
};

// both lanes fight once: the same player, its own luck in each
fight = function() {
    if (fights >= fights_max) return;
    var _skill = skill_at(kind, fights);
    var _r = gmsa_rating_pick(pool, "player", monster_names, targets[target_i]);
    var _won_r = random(1) < true_chance(_skill, monster_rating[_r]);
    gmsa_rating_match(pool, { teams : [["player"], [monster_names[_r]]], places : _won_r ? [1, 2] : [2, 1] });
    var _f = fixed_pick(fights);
    var _won_f = random(1) < true_chance(_skill, monster_rating[_f]);

    array_push(hist_skill, _skill);
    array_push(hist_r, _r);
    array_push(hist_f, _f);
    array_push(won_r, _won_r);
    array_push(won_f, _won_f);
    fights += 1;
    var _w20r = last20(won_r);
    var _w20f = last20(won_f);
    if (fights >= 20) {
        outside_r += (_w20r < 0.4 || _w20r > 0.8);
        outside_f += (_w20f < 0.4 || _w20f > 0.8);
        scored += 1;
    }
    flash_text = "picked by rating: " + monster_names[_r] + (_won_r ? ", won" : ", lost") + "     fixed curve: " + monster_names[_f] + (_won_f ? ", won" : ", lost");
    flash = 30;
};

// wins in the last 20 fights (or fewer at the start), up to fight _end
last20 = function(_list, _end = undefined) {
    if (_end == undefined) _end = array_length(_list);
    var _from = max(0, _end - 20);
    if (_end <= _from) return 0;
    var _w = 0;
    for (var _i = _from; _i < _end; _i++) _w += _list[_i];
    return _w / (_end - _from);
};

tick = function() {
    if (flash > 0) flash -= 1;
    if (!auto) return;
    timer += 1;
    if (timer >= 10) {
        timer = 0;
        fight();
    }
};

reset = function() {
    // drift 20: this player keeps getting better, so the rating must expect skill to change fast
    pool = gmsa_rating_pool_create({ drift : 20 });
    for (var _i = 0; _i < array_length(monster_names); _i++) gmsa_rating_set(pool, monster_names[_i], { rating : monster_rating[_i], pinned : true });
    fights = 0;
    hist_skill = [];
    hist_r = [];
    hist_f = [];
    won_r = [];
    won_f = [];
    outside_r = 0;
    outside_f = 0;
    scored = 0;
    timer = 0;
    flash = 0;
    flash_text = "";
};
reset();