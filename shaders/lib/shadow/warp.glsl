#define warpMethod 2        //[0 1 2]0-log 1-legacy 2-robobo

#if warpMethod==0

    float getWarpFactor(in vec2 x) {
        float nearQuality   = 0.11;
        float farQuality    = 1.1;
        float a     = exp(nearQuality);
        float b     = (exp(farQuality)-a)*(shadowDistance/128.0);
        return log(length(x)*b+a);
    }

    void warpShadowmap(inout vec2 coord, out float distortion) {
        distortion = getWarpFactor(coord);
        coord /= distortion;
    }
    void warpShadowmap(inout vec2 coord) {
        float distortion = getWarpFactor(coord);
        coord /= distortion;
    }
#elif warpMethod==1

    #define shadowmapBias 0.85

    vec2 warpShadowmap(in vec2 coord, out float distortion) {
        distortion = sqrt(coord.x*coord.x + coord.y*coord.y);
        distortion = (1.0-shadowmapBias) + distortion*shadowmapBias;
        coord /= distortion;
        return coord;
    }
    vec2 warpShadowmap(in vec2 coord) {
        float distortion = sqrt(coord.x*coord.x + coord.y*coord.y);
        distortion = (1.0-shadowmapBias) + distortion*shadowmapBias;
        coord /= distortion;
        return coord;
    }
#elif warpMethod==2

    #define shadowmapBias 0.85

    float getWarpFactor(in vec2 x) {
        return length(x * 1.169) * shadowmapBias + (1.0 - shadowmapBias);
    }

    void warpShadowmap(inout vec2 coord, out float distortion) {
        distortion = getWarpFactor(coord);
        coord /= distortion;
    }
    void warpShadowmap(inout vec2 coord) {
        float distortion = getWarpFactor(coord);
        coord /= distortion;
    }
#endif