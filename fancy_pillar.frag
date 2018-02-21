// automatically supplied by info-beamer
uniform sampler2D Texture;
varying vec2 TexCoord;
uniform vec4 Color;

// custom
uniform float time;

// -- config --
const float ROW_SPEED_MULT = 4.2;
const float VERT_SPEED_MULT = 0.12;
const float GRANULARITY  = 0.002;
const vec2 TEX_REPEAT_FACTOR = vec2(1.0, 2.3); // < 1 looks smeary, 1-2 looks nice
const vec2 TEX_RANDOM_SAMPLE = vec2(0.47);

// --------------------

float procrand(vec2 n) {
  return fract(sin(dot(n.xy, vec2(12.9898, 78.233)))* 43758.5453);
}
float procrand_norm(vec2 n) { return procrand(n) * 2.0 - 1.0; }

// yields always the same value for given Texture
float texrand() {
 #ifdef INFOBEAMER_PLAT_PI
  return texture2D(Texture, TEX_RANDOM_SAMPLE).b;
 #else
  return texture2DLod(Texture, TEX_RANDOM_SAMPLE, 0).b;
 #endif
}
float texrand_norm() { return texrand() * 2.0 - 1.0; }

float rowspeed(float y) { return ROW_SPEED_MULT * procrand_norm(vec2(0.0, y)); }
float vertspeed(){ return VERT_SPEED_MULT * texrand_norm(); }

void main()
{
    vec2 uv = TexCoord;
    uv.y -= mod(uv.y, GRANULARITY);             // pixellate rows
    uv.y = mod(uv.y + vertspeed() * time, 1.0); // video hum
    uv.x += rowspeed(uv.y) * time;              // move rows
    uv = mod(uv * TEX_REPEAT_FACTOR, 1.0);      // repeat texture

#ifdef INFOBEAMER_PLAT_PI
    vec4 c = texture2D(Texture, uv);
#else
    vec4 c = texture2DLod(Texture, uv, 0);
#endif
    gl_FragColor = c;
}
