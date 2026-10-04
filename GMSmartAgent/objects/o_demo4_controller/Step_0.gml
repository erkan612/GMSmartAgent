gmsa_scheduler_step(global.demo4_ai);

// up and down: 250 more or fewer bats
if (keyboard_check_pressed(vk_up)) demo4_spawn(250);
if (keyboard_check_pressed(vk_down)) {
    var _left = 250;
    with (o_demo4_bat) {
        if (_left <= 0) break;
        _left--;
        instance_destroy();
    }
}

// left and right: AI budget in 0.5 ms steps
if (keyboard_check_pressed(vk_right)) gmsa_scheduler_set_budget(global.demo4_ai, global.demo4_ai.budget + 500);
if (keyboard_check_pressed(vk_left))  gmsa_scheduler_set_budget(global.demo4_ai, max(0, global.demo4_ai.budget - 500));

// T: tiers on and off, R: restart
if (keyboard_check_pressed(ord("T"))) global.demo4_tiers = !global.demo4_tiers;
if (keyboard_check_pressed(ord("R"))) room_restart();

// count the near tier twice a second, not every frame
near_timer--;
if (near_timer <= 0) {
    near_timer = 30;
    near_count = 0;
    with (o_demo4_bat) if (agent.priority > 0) other.near_count++;
}