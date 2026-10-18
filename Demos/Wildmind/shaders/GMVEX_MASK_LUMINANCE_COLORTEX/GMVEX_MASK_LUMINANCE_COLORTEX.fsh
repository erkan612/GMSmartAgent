varying vec2 v_maskCoord;

uniform sampler2D u_mask;
uniform sampler2D u_colortex;

void main() {
    float luminance = dot(texture2D(u_mask, v_maskCoord).rgb, vec3(0.299, 0.587, 0.114));
    vec4 c = texture2D(u_colortex, v_maskCoord);
    gl_FragColor = vec4(c.rgb, c.a * luminance);
}