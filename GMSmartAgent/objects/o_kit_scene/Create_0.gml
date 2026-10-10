time_avg = 0;
for (var _i = 0; _i < 8; _i++) instance_create_depth(random(room_width), random(room_height), 0, o_kit_coin);
for (var _i = 0; _i < 3; _i++) instance_create_depth(random(room_width), random(room_height), 0, o_kit_potion);
first = instance_create_depth(room_width / 2, room_height / 2, -1, o_kit_goblin);