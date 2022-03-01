#ifndef __VESSELPATHSTRUCT_HLSL__
#define __VESSELPATHSTRUCT_HLSL__

// Store information regarding the vessel paths.
struct VesselPathStruct
{
    StructuredBuffer<float2> coord;
    StructuredBuffer<float> time;
    StructuredBuffer<float> heading;
    StructuredBuffer<float> depth;
};

// Initialize VesselPathStruct
VesselPathStruct InitalizeVesselPath(StructuredBuffer<float2> coord, 
    StructuredBuffer<float> time, StructuredBuffer<float> heading, StructuredBuffer<float> depth)
{
    VesselPathStruct vps;
    vps.coord = coord;
    vps.time = time;
    vps.heading = heading;
    vps.depth = depth;
    return vps;
}

#endif // __VESSELPATHSTRUCT_HLSL__