depth = 90; // under the fighters (0), over the room's background layer (100)
arena = demo_arena_create(room_width / 2, room_height / 2, 576);
var _off = 212; // the pillars stand 300 px from the centre, on the diagonals
demo_arena_add_pillar(arena, arena.cx - _off, arena.cy - _off, 44);
demo_arena_add_pillar(arena, arena.cx + _off, arena.cy - _off, 44);
demo_arena_add_pillar(arena, arena.cx - _off, arena.cy + _off, 44);
demo_arena_add_pillar(arena, arena.cx + _off, arena.cy + _off, 44);
global.arena = arena;

nav_grid = demo_arena_nav_grid(arena, 32);
nav_sched = gmnav_scheduler_create(nav_grid, 2000);
nav_overlay = -1;          // the clearance map drawn once, redrawn only when the grid changes
nav_overlay_version = -1;

player = instance_create_depth(arena.cx, arena.cy + 380, 0, o_player);
varn = instance_create_depth(arena.cx, arena.cy - 380, 0, o_varn);
varn.nav = gmnav_agent_create(nav_sched, varn.x, varn.y, 34, 2.5);
varn.nav.need_clear = gmnav_clearance_for_radius(nav_grid, varn.radius);
varn.nav.reach_dist = 40; // past his own radius, so a goal by a pillar still counts as reached
varn.target = player;
reads = duel_reads_create(player); // what Varn learns about the player's dodges, fresh every fight
ai = gmsa_scheduler_create(2000, { clock : demo_now });
varn.agent = gmsa_agent_create(varn_profile(), varn, { interval : 150000 });
gmsa_scheduler_add(ai, varn.agent);

view_enabled = true;
view_visible[0] = true;
view_wport[0] = 1366;
view_hport[0] = 768;
camera = camera_create_view(0, 0, 1366, 768);
view_camera[0] = camera;

hold_varn = false;
global.debug.scene = function() {
    gmui_text("Varn: " + string(round(varn.hp)) + " / " + string(varn.hp_max));
    var _nav = varn.nav;
    var _state = gmnav_agent_failed(_nav) ? "failed" : (gmnav_agent_arrived(_nav) ? "arrived" : "moving");
    gmui_text("path: " + (hold_varn ? "held" : _state));
    hold_varn = gmui_checkbox(hold_varn, "Hold Varn still");
    if (gmui_button("Restart fight")) room_restart();
    global.duel_learning = gmui_checkbox(global.duel_learning, "Varn learns from you");
    var _kinds = ["cleave", "sweep", "slam", "charge"];
    var _s = duel_situation(varn, player);
    gmui_text("sees: " + duel_situation_words(_s));
    for (var _k = 0; _k < array_length(_kinds); _k++) {
        var _r = duel_read(_kinds[_k], _s);
        gmui_text(_kinds[_k] + ": " + ((_r.sure > 0) ? "dodges " + duel_dodge_words(_r.dodge) + " " + string(round(_r.sure * 100)) + "%" : "no idea yet"));
    }
    var _t = duel_timing_read();
    gmui_text("timing: " + ((_t.sure > 0) ? _t.timing + " " + string(round(_t.sure * 100)) + "% (avg " + string_format(reads.timing_avg, 1, 2) + " s)" : "no idea yet"));
    gmui_separator();
    gmui_text("doing: " + ((varn.doing == "") ? "-" : varn.doing));
    var _lines = gmsa_debug_lines(varn.agent.decision, 8);
    for (var _i = 0; _i < array_length(_lines); _i++) gmui_text(_lines[_i]);
};

seen = { cleave : 0, sweep : 0, slam : 0, charge : 0 }; // answers recorded per attack, for the habits panel
show_habits = true;
intro = true;          // the start screen, the world waits behind it
global.demo_menu = true;
demo_pause(true);