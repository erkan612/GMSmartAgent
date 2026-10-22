if (demo_paused()) exit;
var _dt = demo_dt();
x += lengthdir_x(fly * _dt, dir);
y += lengthdir_y(fly * _dt, dir);
life -= _dt;
if (demo_swing_hit_circle(swing, x, y, 6) > 0 || life <= 0) instance_destroy();
else if (!demo_arena_fits(global.arena, x, y, 2)) instance_destroy(); // pillars and the wall stop it