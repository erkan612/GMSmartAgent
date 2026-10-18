gmvex_init();
gmui_init();
gmui_set_font(fnt_ui);
gmnav_init();
demo_clock_init();
demo_art_init();

global.arena = undefined;
demo_debug_init();
global.duel_learning = true; // Varn learns from the player, the default
global.demo_menu = false;    // true while a scene's menu is up: no pause, no pause label
demo_art_add_base();
duel_art_add();