if (demo_art_pending()) {
    demo_art_bake();
    if (room == rm_boot) room_goto(rm_duel); // nothing is drawn before its art exists
}