function demo_art_init(_quality = 2) { // quality: art is drawn this many times larger, then scaled down for smooth edges
    global.demo_art = { quality : _quality, recipes : [], sprites : {} };
}

function demo_art_add(_name, _w, _h, _xorig, _yorig, _draw, _frames = 1) { // a recipe: draw(frame) draws one frame with GMVex in a w by h box, baked by demo_art_bake
    array_push(global.demo_art.recipes, { name : _name, w : _w, h : _h, xorig : _xorig, yorig : _yorig, draw : _draw, frames : _frames });
}

function demo_art(_name) { // the baked sprite
    var _s = global.demo_art.sprites[$ _name];
    if (_s == undefined) throw "Demo: no art named '" + _name + "', or it isn't baked yet";
    return _s;
}

function demo_art_pending() {
    return array_length(global.demo_art.recipes) > 0;
}

function demo_art_bake() { // bakes every recipe added since the last bake, in a Draw event
    var _art = global.demo_art;
    for (var _i = 0; _i < array_length(_art.recipes); _i++) {
        var _r = _art.recipes[_i];
        var _sprite = -1;
        for (var _f = 0; _f < _r.frames; _f++) {
            var _surf = __demo_art_frame(_r, _f, _art.quality);
            if (_f == 0) _sprite = sprite_create_from_surface(_surf, 0, 0, _r.w, _r.h, false, false, _r.xorig, _r.yorig);
            else sprite_add_from_surface(_sprite, _surf, 0, 0, _r.w, _r.h, false, false);
            surface_free(_surf);
        }
        var _old = _art.sprites[$ _r.name];
        if (_old != undefined) sprite_delete(_old);
        _art.sprites[$ _r.name] = _sprite;
    }
    _art.recipes = [];
}

function __demo_art_frame(_r, _frame, _q) {
    // drawn q times larger onto a clear surface: with this blend mode the surface holds colour already multiplied by alpha
    var _big = surface_create(_r.w * _q, _r.h * _q);
    surface_set_target(_big);
    draw_clear_alpha(c_black, 0);
    gpu_set_blendmode_ext_sepalpha(bm_src_alpha, bm_inv_src_alpha, bm_one, bm_inv_src_alpha);
    var _view = matrix_get(matrix_view);
    matrix_set(matrix_view, matrix_multiply(matrix_build(0, 0, 0, 0, 0, 0, _q, _q, 1), _view)); // GMVex sets the world matrix itself, so the scale goes in the view
    _r.draw(_frame);
    matrix_set(matrix_view, _view);
    gpu_set_blendmode(bm_normal);
    surface_reset_target();

    // scaled down with filtering, then divided back by alpha so the sprite draws normally, without dark edges
    var _small = surface_create(_r.w, _r.h);
    surface_set_target(_small);
    draw_clear_alpha(c_black, 0);
    gpu_set_blendenable(false);
    gpu_set_texfilter(true);
    shader_set(sh_demo_unpremultiply);
    draw_surface_ext(_big, 0, 0, 1 / _q, 1 / _q, 0, c_white, 1);
    shader_reset();
    gpu_set_texfilter(false);
    gpu_set_blendenable(true);
    surface_reset_target();
    surface_free(_big);
    return _small;
}