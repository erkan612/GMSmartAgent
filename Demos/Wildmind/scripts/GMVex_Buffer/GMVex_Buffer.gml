function gmvex_buf_char_at(buf, size, pos) {
    if (pos < 1 || pos > size) return "";
    return chr(buffer_peek(buf, pos - 1, buffer_u8));
}

function gmvex_buf_copy(buf, size, pos, count) {
    if (pos < 1 || count <= 0) return "";
    var _end = min(pos + count - 1, size);
    if (_end < pos) return "";
    var result = "";
    for (var i = pos; i <= _end; i++) {
        result += chr(buffer_peek(buf, i - 1, buffer_u8));
    }
    return result;
}

function gmvex_buf_pos_ext(needle, buf, size, start_pos) {
    var nlen = string_length(needle);
    if (nlen == 0 || start_pos > size) return 0;
    var first_char = string_char_at(needle, 1);
    for (var i = start_pos; i <= size - nlen + 1; i++) {
        if (gmvex_buf_char_at(buf, size, i) != first_char) continue;
        if (gmvex_buf_copy(buf, size, i, nlen) == needle) return i;
    }
    return 0;
}