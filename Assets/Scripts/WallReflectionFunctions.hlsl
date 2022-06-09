#ifndef __WALLREFLECTIONFUNCTIONS_HLSL__
#define __WALLREFLECTIONFUNCTIONS_HLSL__

#include "HLSLMath.hlsl"

float2 ReflectPointOverWall(float2 P, float2 wallStart, float2 wallEnd)
{    
    if (wallStart.x == wallEnd.x)           // If the line is vertical, giving an infinite slope.
    {
        return float2(P.x + 2.0 * (wallEnd.x - P.x), P.y);
    }
    else if (wallStart.y == wallEnd.y)      // If the line is horizontal, giving a slope of zero.
    {
        return float2(P.x, P.y + 2.0 * (wallEnd.y - P.y));
    }
    else // General case.
    {
        // Compute the line corresponding to [wallStart, wallEnd] as a linear function 'y = ax + b'.
        float wallSlope = slope(wallStart, wallEnd);
        float wallIntercept = intercept(wallEnd, wallSlope);
    
        // Compute the following orthogonal line on the same format, 'y = cx + d'.
        float orthoLineSlope = -1.0 / wallSlope;
        float orthoLineIntercept = intercept(P, orthoLineSlope);
    
        // Locate where the original line intercepts the orthogonal line. The following vector from P to lineP 
            // is by definition half the distance of the reflection.
        float linePx = (orthoLineIntercept - wallIntercept) / (wallSlope - orthoLineSlope);
        float linePy = wallSlope * linePx + wallIntercept;
        
        // Compute the reflected point.
        return float2(P.x + 2.0 * (linePx - P.x), P.y + 2.0 * (linePy - P.y));
    }
}

bool isWallReflectionValid(float2 XZ, float2 vesselXZ, float4 wall)
{
    // Define wall.
    float2 wallStart = wall.xy, wallEnd = wall.zw;
    
    // Locate intersection between the wall and the line from the vessel path (source) to the point reflected about the wall.
    float2 p = intersection(wallStart, wallEnd, vesselXZ, XZ);

    // If the intersection is not at the wall, then there should be no reflection, and hence the reflection is invalid.
    if (p.x > max(wallStart.x, wallEnd.x) || p.x < min(wallStart.x, wallEnd.x) ||
        p.y > max(wallStart.y, wallEnd.y) || p.y < min(wallStart.y, wallEnd.y))
    {
        return false;
    }
    return true;
}

bool IsIntersectionAtWall(float2 p, float2 p11, float2 p12, float2 p21, float2 p22)
{
    // Returns true if the intersection between the lines projected by the limits [p11, p12] and [p21, p22] is
        // on within the limit given by the points. (no extrapolation)
    return !(p.x > max(p21.x, p22.x) || p.x < min(p21.x, p22.x) ||
             p.y > max(p21.y, p22.y) || p.y < min(p21.y, p22.y) ||
             p.x > max(p11.x, p12.x) || p.x < min(p11.x, p12.x) ||
             p.y > max(p11.y, p12.y) || p.y < min(p11.y, p12.y));
}

bool IsPointObstructedByWall(float2 XZ, float2 vesselXZ, StructuredBuffer<float4> walls, int currentWall, int numWalls, bool isWallReflection)
{
    
    // Locate intersection between the wall and the line from the vessel path (source) to the point of interest.
    float2 pCurrentWall = intersection(walls[currentWall].xy, walls[currentWall].zw, vesselXZ, XZ);
            
    // Verify that the intersection is at the wall, i.e., that we are evaluating the reflection from the correct side of the wall.
    if (isWallReflection && !IsIntersectionAtWall(pCurrentWall, XZ, vesselXZ, walls[currentWall].xy, walls[currentWall].zw))
    {
        return true;
    }
    
    float2 originalXZ = ReflectPointOverWall(XZ, walls[currentWall].xy, walls[currentWall].zw);
    
    
    for (int i = 0; i < numWalls; i++)
    {
        float2 wallStart = walls[i].xy, wallEnd = walls[i].zw;
    
        if (isWallReflection)   // If it is a wall reflection.
        {
            float2 p1 = intersection(wallStart, wallEnd, vesselXZ, pCurrentWall);
            float2 p2 = intersection(wallStart, wallEnd, originalXZ, pCurrentWall);
            
            if (i != currentWall && 
                (IsIntersectionAtWall(p1, pCurrentWall, vesselXZ, wallStart, wallEnd) ||
                IsIntersectionAtWall(p2, pCurrentWall, originalXZ, wallStart, wallEnd)))
            {
                return true;
            }
        }
        else // If it is not a wall reflection.
        {
            // Locate intersection between the wall and the line from the vessel path (source) to the point of interest.
            float2 p = intersection(wallStart, wallEnd, vesselXZ, XZ);
            
            // If the intersection (within the limits of [XZ, vesselXZ] is at the wall, 
            // then there should be no elevation, since the waves would have been reflected away.
            if (IsIntersectionAtWall(p, XZ, vesselXZ, wallStart, wallEnd))
            {
                // If the intersection is at the wall, return true (since the point is obstructed by wall).
                return true;
            }
        }
    }
    
    return false;
}

#endif // __WALLREFLECTIONFUNCTIONS_HLSL__