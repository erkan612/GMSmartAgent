randomize();
influence = 1;
global.demo5_model = gmsa_learn_linear_create({ half_life : 60, confidence_k : 10 });
global.demo5_player_profile = demo5_player_profile_build();
global.demo5_companion_profile = demo5_companion_profile_build(global.demo5_model, influence);

player    = instance_create_depth(room_width * 0.3, room_height / 2, 0, o_demo5_player);
companion = instance_create_depth(room_width * 0.7, room_height / 2, 0, o_demo5_companion);

loot_target = 30;
spawn = function() {
    instance_create_depth(random_range(30, room_width - 30), random_range(90, room_height - 30), 0, o_demo5_loot, {
        kind : (random(1) < 0.25) ? demo5_loot.GEM : demo5_loot.COIN,
    });
};
repeat (loot_target) spawn();