var _px = global.demo4_player_x;
var _py = global.demo4_player_y;

draw_set_colour(c_dkgray);
draw_circle(_px, _py, 400, true);
draw_set_colour(c_yellow);
draw_circle(_px, _py, 250, true);
draw_set_halign(fa_center);
draw_text(_px, _py - 250 - 18, "near tier");
draw_set_colour(c_dkgray);
draw_text(_px, _py - 400 - 18, "bats notice the player inside here");
draw_set_halign(fa_left);

draw_set_colour(c_white);
draw_circle(_px, _py, 7, false);