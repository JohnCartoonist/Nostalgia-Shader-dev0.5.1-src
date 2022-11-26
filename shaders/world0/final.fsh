#version 400 compatibility
#include "/lib/global.glsl"
#include "/lib/util/math.glsl"

#define INFO 0

#define setBitdepth 8       //[6 8 10 12]

#define setBrightness 1.02   //[0.5 0.6 0.7 0.8 0.9 1.0 1.02 1.1 1.2 1.3 1.4 1.5]
#define setContrast 0.98    //[0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 0.98 1.0 1.05 1.1 1.15 1.2 1.25 1.3]
#define setCurve 0.92       //[0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.90 0.92 0.94 0.96 0.98 1.0 1.02 1.04 1.06 1.08 1.1 1.15 1.2 1.25 1.3 1.35 1.4 1.45 1.5]
#define setSaturation 1.02   //[0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.02 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

const bool colortex0MipmapEnabled = true;

uniform sampler2D colortex0;
uniform sampler2D colortex7;

uniform int frameCounter;

uniform float viewWidth;
uniform float viewHeight;

in vec2 coord;

uniform ivec2 eyeBrightnessSmooth;

flat in float timeNight;
flat in float timeMoon;

#include "/lib/util/colorConversion.glsl"

struct sceneData{
    vec3 hdr;
    vec3 sdr;
    float exposure;
    float lowlightFactor;
} scene;

void autoExposureNonTemporal() {
	float imageLuma = getLuma(textureLod(colortex0, vec2(0.5), log2(viewWidth*0.3)).rgb);
	imageLuma       = clamp((imageLuma), expMinimum, expMaximum);

	scene.exposure  = 1.0 - exp(-1.0/imageLuma);
}
void autoExposureAdvanced() {
	float imageLuma = texture(colortex7, coord).a;
	imageLuma       = clamp((imageLuma), expMinimum, expMaximum);

	scene.exposure  = 1.0 - exp(-1.0/imageLuma);

    #ifdef s_lowlightCompensation
        scene.lowlightFactor = pow2(1.0-linStep(imageLuma, 0.0, 0.07));
    #else
        scene.lowlightFactor = 0.0;
    #endif
}
void autoExposureLegacy() {
    const float expMax  = 2.0;
    const float expMin  = expMinimum;
    float eyeSkylight = eyeBrightnessSmooth.y*(1-timeNight*0.3-timeMoon*0.3);
    float eyeLight = eyeBrightnessSmooth.x*0.7;
    float imageLuma = max(eyeSkylight, eyeLight);
        imageLuma /= 240.0;
        imageLuma = pow2(imageLuma)*expMax;
        imageLuma = clamp(imageLuma, expMin, expMax); 
    scene.exposure = 1.0 - exp(-1.0/imageLuma);
}
void fixedExposure() {
    float exposure = expManual;
    scene.exposure = 1.0 - exp(-1.0/exposure);
}

void noTonemap() {
    scene.sdr   = scene.hdr*scene.exposure;
    scene.sdr   = toSRGB(scene.sdr);
}

/*
void reinhardTonemap() {    //naive reinhard implemetation
    scene.sdr   = scene.hdr*scene.exposure;
    scene.sdr   = scene.sdr/(1.0+scene.sdr);
    scene.sdr   = toSRGB(scene.sdr);
}
*/

void reinhardTonemap(){     //based off jodie's approach
    scene.sdr   = scene.hdr*scene.exposure;
    float luma  = dot(scene.sdr, vec3(0.2126, 0.7152, 0.0722));
    vec3 color  = scene.sdr/(scene.sdr + 1.0);
    scene.sdr   = mix(scene.sdr/(luma + 1.0), color , color);
    scene.sdr   = toSRGB(scene.sdr);
}

struct filmicTonemap {
    float curve;
    float toe;
    float angle;
    float slope;
    float black;
    float range;
    float white;
} filmic;

vec3 filmicCurve(vec3 col) {
    float A   = filmic.curve;
    float B   = filmic.toe;
    float C   = filmic.slope;
    float D   = filmic.angle;
    float E   = filmic.black;
    float F   = filmic.range;
    return ((col * (A*col + C*B) + D*E) / (col * (A*col + B) + D*F)) - E/F;
}

void tonemapFilmic() {
    filmic.curve        = 0.22;
    filmic.toe          = 0.88;
    filmic.slope        = 0.62;
    filmic.angle        = 0.39;
    filmic.black        = 0.00;
    filmic.range        = 0.60;
    filmic.white        = 14.00;

    vec3 colIn = scene.hdr;
    colIn *= scene.exposure+scene.lowlightFactor*3.0;
    vec3 white = filmicCurve(vec3(filmic.white));
    vec3 colOut = filmicCurve(colIn);
    scene.sdr = colOut/white;
}
/*
struct acesTonemap {
    float toe;
    float black;
    float shoulder;
    float slope;
    float range;
} aces;

const mat3x3 acesInput = mat3x3(
    0.59719, 0.35458, 0.04823,
    0.07600, 0.90834, 0.01566,
    0.02840, 0.13383, 0.83777
);
const mat3x3 acesOutput = mat3x3(
     1.60475, -0.53108, -0.07367,
    -0.10208,  1.10813, -0.00605,
    -0.00327, -0.07276,  1.07602
);

vec3 RRTandODTfit(vec3 x) {
    vec3 a = x * (x + aces.toe) - aces.black;
    vec3 b = x * (aces.shoulder * x + aces.slope) + aces.range;
    return a / b;
}
*/
//void tonemapACES(){
    /* default aces */
    /* aces.toe    = 0.0245786;
    aces.black  = 0.000090537;
    aces.shoulder = 0.983729;
    aces.slope  = 0.4329510;
    aces.range  = 0.238081;
    */

    /* custom curve *//*
    aces.toe    = 0.22;
    aces.black  = 0.00;
    aces.shoulder = 0.98;
    aces.slope  = 0.55;
    aces.range  = 1.5;


    vec3 hdr  = scene.hdr;
        hdr  *= scene.exposure;
	    hdr   = hdr*acesInput;
    vec3 sdr  = RRTandODTfit(hdr);
        sdr   = sdr*acesOutput;

    scene.sdr = toSRGB(sdr);
}*/

void vignette() {
    float fade  = length(coord*2.0-1.0);
        fade    = linStep(abs(fade), 0.45, 1.8);
        fade    = pow2(fade);

    scene.sdr   = mix(scene.sdr, vec3(0.0), fade);
}

#include "/lib/util/dither.glsl"

int getColorBit() {
	if (setBitdepth==1) {
		return 1;
	} else if (setBitdepth==2) {
		return 4;
	} else if (setBitdepth==4) {
		return 16;
	} else if (setBitdepth==6) {
		return 64;
	} else if(setBitdepth==8){
		return 255;
	} else if (setBitdepth==10) {
		return 1023;
	} else {
		return 255;
	}
}

void imageDither() {
    int bits = getColorBit();
    vec3 colDither = scene.sdr;
        colDither *= bits;
        colDither += bayer64(gl_FragCoord.xy)-0.5;

        float colR = round(colDither.r);
        float colG = round(colDither.g);
        float colB = round(colDither.b);

    scene.sdr = vec3(colR, colG, colB)/bits;
}

vec3 brightenContrast(vec3 x, const float brighten, const float contrast) {
    return (x - 0.5) * contrast + 0.5 + brighten;
}
vec3 curve(vec3 x, const float exponent) {
    return vec3(pow(abs(x.r), exponent),pow(abs(x.g), exponent),pow(abs(x.b), exponent));
}

void colorGrading() {
    scene.sdr     = curve(scene.sdr, setCurve);
    scene.sdr     = brightenContrast(scene.sdr, setBrightness-1.0, setContrast);
    float imageLuma = getLuma(scene.sdr);
    scene.sdr     = mix(vec3(imageLuma), scene.sdr, setSaturation);
    scene.sdr    *= vec3(1.0, 1.03, 1.0);
}

void main() {
    scene.hdr       = textureLod(colortex0, coord, 0).rgb;
    scene.sdr       = scene.hdr;
    scene.exposure  = 1.0;

    autoExposureAdvanced();

    tonemapFilmic();

    colorGrading();

    vignette();

    imageDither();

    gl_FragColor = toVec4(scene.sdr);
}