function gmvex_text_read_u8(buf, offset)  { buffer_seek(buf, buffer_seek_start, offset); return buffer_read(buf, buffer_u8); }

function gmvex_text_read_s8(buf, offset) {
    var v = gmvex_text_read_u8(buf, offset);
    return (v >= 128) ? (v - 256) : v;
}

function gmvex_text_read_u16be(buf, offset) {
    buffer_seek(buf, buffer_seek_start, offset);
    var b0 = buffer_read(buf, buffer_u8);
    var b1 = buffer_read(buf, buffer_u8);
    return (b0 << 8) | b1;
}
function gmvex_text_read_s16be(buf, offset) {
    var v = gmvex_text_read_u16be(buf, offset);
    return (v >= 32768) ? (v - 65536) : v;
}
function gmvex_text_read_u32be(buf, offset) {
    buffer_seek(buf, buffer_seek_start, offset);
    var b0 = buffer_read(buf, buffer_u8);
    var b1 = buffer_read(buf, buffer_u8);
    var b2 = buffer_read(buf, buffer_u8);
    var b3 = buffer_read(buf, buffer_u8);
    return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3;
}
function gmvex_text_read_tag(buf, offset) {
    buffer_seek(buf, buffer_seek_start, offset);
    var s = "";
    for (var i = 0; i < 4; i++) s += chr(buffer_read(buf, buffer_u8));
    return s;
}

function gmvex_text_read_tag4(buf, offset) {
    return chr(buffer_peek(buf, offset, buffer_u8)) + chr(buffer_peek(buf, offset+1, buffer_u8)) + chr(buffer_peek(buf, offset+2, buffer_u8)) + chr(buffer_peek(buf, offset+3, buffer_u8));
}

function gmvex_text_font_load(path) {
    var buf = buffer_load(path);
    if (buf == -1) {
        show_debug_message("gmvex_text_font_load: failed to load file at " + path);
        return undefined;
    }

    var num_tables = gmvex_text_read_u16be(buf, 4);
    var tables = ds_map_create();
    var offset = 12;
    for (var i = 0; i < num_tables; i++) {
        var tag = gmvex_text_read_tag(buf, offset);
        var table_offset = gmvex_text_read_u32be(buf, offset + 8);
        var table_length  = gmvex_text_read_u32be(buf, offset + 12);
        tables[? tag] = [table_offset, table_length];
        offset += 16;
    }

    if (!ds_map_exists(tables, "glyf") || !ds_map_exists(tables, "loca")) {
        show_debug_message("gmvex_text_font_load: no 'glyf'/'loca' table found -- this is likely a CFF-outline (.otf) font, which this module does not support. See module header.");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }
    if (!ds_map_exists(tables, "cmap") || !ds_map_exists(tables, "head") || !ds_map_exists(tables, "maxp")) {
        show_debug_message("gmvex_text_font_load: missing required table (cmap/head/maxp) -- not a valid font file?");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }

    var head_offset = tables[? "head"][0];
    var magic = gmvex_text_read_u32be(buf, head_offset + 12);
    if (magic != 0x5F0F3CF5) {
        show_debug_message("gmvex_text_font_load: head table magic number mismatch, offsets are likely wrong for this file");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }
    var units_per_em = gmvex_text_read_u16be(buf, head_offset + 18);
    var index_to_loc_format = gmvex_text_read_s16be(buf, head_offset + 50);

    var maxp_offset = tables[? "maxp"][0];
    var num_glyphs = gmvex_text_read_u16be(buf, maxp_offset + 4);

    var hhea_ascent = 0, hhea_descent = 0, hhea_line_gap = 0, num_h_metrics = 0, hmtx_offset = -1;
    if (ds_map_exists(tables, "hhea") && ds_map_exists(tables, "hmtx")) {
        var hhea_offset = tables[? "hhea"][0];
        hhea_ascent   = gmvex_text_read_s16be(buf, hhea_offset + 4);
        hhea_descent  = gmvex_text_read_s16be(buf, hhea_offset + 6);
        hhea_line_gap = gmvex_text_read_s16be(buf, hhea_offset + 8);
        num_h_metrics = gmvex_text_read_u16be(buf, hhea_offset + 34);
        hmtx_offset = tables[? "hmtx"][0];
    }

    var cmap_offset = tables[? "cmap"][0];
    var cmap_num_subtables = gmvex_text_read_u16be(buf, cmap_offset + 2);
    var chosen_subtable_offset = -1;
    var format12_subtable_offset = -1;
    var fallback_subtable_offset = -1;
    var sub_pos = cmap_offset + 4;
    for (var i = 0; i < cmap_num_subtables; i++) {
        var platform_id = gmvex_text_read_u16be(buf, sub_pos);
        var encoding_id = gmvex_text_read_u16be(buf, sub_pos + 2);
        var sub_offset  = gmvex_text_read_u32be(buf, sub_pos + 4);
        if (platform_id == 3 && encoding_id == 1) chosen_subtable_offset = cmap_offset + sub_offset;
        
        if ((platform_id == 3 && encoding_id == 10) || (platform_id == 0 && (encoding_id == 4 || encoding_id == 6))) {
            if (format12_subtable_offset == -1) format12_subtable_offset = cmap_offset + sub_offset;
        }
        if (platform_id == 0 && fallback_subtable_offset == -1) fallback_subtable_offset = cmap_offset + sub_offset;
        sub_pos += 8;
    }
    if (chosen_subtable_offset == -1) chosen_subtable_offset = format12_subtable_offset;
    if (chosen_subtable_offset == -1) chosen_subtable_offset = fallback_subtable_offset;
    if (chosen_subtable_offset == -1) {
        show_debug_message("gmvex_text_font_load: no usable cmap subtable found (need platform 3/encoding 1 or 10, or platform 0)");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }
    var cmap_format = gmvex_text_read_u16be(buf, chosen_subtable_offset);
    if (cmap_format != 0 && cmap_format != 4 && cmap_format != 6 && cmap_format != 12) {
        show_debug_message("gmvex_text_font_load: cmap subtable format " + string(cmap_format) + " is not supported (formats 0, 4, 6, 12 are implemented)");
        ds_map_destroy(tables);
        buffer_delete(buf);
        return undefined;
    }
	
	var kern_offset = -1;
    var kern_pairs_offset = -1;
    var kern_pair_count = 0;
    if (ds_map_exists(tables, "kern")) {
        kern_offset = tables[? "kern"][0];
        var kern_version = gmvex_text_read_u16be(buf, kern_offset);
        if (kern_version == 0) {
            var num_tables = gmvex_text_read_u16be(buf, kern_offset + 2);
            if (num_tables > 0) {
                var subtable_pos = kern_offset + 4;
                var sub_version = gmvex_text_read_u16be(buf, subtable_pos + 2);
                var sub_format = gmvex_text_read_u8(buf, subtable_pos + 4);
                if (sub_format == 0) {
                    kern_pair_count = gmvex_text_read_u16be(buf, subtable_pos + 6);
                    kern_pairs_offset = subtable_pos + 14;
                } else {
                    show_debug_message("gmvex_text_font_load: kern subtable format " + string(sub_format) + " is not supported (only format 0 is implemented) - no kerning will be applied");
                }
            }
        } else {
            show_debug_message("gmvex_text_font_load: kern table version " + string(kern_version) + " is not supported (only version 0 is implemented) - no kerning will be applied");
        }
    }
	
	var liga_lookups = [];
    if (ds_map_exists(tables, "GSUB")) {
        var gsub_offset = tables[? "GSUB"][0];
        var script_list_offset  = gsub_offset + gmvex_text_read_u16be(buf, gsub_offset + 4);
        var feature_list_offset = gsub_offset + gmvex_text_read_u16be(buf, gsub_offset + 6);
        var lookup_list_offset  = gsub_offset + gmvex_text_read_u16be(buf, gsub_offset + 8);

        var feature_count = gmvex_text_read_u16be(buf, feature_list_offset);
        var liga_feature_indices = [];
        for (var f = 0; f < feature_count; f++) {
            var rec_pos = feature_list_offset + 2 + f * 6;
            var tag = gmvex_text_read_tag4(buf, rec_pos);
            if (tag == "liga") {
                var feature_offset = feature_list_offset + gmvex_text_read_u16be(buf, rec_pos + 4);
                array_push(liga_feature_indices, feature_offset);
            }
        }

        var lookup_indices_seen = ds_map_create();
        for (var lf = 0; lf < array_length(liga_feature_indices); lf++) {
            var feature_offset = liga_feature_indices[lf];
            var lookup_count = gmvex_text_read_u16be(buf, feature_offset + 2);
            for (var li = 0; li < lookup_count; li++) {
                var lookup_index = gmvex_text_read_u16be(buf, feature_offset + 4 + li * 2);
                if (!ds_map_exists(lookup_indices_seen, lookup_index)) {
                    ds_map_add(lookup_indices_seen, lookup_index, true);
                    var lookup_offset = lookup_list_offset + gmvex_text_read_u16be(buf, lookup_list_offset + 2 + lookup_index * 2);
                    var lookup_type = gmvex_text_read_u16be(buf, lookup_offset);
                    if (lookup_type == 4) {
                        array_push(liga_lookups, lookup_offset);
                    }
                }
            }
        }
        ds_map_destroy(lookup_indices_seen);
    }

    return {
        buf: buf,
        tables: tables,
        units_per_em: units_per_em,
        index_to_loc_format: index_to_loc_format,
        num_glyphs: num_glyphs,
        glyf_offset: tables[? "glyf"][0],
        loca_offset: tables[? "loca"][0],
        cmap_subtable_offset: chosen_subtable_offset,
        cmap_format: cmap_format,
        hmtx_offset: hmtx_offset,
        num_h_metrics: num_h_metrics,
        ascent: hhea_ascent,
        descent: hhea_descent,
        glyph_cache: ds_map_create(),
        line_gap: hhea_line_gap,
        kern_pairs_offset: kern_pairs_offset,
        kern_pair_count: kern_pair_count,
        liga_lookups: liga_lookups,
    };
}

function gmvex_text_font_destroy(font) {
    if (is_undefined(font)) return;
    buffer_delete(font.buf);
    ds_map_destroy(font.tables);
    ds_map_destroy(font.glyph_cache);
}