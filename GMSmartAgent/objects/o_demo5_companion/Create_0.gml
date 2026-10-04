move_speed  = 2.2;
goal        = noone;
think_timer = 0;
recent      = []; // kinds of the last 10 pickups

wander_pick = function() {
    wander_point = { x : random_range(40, room_width - 40), y : random_range(40, room_height - 40), value : 0 };
};
wander_pick();

agent = gmsa_agent_create(global.demo5_companion_profile, id);