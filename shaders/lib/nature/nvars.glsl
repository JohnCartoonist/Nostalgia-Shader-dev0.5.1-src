#define s_fogMieD 1.0           //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0]
#define s_fogRaylD 1.0          //[0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.2 2.4 2.6 2.8 3.0 3.2 3.4 3.6 3.8 4.0]

flat out vec3 colSunlight;
flat out vec3 colSkylight;
flat out vec3 colSky;
flat out vec3 colHorizon;
flat out vec3 colSunglow;
flat out vec2 fogDensity;

uniform vec3 skyColor;
uniform vec3 fogColor;

void nature() {
    vec3 sunlightSunrise;
        sunlightSunrise.r = 1.0;
        sunlightSunrise.g = 0.43;
        sunlightSunrise.b = 0.11;
        sunlightSunrise *= 0.9;

    vec3 sunlightNoon;
        sunlightNoon.r = 1.0;
        sunlightNoon.g = 0.90;
        sunlightNoon.b = 0.77;
        sunlightNoon *= 1.1;

    vec3 sunlightSunset;
        sunlightSunset.r = 1.0;
        sunlightSunset.g = 0.36;
        sunlightSunset.b = 0.09;
        sunlightSunset *= 0.9;

    vec3 sunlightNight;
        sunlightNight.r = 0.13;
        sunlightNight.g = 0.31;
        sunlightNight.b = 1.0;
        sunlightNight *= 0.2;

    colSunlight = sunlightSunrise*timeSunrise + sunlightNoon*timeNoon + sunlightSunset*timeSunset + sunlightNight*timeNight;

    vec3 skylightSunrise;
        skylightSunrise.r = 0.8;
        skylightSunrise.g = 0.8;
        skylightSunrise.b = 1.0;
        skylightSunrise *= 0.5;

    vec3 skylightNoon;
        skylightNoon.r = 0.59;
        skylightNoon.g = 0.86;
        skylightNoon.b = 1.0;
        skylightNoon *= 0.7;

    vec3 skylightSunset;
        skylightSunset.r = 0.8;
        skylightSunset.g = 0.8;
        skylightSunset.b = 1.0;
        skylightSunset *= 0.5;

    vec3 skylightNight;
        skylightNight.r = 0.25;
        skylightNight.g = 0.56;
        skylightNight.b = 1.0;
        skylightNight *= 0.25;

    colSkylight = skylightSunrise*timeSunrise + skylightNoon*timeNoon + skylightSunset*timeSunset + skylightNight*timeNight;

    vec3 skyVanilla = pow(skyColor, vec3(2.2));

    vec3 skySunrise = skyVanilla;
        //skySunrise.r = 0.24;
        //skySunrise.g = 0.56;
        //skySunrise.b = 1.0;
        skySunrise *= 1.0;

    vec3 skyNoon = skyVanilla*vec3(0.89, 1.18, 1.08);
        //skyNoon.r = 0.16;
        //skyNoon.g = 0.48;
        //skyNoon.b = 1.0;
        skyNoon *= 0.96;

    vec3 skySunset = skyVanilla;
        //skySunset.r = 0.25;
        //skySunset.g = 0.56;
        //skySunset.b = 1.0;
        skySunset *= 0.9;

    vec3 skyNight;
        skyNight.r = 0.08;
        skyNight.g = 0.5;
        skyNight.b = 1.0;
        skyNight *= 0.01;

    colSky = skySunrise*timeSunrise + skyNoon*timeNoon + skySunset*timeSunset + skyNight*timeNight;
    //colSky *= (1-timeMoon*0.7);

    vec3 horizonSunrise;
        horizonSunrise.r = 1.0;
        horizonSunrise.g = 0.12;
        horizonSunrise.b = 0.06;
        horizonSunrise *= 7.0;

    vec3 horizonNoon = pow(fogColor, vec3(2.2));
        //horizonNoon.r = 0.42;
        //horizonNoon.g = 0.76;
        //horizonNoon.b = 1.00;
        horizonNoon *= 10.5;

    vec3 horizonSunset;
        horizonSunset.r = 1.0;
        horizonSunset.g = 0.10;
        horizonSunset.b = 0.04;
        horizonSunset *= 7.0;

    vec3 horizonNight;
        horizonNight.r = 0.08;
        horizonNight.g = 0.5;
        horizonNight.b = 1.0;
        horizonNight *= 0.8;

    colHorizon = horizonSunrise*timeSunrise + horizonNoon*timeNoon + horizonSunset*timeSunset + horizonNight*timeNight;
    colHorizon *= (1-timeMoon*0.89);

    vec3 sunglowSunrise;
        sunglowSunrise.r = 1.0;
        sunglowSunrise.g = 0.12;
        sunglowSunrise.b = 0.02;
        sunglowSunrise *= 9.5;

    vec3 sunglowNoon;
        sunglowNoon.r = 1.0;
        sunglowNoon.g = 0.98;
        sunglowNoon.b = 0.92;
        sunglowNoon *= 9.0;

    vec3 sunglowSunset;
        sunglowSunset.r = 1.0;
        sunglowSunset.g = 0.11;
        sunglowSunset.b = 0.01;
        sunglowSunset *= 9.0;

    vec3 sunglowNight;
        sunglowNight.r = 0.08;
        sunglowNight.g = 0.5;
        sunglowNight.b = 1.0;
        sunglowNight *= 0.04;

    colSunglow = sunglowSunrise*timeSunrise + sunglowNoon*timeNoon + sunglowSunset*timeSunset + sunlightNight*timeNight;

    float mieDensity = 1.0*timeSunrise + 0.3*timeNoon + 0.5*timeSunset + 1.2*timeNight;
    float rayleighDensity = 1.1*timeSunrise + 1.0*timeNoon + 0.9*timeSunset + 0.9*timeNight;

    fogDensity  = vec2(mieDensity*s_fogMieD, rayleighDensity*s_fogRaylD);
}