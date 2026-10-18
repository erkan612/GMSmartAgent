function gmvex_svg_skip_whitespace(str, pos) {
    var buf = str.buf, size = str.size;
    while (pos <= size) {
        var c = gmvex_buf_char_at(buf, size, pos);
        if (c != " " && c != "\n" && c != "\t" && c != "\r") break;
        pos++;
    }
    return pos;
}

function gmvex_svg_try_skip_comment(str, pos) {
    var buf = str.buf, size = str.size;
    if (gmvex_buf_copy(buf, size, pos, 4) == "<!--") {
        var end_pos = gmvex_buf_pos_ext("-->", buf, size, pos);
        if (end_pos == 0) return { skipped: false, pos: pos };
        return { skipped: true, pos: end_pos + 3 };
    }
    return { skipped: false, pos: pos };
}

function gmvex_svg_parse_attribute(str, pos) {
    var buf = str.buf, size = str.size;
    var name_start = pos;
    while (pos <= size) {
        var c = gmvex_buf_char_at(buf, size, pos);
        if (c == "=" || c == " " || c == "\n" || c == "\t" || c == "\r" || c == ">" || c == "/") break;
        pos++;
    }
    var name = gmvex_buf_copy(buf, size, name_start, pos - name_start);
    pos = gmvex_svg_skip_whitespace(str, pos);

    if (pos > size || gmvex_buf_char_at(buf, size, pos) != "=") {
        return { name: name, value: "", pos: pos };
    }
    pos++;
    pos = gmvex_svg_skip_whitespace(str, pos);

    var quote_char = gmvex_buf_char_at(buf, size, pos);
    if (quote_char != "\"" && quote_char != "'") {
        return { name: name, value: "", pos: pos };
    }
    pos++;
    var value_start = pos;
    while (pos <= size && gmvex_buf_char_at(buf, size, pos) != quote_char) pos++;
    var value = gmvex_buf_copy(buf, size, value_start, pos - value_start);
    pos++;
    return { name: name, value: value, pos: pos };
}

function gmvex_svg_parse_element(str, pos) {
    var buf = str.buf, size = str.size;
    pos++;

    var tag_start = pos;
    while (pos <= size) {
        var c = gmvex_buf_char_at(buf, size, pos);
        if (c == " " || c == "\n" || c == "\t" || c == "\r" || c == ">" || c == "/") break;
        pos++;
    }
    var tag = gmvex_buf_copy(buf, size, tag_start, pos - tag_start);

    var attributes = ds_map_create();
    while (true) {
        pos = gmvex_svg_skip_whitespace(str, pos);
        var c = gmvex_buf_char_at(buf, size, pos);
        if (c == "/" || c == ">") break;
        var attr = gmvex_svg_parse_attribute(str, pos);
        attributes[? attr.name] = attr.value;
        pos = attr.pos;
    }

    pos = gmvex_svg_skip_whitespace(str, pos);
    var self_closing = (gmvex_buf_char_at(buf, size, pos) == "/");
    if (self_closing) pos++;
    pos++;

    var element = { tag: tag, attributes: attributes, children: [], self_closing: self_closing, text_content: "" };

    if (self_closing) {
        return { element: element, pos: pos };
    }

    var closing_tag = "</" + tag;
    var closing_tag_len = string_length(closing_tag);
    while (true) {
        var comment_check = gmvex_svg_try_skip_comment(str, pos);
        if (comment_check.skipped) { pos = comment_check.pos; continue; }

        pos = gmvex_svg_skip_whitespace(str, pos);

        var comment_check2 = gmvex_svg_try_skip_comment(str, pos);
        if (comment_check2.skipped) { pos = comment_check2.pos; continue; }

        if (gmvex_buf_copy(buf, size, pos, closing_tag_len) == closing_tag) {
            var gt_pos = gmvex_buf_pos_ext(">", buf, size, pos);
            pos = gt_pos + 1;
            break;
        }
        if (gmvex_buf_char_at(buf, size, pos) != "<") {
            var next_lt = gmvex_buf_pos_ext("<", buf, size, pos);
            if (next_lt == 0) break;
            element.text_content += gmvex_buf_copy(buf, size, pos, next_lt - pos);
            pos = next_lt;
            continue;
        }
        var child_result = gmvex_svg_parse_element(str, pos);
        array_push(element.children, child_result.element);
        pos = child_result.pos;
    }

    return { element: element, pos: pos };
}

function gmvex_svg_parse_xml(content_str) {
    var buf = buffer_create(string_byte_length(content_str) + 1, buffer_fixed, 1);
    buffer_write(buf, buffer_text, content_str);
    var size = string_byte_length(content_str);
    var str = { buf: buf, size: size };

    var pos = 1;
    var root = undefined;
    while (pos <= size) {
        pos = gmvex_svg_skip_whitespace(str, pos);
        var comment_check = gmvex_svg_try_skip_comment(str, pos);
        if (comment_check.skipped) { pos = comment_check.pos; continue; }
        if (gmvex_buf_copy(buf, size, pos, 2) == "<?") {
            var end_pos = gmvex_buf_pos_ext("?>", buf, size, pos);
            if (end_pos == 0) break;
            pos = end_pos + 2;
            continue;
        }
        if (gmvex_buf_copy(buf, size, pos, 9) == "<!DOCTYPE") {
            var doctype_end = gmvex_buf_pos_ext(">", buf, size, pos);
            if (doctype_end == 0) break;
            pos = doctype_end + 1;
            continue;
        }
        if (gmvex_buf_char_at(buf, size, pos) == "<") {
            var result = gmvex_svg_parse_element(str, pos);
            root = result.element;
            break;
        }
        pos++;
    }

    buffer_delete(buf);
    return root;
}

function gmvex_svg_is_digit(c) {
    return c >= "0" && c <= "9";
}

function gmvex_svg_scan_number(str, pos) {
    var buf = str.buf, size = str.size;
    while (pos <= size) {
        var c = gmvex_buf_char_at(buf, size, pos);
        if (c == " " || c == "\n" || c == "\t" || c == "\r" || c == ",") { pos++; continue; }
        break;
    }
    if (pos > size) return { value: undefined, pos: pos };

    var start = pos;
    var c = gmvex_buf_char_at(buf, size, pos);
    if (c == "-" || c == "+") pos++;

    var seen_digit = false;
    var seen_dot = false;
    while (pos <= size) {
        c = gmvex_buf_char_at(buf, size, pos);
        if (gmvex_svg_is_digit(c)) { seen_digit = true; pos++; continue; }
        if (c == "." && !seen_dot) { seen_dot = true; pos++; continue; }
        break;
    }
    if (pos <= size && (gmvex_buf_char_at(buf, size, pos) == "e" || gmvex_buf_char_at(buf, size, pos) == "E")) {
        var exp_start = pos;
        pos++;
        if (pos <= size && (gmvex_buf_char_at(buf, size, pos) == "-" || gmvex_buf_char_at(buf, size, pos) == "+")) pos++;
        var exp_has_digit = false;
        while (pos <= size && gmvex_svg_is_digit(gmvex_buf_char_at(buf, size, pos))) { exp_has_digit = true; pos++; }
        if (!exp_has_digit) pos = exp_start;
    }

    if (!seen_digit) return { value: undefined, pos: start };

    var text = gmvex_buf_copy(buf, size, start, pos - start);
    return { value: real(text), pos: pos };
}

function gmvex_svg_scan_flag(str, pos) {
    var buf = str.buf, size = str.size;
    while (pos <= size) {
        var c = gmvex_buf_char_at(buf, size, pos);
        if (c == " " || c == "\n" || c == "\t" || c == "\r" || c == ",") { pos++; continue; }
        break;
    }
    if (pos > size) return { value: undefined, pos: pos };
    var c = gmvex_buf_char_at(buf, size, pos);
    if (c != "0" && c != "1") return { value: undefined, pos: pos };
    return { value: real(c), pos: pos + 1 };
}

function gmvex_svg_parse_path_data(path, d) {
    var buf = buffer_create(string_byte_length(d) + 1, buffer_fixed, 1);
    buffer_write(buf, buffer_text, d);
    var size = string_byte_length(d);
    var str = { buf: buf, size: size };

    var pos = 1;
    var cmd = "";
    var cur_x = 0, cur_y = 0;
    var subpath_start_x = 0, subpath_start_y = 0;
    var last_cubic_c2x = undefined, last_cubic_c2y = undefined;
    var last_quad_cx = undefined, last_quad_cy = undefined;

    while (pos <= size) {
        pos = gmvex_svg_skip_whitespace(str, pos);
        if (pos > size) break;
        var c = gmvex_buf_char_at(buf, size, pos);

        if ((c >= "A" && c <= "Z") || (c >= "a" && c <= "z")) {
            cmd = c;
            pos++;
            if (cmd == "M") cmd = "M_first";
            else if (cmd == "m") cmd = "m_first";
        }

        if (cmd == "M_first" || cmd == "m_first") {
            var nx = gmvex_svg_scan_number(str, pos); pos = nx.pos;
            var ny = gmvex_svg_scan_number(str, pos); pos = ny.pos;
            if (cmd == "m_first") { cur_x += nx.value; cur_y += ny.value; }
            else { cur_x = nx.value; cur_y = ny.value; }
            gmvex_path_moveto(path, cur_x, cur_y);
            subpath_start_x = cur_x; subpath_start_y = cur_y;
            last_cubic_c2x = undefined; last_quad_cx = undefined;
            cmd = (cmd == "m_first") ? "l" : "L";
        } else if (cmd == "L" || cmd == "l") {
            var nx = gmvex_svg_scan_number(str, pos); pos = nx.pos;
            var ny = gmvex_svg_scan_number(str, pos); pos = ny.pos;
            if (cmd == "l") { cur_x += nx.value; cur_y += ny.value; }
            else { cur_x = nx.value; cur_y = ny.value; }
            gmvex_path_lineto(path, cur_x, cur_y);
            last_cubic_c2x = undefined; last_quad_cx = undefined;
        } else if (cmd == "H" || cmd == "h") {
            var nx = gmvex_svg_scan_number(str, pos); pos = nx.pos;
            cur_x = (cmd == "h") ? cur_x + nx.value : nx.value;
            gmvex_path_lineto(path, cur_x, cur_y);
            last_cubic_c2x = undefined; last_quad_cx = undefined;
        } else if (cmd == "V" || cmd == "v") {
            var ny = gmvex_svg_scan_number(str, pos); pos = ny.pos;
            cur_y = (cmd == "v") ? cur_y + ny.value : ny.value;
            gmvex_path_lineto(path, cur_x, cur_y);
            last_cubic_c2x = undefined; last_quad_cx = undefined;
        } else if (cmd == "C" || cmd == "c") {
            var c1x = gmvex_svg_scan_number(str, pos); pos = c1x.pos;
            var c1y = gmvex_svg_scan_number(str, pos); pos = c1y.pos;
            var c2x = gmvex_svg_scan_number(str, pos); pos = c2x.pos;
            var c2y = gmvex_svg_scan_number(str, pos); pos = c2y.pos;
            var ex  = gmvex_svg_scan_number(str, pos); pos = ex.pos;
            var ey  = gmvex_svg_scan_number(str, pos); pos = ey.pos;
            var abs_c1x, abs_c1y, abs_c2x, abs_c2y, abs_ex, abs_ey;
            if (cmd == "c") {
                abs_c1x = cur_x + c1x.value; abs_c1y = cur_y + c1y.value;
                abs_c2x = cur_x + c2x.value; abs_c2y = cur_y + c2y.value;
                abs_ex  = cur_x + ex.value;  abs_ey  = cur_y + ey.value;
            } else {
                abs_c1x = c1x.value; abs_c1y = c1y.value;
                abs_c2x = c2x.value; abs_c2y = c2y.value;
                abs_ex  = ex.value;  abs_ey  = ey.value;
            }
            gmvex_path_cubicto(path, abs_c1x, abs_c1y, abs_c2x, abs_c2y, abs_ex, abs_ey);
            last_cubic_c2x = abs_c2x; last_cubic_c2y = abs_c2y;
            last_quad_cx = undefined;
            cur_x = abs_ex; cur_y = abs_ey;
        } else if (cmd == "S" || cmd == "s") {
            var c2x = gmvex_svg_scan_number(str, pos); pos = c2x.pos;
            var c2y = gmvex_svg_scan_number(str, pos); pos = c2y.pos;
            var ex  = gmvex_svg_scan_number(str, pos); pos = ex.pos;
            var ey  = gmvex_svg_scan_number(str, pos); pos = ey.pos;
            var abs_c1x, abs_c1y;
            if (!is_undefined(last_cubic_c2x)) {
                abs_c1x = 2*cur_x - last_cubic_c2x;
                abs_c1y = 2*cur_y - last_cubic_c2y;
            } else {
                abs_c1x = cur_x; abs_c1y = cur_y;
            }
            var abs_c2x, abs_c2y, abs_ex, abs_ey;
            if (cmd == "s") {
                abs_c2x = cur_x + c2x.value; abs_c2y = cur_y + c2y.value;
                abs_ex  = cur_x + ex.value;  abs_ey  = cur_y + ey.value;
            } else {
                abs_c2x = c2x.value; abs_c2y = c2y.value;
                abs_ex  = ex.value;  abs_ey  = ey.value;
            }
            gmvex_path_cubicto(path, abs_c1x, abs_c1y, abs_c2x, abs_c2y, abs_ex, abs_ey);
            last_cubic_c2x = abs_c2x; last_cubic_c2y = abs_c2y;
            last_quad_cx = undefined;
            cur_x = abs_ex; cur_y = abs_ey;
        } else if (cmd == "Q" || cmd == "q") {
            var cx = gmvex_svg_scan_number(str, pos); pos = cx.pos;
            var cy = gmvex_svg_scan_number(str, pos); pos = cy.pos;
            var ex = gmvex_svg_scan_number(str, pos); pos = ex.pos;
            var ey = gmvex_svg_scan_number(str, pos); pos = ey.pos;
            var abs_cx, abs_cy, abs_ex, abs_ey;
            if (cmd == "q") {
                abs_cx = cur_x + cx.value; abs_cy = cur_y + cy.value;
                abs_ex = cur_x + ex.value; abs_ey = cur_y + ey.value;
            } else {
                abs_cx = cx.value; abs_cy = cy.value;
                abs_ex = ex.value; abs_ey = ey.value;
            }
            gmvex_path_quadto(path, abs_cx, abs_cy, abs_ex, abs_ey);
            last_quad_cx = abs_cx; last_quad_cy = abs_cy;
            last_cubic_c2x = undefined;
            cur_x = abs_ex; cur_y = abs_ey;
        } else if (cmd == "T" || cmd == "t") {
            var ex = gmvex_svg_scan_number(str, pos); pos = ex.pos;
            var ey = gmvex_svg_scan_number(str, pos); pos = ey.pos;
            var abs_cx, abs_cy;
            if (!is_undefined(last_quad_cx)) {
                abs_cx = 2*cur_x - last_quad_cx;
                abs_cy = 2*cur_y - last_quad_cy;
            } else {
                abs_cx = cur_x; abs_cy = cur_y;
            }
            var abs_ex, abs_ey;
            if (cmd == "t") { abs_ex = cur_x + ex.value; abs_ey = cur_y + ey.value; }
            else { abs_ex = ex.value; abs_ey = ey.value; }
            gmvex_path_quadto(path, abs_cx, abs_cy, abs_ex, abs_ey);
            last_quad_cx = abs_cx; last_quad_cy = abs_cy;
            last_cubic_c2x = undefined;
            cur_x = abs_ex; cur_y = abs_ey;
        } else if (cmd == "A" || cmd == "a") {
            var rx = gmvex_svg_scan_number(str, pos); pos = rx.pos;
            var ry = gmvex_svg_scan_number(str, pos); pos = ry.pos;
            var rot = gmvex_svg_scan_number(str, pos); pos = rot.pos;
            var large_arc = gmvex_svg_scan_flag(str, pos); pos = large_arc.pos;
            var sweep = gmvex_svg_scan_flag(str, pos); pos = sweep.pos;
            var ex = gmvex_svg_scan_number(str, pos); pos = ex.pos;
            var ey = gmvex_svg_scan_number(str, pos); pos = ey.pos;
            var abs_ex, abs_ey;
            if (cmd == "a") { abs_ex = cur_x + ex.value; abs_ey = cur_y + ey.value; }
            else { abs_ex = ex.value; abs_ey = ey.value; }
            gmvex_path_arcto(path, rx.value, ry.value, rot.value, large_arc.value, sweep.value, abs_ex, abs_ey);
            last_cubic_c2x = undefined; last_quad_cx = undefined;
            cur_x = abs_ex; cur_y = abs_ey;
        } else if (cmd == "Z" || cmd == "z") {
            gmvex_path_close(path);
            cur_x = subpath_start_x; cur_y = subpath_start_y;
            last_cubic_c2x = undefined; last_quad_cx = undefined;
        } else {
            break;
        }
    }

    buffer_delete(buf);
}

function gmvex_svg_parse_color(value, default_color) {
    value = string_trim(value);
    if (value == "none") return { is_none: true, color: undefined };
    if (value == "currentColor") return { is_none: false, color: default_color };

    if (string_char_at(value, 1) == "#") {
        var hex = string_copy(value, 2, string_length(value) - 1);
        if (string_length(hex) == 3) {
            var r = string_copy(hex, 1, 1); r += r;
            var g = string_copy(hex, 2, 1); g += g;
            var b = string_copy(hex, 3, 1); b += b;
            return { is_none: false, color: make_color_rgb(
                real("0x" + r), real("0x" + g), real("0x" + b)) };
        } else if (string_length(hex) == 6) {
            var r = string_copy(hex, 1, 2);
            var g = string_copy(hex, 3, 2);
            var b = string_copy(hex, 5, 2);
            return { is_none: false, color: make_color_rgb(
                real("0x" + r), real("0x" + g), real("0x" + b)) };
        }
        return { is_none: false, color: default_color };
    }

    if (string_copy(value, 1, 4) == "rgb(") {
        var inner = string_copy(value, 5, string_length(value) - 5);
        var parts = string_split(inner, ",");
        if (array_length(parts) >= 3) {
            return { is_none: false, color: make_color_rgb(
                real(string_trim(parts[0])),
                real(string_trim(parts[1])),
                real(string_trim(parts[2]))
            ) };
        }
        return { is_none: false, color: default_color };
    }

    switch (value) { // more?
        case "black": return { is_none: false, color: c_black };
        case "white": return { is_none: false, color: c_white };
        case "red": return { is_none: false, color: c_red };
        case "green": return { is_none: false, color: c_green };
        case "blue": return { is_none: false, color: c_blue };
        case "yellow": return { is_none: false, color: c_yellow };
        case "gray": case "grey": return { is_none: false, color: c_gray };
        case "orange": return { is_none: false, color: c_orange };
        case "purple": return { is_none: false, color: c_purple };
        case "transparent": return { is_none: true, color: undefined };
    }

    return { is_none: false, color: default_color };
}

function gmvex_svg_get_attr(attributes, name, default_value, style_map = undefined) {
    if (!is_undefined(style_map) && ds_map_exists(style_map, name)) return style_map[? name];
    if (ds_map_exists(attributes, name)) return attributes[? name];
    return default_value;
}

function gmvex_svg_element_to_result(element, default_color, gradient_map = undefined, id_map = undefined, depth = 0, class_map = undefined) {
    if (depth >= 16) {
        show_debug_message("gmvex_svg_import: clip-path/mask nesting exceeded safe depth (16) - likely a circular reference, stopping recursion here.");
        return undefined;
    }
    var tag = element.tag;
    var attrs = element.attributes;
	
    var path = gmvex_path_create();
    var has_geometry = true;
    var style_map = undefined;
    if (ds_map_exists(attrs, "class") && !is_undefined(class_map)) {
        var class_name = string_trim(attrs[? "class"]);
        if (ds_map_exists(class_map, class_name)) {
            style_map = class_map[? class_name];
        }
    }
    if (ds_map_exists(attrs, "style")) {
        var inline_style = gmvex_svg_parse_style_attr(attrs[? "style"]);
        if (is_undefined(style_map)) {
            style_map = inline_style;
        } else {
            var keys = ds_map_keys_to_array(inline_style);
            for (var k = 0; k < array_length(keys); k++) {
                style_map[? keys[k]] = inline_style[? keys[k]];
            }
        }
    }

    if (tag == "path") {
        var d = gmvex_svg_get_attr(attrs, "d", "");
        gmvex_svg_parse_path_data(path, d);
    } else if (tag == "rect") {
        var xx = real(gmvex_svg_get_attr(attrs, "x", "0"));
        var yy = real(gmvex_svg_get_attr(attrs, "y", "0"));
        var w = real(gmvex_svg_get_attr(attrs, "width", "0"));
        var h = real(gmvex_svg_get_attr(attrs, "height", "0"));
        if (ds_map_exists(attrs, "rx") || ds_map_exists(attrs, "ry")) {
            var rx = real(gmvex_svg_get_attr(attrs, "rx", "0"));
            var ry_str = gmvex_svg_get_attr(attrs, "ry", "-1");
            var ry = (ry_str == "-1") ? -1 : real(ry_str);
            gmvex_path_add_rounded_rect(path, xx, yy, w, h, rx, ry);
        } else {
            gmvex_path_add_rect(path, xx, yy, w, h);
        }
    } else if (tag == "circle") {
        var cx = real(gmvex_svg_get_attr(attrs, "cx", "0"));
        var cy = real(gmvex_svg_get_attr(attrs, "cy", "0"));
        var r  = real(gmvex_svg_get_attr(attrs, "r", "0"));
        gmvex_path_add_circle(path, cx, cy, r);
    } else if (tag == "ellipse") {
        var cx = real(gmvex_svg_get_attr(attrs, "cx", "0"));
        var cy = real(gmvex_svg_get_attr(attrs, "cy", "0"));
        var rx = real(gmvex_svg_get_attr(attrs, "rx", "0"));
        var ry = real(gmvex_svg_get_attr(attrs, "ry", "0"));
        gmvex_path_add_ellipse(path, cx, cy, rx, ry);
    } else if (tag == "line") {
        var x1 = real(gmvex_svg_get_attr(attrs, "x1", "0"));
        var y1 = real(gmvex_svg_get_attr(attrs, "y1", "0"));
        var x2 = real(gmvex_svg_get_attr(attrs, "x2", "0"));
        var y2 = real(gmvex_svg_get_attr(attrs, "y2", "0"));
        gmvex_path_add_line(path, x1, y1, x2, y2);
    } else if (tag == "polyline" || tag == "polygon") {
        var points_str = gmvex_svg_get_attr(attrs, "points", "");
		var points = [];
		var pts_buf = buffer_create(string_byte_length(points_str) + 1, buffer_fixed, 1);
		buffer_write(pts_buf, buffer_text, points_str);
		var pts_str_obj = { buf: pts_buf, size: string_byte_length(points_str) };
		var pos = 1;
		while (pos <= pts_str_obj.size) {
		    var nx = gmvex_svg_scan_number(pts_str_obj, pos);
		    if (is_undefined(nx.value)) break;
		    var ny = gmvex_svg_scan_number(pts_str_obj, nx.pos);
		    if (is_undefined(ny.value)) break;
		    array_push(points, [nx.value, ny.value]);
		    pos = ny.pos;
		}
		buffer_delete(pts_buf);
        if (tag == "polygon") gmvex_path_add_polygon(path, points);
        else gmvex_path_add_polyline(path, points);
    } else {
        has_geometry = false;
    }

    if (!has_geometry) return undefined;

    if (ds_map_exists(attrs, "transform")) {
        var shape_transform_str = attrs[? "transform"];
        var shape_m = gmvex_svg_parse_transform_attr(shape_transform_str);
        path.tox = 0;
        path.toy = 0;
        path.tmatrix = shape_m;
    }

    var fill_str = gmvex_svg_get_attr(attrs, "fill", "black", style_map);
    var element_opacity = real(gmvex_svg_get_attr(attrs, "opacity", "1", style_map));

    var fill_gradient = undefined;
    var fill_result;
    if (string_copy(fill_str, 1, 4) == "url(" && !is_undefined(gradient_map)) {
        var grad_id = gmvex_svg_extract_url_id(fill_str);
        if (ds_map_exists(gradient_map, grad_id)) {
            fill_gradient = gradient_map[? grad_id];
        }
        fill_result = { is_none: false, color: default_color };
    } else {
        fill_result = gmvex_svg_parse_color(fill_str, default_color);
    }
    var fill_opacity = real(gmvex_svg_get_attr(attrs, "fill-opacity", "1", style_map)) * element_opacity;

    var stroke_str = gmvex_svg_get_attr(attrs, "stroke", "none", style_map);
    var stroke_gradient = undefined;
    var stroke_result;
    if (string_copy(stroke_str, 1, 4) == "url(" && !is_undefined(gradient_map)) {
        var grad_id2 = gmvex_svg_extract_url_id(stroke_str);
        if (ds_map_exists(gradient_map, grad_id2)) {
            stroke_gradient = gradient_map[? grad_id2];
        }
        stroke_result = { is_none: false, color: default_color };
    } else {
        stroke_result = gmvex_svg_parse_color(stroke_str, default_color);
    }
    var stroke_opacity = real(gmvex_svg_get_attr(attrs, "stroke-opacity", "1", style_map)) * element_opacity;
    var stroke_width = real(gmvex_svg_get_attr(attrs, "stroke-width", "1", style_map));

    var fill_rule_str = gmvex_svg_get_attr(attrs, "fill-rule", "nonzero", style_map);
    gmvex_path_set_winding(path, (fill_rule_str == "evenodd") ? gmvex_winding.EVENODD : gmvex_winding.NONZERO);

    var linecap_str = gmvex_svg_get_attr(attrs, "stroke-linecap", "butt", style_map);
    var cap_mode = gmvex_cap.BUTT;
    if (linecap_str == "round") cap_mode = gmvex_cap.ROUND;
    else if (linecap_str == "square") cap_mode = gmvex_cap.SQUARE;

    var linejoin_str = gmvex_svg_get_attr(attrs, "stroke-linejoin", "miter", style_map);
    var join_mode = gmvex_join.MITER;
    if (linejoin_str == "round") join_mode = gmvex_join.ROUND;
    else if (linejoin_str == "bevel") join_mode = gmvex_join.BEVEL;

    var dash_array = [];
	var dash_str = gmvex_svg_get_attr(attrs, "stroke-dasharray", "", style_map);
	if (dash_str != "" && dash_str != "none") {
	    var dash_buf = buffer_create(string_byte_length(dash_str) + 1, buffer_fixed, 1);
	    buffer_write(dash_buf, buffer_text, dash_str);
	    var dash_str_obj = { buf: dash_buf, size: string_byte_length(dash_str) };
	    var pos = 1;
	    while (pos <= dash_str_obj.size) {
	        var num = gmvex_svg_scan_number(dash_str_obj, pos);
	        if (is_undefined(num.value)) break;
	        array_push(dash_array, num.value);
	        pos = num.pos;
	    }
	    buffer_delete(dash_buf);
	}
    var dash_offset = real(gmvex_svg_get_attr(attrs, "stroke-dashoffset", "0", style_map));

    if (ds_map_exists(attrs, "clip-path") && !is_undefined(id_map)) {
        path = gmvex_svg_resolve_clip_path(path, attrs[? "clip-path"], id_map, default_color, gradient_map, depth + 1, class_map);
    }

    if (ds_map_exists(attrs, "mask") && !is_undefined(id_map)) {
        gmvex_svg_resolve_mask(path, attrs[? "mask"], id_map, default_color, gradient_map, depth + 1, class_map);
    }

    return {
        path: path,
        has_fill: !fill_result.is_none,
        fill_color: fill_result.color,
        fill_alpha: fill_opacity,
        fill_gradient: fill_gradient,
        has_stroke: !stroke_result.is_none,
        stroke_color: stroke_result.color,
        stroke_alpha: stroke_opacity,
        stroke_gradient: stroke_gradient,
        stroke_width: stroke_width,
        dash_array: dash_array,
        dash_offset: dash_offset,
        cap_mode: cap_mode,
        join_mode: join_mode
    };
}

function gmvex_svg_walk_element(element, results, default_color) {
    var gradient_map = ds_map_create();
    gmvex_svg_collect_gradients(element, gradient_map);
    var id_map = ds_map_create();
    gmvex_svg_collect_ids(element, id_map);
    var class_map = ds_map_create();
    gmvex_svg_collect_css_classes(element, class_map);

    gmvex_svg_walk_element_inner(element, results, default_color, gradient_map, id_map, class_map);

    ds_map_destroy(gradient_map);
    ds_map_destroy(id_map);
    ds_map_destroy(class_map);
}

function gmvex_svg_walk_element_inner(element, results, default_color, gradient_map, id_map, class_map) {
    if (element.tag == "g" || element.tag == "svg") {
        for (var i = 0; i < array_length(element.children); i++) {
            gmvex_svg_walk_element_inner(element.children[i], results, default_color, gradient_map, id_map, class_map);
        }
        return;
    }
    var result = gmvex_svg_element_to_result(element, default_color, gradient_map, id_map, 0, class_map);
    if (!is_undefined(result)) array_push(results, result);
}

function gmvex_svg_walk_collect(element, group, results, default_color, gradient_map = undefined, id_map = undefined, font_map = undefined, default_font = undefined, class_map = undefined) {
    if (element.tag == "g" || element.tag == "svg") {
        if (ds_map_exists(element.attributes, "transform")) {
            var m = gmvex_svg_parse_transform_attr(element.attributes[? "transform"]);
            group.gtmatrix = m;
        }

        var has_clip = !is_undefined(id_map) && ds_map_exists(element.attributes, "clip-path");
        var has_mask = !is_undefined(id_map) && ds_map_exists(element.attributes, "mask");

        if (has_clip || has_mask) {
            var clip_str = has_clip ? element.attributes[? "clip-path"] : "";
            var mask_str = has_mask ? element.attributes[? "mask"] : "";
            var resolved = gmvex_svg_resolve_group_clip_mask(element, default_color, gradient_map, id_map, font_map, default_font, class_map, clip_str, mask_str);
            for (var i = 0; i < array_length(resolved); i++) {
                gmvex_group_add_path(group, resolved[i].path);
                array_push(results, resolved[i]);
            }
            return;
        }

        gmvex_svg_walk_collect_children(element, group, results, default_color, gradient_map, id_map, font_map, default_font, class_map);
    }
}

function gmvex_svg_import(filename, default_color = c_black, font_map = undefined, default_font = undefined) {
    if (!file_exists(filename)) {
        show_debug_message("gmvex_svg_import: file not found - " + filename);
        return { group: undefined, results: [], doc_width: undefined, doc_height: undefined };
    }
    var file = file_text_open_read(filename);
    var content = "";
    while (!file_text_eof(file)) {
        content += file_text_read_string(file);
        file_text_readln(file);
        content += "\n";
    }
    file_text_close(file);

    var root = gmvex_svg_parse_xml(content);
    if (is_undefined(root)) {
        show_debug_message("gmvex_svg_import: failed to parse XML - " + filename);
        return { group: undefined, results: [], doc_width: undefined, doc_height: undefined };
    }

    var gradient_map = ds_map_create();
    gmvex_svg_collect_gradients(root, gradient_map);

    var id_map = ds_map_create();
    gmvex_svg_collect_ids(root, id_map);

    var class_map = ds_map_create();
    gmvex_svg_collect_css_classes(root, class_map);

    var results = [];
    var root_group = gmvex_group_create();

    gmvex_svg_walk_collect(root, root_group, results, default_color, gradient_map, id_map, font_map, default_font, class_map);
    gmvex_group_resolve_transforms(root_group);

    var doc_width = undefined;
    var doc_height = undefined;

    if (ds_map_exists(root.attributes, "width")) {
        doc_width = gmvex_svg_parse_length(root.attributes[? "width"]);
    }
    if (ds_map_exists(root.attributes, "height")) {
        doc_height = gmvex_svg_parse_length(root.attributes[? "height"]);
    }
    if ((is_undefined(doc_width) || is_undefined(doc_height)) && ds_map_exists(root.attributes, "viewBox")) {
	    var viewbox_str = root.attributes[? "viewBox"];
	    var vb_parts = [];
	    var vb_buf = buffer_create(string_byte_length(viewbox_str) + 1, buffer_fixed, 1);
	    buffer_write(vb_buf, buffer_text, viewbox_str);
	    var vb_str_obj = { buf: vb_buf, size: string_byte_length(viewbox_str) };
	    var pos = 1;
	    while (pos <= vb_str_obj.size) {
	        var num = gmvex_svg_scan_number(vb_str_obj, pos);
	        if (is_undefined(num.value)) break;
	        array_push(vb_parts, num.value);
	        pos = num.pos;
	    }
	    buffer_delete(vb_buf);
	    if (array_length(vb_parts) >= 4) {
	        if (is_undefined(doc_width)) doc_width = vb_parts[2];
	        if (is_undefined(doc_height)) doc_height = vb_parts[3];
	    }
	}

    return { group: root_group, results: results, doc_width: doc_width, doc_height: doc_height };
}

function gmvex_svg_matrix_multiply(m1, m2) {
    var a1=m1[0], b1=m1[1], c1=m1[2], d1=m1[3], e1=m1[4], f1=m1[5];
    var a2=m2[0], b2=m2[1], c2=m2[2], d2=m2[3], e2=m2[4], f2=m2[5];
    return [
        a1*a2 + c1*b2,
        b1*a2 + d1*b2,
        a1*c2 + c1*d2,
        b1*c2 + d1*d2,
        a1*e2 + c1*f2 + e1,
        b1*e2 + d1*f2 + f1
    ];
}

function gmvex_svg_matrix_identity() {
    return [1, 0, 0, 1, 0, 0];
}

function gmvex_svg_parse_transform_function(str, pos) {
    var buf = str.buf, size = str.size;
    var name_start = pos;
    while (pos <= size && gmvex_buf_char_at(buf, size, pos) != "(") pos++;
    if (pos > size) return { matrix: undefined, pos: name_start };
    var name = string_trim(gmvex_buf_copy(buf, size, name_start, pos - name_start));
    pos++; // skip '('

    var arg_start = pos;
    while (pos <= size && gmvex_buf_char_at(buf, size, pos) != ")") pos++;
    var args_str = gmvex_buf_copy(buf, size, arg_start, pos - arg_start);
    pos++; // skip ')'

    var parts = [];
    var cur = "";
    var alen = string_length(args_str);
    for (var i = 1; i <= alen; i++) {
        var c = string_char_at(args_str, i);
        if (c == "," || c == " " || c == "\n" || c == "\t") {
            if (string_length(cur) > 0) { array_push(parts, real(cur)); cur = ""; }
        } else {
            cur += c;
        }
    }
    if (string_length(cur) > 0) array_push(parts, real(cur));

    var n = array_length(parts);
    var m = gmvex_svg_matrix_identity();

    if (name == "translate") {
        var tx = (n >= 1) ? parts[0] : 0;
        var ty = (n >= 2) ? parts[1] : 0;
        m = [1, 0, 0, 1, tx, ty];
    } else if (name == "scale") {
        var sx = (n >= 1) ? parts[0] : 1;
        var sy = (n >= 2) ? parts[1] : sx;
        m = [sx, 0, 0, sy, 0, 0];
    } else if (name == "rotate") {
        var deg = (n >= 1) ? parts[0] : 0;
        var rad = degtorad(deg);
        var cs = cos(rad), sn = sin(rad);
        if (n >= 3) {
            var cx = parts[1], cy = parts[2];
            var t1 = [1,0,0,1,-cx,-cy];
            var r  = [cs,sn,-sn,cs,0,0];
            var t2 = [1,0,0,1,cx,cy];
            m = gmvex_svg_matrix_multiply(t2, gmvex_svg_matrix_multiply(r, t1));
        } else {
            m = [cs, sn, -sn, cs, 0, 0];
        }
    } else if (name == "matrix") {
	    if (n >= 6) m = [parts[0], parts[1], parts[2], parts[3], parts[4], parts[5]];
	} else if (name == "skewX") {
	    var deg = (n >= 1) ? parts[0] : 0;
	    m = [1, 0, tan(degtorad(deg)), 1, 0, 0];
	} else if (name == "skewY") {
	    var deg = (n >= 1) ? parts[0] : 0;
	    m = [1, tan(degtorad(deg)), 0, 1, 0, 0];
	} else {
	    return { matrix: gmvex_svg_matrix_identity(), pos: pos };
	}

    return { matrix: m, pos: pos };
}

function gmvex_svg_parse_transform_attr(value) {
    var result = gmvex_svg_matrix_identity();
    var buf = buffer_create(string_byte_length(value) + 1, buffer_fixed, 1);
    buffer_write(buf, buffer_text, value);
    var str_obj = { buf: buf, size: string_byte_length(value) };
    var pos = 1;
    while (pos <= str_obj.size) {
        pos = gmvex_svg_skip_whitespace(str_obj, pos);
        if (pos > str_obj.size) break;
        var parsed = gmvex_svg_parse_transform_function(str_obj, pos);
        if (is_undefined(parsed.matrix)) break;
        result = gmvex_svg_matrix_multiply(result, parsed.matrix);
        pos = parsed.pos;
    }
    buffer_delete(buf);
    return result;
}

function gmvex_svg_decompose_matrix(m) {
    var a = m[0], b = m[1], c = m[2], d = m[3], e = m[4], f = m[5];

    var xscale = sqrt(a*a + b*b);
    var rot = radtodeg(arctan2(b, a));

    var col_dot = a*c + b*d;
    var col_mag_product = max(xscale * sqrt(c*c + d*d), 0.000001);
    var has_shear = abs(col_dot / col_mag_product) > 0.001;

    var det = a*d - b*c;
    var yscale = (xscale == 0) ? 0 : det / xscale; // signed, negative means reflection

    return { x: e, y: f, rot: rot, xscale: xscale, yscale: yscale, has_shear: has_shear };
}

function gmvex_svg_walk_element_grouped(element, default_color) {
    var gradient_map = ds_map_create();
    gmvex_svg_collect_gradients(element, gradient_map);
    var id_map = ds_map_create();
    gmvex_svg_collect_ids(element, id_map);
    var class_map = ds_map_create();
    gmvex_svg_collect_css_classes(element, class_map);

    var result = gmvex_svg_walk_element_grouped_inner(element, default_color, gradient_map, id_map, class_map);

    ds_map_destroy(gradient_map);
    ds_map_destroy(id_map);
    ds_map_destroy(class_map);
    return result;
}

function gmvex_svg_walk_element_grouped_inner(element, default_color, gradient_map, id_map, class_map) {
    if (element.tag == "g" || element.tag == "svg") {
        var group = gmvex_group_create();
        if (ds_map_exists(element.attributes, "transform")) {
            var transform_str = element.attributes[? "transform"];
            var m = gmvex_svg_parse_transform_attr(transform_str);
            group.gtmatrix = m;
        }
        for (var i = 0; i < array_length(element.children); i++) {
            var child = element.children[i];
            if (child.tag == "g" || child.tag == "svg") {
                var child_group = gmvex_svg_walk_element_grouped_inner(child, default_color, gradient_map, id_map, class_map);
                gmvex_group_add_group(group, child_group);
            } else {
                var result = gmvex_svg_element_to_result(child, default_color, gradient_map, id_map, 0, class_map);
                if (!is_undefined(result)) gmvex_group_add_path(group, result.path);
            }
        }
        return group;
    }
    return undefined;
}

function gmvex_svg_parse_length(value) {
    var num_part = value;
    var unit = "";
    var len = string_length(value);
    var i = len;
    while (i >= 1 && !gmvex_svg_is_digit(string_char_at(value, i)) && string_char_at(value, i) != ".") {
        i--;
    }
    if (i < len) {
        num_part = string_copy(value, 1, i);
        unit = string_copy(value, i + 1, len - i);
    }
    var n = real(num_part);
    unit = string_trim(unit);

    if (unit == "" || unit == "px") return n;
    if (unit == "pt") return n * (96 / 72);
    if (unit == "pc") return n * (96 / 6);
    if (unit == "in") return n * 96;
    if (unit == "mm") return n * (96 / 25.4);
    if (unit == "cm") return n * (96 / 2.54);
    return n; // unrecognized unit, should be trated as pixel
}

function gmvex_svg_parse_style_attr(style_str) {
    var result = ds_map_create();
    var declarations = string_split(style_str, ";");
    for (var i = 0; i < array_length(declarations); i++) {
        var decl = string_trim(declarations[i]);
        if (decl == "") continue;
        var colon_pos = string_pos(":", decl);
        if (colon_pos == 0) continue;
        var prop = string_trim(string_copy(decl, 1, colon_pos - 1));
        var value = string_trim(string_copy(decl, colon_pos + 1, string_length(decl) - colon_pos));
        result[? prop] = value;
    }
    return result;
}

function gmvex_svg_collect_gradients(element, gradient_map) {
    if (element.tag == "linearGradient" || element.tag == "radialGradient") {
        var attrs = element.attributes;
        if (ds_map_exists(attrs, "id")) {
            var stops = [];
            for (var i = 0; i < array_length(element.children); i++) {
                var child = element.children[i];
                if (child.tag != "stop") continue;
                var c_attrs = child.attributes;
                var c_style = ds_map_exists(c_attrs, "style") ? gmvex_svg_parse_style_attr(c_attrs[? "style"]) : undefined;

                var offset_str = gmvex_svg_get_attr(c_attrs, "offset", "0", c_style);
                var offset = 0;
                if (string_char_at(offset_str, string_length(offset_str)) == "%") {
                    offset = real(string_copy(offset_str, 1, string_length(offset_str) - 1)) / 100;
                } else {
                    offset = real(offset_str);
                }

                var color_str = gmvex_svg_get_attr(c_attrs, "stop-color", "black", c_style);
                var color_result = gmvex_svg_parse_color(color_str, c_black);
                var stop_opacity = real(gmvex_svg_get_attr(c_attrs, "stop-opacity", "1", c_style));

                array_push(stops, [offset, color_result.color, stop_opacity]);
            }

            var grad_transform = gmvex_svg_matrix_identity();
            if (ds_map_exists(attrs, "gradientTransform")) {
                grad_transform = gmvex_svg_parse_transform_attr(attrs[? "gradientTransform"]);
            }

            gradient_map[? attrs[? "id"]] = {
                type: (element.tag == "linearGradient") ? gmvex_gradient.LINEAR : gmvex_gradient.RADIAL,
                x1: real(gmvex_svg_get_attr(attrs, "x1", "0")),
                y1: real(gmvex_svg_get_attr(attrs, "y1", "0")),
                x2: real(gmvex_svg_get_attr(attrs, "x2", "1")),
                y2: real(gmvex_svg_get_attr(attrs, "y2", "0")),
                cx: real(gmvex_svg_get_attr(attrs, "cx", "0.5")),
                cy: real(gmvex_svg_get_attr(attrs, "cy", "0.5")),
                r: real(gmvex_svg_get_attr(attrs, "r", "0.5")),
                units: gmvex_svg_get_attr(attrs, "gradientUnits", "objectBoundingBox"),
                transform: grad_transform,
                stops: stops
            };
        }
    }
    for (var i = 0; i < array_length(element.children); i++) {
        gmvex_svg_collect_gradients(element.children[i], gradient_map);
    }
}

function gmvex_svg_compute_gradient_coords(path, gradient) {
    if (path.dirty) gmvex_path_rebuild(path);
    var bbox = path.bbox;
    var bw = bbox[2] - bbox[0];
    var bh = bbox[3] - bbox[1];

    if (gradient.type == gmvex_gradient.LINEAR) {
        var p0x, p0y, p1x, p1y;
        if (gradient.units == "userSpaceOnUse") {
            p0x = gradient.x1; p0y = gradient.y1;
            p1x = gradient.x2; p1y = gradient.y2;
        } else {
            p0x = bbox[0] + gradient.x1 * bw; p0y = bbox[1] + gradient.y1 * bh;
            p1x = bbox[0] + gradient.x2 * bw; p1y = bbox[1] + gradient.y2 * bh;
        }
        var t0 = gmvex_svg_matrix_apply_point(gradient.transform, p0x, p0y);
        var t1 = gmvex_svg_matrix_apply_point(gradient.transform, p1x, p1y);
        return { p0x: t0.x, p0y: t0.y, p1x: t1.x, p1y: t1.y };
    } else {
        var rcx, rcy, rr;
        if (gradient.units == "userSpaceOnUse") {
            rcx = gradient.cx; rcy = gradient.cy; rr = gradient.r;
        } else {
            rcx = bbox[0] + gradient.cx * bw; rcy = bbox[1] + gradient.cy * bh;
            rr = gradient.r * max(bw, bh);
        }
        var tc = gmvex_svg_matrix_apply_point(gradient.transform, rcx, rcy);
        return { p0x: tc.x, p0y: tc.y, p1x: rr, p1y: 0 };
    }
}

function gmvex_svg_draw_fill(s) {
    if (!s.has_fill) return;

    var has_mask = variable_struct_exists(s.path, "mask_path") && !is_undefined(s.path.mask_path);

    if (is_undefined(s.fill_gradient)) {
        if (has_mask) gmvex_fill_draw_masked(s.path, s.fill_color, s.fill_alpha);
        else gmvex_fill_draw(s.path, s.fill_color, s.fill_alpha);
        return;
    }

    var g = s.fill_gradient;
    var coords = gmvex_svg_compute_gradient_coords(s.path, g);
    if (has_mask) gmvex_fill_draw_gradient_masked(s.path, g.type, coords.p0x, coords.p0y, coords.p1x, coords.p1y, g.stops);
    else gmvex_fill_draw_gradient(s.path, g.type, coords.p0x, coords.p0y, coords.p1x, coords.p1y, g.stops);
}

function gmvex_svg_draw_all(imported) {
    var n = array_length(imported.results);
    for (var i = 0; i < n; i++) {
        gmvex_svg_draw_fill(imported.results[i]);
        gmvex_svg_draw_stroke(imported.results[i]);
    }
}

function gmvex_svg_collect_ids(element, id_map) {
    if (ds_map_exists(element.attributes, "id")) {
        id_map[? element.attributes[? "id"]] = element;
    }
    for (var i = 0; i < array_length(element.children); i++) {
        gmvex_svg_collect_ids(element.children[i], id_map);
    }
}

function gmvex_svg_resolve_use(element, group, results, default_color, gradient_map, id_map, depth, class_map) {
    if (depth >= 16) {
        show_debug_message("gmvex_svg_import: <use> nesting exceeded safe depth (16) - likely a circular reference, stopping recursion here.");
        return;
    }

    var attrs = element.attributes;
    var href = "";
    if (ds_map_exists(attrs, "href")) href = attrs[? "href"];
    else if (ds_map_exists(attrs, "xlink:href")) href = attrs[? "xlink:href"];

    if (string_char_at(href, 1) != "#") return;
    var ref_id = string_copy(href, 2, string_length(href) - 1);

    if (!ds_map_exists(id_map, ref_id)) {
        show_debug_message("gmvex_svg_import: <use> references unknown id '" + ref_id + "' - skipped.");
        return;
    }
    var referenced = id_map[? ref_id];

    var use_x = real(gmvex_svg_get_attr(attrs, "x", "0"));
    var use_y = real(gmvex_svg_get_attr(attrs, "y", "0"));
    var own_transform_str = gmvex_svg_get_attr(attrs, "transform", "");
    var combined_transform_str = "translate(" + string(use_x) + "," + string(use_y) + ") " + own_transform_str;

    var use_group = gmvex_group_create();
    var m = gmvex_svg_parse_transform_attr(combined_transform_str);
    use_group.gtmatrix = m;
    gmvex_group_add_group(group, use_group);

    if (referenced.tag == "g" || referenced.tag == "symbol" || referenced.tag == "svg") {
        for (var i = 0; i < array_length(referenced.children); i++) {
            var child = referenced.children[i];
            if (child.tag == "use") {
                gmvex_svg_resolve_use(child, use_group, results, default_color, gradient_map, id_map, depth + 1, class_map);
            } else if (child.tag == "g") {
                var child_group = gmvex_group_create();
                gmvex_group_add_group(use_group, child_group);
                gmvex_svg_walk_collect(child, child_group, results, default_color, gradient_map, id_map, undefined, undefined, class_map);
            } else {
                var result = gmvex_svg_element_to_result(child, default_color, gradient_map, id_map, 0, class_map);
                if (!is_undefined(result)) {
                    gmvex_group_add_path(use_group, result.path);
                    array_push(results, result);
                }
            }
        }
        if (ds_map_exists(referenced.attributes, "transform")) {
            var sm = gmvex_svg_parse_transform_attr(referenced.attributes[? "transform"]);
            var sdec = gmvex_svg_decompose_matrix(sm);
            var use_dec = gmvex_svg_decompose_matrix(use_group.gtmatrix);
            if (!sdec.has_shear && !use_dec.has_shear) {
                gmvex_group_set_transform(use_group, use_dec.x, use_dec.y, use_dec.rot + sdec.rot, use_dec.xscale * sdec.xscale, use_dec.yscale * sdec.yscale);
            }
        }
    } else {
        var result = gmvex_svg_element_to_result(referenced, default_color, gradient_map, id_map, 0, class_map);
        if (!is_undefined(result)) {
            gmvex_group_add_path(use_group, result.path);
            array_push(results, result);
        }
    }
}

function gmvex_svg_resolve_text(element, default_color, font_map, default_font) {
    var attrs = element.attributes;
    var style_map = ds_map_exists(attrs, "style") ? gmvex_svg_parse_style_attr(attrs[? "style"]) : undefined;

    var font_family = gmvex_svg_get_attr(attrs, "font-family", "", style_map);
    var font = undefined;
    if (!is_undefined(font_map) && ds_map_exists(font_map, font_family)) {
        font = font_map[? font_family];
    } else {
        font = default_font;
    }
    if (is_undefined(font)) {
        show_debug_message("gmvex_svg_import: <text> found but no font resolved (font-family='" + font_family + "', no matching font_map entry, no default_font supplied) - skipped.");
        return [];
    }

    var full_text = element.text_content;
    for (var i = 0; i < array_length(element.children); i++) {
        if (element.children[i].tag == "tspan") {
            full_text += element.children[i].text_content;
        }
    }
    full_text = string_trim(full_text);
    if (full_text == "") return [];

    var xx = real(gmvex_svg_get_attr(attrs, "x", "0"));
    var yy = real(gmvex_svg_get_attr(attrs, "y", "0"));
    var font_size = real(gmvex_svg_get_attr(attrs, "font-size", "16", style_map));

    var anchor_str = gmvex_svg_get_attr(attrs, "text-anchor", "start", style_map);
    var halign = gmvex_halign.LEFT;
    if (anchor_str == "middle") halign = gmvex_halign.CENTER;
    else if (anchor_str == "end") halign = gmvex_halign.RIGHT;

    var fill_str = gmvex_svg_get_attr(attrs, "fill", "black", style_map);
    var fill_result = gmvex_svg_parse_color(fill_str, default_color);

    var text_paths = gmvex_text_to_paths(font, full_text, font_size, xx, yy, { halign: halign });

    var results = [];
    for (var i = 0; i < array_length(text_paths); i++) {
        array_push(results, {
            path: text_paths[i].path,
            has_fill: !fill_result.is_none,
            fill_color: fill_result.color,
            fill_alpha: 1,
            fill_gradient: undefined,
            has_stroke: false,
            stroke_color: c_black,
            stroke_alpha: 1,
            stroke_gradient: undefined,
            stroke_width: 1,
            dash_array: [],
            dash_offset: 0,
            cap_mode: gmvex_cap.BUTT,
            join_mode: gmvex_join.MITER
        });
    }
    return results;
}

function gmvex_svg_extract_url_id(value) {
    if (string_copy(value, 1, 4) != "url(") return "";
    var id_start = string_pos("#", value) + 1;
    var id_end = string_pos(")", value);
    if (id_start <= 1 || id_end == 0) return "";
    return string_copy(value, id_start, id_end - id_start);
}

function gmvex_svg_resolve_clip_path(target_path, clip_path_str, id_map, default_color, gradient_map, depth = 0, class_map = undefined) {
    var clip_id = gmvex_svg_extract_url_id(clip_path_str);
    if (clip_id == "" || !ds_map_exists(id_map, clip_id)) return target_path;

    var clip_element = id_map[? clip_id];
    if (clip_element.tag != "clipPath" || array_length(clip_element.children) == 0) return target_path;

    var units = gmvex_svg_get_attr(clip_element.attributes, "clipPathUnits", "userSpaceOnUse");
    var use_obb = (units == "objectBoundingBox");
    var bx0 = 0, by0 = 0, bw = 1, bh = 1;
    if (use_obb) {
        if (target_path.dirty) gmvex_path_rebuild(target_path);
        var tbbox = target_path.bbox;
        bx0 = tbbox[0]; by0 = tbbox[1];
        bw = tbbox[2] - tbbox[0]; bh = tbbox[3] - tbbox[1];
    }

    var clip_shape_path = gmvex_svg_build_clip_shape(clip_element, clip_id, default_color, gradient_map, id_map, depth, class_map, bx0, by0, bw, bh, use_obb);
    if (is_undefined(clip_shape_path)) return target_path;

    gmvex_path_apply_position(target_path);
    gmvex_path_apply_rotation(target_path);
    gmvex_path_apply_scale(target_path);
    gmvex_svg_shift_flat_subpaths(clip_shape_path, 0.0173, 0.0091);

    var clipped_path = gmvex_path_boolean(target_path, clip_shape_path, gmvex_bool.INTERSECTION);
    gmvex_path_destroy(target_path);
    gmvex_path_destroy(clip_shape_path);
    return clipped_path;
}

function gmvex_svg_resolve_mask(target_path, mask_str, id_map, default_color, gradient_map, depth = 0, class_map = undefined) {
    var mask_id = gmvex_svg_extract_url_id(mask_str);
    if (mask_id == "" || !ds_map_exists(id_map, mask_id)) return;

    var mask_element = id_map[? mask_id];
    if (mask_element.tag != "mask" || array_length(mask_element.children) == 0) return;

    var content_units = gmvex_svg_get_attr(mask_element.attributes, "maskContentUnits", "userSpaceOnUse");
    var use_obb = (content_units == "objectBoundingBox");
    var bx0 = 0, by0 = 0, bw = 1, bh = 1;
    if (use_obb) {
        if (target_path.dirty) gmvex_path_rebuild(target_path);
        var bbox = target_path.bbox;
        bx0 = bbox[0]; by0 = bbox[1];
        bw = bbox[2] - bbox[0]; bh = bbox[3] - bbox[1];
    }

    var combined = gmvex_svg_build_clip_shape(mask_element, mask_id, default_color, gradient_map, id_map, depth, class_map, bx0, by0, bw, bh, use_obb);
    if (is_undefined(combined)) return;

    gmvex_path_set_mask(target_path, combined);
}

function gmvex_svg_draw_stroke(s) {
    if (!s.has_stroke) return;

    s.path.dash_array = s.dash_array;
    s.path.dash_offset = s.dash_offset;

    var has_mask = variable_struct_exists(s.path, "mask_path") && !is_undefined(s.path.mask_path);

    if (!is_undefined(s.stroke_gradient)) {
        var g = s.stroke_gradient;
        var coords = gmvex_svg_compute_gradient_coords(s.path, g);
        if (has_mask) {
            gmvex_stroke_draw_gradient_masked(s.path, s.stroke_width, g.type, coords.p0x, coords.p0y, coords.p1x, coords.p1y, g.stops, s.join_mode, s.cap_mode);
        } else {
            gmvex_stroke_draw_gradient(s.path, s.stroke_width, g.type, coords.p0x, coords.p0y, coords.p1x, coords.p1y, g.stops, s.join_mode, s.cap_mode);
        }
        return;
    }

    if (has_mask) {
        gmvex_stroke_draw_masked(s.path, s.stroke_width, s.stroke_color, s.stroke_alpha, s.join_mode, s.cap_mode);
    } else {
        gmvex_stroke_draw(s.path, s.stroke_width, s.stroke_color, s.stroke_alpha, s.join_mode, s.cap_mode);
    }
}

function gmvex_svg_merge_paths_flat(paths) {
	return gmvex_path_merge(paths);
}

function gmvex_svg_shift_flat_subpaths(path, dx, dy) {
    for (var s = 0; s < array_length(path.flat_subpaths); s++) {
        var pts = path.flat_subpaths[s].points;
        for (var p = 0; p < array_length(pts); p++) { pts[p][0] += dx; pts[p][1] += dy; }
    }
    path.bbox[0] += dx; path.bbox[2] += dx;
    path.bbox[1] += dy; path.bbox[3] += dy;
}

function gmvex_svg_matrix_apply_point(m, x, y) {
    return {
        x: m[0]*x + m[2]*y + m[4],
        y: m[1]*x + m[3]*y + m[5]
    };
}

function gmvex_svg_parse_css_classes(css_text, class_map) {
    var len = string_length(css_text);
    var pos = 1;
    while (pos <= len) {
        var dot_pos = string_pos_ext(".", css_text, pos);
        if (dot_pos == 0) break;

        var name_start = dot_pos + 1;
        var brace_pos = string_pos_ext("{", css_text, name_start);
        if (brace_pos == 0) break;

        var selector = string_trim(string_copy(css_text, name_start, brace_pos - name_start));
        if (string_pos(" ", selector) != 0 || string_pos(",", selector) != 0 || selector == "") {
            pos = brace_pos + 1;
            continue;
        }

        var close_brace = string_pos_ext("}", css_text, brace_pos);
        if (close_brace == 0) break;

        var body = string_copy(css_text, brace_pos + 1, close_brace - brace_pos - 1);
        var props = gmvex_svg_parse_style_attr(body);

        if (!ds_map_exists(class_map, selector)) {
            class_map[? selector] = props;
        } else {
            var existing = class_map[? selector];
            var keys = ds_map_keys_to_array(props);
            for (var k = 0; k < array_length(keys); k++) {
                existing[? keys[k]] = props[? keys[k]];
            }
        }

        pos = close_brace + 1;
    }
}

function gmvex_svg_collect_css_classes(element, class_map) {
    if (element.tag == "style") {
        gmvex_svg_parse_css_classes(element.text_content, class_map);
    }
    for (var i = 0; i < array_length(element.children); i++) {
        gmvex_svg_collect_css_classes(element.children[i], class_map);
    }
}

function gmvex_svg_build_clip_shape(source_element, source_id, default_color, gradient_map, id_map, depth, class_map, bx0, by0, bw, bh, use_obb) {
    var child_paths = [];
    var winding_counts = [0, 0];
    var n = array_length(source_element.children);
    for (var i = 0; i < n; i++) {
        var child_result = gmvex_svg_element_to_result(source_element.children[i], default_color, gradient_map, id_map, depth, class_map);
        if (is_undefined(child_result)) continue;
        var cp = child_result.path;
        winding_counts[cp.winding] += 1;
        gmvex_path_apply_transform_all(cp);
        if (use_obb) {
            gmvex_path_set_transform(cp, 0, 0, 0, bw, bh);
            gmvex_path_apply_scale(cp);
            gmvex_path_set_transform(cp, bx0, by0, 0, 1, 1);
            gmvex_path_apply_position(cp);
        }
        array_push(child_paths, cp);
    }

    var shape_path = gmvex_svg_merge_paths_flat(child_paths);
    if (winding_counts[0] > 0 && winding_counts[1] > 0) {
        show_debug_message("gmvex_svg_import: clip/mask source '" + source_id + "' has children with different fill-rule values - not preserved when merging, result uses nonzero winding.");
    }
    return shape_path;
}

function gmvex_svg_walk_collect_children(element, group, results, default_color, gradient_map, id_map, font_map, default_font, class_map) {
    for (var i = 0; i < array_length(element.children); i++) {
        var child = element.children[i];
        if (child.tag == "use" && !is_undefined(id_map)) {
            gmvex_svg_resolve_use(child, group, results, default_color, gradient_map, id_map, 0, class_map);
        } else if (child.tag == "text") {
            var text_results = gmvex_svg_resolve_text(child, default_color, font_map, default_font);
            for (var j = 0; j < array_length(text_results); j++) {
                gmvex_group_add_path(group, text_results[j].path);
                array_push(results, text_results[j]);
            }
        } else if (child.tag == "g") {
            var child_group = gmvex_group_create();
            gmvex_group_add_group(group, child_group);
            gmvex_svg_walk_collect(child, child_group, results, default_color, gradient_map, id_map, font_map, default_font, class_map);
        } else {
            var result = gmvex_svg_element_to_result(child, default_color, gradient_map, id_map, 0, class_map);
            if (!is_undefined(result)) {
                gmvex_group_add_path(group, result.path);
                array_push(results, result);
            }
        }
    }
}

function gmvex_svg_apply_group_clip(results_in, clip_path_str, default_color, gradient_map, id_map, class_map, depth = 0) {
    if (depth >= 16) {
        show_debug_message("gmvex_svg_import: clip-path nesting exceeded safe depth (16) on a <g> - likely a circular reference, clip-path left unapplied here.");
        return results_in;
    }
    var clip_id = gmvex_svg_extract_url_id(clip_path_str);
    if (clip_id == "" || !ds_map_exists(id_map, clip_id)) return results_in;

    var clip_element = id_map[? clip_id];
    if (clip_element.tag != "clipPath" || array_length(clip_element.children) == 0) return results_in;

    var units = gmvex_svg_get_attr(clip_element.attributes, "clipPathUnits", "userSpaceOnUse");
    if (units == "objectBoundingBox") {
        show_debug_message("gmvex_svg_import: clip-path with clipPathUnits=objectBoundingBox on a <g> is not supported yet (only userSpaceOnUse) - clip-path '" + clip_id + "' left unapplied.");
        return results_in;
    }

    var clip_shape_path = gmvex_svg_build_clip_shape(clip_element, clip_id, default_color, gradient_map, id_map, depth + 1, class_map, 0, 0, 1, 1, false);
    if (is_undefined(clip_shape_path)) return results_in;
    gmvex_svg_shift_flat_subpaths(clip_shape_path, 0.0173, 0.0091);

    for (var i = 0; i < array_length(results_in); i++) {
        var clipped = gmvex_path_boolean(results_in[i].path, clip_shape_path, gmvex_bool.INTERSECTION);
        gmvex_path_destroy(results_in[i].path);
        results_in[i].path = clipped;
    }
    gmvex_path_destroy(clip_shape_path);
    return results_in;
}

function gmvex_svg_apply_group_mask(results_in, mask_str, default_color, gradient_map, id_map, class_map, depth = 0) {
    if (depth >= 16) {
        show_debug_message("gmvex_svg_import: mask nesting exceeded safe depth (16) on a <g> - likely a circular reference, mask left unapplied here.");
        return;
    }
    var mask_id = gmvex_svg_extract_url_id(mask_str);
    if (mask_id == "" || !ds_map_exists(id_map, mask_id)) return;

    var mask_element = id_map[? mask_id];
    if (mask_element.tag != "mask" || array_length(mask_element.children) == 0) return;

    var units = gmvex_svg_get_attr(mask_element.attributes, "maskContentUnits", "userSpaceOnUse");
    if (units == "objectBoundingBox") {
        show_debug_message("gmvex_svg_import: mask with maskContentUnits=objectBoundingBox on a <g> is not supported yet (only userSpaceOnUse) - mask '" + mask_id + "' left unapplied.");
        return;
    }

    var mask_shape_path = gmvex_svg_build_clip_shape(mask_element, mask_id, default_color, gradient_map, id_map, depth + 1, class_map, 0, 0, 1, 1, false);
    if (is_undefined(mask_shape_path)) return;

    for (var i = 0; i < array_length(results_in); i++) {
        gmvex_path_set_mask(results_in[i].path, gmvex_path_clone(mask_shape_path));
    }
    gmvex_path_destroy(mask_shape_path);
}

function gmvex_svg_resolve_group_clip_mask(group_element, default_color, gradient_map, id_map, font_map, default_font, class_map, clip_str, mask_str) {
    var temp_results = [];
    var temp_group = gmvex_group_create();
    gmvex_svg_walk_collect_children(group_element, temp_group, temp_results, default_color, gradient_map, id_map, font_map, default_font, class_map);
    gmvex_group_resolve_transforms(temp_group);

    if (clip_str != "") {
        temp_results = gmvex_svg_apply_group_clip(temp_results, clip_str, default_color, gradient_map, id_map, class_map);
    }
    if (mask_str != "") {
        gmvex_svg_apply_group_mask(temp_results, mask_str, default_color, gradient_map, id_map, class_map);
    }
    return temp_results;
}