if (instance_exists(player)) {
    var _w = camera_get_view_width(camera);
    var _h = camera_get_view_height(camera);
    camera_set_view_pos(camera, clamp(player.x - _w / 2, 0, room_width - _w), clamp(player.y - _h / 2, 0, room_height - _h));
}