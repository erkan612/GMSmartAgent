varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main() {
    vec4 c = texture2D(gm_BaseTexture, v_vTexcoord);
    if (c.a > 0.0) c.rgb /= c.a;
    gl_FragColor = c;
}