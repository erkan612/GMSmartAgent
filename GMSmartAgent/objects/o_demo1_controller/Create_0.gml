randomize();
instance_create_depth(room_width / 2, room_height / 2, 0, o_demo1_agent);
for (var _i = 0; _i < 10; _i++) {
    instance_create_depth(random_range(40, room_width - 40), random_range(80, room_height - 40), 0, o_demo1_item, {
        kind : irandom(3),
    });
}