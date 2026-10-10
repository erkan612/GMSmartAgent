draw_text(10, 10, "goblins " + string(instance_number(o_kit_goblin)) + ", update " + string_format(time_avg, 0, 1) + " us each (thinks and walking included)");
draw_text(10, 26, "left click coin, right click potion, down hurts all, G adds 20 goblins");
if (instance_exists(first)) {
    gmsa_debug_draw(first.agent.decision, 10, 50, 8, function(_target) {
        if (_target == undefined) return "-";
        if (is_struct(_target)) return "point";
        if (!instance_exists(_target)) return "gone";
        return object_get_name(_target.object_index);
    });
}