draw_set_colour(c_white);
draw_text(10, 40, "hp " + string(hp) + "   keys " + string(keys) + "   chests " + string(chests) + "   sight " + string(sight));
gmsa_debug_draw(agent.decision, 10, 70, 8, function(_target) {
    if (is_struct(_target)) return "point";
    return instance_exists(_target) ? demo1_item_name(_target.kind) : "gone";
});