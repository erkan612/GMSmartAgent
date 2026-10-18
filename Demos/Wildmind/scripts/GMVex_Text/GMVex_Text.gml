function gmvex_text_measure_width(font, text, size, letter_spacing = 0, use_ligatures = true) {
    var scale = size / font.units_per_em;
    var total = 0;
    var len = string_length(text);
    var prev_gid = -1;
    var i = 1;

    while (i <= len) {
        var char_code = string_ord_at(text, i);
        var gid = gmvex_text_char_to_glyph(font, char_code);
        var consumed = 1;

        if (use_ligatures && array_length(font.liga_lookups) > 0 && i < len) {
            var rest_gids = [];
            var lookahead = min(len - i, 3);
            for (var k = 1; k <= lookahead; k++) {
                array_push(rest_gids, gmvex_text_char_to_glyph(font, string_ord_at(text, i + k)));
            }
            var lig = gmvex_text_find_ligature(font, gid, rest_gids);
            if (!is_undefined(lig)) { gid = lig.ligature_gid; consumed = lig.length; }
        }

        if (prev_gid != -1) total += gmvex_text_get_kerning(font, prev_gid, gid) * scale;
        total += gmvex_text_get_advance_width(font, gid) * scale;
        if (i + consumed <= len) total += letter_spacing;
        prev_gid = gid;
        i += consumed;
    }
    return total;
}

function gmvex_text_to_paths(font, text, size, x = 0, y = 0, style = undefined, line_spacing_extra = 0, use_ligatures = true) {
    var bold          = false;
    var bold_strength = 0.02;
    var italic        = false;
    var italic_shear  = 0.20;
    var halign        = gmvex_halign.LEFT;
    var valign        = gmvex_valign.BASELINE;
    var letter_spacing = 0;

    if (!is_undefined(style)) {
        if (variable_struct_exists(style, "bold"))           bold           = style.bold;
        if (variable_struct_exists(style, "bold_strength"))  bold_strength  = style.bold_strength;
        if (variable_struct_exists(style, "italic"))         italic         = style.italic;
        if (variable_struct_exists(style, "italic_shear"))   italic_shear   = style.italic_shear;
        if (variable_struct_exists(style, "halign"))         halign         = style.halign;
        if (variable_struct_exists(style, "valign"))         valign         = style.valign;
        if (variable_struct_exists(style, "letter_spacing")) letter_spacing = style.letter_spacing;
    }

    var scale = size / font.units_per_em;
    var bold_amount = bold ? (bold_strength * size) / scale : 0;
    var shear = italic ? italic_shear : 0;

    var ascent_px   = font.ascent * scale;
    var descent_px  = font.descent * scale; // negative
    var line_gap_px = font.line_gap * scale;
    var line_height = (ascent_px - descent_px) + line_gap_px + line_spacing_extra;

    var lines = string_split(text, "\n");
    var num_lines = array_length(lines);

    var first_baseline_y = y;
    if (valign != gmvex_valign.BASELINE) {
        var total_height = (ascent_px - descent_px) + (num_lines - 1) * line_height;
        if (valign == gmvex_valign.TOP) {
            first_baseline_y = y + ascent_px;
        } else if (valign == gmvex_valign.MIDDLE) {
            first_baseline_y = y + (ascent_px + descent_px - (num_lines - 1) * line_height) / 2;
        } else if (valign == gmvex_valign.BOTTOM) {
            first_baseline_y = y + descent_px - (num_lines - 1) * line_height;
        }
    }

    var results = [];

    for (var line_i = 0; line_i < num_lines; line_i++) {
        var line_text = lines[line_i];
        var baseline_y = first_baseline_y + line_i * line_height;

        var start_x = x;
        if (halign == gmvex_halign.CENTER) start_x = x - gmvex_text_measure_width(font, line_text, size, letter_spacing) / 2;
        else if (halign == gmvex_halign.RIGHT) start_x = x - gmvex_text_measure_width(font, line_text, size, letter_spacing);

        var cursor_x = start_x;
        var len = string_length(line_text);
        var prev_gid = -1;
        var i = 1;

        while (i <= len) {
	        var char_code = string_ord_at(line_text, i);
	        var gid = gmvex_text_char_to_glyph(font, char_code);
	        var consumed = 1;

	        if (use_ligatures && array_length(font.liga_lookups) > 0 && i < len) {
	            var rest_gids = [];
	            var lookahead = min(len - i, 3); // 3 might need adjustment, laters work
	            for (var k = 1; k <= lookahead; k++) {
	                array_push(rest_gids, gmvex_text_char_to_glyph(font, string_ord_at(line_text, i + k)));
	            }
	            var lig = gmvex_text_find_ligature(font, gid, rest_gids);
	            if (!is_undefined(lig)) {
	                gid = lig.ligature_gid;
	                consumed = lig.length;
	            }
	        }

            if (prev_gid != -1) cursor_x += gmvex_text_get_kerning(font, prev_gid, gid) * scale;
            var contours = gmvex_text_get_glyph_contours(font, gid);

            var path = gmvex_path_create();
            for (var c = 0; c < array_length(contours); c++) {
                gmvex_text_add_contour_to_path(path, contours[c], scale, 0, 0, bold_amount, shear);
            }
            gmvex_path_set_transform(path, cursor_x, baseline_y);

            array_push(results, { path: path, char: char_code, line: line_i });

            var advance = gmvex_text_get_advance_width(font, gid);
            cursor_x += advance * scale + letter_spacing;
            prev_gid = gid;
            i += consumed;
        }
    }

    return results;
}

function gmvex_text_char_to_path(font, char_code, size, style = undefined) {
    var bold			= false;
    var bold_strength	= 0.02;
    var italic			= false;
    var italic_shear	= 0.20;
    var halign			= gmvex_halign.LEFT;
    var valign			= gmvex_valign.BASELINE;
	var letter_spacing	= 0;

    if (!is_undefined(style)) {
        if (variable_struct_exists(style, "bold"))           bold					= style.bold;
        if (variable_struct_exists(style, "bold_strength"))  bold_strength			= style.bold_strength;
        if (variable_struct_exists(style, "italic"))         italic					= style.italic;
        if (variable_struct_exists(style, "italic_shear"))   italic_shear			= style.italic_shear;
        if (variable_struct_exists(style, "halign"))         halign					= style.halign;
        if (variable_struct_exists(style, "valign"))         valign					= style.valign;
        if (variable_struct_exists(style, "letter_spacing")) letter_spacing         = style.letter_spacing;
    }

    var scale = size / font.units_per_em;
    var bold_amount = bold ? (bold_strength * size) / scale : 0;
    var shear = italic ? italic_shear : 0;

    var origin_y = 0;
    if (valign != gmvex_valign.BASELINE) {
        var ascent_px = font.ascent * scale;
        var descent_px = font.descent * scale;
        var total_height_px = ascent_px - descent_px;
        if (valign == gmvex_valign.TOP) origin_y = ascent_px;
        else if (valign == gmvex_valign.MIDDLE) origin_y = total_height_px/2 - ascent_px;
        else if (valign == gmvex_valign.BOTTOM) origin_y = descent_px;
    }

    var gid = gmvex_text_char_to_glyph(font, char_code);
    var contours = gmvex_text_get_glyph_contours(font, gid);

    var path = gmvex_path_create();
    for (var i = 0; i < array_length(contours); i++) {
        gmvex_text_add_contour_to_path(path, contours[i], scale, 0, origin_y, bold_amount, shear);
    }
    return path;
}

function gmvex_text_get_width(font, text, size, letter_spacing = 0) {
    var lines = string_split(text, "\n");
    var max_width = 0;
    for (var i = 0; i < array_length(lines); i++) {
        var w = gmvex_text_measure_width(font, lines[i], size, letter_spacing);
        if (w > max_width) max_width = w;
    }
    return max_width;
}

function gmvex_text_get_height(font, text, size, line_spacing_extra = 0) {
    var lines = string_split(text, "\n");
    var num_lines = array_length(lines);
    var scale = size / font.units_per_em;
    var ascent_px = font.ascent * scale;
    var descent_px = font.descent * scale; // negative
    var line_gap_px = font.line_gap * scale;
    var line_height = (ascent_px - descent_px) + line_gap_px + line_spacing_extra;
    if (num_lines <= 1) return ascent_px - descent_px;
    return (ascent_px - descent_px) + (num_lines - 1) * line_height;
}

function gmvex_text_get_size(font, text, size, letter_spacing = 0, line_spacing_extra = 0) {
    return {
        width: gmvex_text_get_width(font, text, size, letter_spacing),
        height: gmvex_text_get_height(font, text, size, line_spacing_extra)
    };
}

function gmvex_text_set_transform(text_paths, x, y, rot = 0, xscale = 1, yscale = 1, origin_x = 0, origin_y = 0) {
    var rot_sign = -1;
    var rad = degtorad(rot * rot_sign);
    var cos_r = cos(rad);
    var sin_r = sin(rad);
    for (var i = 0; i < array_length(text_paths); i++) {
        var path = text_paths[i].path;
        if (!variable_struct_exists(path, "text_orig_tmatrix")) {
            path.text_orig_tmatrix = path.tmatrix;
        }
        var orig_tx = path.text_orig_tmatrix[4];
        var orig_ty = path.text_orig_tmatrix[5];
        var lx = (orig_tx - origin_x) * xscale;
        var ly = (orig_ty - origin_y) * yscale;
        var rx = lx * cos_r - ly * sin_r;
        var ry = lx * sin_r + ly * cos_r;
        gmvex_path_set_transform(path, x + rx, y + ry, rot, xscale, yscale, 0, 0);
    }
}