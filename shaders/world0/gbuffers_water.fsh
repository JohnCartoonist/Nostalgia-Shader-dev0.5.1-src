#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

const float shadowIllumination  = 0.0;
const float sunlightLuma        = 7.0;
const float skylightLuma        = 0.46;
const float minLight            = 0.012*minLightLum;
const vec3 minLightColor        = vec3(0.5, 0.75, 1.0);
const float lightLuma           = 2.8*torchlightLuma;
const vec3 lightColor           = torchlightCol;


/* ------ uniforms ------ */

uniform sampler2D tex;

uniform int frameCounter;

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

const bool shadowHardwareFiltering = true;

uniform sampler2DShadow shadowtex0;
uniform sampler2DShadow shadowtex1;

uniform sampler2DShadow shadowcolor0;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;


/* ------ inputs from vertex stage ------ */

in vec4 col;
in vec2 coord;
in vec2 lmap;
flat in vec3 nrm;

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

flat in int water;


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
} depth;

struct positionData {
    //vec3 sun;
    //vec3 moon;
    //vec3 light;
    //vec3 up;
    vec3 camera;
    vec3 screen;
    vec3 world;
} pos;

struct vectorData {
    vec3 sun;
    vec3 moon;
    vec3 light;
    vec3 up;
    vec3 view;
} vec;

struct shadingData {
    float diffuse;
    float specular;
    float shadow;

    float direct;
    float ao;
    float cave;
    float lightmap;

    vec3 shadowcolor;
    vec3 color;
    vec3 indirect;
    vec3 skylight;

    vec3 result;
} sdata;

struct lightData {
    vec3 sun;
    vec3 sky;
    vec3 artificial;
} light;

struct pbrData {
    float roughness;
    float specular;
    float metallic;
} pbr;

struct returnData{
    vec4 scene;
    vec2 lmap;
    float roughness;
    float specular;
    float metalness;
    float materials;
} rdata;


/* ------ includes ------ */

#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"
#include "/lib/util/encode.glsl"


/* ------ functions ------ */

void diffuseLambert(in vec3 normal) {
    normal          = normalize(normal);
    vec3 light      = normalize(vec.light);
    float lambert   = dot(normal, light);
        lambert     = max(lambert, 0.0);
    sdata.diffuse   = lambert;
}

void specGGX(in vec3 normal) {
    float roughness = pow2(max(pbr.roughness, 0.04));
    float F0        = 0.08;
    if (pbr.metallic>0.5) {
        F0          = 0.2;
    }
    vec3 h          = vec.light - vec.view;
    float hn        = inversesqrt(dot(h, h));
    float dotLH     = saturate(dot(h,vec.light)*hn);
    float dotNH     = saturate(dot(h,normal)*hn);
    float dotNL     = saturate(dot(normal,vec.light));  
    float denom     = (dotNH * roughness - dotNH) * dotNH + 1.0;
    float D         = roughness / (pi * denom * denom);
    float F         = F0 + (1.0 - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
    float k2        = 0.25 * roughness;

    sdata.specular  = dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2)*pbr.specular;
    sdata.specular *= 1.0-rainStrength;
}

#include "/lib/shadow/warp.glsl"

vec3 getShadowCoord(in float offset, out bool canShadow, out float distortion, out float filterFix, out float distSqXZ, out float distSqY, out float shadowDistSq, out float cDepth, out vec3 wPosR) {
    float dist      = length(pos.screen.xyz);
    vec3 wPos       = vec3(0.0);
    canShadow       = false;
    distortion      = 0.0;
    distSqXZ        = 0.0;
    distSqY         = 0.0;
    shadowDistSq    = 0.0;
    cDepth          = 0.0;
    offset         *= 3072.0/shadowMapResolution;

    if (dist > 0.05) {
        shadowDistSq    = pow2(shadowDistance);
        wPos            = pos.screen;

        #ifdef temporalAA
            wPos        = screenSpacePos(depth.depth, taaJitter(gl_FragCoord.xy/vec2(viewWidth, viewHeight), -0.5));
        #endif

        wPos.xyz       += vec3(offset)*vec.light;
        wPos.xyz        = viewMAD(gbufferModelViewInverse, wPos.xyz);
        distSqXZ        = pow2(wPos.x) + pow2(wPos.z);
        distSqY         = pow2(wPos.y);

            wPos.xyz            = viewMAD(shadowModelView, wPos.xyz);
            wPosR               = wPos;
            wPos.xyz            = projMAD(shadowProjection, wPos.xyz);
            warpShadowmap(wPos.xy, distortion);
            filterFix           = 1.0/distortion;
            wPos.z             *= 0.2;
            
            wPos.xyz            = wPos.xyz*0.5+0.5;

            canShadow   = true;
    }
    return wPos;
}

float shadowFilter(in sampler2DShadow shadowtex, in vec3 wPos) {
    const float step = 1.0/shadowMapResolution;
    float noise     = ditherGradNoise()*pi;
    vec2 offset     = vec2(cos(noise), sin(noise))*step;
    float shade     = shadow2D(shadowtex, vec3(wPos.xy+offset, wPos.z)).x;
        shade      += shadow2D(shadowtex, vec3(wPos.xy-offset, wPos.z)).x;
        shade      += shadow2D(shadowtex, wPos.xyz).x*0.5;
    return shade*0.4;
}
vec4 shadowFilterCol(in sampler2DShadow shadowtex, in vec3 wPos) {
    const float step = 1.0/shadowMapResolution;
    float noise     = ditherGradNoise()*pi;
    vec2 offset     = vec2(cos(noise), sin(noise))*step;
    vec4 shade     = shadow2D(shadowtex, vec3(wPos.xy+offset, wPos.z));
        shade      += shadow2D(shadowtex, vec3(wPos.xy-offset, wPos.z));
        shade      += shadow2D(shadowtex, wPos.xyz)*0.5;
    return shade*0.4;
}

void getDirectLight(bool diffuseLit) {
    float offset    = 0.08;

    bool canShadow      = false;
    float distortion    = 0.0;
    float filterFix     = 0.0;
    float distSqXZ      = 0.0;
    float distSqY       = 0.0;
    float shadowDistSq  = 0.0;
    float cDepth        = 0.0;
    float shadowFade    = 1.0;

    vec3 wPosR          = vec3(0.0);
    vec3 wPos           = getShadowCoord(offset, canShadow, distortion, filterFix, distSqXZ, distSqY, shadowDistSq, cDepth, wPosR);

    float shade         = 1.0;
    vec4 shadowcol      = vec4(1.0);
    bool translucencyShadow = false;

    if (canShadow) {
        if (diffuseLit) {

        shade       = shadowFilter(shadowtex1, wPos.xyz);

        shadowcol   = shadowFilterCol(shadowcolor0, wPos.xyz);

        float temp1 = shadowFilter(shadowtex0, wPos.xyz);

        translucencyShadow = temp1<shade;
        }
    }

    sdata.shadow  = shade;
    sdata.shadowcolor = translucencyShadow ? mix(vec3(1.0), shadowcol.rgb, shadowcol.a) : vec3(1.0);
}

float getLightmap(in float lightmap) {
    lightmap = 1-clamp(lightmap*1.1, 0.0, 1.0);
    lightmap *= 5.0;
    lightmap = 1.0 / pow2(lightmap+0.1);
    lightmap = ismoothstep(lightmap, 0.025, 1.0);
    return lightmap;
}
vec3 artificialLight() {
    float lightmap      = getLightmap(scene.lightmap.x);
    vec3 lcol           = light.artificial;
    vec3 light          = mix(vec3(0.0), lcol, lightmap);
    return light;
}

void applyShading() {
    sdata.lightmap      = ismoothstep(scene.lightmap.y, 0.15, 0.95);
    sdata.cave          = 1.0-ismoothstep(scene.lightmap.y, 0.2, 0.5);

    vec3 indirectLight  = mix(sdata.skylight, light.sun, saturate(s_shadowLuminance));
        indirectLight   = mix(indirectLight, minLightColor*minLight, sdata.cave);

        indirectLight  += light.sun*sdata.indirect*(1.0-sdata.direct);

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = mix(indirectLight, light.sun*sdata.color, sdata.direct);
        directLight     = bLighten(directLight, artificial);

    vec3 metalCol       = scene.albedo*normalize(scene.albedo);

    rdata.scene.rgb    *= 1.0-pbr.metallic;

    sdata.result        = directLight*sdata.ao;
    rdata.scene.rgb    *= sdata.result;
    vec3 specular       = sdata.specular*light.sun*sdata.direct*mix(vec3(1.0), metalCol, saturate(pbr.metallic*10.0));
    rdata.scene.rgb    += specular;

    rdata.scene.rgb    += metalCol*pbr.metallic*sdata.result;
}

vec2 fcoord     = gl_FragCoord.xy/vec2(viewWidth, viewHeight);

void main() {
vec4 inputSample        = texture(tex, coord);
    inputSample.rgb    *= col.rgb;
    scene.albedo        = toLinear(inputSample.rgb);
    scene.normal        = nrm;
    scene.lightmap      = lmap;

    depth.depth         = gl_FragCoord.z;
    depth.linear        = depthLin(depth.depth);

    pbr.roughness       = water==1 ? 0.0 : 0.25;
    pbr.specular        = 0.5;
    pbr.metallic        = 0.0;

    rdata.scene.rgb     = scene.albedo;
    rdata.lmap          = lmap;
    rdata.materials     = 0.0;
    rdata.metalness     = pbr.metallic;
    rdata.roughness     = pbr.roughness;
    rdata.specular      = pbr.specular;

    sdata.shadow        = 1.0;
    sdata.diffuse       = 1.0;
    sdata.specular      = 0.0;
    sdata.ao            = flatten(col.a, 0.85);

    sdata.direct        = 1.0;
    sdata.indirect      = vec3(0.0);
    sdata.specular      = 0.0;
    sdata.shadowcolor   = vec3(1.0);
    sdata.color         = vec3(1.0);
    sdata.skylight      = vec3(0.0);
    sdata.result        = vec3(0.0);

    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth, fcoord);
    pos.world       = worldSpacePos(depth.depth, fcoord);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    light.sun       = colSunlight*sunlightLuma;
    light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
    light.sky       = colSkylight*(normalize(colSky)*0.7+0.3)*skylightLuma;
    light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
    light.artificial = lightColor*lightLuma;

    diffuseLambert(scene.normal);

    getDirectLight(sdata.diffuse>0.01);

    sdata.direct    = min(sdata.shadow, sdata.diffuse);
    sdata.color     = sdata.shadowcolor;

    if (sdata.direct>0.01) specGGX(scene.normal);
    sdata.specular *= sdata.direct;

    sdata.skylight  = light.sky;

    applyShading();

    rdata.scene.a       = pow2(inputSample.a);

    //rdata.scene.rgb     = vec3(sdata.direct);
    //rdata.scene.a       = 1.0;

    /*DRAWBUFFERS:612*/
    gl_FragData[0] = makeSceneOutput(rdata.scene)*vec4(vec3(0.05), 1.0);
    gl_FragData[1] = toVec4(nrm*0.5+0.5);
    gl_FragData[2] = vec4(rdata.lmap, encodeV2(rdata.specular, rdata.roughness), 1.0);
    //gl_FragData[3] = vec4(0.25, rdata.materials, 0.0, 1.0);
    //gl_FragData[4] = vec4(vec3(0.0), col.a);
}