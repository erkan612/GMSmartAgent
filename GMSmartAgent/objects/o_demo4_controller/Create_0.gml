global.demo4_ai          = gmsa_scheduler_create(2000); // 2 ms of AI per frame
global.demo4_tiers       = true;
global.demo4_player_x    = room_width / 2;
global.demo4_player_y    = room_height / 2;
global.demo4_near_thinks = 0;
global.demo4_far_thinks  = 0;

player_t   = 0;
fps_avg    = 60;
ai_avg     = 0;
near_rate  = 0;
far_rate   = 0;
near_count = 0;
near_timer = 0;

demo4_spawn(1500);