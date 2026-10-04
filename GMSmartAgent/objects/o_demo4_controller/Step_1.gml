// the player walks a shape of eight
player_t += 0.008;
global.demo4_player_x = room_width / 2 + room_width * 0.35 * sin(player_t);
global.demo4_player_y = room_height / 2 + room_height * 0.3 * sin(player_t * 2);

// decision counters for this frame, filled by demo4_on_decide
global.demo4_near_thinks = 0;
global.demo4_far_thinks  = 0;