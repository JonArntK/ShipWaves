#ifndef __WALLREFLECTION_HLSL__
#define __WALLREFLECTION_HLSL__

#include "ComputeElevationGlobal.hlsl"
#include "VesselGeometryStruct.hlsl"
#include "VesselPathStruct.hlsl"
#include "WallReflectionFunctions.hlsl"

float ComputeWallReflection(float2 XZ, int vesselNum, VesselGeometryStruct vgs, VesselPathStruct vps, StructuredBuffer<float4> walls, int numWalls)
{
    // Initialize elevation as 0.
    float elevation = 0;
    
    // Add contribution from wall reflection from all walls.
    for (int i = 0; i < numWalls; i++)
    {
        // Compute point reflected about wall.
        float2 reflectedPoint = ReflectPointOverWall(XZ, walls[i].xy, walls[i].zw);
    
        // Compute elevation as if the reflected point was the point of interest. This will give the mirroring effect.
        elevation += ComputeShipWaveElevationGlobal(reflectedPoint, vesselNum, vgs, vps, true, walls, i, numWalls);
    }
    
    // Return the elevation.
    return elevation;
}


#endif // __WALLREFLECTION_HLSL__