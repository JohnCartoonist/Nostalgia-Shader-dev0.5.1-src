#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

out vec4 col;
out vec2 coord;
out vec2 lmap;
flat out vec3 nrm;
flat out int water;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 shadowLightPosition;

flat out vec3 sunVector;
flat out vec3 moonVector;
flat out vec3 lightVector;
flat out vec3 upVector;

vec4 position;

#include "/lib/util/taaJitter.glsl"
#include "/lib/terrain/blocks.glsl"
#include "/lib/terrain/transform.glsl"
#include "/lib/util/time.glsl"
#include "/lib/nature/nvars.glsl"

void waterWaves() {
    float animTick = frameTimeCounter*2.0;

    float sin1 = sin(length(position.xz)*pi+animTick);
    float cos1 = cos(length(position.xz)*pi*0.3+animTick*0.8)*0.5+0.5;

    float sin2 = sin(length(position.xz*vec2(1.0, 0.7))*pi*0.35+animTick*0.9);

    float wave1 = sin1*cos1;

    float wave   = wave1+sin2;

    position.y += wave*0.035;
}

void main() {
    daytime();
    nature();

    position        = ftransform();

    if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) water = 1;
    else water = 0;

    unpackPos();
    #ifdef setWindEffect
        if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) waterWaves();
    #endif
    repackPos();

    #ifdef temporalAA
        position.xy = taaJitter(position.xy, position.w);
    #endif
    gl_Position     = position;

    col             = gl_Color;
    coord           = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    lmap            = (gl_TextureMatrix[1]*gl_MultiTexCoord1).xy;
    nrm             = normalize(gl_NormalMatrix*gl_Normal);
    sunVector       = normalize(sunPosition);
    moonVector      = normalize(moonPosition);
    lightVector     = normalize(shadowLightPosition);
    upVector        = normalize(upPosition);
}