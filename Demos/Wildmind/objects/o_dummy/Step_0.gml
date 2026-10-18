if (demo_paused()) exit;
var _dt = demo_dt();
fighter_tick(id, _dt);
regen_wait -= _dt;
if (regen_wait <= 0) hp = hp_max;
damage_show -= _dt;