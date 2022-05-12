#ifndef __TESTSINWAVE_HLSL__
#define __TESTSINWAVE_HLSL__

#include "ComputeElevationGlobal.hlsl"
#include "VesselGeometryStruct.hlsl"
#include "VesselPathStruct.hlsl"
#include "WallReflectionFunctions.hlsl"

float ComputeShipElevationGlobalSinWave(float2 XZ, float2 sourceXZ, bool isWallReflection, StructuredBuffer<float4> walls, int numWalls, int currentWall, float time)
{
    // Check if point is valid, i.e., if it is inside the region on disturbance and not obstructed by any walls w.r.t. the source point. 
    if (!IsPointObstructedByWall(XZ, sourceXZ, walls, currentWall, numWalls, isWallReflection))
    {
        if (!isWallReflection ||
                (isWallReflection && isWallReflectionValid(XZ, sourceXZ, walls[currentWall])))
        {
            float theta = atan2(-sourceXZ.y, -sourceXZ.x);
            float A = 0.04;
            float omega = 2.0 * PI / 1.7;
            float k = omega * omega / g;
            
            float elevation = A * cos(k * XZ.x * cos(theta) + k * XZ.y * sin(theta) - omega * time);
            
            return elevation;
        }
    }
    
    return 0.0;
}

float ComputeWallReflectionSinWave(float2 XZ, float2 sourceXZ, StructuredBuffer<float4> walls, int numWalls, int currentWall, float time)
{
    // Initialize elevation as 0.
    float elevation = 0;
    
    // Add contribution from wall reflection from all walls.
    for (int i = 0; i < numWalls; i++)
    {
        // Compute point reflected about wall.
        float2 reflectedPoint = ReflectPointOverWall(XZ, walls[i].xy, walls[i].zw);
    
        // Compute elevation as if the reflected point was the point of interest. This will give the mirroring effect.
        elevation += ComputeShipElevationGlobalSinWave(reflectedPoint, sourceXZ, true, walls, numWalls, i, time);
    }
    
    // Return the elevation.
    return elevation;
}


#endif // __TESTSINWAVE_HLSL__