energy     = random_range(30, 100);
home_x     = random_range(20, room_width - 20);
home_y     = random_range(20, room_height - 20);
wander_x   = random_range(20, room_width - 20);
wander_y   = random_range(20, room_height - 20);
state      = "wander";
flash      = 0;
tier_timer = irandom(30); // staggered, so bats don't all re-tier on the same frame

agent = gmsa_agent_create(demo4_profile(), id, {
    interval  : 100000, // at most 10 decisions a second
    on_decide : demo4_on_decide,
});
gmsa_scheduler_add(global.demo4_ai, agent);