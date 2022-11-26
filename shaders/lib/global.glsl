const int shadowMapResolution   = 2560;         //[512 1024 1536 2048 2560 3072 3840 4096 6144 8192]
const float shadowDistance      = 128.0;
#define s_shadowLuminance 0.0   //[0.0 0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98]

#define setAmbientOcclusion
#define setAOQuality 1          //[0 1 2]

#define torchlightLuma 1.0      //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]
#define torchlightCol vec3(1.0, 0.28, 0.0)

#define minLightLum 1.0         //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

#define s_cloudStyle 0          //[0 1]
#define s_cloudAltitude 175.0   //[150.0 175.0 200.0 225.0 250.0 275.0 300.0]
#define s_cloudSamples 12       //[4 6 8 10 12 14 16 18 20]
#define s_cloudLightingQuality 1 //[0 1]
#define s_cloudEdgeSmoothing 4  //[1 2 4 6 8 9 12 16]

#define s_fogMode 2             //[0 1 2]
#define s_fogSamples 8          //[2 3 4 5 6 7 8 10 12 14 16]
#define s_fogStart 0.35         //[0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75]
#define s_fogExp 2.0            //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.1 2.2 2.3 2.4 2.5 2.6 2.7 2.8 2.9 3.0 3.1 3.2 3.3 3.4 3.5 3.6 3.7 3.8 3.9 4.0]

//#define s_usePBR
#define s_useTexAO
#define s_useTexEmission
//#define s_useNormal
#define setNormalFlatten 0.0    //[0.0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5 0.55 0.6 0.65 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
#define setWindEffect

#define setBloom
#define setMotionblur
#define temporalAA
#define expMethod 0     //[0 1 2] 0-temporal 1-non temporal 2-legacy 3-manual
#define expMinimum 0.0005
#define expMaximum 15.0
#define expManual 1.0
#define s_lowlightCompensation