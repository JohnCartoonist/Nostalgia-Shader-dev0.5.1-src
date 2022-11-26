#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

const float sunlightLuma        = 7.0;
const float skylightLuma        = 0.46;

/* ------ uniforms ------ */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex6;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

uniform int isEyeInWater;
uniform int worldTime;
uniform int frameCounter;

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;

uniform vec3 skyColor;
uniform vec3 fogColor;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform sampler2D noisetex;

const int noiseTextureResolution = 1024;


/* ------ inputs from vertex stage ------ */

in vec2 coord;

flat in vec3 sunVector;
flat in vec3 moonVector;
flat in vec3 lightVector;
flat in vec3 upVector;

flat in float timeSunrise;
flat in float timeNoon;
flat in float timeSunset;
flat in float timeNight;
flat in float timeMoon;
flat in float timeLightTransition;
flat in float timeSun;

flat in vec3 colSunlight;
flat in vec3 colSkylight;
flat in vec3 colSky;
flat in vec3 colHorizon;
flat in vec3 colSunglow;

flat in vec2 fogDensity;


/* ------ structs ------ */

struct sceneData {
    vec3 albedo;
    vec3 normal;
    vec2 lightmap;
    vec4 sample2;
    vec4 sample3;
} scene;

struct depthData {
    float depth;
    float linear;
    float solid;
    float solidLin;
} depth;

struct positionData {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 camera;
    vec3 screen;
    vec3 world;
    vec3 worldSolid;
} pos;

struct vectorData {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} vec;

struct lightData {
    vec3 sun;
    vec3 sky;
    float vDotL;
} light;

struct returnData {
    vec4 fog;
    vec4 fog_t;
} rdata;

vec3 returnCol  = vec3(0.0);
bool translucency = false;
float cloudAlpha = 0.0;
bool water = false;

/* ------ includes ------ */

#include "/lib/util/decode.glsl"
#include "/lib/util/decodeIn.glsl"
#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"
#include "/lib/util/encode.glsl"
#include "/lib/nature/phase.glsl"

vec3 unpackNormal(vec3 x) {
    return x*2.0-1.0;
}

vec3 sunlightMod    = mix(normalize(colSkylight), vec3(1.0), timeNight*0.6);

vec3 skyVanilla = toLinear(skyColor)*3.0*sunlightMod*vec3(0.8, 1.24, 1.1)+vec3(0.01, 0.022, 0.04)*timeNight*0.25;
vec3 fogVanilla = toLinear(fogColor)*10.0*mix(normalize(colSunlight), vec3(1.0), timeNight*0.25);

vec3 skyGradient() {
    vec3 nFrag      = -normalize(screenSpacePos(depth.solid).xyz);
    vec3 hVec       = normalize(-vec.up+nFrag);
    vec3 hVec2      = normalize(vec.up+nFrag);
    vec3 sgVec      = normalize(vec.sun+nFrag);
    vec3 mgVec      = normalize(vec.moon+nFrag);

    float hTop      = dot(hVec, nFrag);
    float hBottom   = dot(hVec2, nFrag);

    float horizonFade = linStep(hBottom, 0.3, 0.8);
        horizonFade = pow4(horizonFade)*0.75;

    float lowDome   = linStep(hBottom, 0.66, 0.71);
        lowDome     = pow3(lowDome);

    float horizonGrad = 1.0-max(hBottom, hTop);

    float horizon   = linStep(horizonGrad, 0.15, 0.31);
        horizon     = pow6(horizon)*0.8;

    float sunGrad   = 1.0-dot(sgVec, nFrag);
    float moonGrad  = 1.0-dot(mgVec, nFrag);

    float horizonGlow = saturate(pow2(sunGrad));
        horizonGlow = pow3(linStep(horizonGrad, 0.1-horizonGlow*0.1, 0.33-horizonGlow*0.05))*horizonGlow;
        horizonGlow = pow2(horizonGlow*1.3);
        horizonGlow = saturate(horizonGlow*0.75);

    float sunGlow   = linStep(sunGrad, 0.7, 0.98);
        sunGlow     = pow6(sunGlow);
        sunGlow    *= 0.4-timeNoon*0.3;

    float moonGlow  = pow(moonGrad*0.85, 15.0);
        moonGlow    = saturate(moonGlow*1.05)*0.8;

    vec3 sunColor   = colSunglow;
    vec3 sunLight   = colSunlight*8;
    vec3 moonColor  = vec3(0.55, 0.75, 1.0)*0.2;

    vec3 sky        = mix(colSky, colHorizon, horizonFade);
        sky         = mix(sky, colHorizon, horizon);
        sky         = mix(sky, colHorizon, lowDome);
        sky         = mix(sky, sunColor*4.0, saturate(sunGlow+horizonGlow)*(1.0-timeNight));
        sky         = mix(sky, moonColor, moonGlow*timeNight);

    return sky;
}

void simpleFog() {
    vec3 fogVanilla = toLinear(fogColor)*2.0;
    
    float falloff   = saturate(length(pos.world.xyz-pos.camera)/far);
        falloff     = linStep(falloff, s_fogStart, 0.999);
        falloff     = pow(falloff, s_fogExp);
    
    vec3 skyCol     = falloff>0.0 ? skyGradient() : fogVanilla;

    if (eyeAltitude > s_cloudAltitude-20) falloff *= 1.0-cloudAlpha;

    returnCol       = mix(returnCol, skyCol, falloff);
}

#include "/lib/shadow/warp.glsl"
vec3 getShadowCoord(in vec3 pos, in vec3 screenPos, in float offset, out bool canShadow, out float distSqXZ, out float distSqY, out float shadowDistSq, out float cdepth, const bool doOffset) {
    float dist      = length(screenPos.xyz);
    vec3 wPos       = vec3(0.0);
    canShadow       = false;
    distSqXZ        = 0.0;
    distSqY         = 0.0;
    shadowDistSq    = 0.0;
    cdepth          = 0.0;
    offset         *= 3072.0/shadowMapResolution;
    float distortion = 0.0;

    if (dist > 0.05) {
        shadowDistSq    = pow2(180.0);

        if (doOffset) {
            wPos            = screenPos;
            wPos.xyz       += vec3(offset)*vec.light;
            wPos            = viewMAD(gbufferModelViewInverse, wPos.xyz);
        } else {
            wPos = pos;
        }
        
        distSqXZ        = pow2(wPos.x) + pow2(wPos.z);
        distSqY         = pow2(wPos.y);

            wPos.xyz            = viewMAD(shadowModelView, wPos.xyz);
            wPos.xyz            = projMAD(shadowProjection, wPos.xyz);
            warpShadowmap(wPos.xy, distortion);
            wPos.z             *= 0.2;

            vec3 temp   = wPos.xyz;
            temp.xy    *= distortion;
            temp        = projMAD(shadowProjectionInverse, wPos.xyz);
            cdepth      = -temp.z;
            
            wPos.xyz            = wPos.xyz*0.5+0.5;

            canShadow   = true;
    }
    return wPos;
}

float getShadow(in vec3 pos) {
    float shadow    = 1.0;
    shadow  = shadow2DLod(shadowtex1, pos.xyz, 0).x;

    return shadow;
}
float getShadow0(in vec3 pos) {
    float shadow    = 1.0;

    shadow  = shadow2DLod(shadowtex0, pos.xyz, 0).x;

    return shadow;
}

const float fogAltitude     = 90.0;
const float fogSmoothing    = 40.0;

vec3 rayPos(in float depth) {
    vec3 viewPos    = screenSpacePos(depth).xyz;
    vec3 worldPos   = viewMAD(gbufferModelViewInverse, viewPos);
    return worldPos;
}
vec3 rayPos(in float depth, out vec3 screenPos) {
    vec3 viewPos    = screenSpacePos(depth).xyz;
        screenPos   = viewPos;
    vec3 worldPos   = viewMAD(gbufferModelViewInverse, viewPos);
    return worldPos;
}
vec2 getFogOD(in float rayDepth, in float rayStart, in float weight, in float altitude) {
    float height        = 1.0-linStep(altitude, fogAltitude, fogAltitude+fogSmoothing)*0.99;
        height         *= 1.0-linStep(altitude, 128.0, 512.0);
    return vec2(rayStart*height*weight)*fogDensity;
}

void volumetricFog() {
    const float highEdge    = fogAltitude+fogSmoothing;
    const float lowEdge     = fogAltitude;
    const int samples       = s_fogSamples;
    bool isSky              = !mask.terrain && !translucency;
    bool isWater            = translucency && water;
    bool isRayInWater       = false;
    bool isRayBehindTranslucent = false;
    bool canShadow          = false;

    const float mieG        = 0.8;
    vec2 phase              = getPhase(mix(light.vDotL, 1.0, timeLightTransition), mieG);

    const float mieCoeff    = 1.0;
    const float rayleighCoeff = 1.0;

    vec3 mieColor           = mix(light.sun, colSunglow*2.5, (timeSunrise+timeSunset)*0.9);
    vec3 rayleighColor      = mix(mix(colSkylight, colSky, 0.5)*3.0, colHorizon*0.7, timeNoon*0.7)*(1.0+timeLightTransition*0.5);

        rayleighColor       = mix(vec3(0.0), rayleighColor, linStep(eyeBrightnessSmooth.y/240.0, 0.0, 0.5));

    float mieNoonAlpha      = 0.4;
    vec3 mieNoon            = mix(rayleighColor*(sunlightLuma/skylightLuma), mieColor, phase.x*mieNoonAlpha+(1.0-mieNoonAlpha));
        mieColor            = mix(mieColor, mieNoon, timeNoon);

    //rayleighColor       = mix(vec3(0.0), rayleighColor, linStep(eyeBrightnessSmooth.y/240.0, 0.0, 0.5));

    float mie               = 0.0;
    float rayleigh          = 0.0;
    float transmittance     = 1.0;

    float mie_t             = 0.0;
    float rayleigh_t        = 0.0;
    float transmittance_t   = 1.0;

    float rayStart          = depth.solidLin;
    float rayStep           = rayStart/samples;
    float rayDepth          = rayStart - rayStep*ditherDynamic;

    vec2 oD                 = vec2(0.0);
    float weight            = 1.0/samples;
    float shadow            = 0.0;

    float rStartWorld       = isSky ? rayStart*max(far/far16, 1.0) : min(length(pos.worldSolid.xyz-pos.camera), far)/far16;

    float miePhase  = phase.x*0.94+0.06;

    float skyPhase          = dot(vec.view, vec.up)*0.5+0.5;
        skyPhase            = (1.0-pow2(linStep(skyPhase, 0.25, 1.0)))*0.5+0.5;
        skyPhase            = mix(skyPhase, 1.0, 0.7*float(mask.terrain || translucency));

    #ifdef s_coloredVL
        vec3 coloredVL          = vec3(0.0);
        vec3 coloredVL_t        = vec3(0.0);
    #else
        const vec3 coloredVL          = vec3(1.0);
        const vec3 coloredVL_t        = vec3(1.0);
    #endif

    for (int i = 0; i<samples; i++) {
        if (rayDepth>0.0) {

            float rDepth    = depthLinInv(rayDepth);
            vec3 screenP    = vec3(0.0);
            vec3 rPos       = rayPos(rDepth, screenP);
            float rDepthWorld = isSky ? rayDepth*max(far/far16, 1.0) : (length(rPos.xyz))/far16;
            float rayAltitude = rPos.y+pos.camera.y;

            isRayInWater = isEyeInWater==1 ? rayDepth<depth.linear : (rayDepth>depth.linear && isWater);
            isRayBehindTranslucent = isEyeInWater==0 ? rayDepth>depth.linear : false;

            float distSqXZ  = 0.0;
            float distSqY   = 0.0;
            float shadowDistSq = 0.0;
            float cdepth    = 0.0;

            vec3 shadowCoord    = getShadowCoord(rPos, screenP, 0.0002, canShadow, distSqXZ, distSqY, shadowDistSq, cdepth, false);
            float shadowFade    = min(1.0-distSqXZ/shadowDistSq, 1.0) * min(1.0-distSqY/shadowDistSq, 1.0);
            shadowFade          = saturate(shadowFade*2.0);

            if (canShadow && shadowFade > 0.01) shadow = getShadow(shadowCoord.xyz);

            #ifdef s_coloredVL
                float shadow1       = shadow;
            #endif
            
            shadow  = mix(1.0, shadow, shadowFade);

            if (isRayInWater) {
                //water volume maybe?
            } else {
                oD              = getFogOD(rDepthWorld, rStartWorld, weight, rayAltitude);

                if (isRayBehindTranslucent && !water) {
                    mie_t          += oD.x*mieCoeff*miePhase*shadow;
                    rayleigh_t     += oD.y*rayleighCoeff*phase.y*skyPhase;
                    transmittance_t *= exp2(-oD.x * invLog2);

                    #ifdef s_coloredVL
                        coloredVL_t += shadowcolor.rgb*(1.0/samples);
                    #endif

                } else {
                    mie            += oD.x*mieCoeff*miePhase*shadow;
                    rayleigh       += oD.y*rayleighCoeff*phase.y*skyPhase;
                    transmittance  *= exp2(-oD.x * invLog2);

                    #ifdef s_coloredVL
                        coloredVL  += shadowcolor.rgb*(1.0/samples);
                    #endif
                }
            }
            rayDepth       -= rayStep;
        } else {
            break;
        }
    }

    mie            *= 1.0-timeLightTransition;
    mie_t          *= 1.0-timeLightTransition;

    vec3 fogColor   = mie*mieColor*pow2(coloredVL) + rayleigh*rayleighColor;
    vec3 fogColor_t = mie_t*mieColor*pow2(coloredVL_t) + rayleigh_t*rayleighColor;

    transmittance   = isSky ? transmittance*0.8+0.2 : transmittance;

    rdata.fog       = max(vec4(fogColor, transmittance), 0.0);
    rdata.fog_t     = max(vec4(fogColor_t, transmittance_t), 0.0);

    returnCol       = returnCol*rdata.fog_t.a + rdata.fog_t.rgb;
}

void simpleFogEyeInWater() {
    vec3 fogVanilla = toLinear(fogColor)*2.0;

    vec3 wPosSolid  = worldSpacePos(depth.solid).xyz;
    vec3 wPos       = pos.world.xyz;
    float solidDistance = length(wPosSolid-pos.camera)/(far*0.8);
    float transDistance  = length(wPos-pos.camera)/(far*0.8);
    
    float falloff   = saturate(solidDistance-transDistance);
        falloff     = linStep(falloff, 0.35, 0.999);
        falloff     = pow2(falloff);
    
    vec3 skyCol     = falloff>0.0 ? skyGradient() : fogVanilla;

    returnCol       = mix(returnCol, skyCol, falloff);
}

void underwaterFog() {
    vec3 wPosSolid  = worldSpacePos(depth.solid).xyz;
    vec3 wPos       = pos.world.xyz;

    float solidDistance = length(wPosSolid-pos.camera)/far16;
    float transDistance  = length(wPos-pos.camera)/far16;

    float falloff   = isEyeInWater==1 ? transDistance : solidDistance-transDistance;
        falloff     = saturate(falloff);
        falloff     = linStep(falloff, 0.0, 0.2);
        falloff     = 1.0-pow2(1.0-falloff);

    vec3 fogCol     = (colSunlight*sunlightLuma+colSkylight*0.1)*vec3(0.1, 0.4, 1.0)*0.1;

    if (eyeAltitude > s_cloudAltitude-20) falloff *= 1.0-cloudAlpha;

    float caveFix   = isEyeInWater==1 ? 1.0 : linStep(eyeBrightnessSmooth.y/240.0, 0.0, 0.5);
    
    returnCol       = mix(returnCol, fogCol, falloff*caveFix);
}

void applyTranslucents() {
    vec4 translucents   = texture(colortex6, coord)*vec4(vec3(20.0), 1.0);
    if (eyeAltitude > s_cloudAltitude-20) translucents.a *= 1.0-cloudAlpha;
    returnCol       = mix(returnCol, translucents.rgb, translucents.a);
}

void applyTranslucentsFog() {
    vec3 fogVanilla = toLinear(fogColor)*2.0;
    vec4 translucents   = texture(colortex6, coord)*vec4(vec3(20.0), 1.0);
    
    float falloff   = saturate(length(pos.world.xyz-pos.camera)/far);
        falloff     = linStep(falloff, s_fogStart, 0.999);
        falloff     = pow(falloff, s_fogExp);
    
    vec3 skyCol     = falloff>0.0 ? skyGradient() : fogVanilla;

    if (eyeAltitude > s_cloudAltitude-20) falloff *= 1.0-cloudAlpha;

    vec3 tCol       = mix(translucents.rgb, skyCol, falloff);

    if (eyeAltitude > s_cloudAltitude-20) translucents.a *= 1.0-cloudAlpha;
    returnCol       = mix(returnCol, tCol, translucents.a);
}

vec4 bilinear(sampler2D tex, vec2 coord) {
    ivec2 texSize = textureSize(tex, 0)*s_cloudEdgeSmoothing;
    vec2 texelSize = vec2(1.0)/texSize;
    vec4 p0q0 = texture(tex, coord);
    vec4 p1q0 = texture(tex, coord + vec2(texelSize.x, 0));

    vec4 p0q1 = texture(tex, coord + vec2(0, texelSize.y));
    vec4 p1q1 = texture(tex, coord + vec2(texelSize.x , texelSize.y));

    float a = fract(coord.x * texSize.x);

    vec4 pInterp_q0 = mix(p0q0, p1q0, a);
    vec4 pInterp_q1 = mix(p0q1, p1q1, a);

    float b = fract(coord.y*texSize.y);
    return mix(pInterp_q0, pInterp_q1, b);
}

float noise2DCloud(in vec2 coord, in vec2 offset, float size) {
    coord += offset;
    coord = coord*size;
    coord /= noiseTextureResolution;

    return bilinear(colortex4, coord).a;
}
float heightFade(vec3 wPos, float limit, in float smoothing) {
    float density   = ismoothstep(wPos.y, limit-smoothing/2, limit+smoothing/2);
    return density;
}

const float cloudAltitude = s_cloudAltitude;
const float cloudDepth    = 20.0;

float cloudDensityPlane(vec3 pos) {
    const float lowEdge     = cloudAltitude-cloudDepth/2;
    const float highEdge    = cloudAltitude+cloudDepth/2;
    float size              = 0.15;
    vec2 coord              = pos.xz;
    float height            = heightFade(pos, lowEdge, 0.0)-heightFade(pos, highEdge, 0.0);

    float animTick          = frameTimeCounter*1.0;
    vec2 animVec            = vec2(animTick, 0.0);
    
    float shape;
    shape           = noise2DCloud(coord, animVec, size);

    float low       = pow3(1.0-linStep(pos.y, lowEdge, cloudAltitude-cloudDepth/6));
    float high      = pow3(linStep(pos.y, cloudAltitude+cloudDepth/6, highEdge));
    shape          -= low+high;

    return saturate(shape*2.0*height);
}
float cloudDensityStory(vec3 pos) {
    const float lowEdge     = cloudAltitude-cloudDepth/2;
    const float highEdge    = cloudAltitude+cloudDepth/2;
    float size              = 0.15;
    vec2 coord              = pos.xz;
    float height            = heightFade(pos, lowEdge, 0.0)-heightFade(pos, highEdge, 0.0);

    float fade              = exp2(-linStep(pos.y, lowEdge, highEdge)*3);

    float animTick          = frameTimeCounter*1.0;
    vec2 animVec            = vec2(animTick, 0.0);
    
    float shape;
    shape           = noise2DCloud(coord, animVec, size);

    float low       = pow3(1.0-linStep(pos.y, lowEdge, cloudAltitude-cloudDepth/6));
    float high      = pow3(linStep(pos.y, cloudAltitude+cloudDepth/6, highEdge));
    shape          -= low+high;

    return saturate(shape*2.0*height)*fade;
}

float c_miePhase(float x) {
    float mie1  = mie(x, 0.8*0.8);
    float mie2  = mie(x, -0.5*0.8);
    return mix(mie2, mie1, 0.75);
}
float scatterIntegral(float transmittance, const float coeff) {
    float a   = -1.0/coeff;
    return transmittance * a - a;
}

float vc_lD(in vec3 rPos, const int steps) {
    float density       = 1.0;

    vec3 dir            = mix(vec.light, vec.up, timeLightTransition);
        dir             = normalize(mat3(gbufferModelViewInverse)*dir);
    float stepSize      = (cloudDepth/steps)*0.5;
    vec3 rayStep        = dir*stepSize;

    rPos           += rayStep;
    
    float transmittance = 0.0;

    for (int i = 0; i<steps; i++) {
        transmittance  += cloudDensityPlane(rPos)*0.5;
        rPos           += rayStep;
    }
    return transmittance*density*stepSize;
}

float vc_getScatter(in float oD, in float lD, in float powder, in float phaseMod, in float lDmod, in float vDotL) {
    float transmittance = exp2(-lD*lDmod);
    float inscatter     = exp2(-oD*lDmod);
    float phase         = c_miePhase(vDotL*phaseMod)*0.93+0.07;
        phase           = mix(phase, 1.0, rainStrength*0.1);

    return max(powder*phase*transmittance, inscatter*0.06*(phase*0.5+0.5));
}
float vc_getScatterLQ(in float oD, in float lD, in float powder, in float vDotL) {
    float transmittance = exp2(-lD);
    float phase         = c_miePhase(vDotL)*0.9+0.1;

    return max(powder*phase*transmittance, 0.0);
}
void vc_scatterLQ(inout float scatter, in float oD, in vec3 rayPos, in float scatterCoeff, in float vDotL, in float transmittance, in float stepTransmittance) {
    float lD            = vc_lD(rayPos, 4)*0.45;
    float scatterInt    = scatterIntegral(stepTransmittance, 1.11);

    float tempScatter   = vc_getScatterLQ(oD, lD, 1.0, vDotL)*scatterCoeff*scatterInt*transmittance;

    scatter += tempScatter*transmittance*2.0;
}
void vc_scatter(inout float scatter, in float oD, in vec3 rayPos, in float scatterCoeff, in float vDotL, in float transmittance, in float stepTransmittance) {
    float lD            = vc_lD(rayPos, 6)*0.45;
    float powder        = 1.0-exp2(-oD*2.0);
        powder          = mix(powder, 1.0, vDotL*0.5+0.5);
    float scatterInt    = scatterIntegral(stepTransmittance, 1.11);

    float tempScatter   = vc_getScatter(oD, lD, powder, 1.0, 1.0, vDotL)*scatterCoeff*scatterInt*transmittance;

    scatter += tempScatter*transmittance*2.0;
}
void vc_storyMode(inout float scatter, in float oD, in vec3 rayPos, in float scatterCoeff, in float vDotL, in float transmittance, in float stepTransmittance) {
    const float lowEdge     = cloudAltitude-cloudDepth/2;
    const float highEdge    = cloudAltitude+cloudDepth/2;
    float scatterInt    = scatterIntegral(stepTransmittance, 1.11);

    float fade          = exp2(-linStep(rayPos.y, lowEdge, highEdge)*5);

    float tempScatter   = fade*0.4*scatterCoeff*scatterInt*transmittance;

    scatter += tempScatter*transmittance;
}
/*
void vc_multiscatter(inout float scatter, in float oD, in vec3 rayPos, in float scatterCoeff, in float vDotL, in float transmittance, in float stepTransmittance) {
    float tempScatter   = 0.0;
    float lD            = vc_lD(rayPos, 6)*1.1;
    float powder        = 1.0-exp2(-oD*2.0);
        powder          = mix(powder, 1.0, vDotL*0.4+0.6);
    float scatterInt    = scatterIntegral(stepTransmittance, 1.11);
        
    for (int i = 0; i<3; i++) {

        float scatterMod = pow(0.25, float(i));
        float lDmod = pow(0.15, float(i));
        float phaseMod = pow(0.85, float(i));

        scatterCoeff *= scatterMod;

        tempScatter += vc_getScatter(oD, lD, powder, phaseMod, lDmod, vDotL)*scatterCoeff*scatterInt*transmittance;
    }
    scatter += tempScatter*transmittance*2.0;
}*/

void cloudVolumetricVanilla() {
    const int samples       = 12;
    const float lowEdge     = cloudAltitude-cloudDepth/2;
    const float highEdge    = cloudAltitude+cloudDepth/2;

    vec3 wPos   = worldSpacePos(depth.solid).xyz;
    vec3 wVec   = normalize(wPos-pos.camera.xyz);

    bool isCorrectStepDir = pos.camera.y<cloudAltitude;

    float heightStep    = cloudDepth/samples;
    float height;
    if (isCorrectStepDir) {
            height      = lowEdge;
            height     += heightStep*ditherDynamic;
    } else {
            height      = highEdge;
            height     -= heightStep*ditherDynamic;
    }

    vec3 lightColor     = mix(light.sun*8.0, light.sky*30.5, timeLightTransition);
    vec3 rayleighColor  = light.sky*0.4;
        rayleighColor = colSky*1.5;

    float cloud         = 0.0;
    float shading       = 1.0;
    float scatter       = 0.0;
    float distanceFade  = 1.0;
    float fadeAlpha     = 1.0;
    float transmittance = 1.0;

    float vDotL         = dot(vec.view, vec.light);

    bool isCloudVisible = false;
    bool isCloserThanLastStep = false;

    float lastStepLength = 100000;

    for (int i = 0; i<samples; i++) {
        if (!mask.terrain) {
            isCloudVisible = (wPos.y>=pos.camera.y && pos.camera.y<=height) || 
            (wPos.y<=pos.camera.y && pos.camera.y>=height);
        } else if (mask.terrain) {
            isCloudVisible = (wPos.y>=height && pos.camera.y<=height) || 
            (wPos.y<=height && pos.camera.y>=height);
        }

        if (isCloudVisible) {
            vec3 getPlane   = wVec*((height-pos.camera.y)/wVec.y);
            vec3 stepPos    = pos.camera.xyz+getPlane;

            #if s_cloudStyle==0
                float oD        = cloudDensityPlane(stepPos);
            #else
                float oD        = cloudDensityStory(stepPos);
            #endif

            //if (oD <= 0.0) continue;

            float stepTransmittance = exp2(-oD*1.11*invLog2);

            float currStepLength = length(stepPos-pos.camera);

            distanceFade    = pow2(1.0-linStep(currStepLength*(175.0/cloudAltitude), 500.0, 2400.0));
            fadeAlpha      -= distanceFade*(1.0/samples);

            isCloserThanLastStep = (currStepLength<lastStepLength) && oD>0.02;

            if (distanceFade>0.01) {
                cloud          += oD;

                #if s_cloudStyle==0
                    #if s_cloudLightingQuality==0
                    vc_scatterLQ(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);
                    #elif s_cloudLightingQuality==1
                    vc_scatter(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);
                    #endif
                #else
                    vc_storyMode(scatter, oD, stepPos, 1.0, vDotL, transmittance, stepTransmittance);
                #endif
            }
            
            if (oD>0.01) lastStepLength  = currStepLength;

            transmittance  *= stepTransmittance;
        }

        if (isCorrectStepDir) {
            height         += heightStep;
        } else {
            height         -= heightStep; 
        }
    }
    vec3 color          = mix(rayleighColor, lightColor, scatter);
        color           = mix(color, scene.albedo, saturate((1.0-pow2(1.0-fadeAlpha))));

    cloud               = linStep(cloud, 0.04, 1.0);
    cloudAlpha          = linStep(cloud, 0.0, 0.99);
    returnCol           = mix(returnCol, color, cloud*0.94);
}


void main() {
    scene.albedo    = texture(colortex0, coord).rgb;
    scene.normal    = unpackNormal(texture(colortex1, coord).rgb);
    scene.sample2   = texture(colortex2, coord);
    scene.sample3   = texture(colortex3, coord);

    decodeData();

    depth.depth     = texture(depthtex0, coord).x;
    depth.linear    = depthLin(depth.depth);
    depth.solid     = texture(depthtex1, coord).x;
    depth.solidLin  = depthLin(depth.solid);

    translucency = depth.solid>depth.depth;

    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth);
    pos.world       = worldSpacePos(depth.depth);
    pos.worldSolid  = worldSpacePos(depth.solid);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    returnCol       = scene.albedo;

    light.sun       = colSunlight*sunlightLuma;
    light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
    light.sky       = mix(colSkylight, colSky*1.2, 0.66)*skylightLuma;
    light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
    light.vDotL     = dot(vec.view, vec.light);

    water = pbr.roughness < 0.01;

    cloudVolumetricVanilla();

    #if s_fogMode==2
        volumetricFog();
    #endif


    if (isEyeInWater==0 && (mask.terrain || translucency)) {
        if (water) underwaterFog();
        applyTranslucents();

        #if s_fogMode==1
            if (translucency) simpleFog();
        #endif

        #if s_fogMode==2
            returnCol       = returnCol*rdata.fog.a + rdata.fog.rgb;
        #endif
        
    } else if (isEyeInWater==1) {
        if (mask.terrain) simpleFogEyeInWater();
        returnCol       = returnCol*rdata.fog.a + rdata.fog.rgb;
        applyTranslucents();
        underwaterFog();
    }

    #if s_fogMode==2
        if (!(mask.terrain || translucency)) returnCol = returnCol*rdata.fog.a + rdata.fog.rgb;
    #endif


    /*DRAWBUFFERS:0*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
}