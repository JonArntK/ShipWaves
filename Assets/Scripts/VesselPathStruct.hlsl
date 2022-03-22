#ifndef __VESSELPATHSTRUCT_HLSL__
#define __VESSELPATHSTRUCT_HLSL__

// Store information regarding the vessel paths.
struct VesselPathStruct
{
    int numPoints;
    StructuredBuffer<float2> coord;
    StructuredBuffer<float> time;
    StructuredBuffer<float> heading;
    StructuredBuffer<float> depth;

    // Finite water info
    StructuredBuffer<float2> finiteWaterStationaryPoints;
    float4 fnhInfo, hInfo, alphaInfo;
};

// Initialize VesselPathStruct
VesselPathStruct InitializeVesselPath(int numPoints, StructuredBuffer<float2> coord, 
    StructuredBuffer<float> time, StructuredBuffer<float> heading, StructuredBuffer<float> depth,
    StructuredBuffer<float2> finiteWaterStationaryPoints, float4 fnhInfo, float4 hInfo, float4 alphaInfo)
{
    VesselPathStruct vps;
    vps.numPoints = numPoints;
    vps.coord = coord;
    vps.time = time;
    vps.heading = heading;
    vps.depth = depth;

    vps.finiteWaterStationaryPoints = finiteWaterStationaryPoints;
    vps.fnhInfo = fnhInfo;
    vps.hInfo = hInfo;
    vps.alphaInfo = alphaInfo;

    return vps;
}

#endif // __VESSELPATHSTRUCT_HLSL__