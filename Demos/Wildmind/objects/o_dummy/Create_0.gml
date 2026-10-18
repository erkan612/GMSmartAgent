event_inherited();
team = 2;
radius = 16;
hp_max = 300;
hp = hp_max;
regen_wait = 0;
last_damage = 0;
damage_show = 0; // seconds the last damage number stays up

on_hurt = function(_damage) {
    regen_wait = 2;
    last_damage = _damage;
    damage_show = 0.6;
};

on_death = function() { // a dummy can't die, it fills up again
    dead = false;
    hp = hp_max;
};