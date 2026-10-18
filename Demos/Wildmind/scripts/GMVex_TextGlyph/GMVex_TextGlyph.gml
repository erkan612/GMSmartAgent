function gmvex_text_char_to_glyph(font, char_code) {
    var sub = font.cmap_subtable_offset;

    switch (font.cmap_format) {
        case 0: { // format 0
            if (char_code < 0 || char_code > 255) return 0;
            return gmvex_text_read_u8(font.buf, sub + 6 + char_code);
        }
        case 6: { // format 6
            var first_code = gmvex_text_read_u16be(font.buf, sub + 6);
            var entry_count = gmvex_text_read_u16be(font.buf, sub + 8);
            if (char_code < first_code || char_code >= first_code + entry_count) return 0;
            return gmvex_text_read_u16be(font.buf, sub + 10 + (char_code - first_code) * 2);
        }
        case 12: { // format 12
            var num_groups = gmvex_text_read_u32be(font.buf, sub + 12);
            var groups_pos = sub + 16;
            
            var lo = 0, hi = num_groups - 1;
            while (lo <= hi) {
                var mid = (lo + hi) div 2;
                var g_pos = groups_pos + mid * 12;
                var start_code = gmvex_text_read_u32be(font.buf, g_pos);
                var end_code   = gmvex_text_read_u32be(font.buf, g_pos + 4);
                if (char_code < start_code) { hi = mid - 1; }
                else if (char_code > end_code) { lo = mid + 1; }
                else {
                    var start_gid = gmvex_text_read_u32be(font.buf, g_pos + 8);
                    return start_gid + (char_code - start_code);
                }
            }
            return 0;
        }
        default: { // format 4
            var seg_count_x2 = gmvex_text_read_u16be(font.buf, sub + 6);
            var seg_count = seg_count_x2 / 2;
            var end_codes_pos    = sub + 14;
            var start_codes_pos  = end_codes_pos + seg_count_x2 + 2;
            var id_deltas_pos    = start_codes_pos + seg_count_x2;
            var id_range_off_pos = id_deltas_pos + seg_count_x2;

            for (var i = 0; i < seg_count; i++) {
                var end_code = gmvex_text_read_u16be(font.buf, end_codes_pos + i*2);
                if (char_code <= end_code) {
                    var start_code = gmvex_text_read_u16be(font.buf, start_codes_pos + i*2);
                    if (char_code < start_code) return 0;
                    var id_delta = gmvex_text_read_s16be(font.buf, id_deltas_pos + i*2);
                    var id_range_offset = gmvex_text_read_u16be(font.buf, id_range_off_pos + i*2);
                    if (id_range_offset == 0) {
                        return (char_code + id_delta) & 0xFFFF;
                    } else {
                        var glyph_addr = id_range_off_pos + i*2 + id_range_offset + (char_code - start_code) * 2;
                        var gid = gmvex_text_read_u16be(font.buf, glyph_addr);
                        if (gid == 0) return 0;
                        return (gid + id_delta) & 0xFFFF;
                    }
                }
            }
            return 0;
        }
    }
}

function gmvex_text_get_loca_range(font, gid) {
    if (font.index_to_loc_format == 0) {
        var a = gmvex_text_read_u16be(font.buf, font.loca_offset + gid*2) * 2;
        var b = gmvex_text_read_u16be(font.buf, font.loca_offset + (gid+1)*2) * 2;
        return [a, b];
    } else {
        var a = gmvex_text_read_u32be(font.buf, font.loca_offset + gid*4);
        var b = gmvex_text_read_u32be(font.buf, font.loca_offset + (gid+1)*4);
        return [a, b];
    }
}

function gmvex_text_get_advance_width(font, gid) {
    if (font.hmtx_offset == -1) return font.units_per_em / 2; // no hmtx - fallback
    if (gid < font.num_h_metrics) {
        return gmvex_text_read_u16be(font.buf, font.hmtx_offset + gid*4);
    } else {
        return gmvex_text_read_u16be(font.buf, font.hmtx_offset + (font.num_h_metrics-1)*4);
    }
}

function gmvex_text_decode_simple_glyph(font, glyph_offset, number_of_contours) {
    var pos = glyph_offset + 10; // skip numberOfContours(2) + bbox(8)

    var end_pts = array_create(number_of_contours);
    for (var i = 0; i < number_of_contours; i++) {
        end_pts[i] = gmvex_text_read_u16be(font.buf, pos);
        pos += 2;
    }
    var num_points = end_pts[number_of_contours - 1] + 1;

    var instruction_length = gmvex_text_read_u16be(font.buf, pos);
    pos += 2 + instruction_length;

    var flags = array_create(num_points);
    var fi = 0;
    while (fi < num_points) {
        var flag = gmvex_text_read_u8(font.buf, pos); pos += 1;
        flags[fi] = flag; fi++;
        if (flag & 0x08) { // REPEAT_FLAG
            var repeat_count = gmvex_text_read_u8(font.buf, pos); pos += 1;
            for (var r = 0; r < repeat_count; r++) { flags[fi] = flag; fi++; }
        }
    }

    var xs = array_create(num_points);
    var xx = 0;
    for (var i = 0; i < num_points; i++) {
        var flag = flags[i];
        var dx = 0;
        if (flag & 0x02) { // X_SHORT_VECTOR
            dx = gmvex_text_read_u8(font.buf, pos); pos += 1;
            if (!(flag & 0x10)) dx = -dx;
        } else {
            if (flag & 0x10) { dx = 0; } // X_SAME_OR_POSITIVE
            else { dx = gmvex_text_read_s16be(font.buf, pos); pos += 2; }
        }
        xx += dx;
        xs[i] = xx;
    }

    var ys = array_create(num_points);
    var yy = 0;
    for (var i = 0; i < num_points; i++) {
        var flag = flags[i];
        var dy = 0;
        if (flag & 0x04) { // Y_SHORT_VECTOR
            dy = gmvex_text_read_u8(font.buf, pos); pos += 1;
            if (!(flag & 0x20)) dy = -dy;
        } else {
            if (flag & 0x20) { dy = 0; }
            else { dy = gmvex_text_read_s16be(font.buf, pos); pos += 2; }
        }
        yy += dy;
        ys[i] = yy;
    }

    var contours = [];
    var start = 0;
    for (var c = 0; c < number_of_contours; c++) {
        var _end = end_pts[c];
        var contour = [];
        for (var i = start; i <= _end; i++) {
            array_push(contour, { x: xs[i], y: ys[i], on_curve: (flags[i] & 0x01) != 0 });
        }
        array_push(contours, contour);
        start = _end + 1;
    }
    return contours;
}

function gmvex_text_decode_composite_glyph(font, glyph_offset, dx0, dy0, ma0 = 1, mb0 = 0, mc0 = 0, md0 = 1) {
    var ARG_1_AND_2_ARE_WORDS    = 0x0001;
    var ARGS_ARE_XY_VALUES       = 0x0002;
    var WE_HAVE_A_SCALE          = 0x0008;
    var MORE_COMPONENTS          = 0x0020;
    var WE_HAVE_AN_X_AND_Y_SCALE = 0x0040;
    var WE_HAVE_A_TWO_BY_TWO     = 0x0080;

    var pos = glyph_offset + 10;
    var all_contours = [];

    while (true) {
        var flags = gmvex_text_read_u16be(font.buf, pos);
        var glyph_index = gmvex_text_read_u16be(font.buf, pos + 2);
        pos += 4;

        var arg1 = 0, arg2 = 0;
        if (flags & ARG_1_AND_2_ARE_WORDS) {
            arg1 = gmvex_text_read_s16be(font.buf, pos);
            arg2 = gmvex_text_read_s16be(font.buf, pos + 2);
            pos += 4;
        } else {
            arg1 = gmvex_text_read_s8(font.buf, pos);
            arg2 = gmvex_text_read_s8(font.buf, pos + 1);
            pos += 2;
        }

        var ca = 1, cb = 0, cc = 0, cd = 1;
        if (flags & WE_HAVE_A_SCALE) {
            ca = gmvex_text_read_s16be(font.buf, pos) / 16384;
            cd = ca;
            pos += 2;
        } else if (flags & WE_HAVE_AN_X_AND_Y_SCALE) {
            ca = gmvex_text_read_s16be(font.buf, pos) / 16384;
            cd = gmvex_text_read_s16be(font.buf, pos + 2) / 16384;
            pos += 4;
        } else if (flags & WE_HAVE_A_TWO_BY_TWO) {
            ca = gmvex_text_read_s16be(font.buf, pos) / 16384;
            cb = gmvex_text_read_s16be(font.buf, pos + 2) / 16384;
            cc = gmvex_text_read_s16be(font.buf, pos + 4) / 16384;
            cd = gmvex_text_read_s16be(font.buf, pos + 6) / 16384;
            pos += 8;
        }

        var use_dx = dx0, use_dy = dy0;
        if (flags & ARGS_ARE_XY_VALUES) {
            use_dx += arg1;
            use_dy += arg2;
        }
        
        var combined_a = ca*ma0 + cb*mc0;
        var combined_b = ca*mb0 + cb*md0;
        var combined_c = cc*ma0 + cd*mc0;
        var combined_d = cc*mb0 + cd*md0;

        var sub_contours = gmvex_text_get_glyph_contours(font, glyph_index, use_dx, use_dy, combined_a, combined_b, combined_c, combined_d);
        for (var i = 0; i < array_length(sub_contours); i++) array_push(all_contours, sub_contours[i]);

        if (!(flags & MORE_COMPONENTS)) break;
    }
    return all_contours;
}

function gmvex_text_get_glyph_contours(font, gid, dx = 0, dy = 0, ma = 1, mb = 0, mc = 0, md = 1) {
    if (gid < 0 || gid >= font.num_glyphs) return [];
    var range = gmvex_text_get_loca_range(font, gid);
    if (range[1] == range[0]) return [];

    var glyph_offset = font.glyf_offset + range[0];
    var number_of_contours = gmvex_text_read_s16be(font.buf, glyph_offset);

    var contours;
    if (number_of_contours >= 0) {
        contours = gmvex_text_decode_simple_glyph(font, glyph_offset, number_of_contours);
    } else {
        return gmvex_text_decode_composite_glyph(font, glyph_offset, dx, dy, ma, mb, mc, md);
    }

    var is_identity = (ma == 1 && mb == 0 && mc == 0 && md == 1);
    if (dx != 0 || dy != 0 || !is_identity) {
        for (var c = 0; c < array_length(contours); c++) {
            var contour = contours[c];
            for (var p = 0; p < array_length(contour); p++) {
                var px = contour[p].x, py = contour[p].y;
                var nx = is_identity ? px : (px*ma + py*mc);
                var ny = is_identity ? py : (px*mb + py*md);
                contour[p].x = nx + dx;
                contour[p].y = ny + dy;
            }
        }
    }
    return contours;
}

function gmvex_text_get_kerning(font, left_gid, right_gid) {
    if (font.kern_pairs_offset == -1 || font.kern_pair_count == 0) return 0;

    var key = (left_gid << 16) | right_gid; // binary search
    var lo = 0, hi = font.kern_pair_count - 1;
    while (lo <= hi) {
        var mid = (lo + hi) div 2;
        var p_pos = font.kern_pairs_offset + mid * 6;
        var p_left = gmvex_text_read_u16be(font.buf, p_pos);
        var p_right = gmvex_text_read_u16be(font.buf, p_pos + 2);
        var p_key = (p_left << 16) | p_right;
        if (key < p_key) { hi = mid - 1; }
        else if (key > p_key) { lo = mid + 1; }
        else { return gmvex_text_read_s16be(font.buf, p_pos + 4); }
    }
    return 0;
}

function gmvex_text_find_ligature(font, first_gid, rest_gids) {
    var best = undefined;
    for (var l = 0; l < array_length(font.liga_lookups); l++) {
        var lookup_offset = font.liga_lookups[l];
        var subtable_count = gmvex_text_read_u16be(font.buf, lookup_offset + 4);
        for (var s = 0; s < subtable_count; s++) {
            var subtable_offset = lookup_offset + gmvex_text_read_u16be(font.buf, lookup_offset + 6 + s * 2);
            var coverage_offset = subtable_offset + gmvex_text_read_u16be(font.buf, subtable_offset + 2);
            var cov_index = gmvex_text_gsub_coverage_index(font, coverage_offset, first_gid);
            if (cov_index == -1) continue;

            var lig_set_count = gmvex_text_read_u16be(font.buf, subtable_offset + 4);
            if (cov_index >= lig_set_count) continue;
            var lig_set_offset = subtable_offset + gmvex_text_read_u16be(font.buf, subtable_offset + 6 + cov_index * 2);

            var lig_count = gmvex_text_read_u16be(font.buf, lig_set_offset);
            for (var lg = 0; lg < lig_count; lg++) {
                var lig_offset = lig_set_offset + gmvex_text_read_u16be(font.buf, lig_set_offset + 2 + lg * 2);
                var lig_glyph = gmvex_text_read_u16be(font.buf, lig_offset);
                var component_count = gmvex_text_read_u16be(font.buf, lig_offset + 2);
                var needed = component_count - 1;
                if (needed > array_length(rest_gids)) continue;

                var matched = true;
                for (var c = 0; c < needed; c++) {
                    var comp_gid = gmvex_text_read_u16be(font.buf, lig_offset + 4 + c * 2);
                    if (rest_gids[c] != comp_gid) { matched = false; break; }
                }
                if (matched && (is_undefined(best) || needed + 1 > best.length)) {
                    best = { ligature_gid: lig_glyph, length: needed + 1 };
                }
            }
        }
    }
    return best;
}

function gmvex_text_gsub_coverage_index(font, coverage_offset, gid) {
    var format = gmvex_text_read_u16be(font.buf, coverage_offset);
    if (format == 1) {
        var glyph_count = gmvex_text_read_u16be(font.buf, coverage_offset + 2);
        for (var i = 0; i < glyph_count; i++) {
            var g = gmvex_text_read_u16be(font.buf, coverage_offset + 4 + i * 2);
            if (g == gid) return i;
            if (g > gid) break;
        }
        return -1;
    } else if (format == 2) {
        var range_count = gmvex_text_read_u16be(font.buf, coverage_offset + 2);
        for (var i = 0; i < range_count; i++) {
            var r_pos = coverage_offset + 4 + i * 6;
            var start_gid = gmvex_text_read_u16be(font.buf, r_pos);
            var end_gid = gmvex_text_read_u16be(font.buf, r_pos + 2);
            if (gid >= start_gid && gid <= end_gid) {
                var start_coverage_index = gmvex_text_read_u16be(font.buf, r_pos + 4);
                return start_coverage_index + (gid - start_gid);
            }
        }
        return -1;
    }
    return -1;
}