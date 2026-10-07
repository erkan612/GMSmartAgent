randomize(); // the demo's own randomness, GMSmartAgent never touches it

area_w = room_width * 0.6;
sword = { price : 60 };
shelf = [];  // the potions on offer, new prices every visit

// the shopper stands for the player: every item is a target with its price
var _p = gmsa_profile_create("d16 shopper");
gmsa_profile_add_input(_p, gmsa_input_pull("price", function(_agent, _t) { return _t.price; }, 0, 100, true));
gmsa_profile_set_features(_p, ["price"]);
gmsa_profile_add_action(_p, "sword", { targets : function(_agent) { return [_agent.ctrl.sword]; } });
gmsa_profile_add_action(_p, "potion", { targets : function(_agent) { return _agent.ctrl.shelf; } });
gmsa_profile_build(_p);
shopper = gmsa_agent_create(_p);
shopper.ctrl = id;

// two learners, the same choices
ngram = gmsa_learn_ngram_create();
tdnn = gmsa_learn_tdnn_create({ remember : ["price"] });   // remembers what each past item cost
scheduler = gmsa_scheduler_create(2000);                   // 2 ms a frame for the TDNN's replays
gmsa_learn_schedule(tdnn, scheduler);

paused = false;
fast = false;
slow = false;
slow_count = 0;
auto = true;
habits = 0;
timer = 0;
ng_p = array_create(5, 0);
td_p = array_create(5, 0);
habit_text = [
    "A sword, then the cheapest potion, then the priciest, again.",
    "After a sword the priciest potion. After an expensive potion (over 50) the cheapest, after a cheap one a sword.",
];

restock = function() {
    shelf = [];
    repeat (4) array_push(shelf, { price : irandom_range(10, 95) });
};

cheapest = function() {
    var _b = 0;
    for (var _i = 1; _i < array_length(shelf); _i++) if (shelf[_i].price < shelf[_b].price) _b = _i;
    return _b;
};

priciest = function() {
    var _b = 0;
    for (var _i = 1; _i < array_length(shelf); _i++) if (shelf[_i].price > shelf[_b].price) _b = _i;
    return _b;
};

// items: 0 the sword, 1 to 4 the potions on the shelf
item_of = function(_option) {
    if (_option.target == sword) return 0;
    for (var _i = 0; _i < array_length(shelf); _i++) if (_option.target == shelf[_i]) return _i + 1;
    return 0;
};

item_name = function(_item) {
    return (_item == 0) ? "the sword" : "the " + string(shelf[_item - 1].price) + " potion";
};

// the auto-shopper's habits, one buy in ten is anything
auto_pick = function() {
    if (random(1) < 0.1) return irandom(4);
    var _n = array_length(bought);
    var _last = (_n > 0) ? bought[_n - 1] : undefined;
    if (habits == 0) {
        if (_last == undefined) return 0;
        if (_last.kind == "sword") return 1 + cheapest();
        if (_n >= 2 && bought[_n - 2].kind == "sword") return 1 + priciest();
        return 0;
    }
    if (_last == undefined) return 0;
    if (_last.kind == "sword") return 1 + priciest();
    if (_last.price > 50) return 1 + cheapest();
    return 0;
};

// what each learner expects, per item on the shelf
predict_next = function() {
    var _e = gmsa_agent_evaluate(shopper);
    var _n = array_length(_e.options);
    var _a = gmsa_learn_predict(ngram, _e);
    for (var _i = 0; _i < _n; _i++) ng_p[item_of(_e.options[_i])] = _a.p[_i];
    ng_best = item_of(_e.options[_a.best]);
    ng_sure = _a.sure;
    var _la = gmsa_learn_explain(ngram, _e, _a.best);
    ng_why = _la[0];
    var _b = gmsa_learn_predict(tdnn, _e);
    for (var _i = 0; _i < _n; _i++) td_p[item_of(_e.options[_i])] = _b.p[_i];
    td_best = item_of(_e.options[_b.best]);
    td_sure = _b.sure;
    var _lb = gmsa_learn_explain(tdnn, _e, _b.best);
    td_why = _lb[0];
};

buy = function(_item) {
    // did each learner point at this exact item
    array_push(ng_recent, ng_best == _item);
    array_push(td_recent, td_best == _item);
    if (array_length(ng_recent) > 30) array_delete(ng_recent, 0, 1);
    if (array_length(td_recent) > 30) array_delete(td_recent, 0, 1);

    // the choice, recorded once, learned by both
    var _options = [{ action : "sword", target : sword }];
    for (var _i = 0; _i < array_length(shelf); _i++) array_push(_options, { action : "potion", target : shelf[_i] });
    var _d = gmsa_observe(shopper, _options, _item);
    gmsa_learn_observe(ngram, _d);
    gmsa_learn_observe(tdnn, _d);

    array_push(bought, { kind : (_item == 0) ? "sword" : "potion", price : (_item == 0) ? sword.price : shelf[_item - 1].price });
    if (array_length(bought) > 6) array_delete(bought, 0, 1);
    total += 1;
    flash_text = "bought " + item_name(_item);
    flash = 40;
    restock();
    predict_next();
};

tick = function() {
    gmsa_scheduler_step(scheduler); // the TDNN's replays, inside 2 ms
    if (flash > 0) flash -= 1;
    if (!auto) return;
    timer += 1;
    if (timer >= 40) {
        timer = 0;
        buy(auto_pick());
    }
};

// where each item stands on the shelf
item_box = function(_item) {
    var _x = (_item == 0) ? area_w * 0.14 : area_w * (0.34 + (_item - 1) * 0.17);
    var _y = room_height * 0.42;
    return { l : _x - 36, t : _y - 50, r : _x + 36, b : _y + 50, x : _x, y : _y };
};

reset = function() {
    gmsa_learn_reset(ngram);
    gmsa_learn_reset(tdnn);
    bought = [];
    ng_recent = [];
    td_recent = [];
    total = 0;
    flash = 0;
    flash_text = "";
    restock();
    predict_next();
};
reset();