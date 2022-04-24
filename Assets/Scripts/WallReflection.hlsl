#ifndef __WALLREFLECTION_HLSL__
#define __WALLREFLECTION_HLSL__

#include "ComputeElevationGlobal.hlsl"
#include "VesselGeometryStruct.hlsl"
#include "VesselPathStruct.hlsl"
#include "./Wall Reflection/WallReflectionFunctions.hlsl"

float ComputeWallReflection(float X, float Z, int vesselNum, VesselGeometryStruct vgs, VesselPathStruct vps)
{
    // Define wall.
    float2 wallStart = float2(-50.0, -50.0), wallEnd = float2(0, -50.0);    
    
    // Compute point reflected about wall.
    float2 reflectedPoint = ReflectPointOverWall(float2(X, Z), wallStart, wallEnd);
    
    float elevation = ComputeShipWaveElevationGlobal(reflectedPoint.x, reflectedPoint.y, vesselNum, vgs, vps, true);
    return elevation;
}


#endif // __WALLREFLECTION_HLSL__