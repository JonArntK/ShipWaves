#ifndef __WALLREFLECTION_HLSL__
#define __WALLREFLECTION_HLSL__

#include "ComputeElevationGlobal.hlsl"
#include "VesselGeometryStruct.hlsl"
#include "VesselPathStruct.hlsl"

float2 ReflectPointOverLine(float2 P, float2 lineStart, float2 lineEnd)
{    
    if (lineStart.x == lineEnd.x)           // If the line is vertical, giving an infinite slope.
    {
        return float2(P.x + 2.0 * (lineEnd.x - P.x), P.y);
    }
    else if (lineStart.y == lineEnd.y)      // If the line is horizontal, giving a slope of zero.
    {
        return float2(P.x, P.y + 2.0 * (lineEnd.y - P.y));
    }
    else // General case.
    {
        float lineSlope = (lineEnd.y - lineStart.y) / (lineEnd.x - lineStart.x);
        float lineIntercept = lineEnd.y - lineSlope * lineEnd.x;
    
        float orthoLineSlope = -1.0 / lineSlope;
        float orthoLineIntercept = P.y - orthoLineSlope * P.x;
    
        float linePx = (orthoLineIntercept - lineIntercept) / (lineSlope - orthoLineSlope);
        float linePy = lineSlope * linePx + lineIntercept;
        
        return float2(P.x + 2.0 * (linePx - P.x), P.y + 2.0 * (linePy - P.y));
    }
}

float ComputeWallReflection(float X, float Z, int vesselNum, VesselGeometryStruct vgs, VesselPathStruct vps)
{
    // Define wall.
    float2 wallStart = float2(-50.0, -50.0), wallEnd = float2(0, -50.0);    
    
    // Compute point reflected about wall.
    float2 reflectedPoint = ReflectPointOverLine(float2(X, Z), wallStart, wallEnd);
    
    float elevation = ComputeShipWaveElevationGlobal(reflectedPoint.x, reflectedPoint.y, vesselNum, vgs, vps);
    return elevation;
}

#endif // __WALLREFLECTION_HLSL__