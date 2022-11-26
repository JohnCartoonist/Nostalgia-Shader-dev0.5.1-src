#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float shadowBias = 0.85;

out vec4 col;
out vec2 coord;

uniform int frameCounter;
uniform float viewWidth;
uniform float viewHeight;

vec4 position;

#include "/lib/terrain/blocks.glsl"
#include "/lib/terrain/transform.glsl"
#include "/lib/terrain/wind.glsl"

void waterWaves() {
    float animTick = frameTimeCounter*2.0;

    float sin1 = sin(length(position.xz)*pi+animTick);
    float cos1 = cos(length(position.xz)*pi*0.3+animTick*0.8)*0.5+0.5;

    float sin2 = sin(length(position.xz*vec2(1.0, 0.7))*pi*0.35+animTick*0.9);

    float wave1 = sin1*cos1;

    float wave   = wave1+sin2;

    position.y += wave*0.035;
}

#include "/lib/shadow/warp.glsl"

void main() {

    idSetup();
    matSetup();

        position = gl_ProjectionMatrix*gl_ModelViewMatrix*gl_Vertex;

        unpackShadow();
        #ifdef setWindEffect
            applyWind();
            if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) waterWaves();
        #endif
        repackShadow();
   
        warpShadowmap(position.xy);

    gl_Position = position;
    gl_Position.z *= 0.2;
    coord       = (gl_TextureMatrix[0]*gl_MultiTexCoord0).xy;
    col         = gl_Color;
}