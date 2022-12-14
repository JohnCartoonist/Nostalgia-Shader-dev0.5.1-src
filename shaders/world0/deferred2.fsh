#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/buffer.glsl"
#include "/lib/util/math.glsl"

const float shadowIllumination  = 0.0;
const float sunlightLuma        = 7.0;
const float skylightLuma        = 0.46;
const float minLight            = 0.012*minLightLum;
const vec3 minLightColor        = vec3(0.5, 0.75, 1.0);
const float lightLuma           = 2.8*torchlightLuma;
const vec3 lightColor           = torchlightCol;

/* ------ uniforms ------ */

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

uniform sampler2D depthtex1;

uniform int frameCounter;

uniform float far;
uniform float near;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform float viewWidth;
uniform float viewHeight;
uniform float rainStrength;
uniform float wetness;

uniform ivec2 eyeBrightness;

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;


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
    float direct;
    float specular;
    float ao;
    float cave;
    float lightmap;

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

vec3 returnCol  = vec3(0.0);


/* ------ includes ------ */

#include "/lib/util/decode.glsl"
#include "/lib/util/decodeIn.glsl"
#include "/lib/util/colorConversion.glsl"
#include "/lib/util/depth.glsl"
#include "/lib/util/positions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaJitter.glsl"
#include "/lib/util/encode.glsl"

vec3 unpackNormal(vec3 x) {
    return x*2.0-1.0;
}

float getLightmap(in float lightmap) {
    lightmap = linStep(lightmap, 1.0/24.0, 14.0/16.0);
    //lightmap = 1-clamp(lightmap*1.1, 0.0, 1.0);
    //lightmap *= 5.0;
    //lightmap = 1.0 / pow2(lightmap+0.1);
    return pow3(lightmap);
}
vec3 artificialLight() {
    float lightmap      = getLightmap(scene.lightmap.x);
    vec3 lcol           = light.artificial;
    vec3 light          = mix(vec3(0.0), lcol, lightmap+mat.emissive*8.0);
    return light;
}

void applyShading() {
    sdata.lightmap      = ismoothstep(scene.lightmap.y, 0.15, 0.95);
    sdata.cave          = 1.0-ismoothstep(scene.lightmap.y, 0.2, 0.5);

    vec3 indirectLight  = mix(sdata.skylight, light.sun, saturate(max(s_shadowLuminance, rainStrength*0.2)));
        indirectLight   = mix(indirectLight, minLightColor*minLight, sdata.cave);

    vec3 artificial     = scene.lightmap.x > 0.01 ? artificialLight() : vec3(0.0);

    vec3 directLight    = mix(indirectLight, light.sun*sdata.color, sdata.direct*finv(timeLightTransition));
        directLight     = bLighten(directLight, artificial);

    vec3 metalCol       = scene.albedo*normalize(scene.albedo);

    returnCol          *= 1.0-pbr.metallic;

    sdata.result        = directLight*sdata.ao;
    returnCol          *= sdata.result;
    vec3 specular       = sdata.specular*light.sun*sdata.direct*mix(vec3(1.0), metalCol, saturate(pbr.metallic*10.0));
    returnCol          += specular*sdata.color;

    returnCol          += metalCol*pbr.metallic*sdata.result;
}

void main() {
    scene.albedo    = texture(colortex0, coord).rgb;
    scene.normal    = unpackNormal(texture(colortex1, coord).rgb);
    scene.sample2   = texture(colortex2, coord);
    scene.lightmap  = scene.sample2.rg;
    scene.sample3   = texture(colortex3, coord);

    decodeData();

    depth.depth     = texture(depthtex1, coord).x;
    depth.linear    = depthLin(depth.depth);

    pos.camera      = cameraPosition;
    pos.screen      = screenSpacePos(depth.depth);
    pos.world       = worldSpacePos(depth.depth);

    vec.sun         = sunVector;
    vec.moon        = moonVector;
    vec.light       = lightVector;
    vec.up          = upVector;
    vec.view        = normalize(pos.screen).xyz;

    sdata.direct        = 1.0;
    sdata.indirect      = vec3(0.0);
    sdata.ao            = 1.0;
    sdata.specular      = 0.0;
    sdata.color         = vec3(1.0);
    sdata.skylight      = vec3(0.0);
    sdata.result        = vec3(0.0);

    returnCol           = scene.albedo;

    if(mask.terrain) {
        light.sun       = colSunlight*sunlightLuma;
        light.sun       = mix(light.sun, vec3(vec3avg(light.sun))*0.15, rainStrength*0.95);
        light.sky       = colSkylight*skylightLuma;
        light.sky       = mix(light.sky, vec3(vec3avg(light.sky))*0.4, rainStrength*0.95);
        light.artificial = lightColor*lightLuma;

        vec3 sample5    = texture(colortex5, coord).rgb;
        sdata.direct    = sample5.r;
        sdata.specular  = sample5.g*8.0;

        sdata.color     = decodeColor(scene.sample3.a);

        vec4 sample4    = texture(colortex4, coord);

        sdata.ao        = mix(sample4.a, 1.0, sdata.direct*0.45);
        //sdata.indirect  = sample4.rgb;
        sdata.skylight  = light.sky;

        applyShading();
    }

    if (mat.beacon) {
        vec3 beaconCol  = mix(light.sun, light.sky, timeLightTransition);
        float luma      = vec3avg(beaconCol);
        returnCol       = scene.albedo*max(luma, 1.0);
    }

    if (mat.unlit) {
        vec3 beaconCol  = mix(light.sun, light.sky, timeLightTransition);
        float luma      = max(vec3avg(beaconCol), 8.0);
        returnCol       = scene.albedo*max(luma, 1.0)*0.25*saturate(eyeBrightness.y/255.0+0.005+eyeBrightness.x/355.0);
    }

    //returnCol   = light.sun;

    /*DRAWBUFFERS:03*/
    gl_FragData[0]  = makeSceneOutput(returnCol);
    gl_FragData[1]  = vec4(scene.sample3.r, encodeV3(scene.albedo), scene.sample3.b, 1.0);
}