function duel_art_add() { // placeholder art for the arena and Varn, until the real art is drawn
    demo_art_add("floor", 1152, 1152, 576, 576, function(_frame) {
        var _floor = gmvex_path_create();
        gmvex_path_add_circle(_floor, 576, 576, 572);
        gmvex_fill_draw_gradient(_floor, gmvex_gradient.RADIAL, 576, 576, 572, 0, [[0, make_color_rgb(150, 128, 98), 1], [1, make_color_rgb(88, 74, 58), 1]]);
        gmvex_stroke_draw(_floor, 8, make_color_rgb(40, 32, 26), 1);
        var _ring = gmvex_path_create();
        gmvex_path_add_circle(_ring, 576, 576, 420);
        gmvex_stroke_draw(_ring, 3, make_color_rgb(110, 94, 72), 1);
        gmvex_path_destroy(_floor);
        gmvex_path_destroy(_ring);
    });

    demo_art_add("pillar", 96, 96, 48, 48, function(_frame) {
        var _p = gmvex_path_create();
        gmvex_path_add_circle(_p, 48, 48, 44);
        gmvex_fill_draw_gradient(_p, gmvex_gradient.RADIAL, 40, 40, 48, 0, [[0, make_color_rgb(170, 160, 145), 1], [1, make_color_rgb(80, 74, 66), 1]]);
        gmvex_stroke_draw(_p, 3, make_color_rgb(40, 36, 32), 1);
        gmvex_path_destroy(_p);
    });

    demo_art_add("varn", 128, 128, 64, 64, function(_frame) {
        var _shield = gmvex_path_create();
        gmvex_path_add_rounded_rect(_shield, 62, 20, 32, 22, 4);
        gmvex_fill_draw(_shield, make_color_rgb(60, 66, 76), 1);
        gmvex_stroke_draw(_shield, 2, make_color_rgb(200, 160, 70), 1);
        var _sword = gmvex_path_create();
        gmvex_path_add_rect(_sword, 70, 86, 52, 7);
        gmvex_fill_draw(_sword, make_color_rgb(200, 208, 216), 1);
        var _body = gmvex_path_create();
        gmvex_path_add_circle(_body, 58, 64, 34);
        gmvex_fill_draw_gradient(_body, gmvex_gradient.RADIAL, 64, 64, 36, 0, [[0, make_color_rgb(110, 120, 134), 1], [1, make_color_rgb(36, 42, 50), 1]]);
        gmvex_stroke_draw(_body, 2, make_color_rgb(18, 22, 27), 1);
        var _visor = gmvex_path_create();
        gmvex_path_add_rounded_rect(_visor, 78, 57, 4, 14, 2);
        gmvex_fill_draw(_visor, make_color_rgb(255, 120, 40), 1);
        gmvex_path_destroy(_shield);
        gmvex_path_destroy(_sword);
        gmvex_path_destroy(_body);
        gmvex_path_destroy(_visor);
    });
}