varying vec2 v_maskCoord;

uniform vec4 u_color;
uniform sampler2D u_mask;

void main() {
    vec4 mask_sample = texture2D(u_mask, v_maskCoord);
    float luminance = dot(mask_sample.rgb, vec3(0.299, 0.587, 0.114));
    gl_FragColor = vec4(u_color.rgb, u_color.a * luminance);
}