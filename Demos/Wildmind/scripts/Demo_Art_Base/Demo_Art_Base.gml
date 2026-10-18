function demo_art_add_base() { // the player, the slash, the arrow and the test dummy
    demo_art_add("player", 48, 48, 24, 24, function(_frame) {
        var _body = gmvex_path_create();
        gmvex_path_add_circle(_body, 24, 24, 14);
        gmvex_fill_draw_gradient(_body, gmvex_gradient.RADIAL, 20, 20, 16, 0, [[0, make_color_rgb(120, 230, 220), 1], [1, make_color_rgb(30, 120, 140), 1]]);
        gmvex_stroke_draw(_body, 2, make_color_rgb(15, 40, 50), 1);
        var _nose = gmvex_path_create();   // points the way the player aims
        gmvex_path_add_polygon(_nose, [[34, 18], [44, 24], [34, 30]]);
        gmvex_fill_draw(_nose, c_white, 1);
        gmvex_path_destroy(_body);
        gmvex_path_destroy(_nose);
    });

    demo_art_add("slash", 64, 64, 32, 32, function(_frame) {
        var _outer = gmvex_path_create();
        gmvex_path_add_circle(_outer, 32, 32, 28);
        var _inner = gmvex_path_create();
        gmvex_path_add_circle(_inner, 22, 32, 26);
        var _arc = gmvex_path_boolean(_outer, _inner, gmvex_bool.A_NOT_C);
        gmvex_fill_draw(_arc, c_white, 0.9);
        gmvex_path_destroy(_outer);
        gmvex_path_destroy(_inner);
        gmvex_path_destroy(_arc);
    });

    demo_art_add("arrow", 28, 8, 14, 4, function(_frame) {
        var _shaft = gmvex_path_create();
        gmvex_path_add_rect(_shaft, 2, 3, 19, 2);
        gmvex_fill_draw(_shaft, make_color_rgb(200, 170, 120), 1);
        var _head = gmvex_path_create();
        gmvex_path_add_polygon(_head, [[20, 0], [28, 4], [20, 8]]);
        gmvex_fill_draw(_head, make_color_rgb(220, 220, 230), 1);
        gmvex_path_destroy(_shaft);
        gmvex_path_destroy(_head);
    });

    demo_art_add("dummy", 48, 48, 24, 24, function(_frame) {
        var _body = gmvex_path_create();
        gmvex_path_add_circle(_body, 24, 24, 16);
        gmvex_fill_draw(_body, make_color_rgb(190, 150, 90), 1);
        gmvex_stroke_draw(_body, 2, make_color_rgb(90, 60, 30), 1);
        var _cross = gmvex_path_create();
        gmvex_path_add_line(_cross, 16, 16, 32, 32);
        gmvex_path_add_line(_cross, 32, 16, 16, 32);
        gmvex_stroke_draw(_cross, 3, make_color_rgb(90, 60, 30), 1);
        gmvex_path_destroy(_body);
        gmvex_path_destroy(_cross);
    });
}