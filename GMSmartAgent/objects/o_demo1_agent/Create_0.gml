hp          = 100;
hp_max      = 100;
keys        = 0;
chests      = 0;
sight       = 400;
move_speed  = 2;
goal        = noone;
think_timer = 0;

// the caller's own query, GMSA never searches the world itself
find = function(_kind) {
    var _found = [];
    var _x = x, _y = y, _r = sight;
    with (o_demo1_item) {
        if (kind == _kind && point_distance(x, y, _x, _y) <= _r) array_push(_found, id);
    }
    return _found;
};

// a point to explore, rerolled only when reached
wander_pick = function() {
    wander_point = { x : random_range(40, room_width - 40), y : random_range(80, room_height - 40) };
};
wander_pick();

agent = gmsa_agent_create(demo1_profile(), id);