attribute vec3 in_Position;
attribute vec4 in_Colour;
attribute vec2 in_TextureCoord;

varying vec2 v_maskCoord;

uniform vec4 u_bbox; // xmin, ymin, xmax, ymax

void main() {
    vec4 object_space_pos = vec4(in_Position.x, in_Position.y, in_Position.z, 1.0);
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;

    v_maskCoord = vec2(
        (in_Position.x - u_bbox.x) / (u_bbox.z - u_bbox.x),
        (in_Position.y - u_bbox.y) / (u_bbox.w - u_bbox.y)
    );
}