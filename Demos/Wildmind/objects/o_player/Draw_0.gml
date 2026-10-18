fighter_draw(demo_art("player"), aim, (state == player_state.ROLL) ? 0.6 : 1);
if (state == player_state.ATTACK) {
    var _hit = player_combo_hit(combo);
    if (state_time >= _hit.windup && state_time < _hit.windup + PLAYER_MELEE_ACTIVE) {
        draw_sprite_ext(demo_art("slash"), 0, x + lengthdir_x(PLAYER_MELEE_REACH, attack_dir), y + lengthdir_y(PLAYER_MELEE_REACH, attack_dir), 1, 1, attack_dir, c_white, 0.85);
    }
}

if (global.debug.hitboxes && state == player_state.ATTACK) {
    var _hit = player_combo_hit(combo);
    if (state_time >= _hit.windup && state_time < _hit.windup + PLAYER_MELEE_ACTIVE) {
        draw_set_colour(c_red);
        draw_circle(x + lengthdir_x(PLAYER_MELEE_REACH, attack_dir), y + lengthdir_y(PLAYER_MELEE_REACH, attack_dir), PLAYER_MELEE_RADIUS, true);
    }
}