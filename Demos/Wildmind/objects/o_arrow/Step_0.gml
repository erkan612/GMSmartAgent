if (demo_paused()) exit;
var _dt = demo_dt();
x += lengthdir_x(PLAYER_ARROW_SPEED * _dt, dir);
y += lengthdir_y(PLAYER_ARROW_SPEED * _dt, dir);
life -= _dt;
if (demo_swing_hit_circle(swing, x, y, 5) > 0 || life <= 0) instance_destroy();
else if (x < 0 || y < 0 || x > room_width || y > room_height) instance_destroy();
else if (global.arena != undefined && !demo_arena_fits(global.arena, x, y, 2)) instance_destroy(); // stopped by a pillar or the wall