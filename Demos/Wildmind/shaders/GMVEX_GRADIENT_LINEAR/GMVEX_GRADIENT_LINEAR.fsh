varying vec2 v_vLocalPos;

uniform vec2  u_gradStart;
uniform vec2  u_gradEnd;
uniform int   u_stopCount;
uniform float u_stopPos[32];
uniform vec4  u_stopColor[32];

void main() {
    vec2 dir = u_gradEnd - u_gradStart;
    float lenSq = dot(dir, dir);
    float t = 0.0;
    if (lenSq > 0.0001) t = dot(v_vLocalPos - u_gradStart, dir) / lenSq;
    t = clamp(t, 0.0, 1.0);

    vec4 color = u_stopColor[0];
    for (int i = 0; i < 7; i++) {
        if (i >= u_stopCount - 1) break;
        float p0 = u_stopPos[i];
        float p1 = u_stopPos[i + 1];
        if (t >= p0 && t <= p1) {
            float localT = (p1 > p0) ? (t - p0) / (p1 - p0) : 0.0;
            color = mix(u_stopColor[i], u_stopColor[i + 1], localT);
        }
    }
    gl_FragColor = color;
}