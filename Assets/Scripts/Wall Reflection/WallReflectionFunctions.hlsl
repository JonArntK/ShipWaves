#ifndef __WALLREFLECTIONFUNCTIONS_HLSL__
#define __WALLREFLECTIONFUNCTIONS_HLSL__

#include "../HLSLMath.hlsl"

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

bool isWallReflectionValid(float X, float Z, float vesselX, float vesselZ)
{
    // Define wall.
    float2 wallStart = float2(-50.0, -50.0), wallEnd = float2(0, -50.0);
    
    // Compute the line corresponding to [wallStart, wallEnd] as a linear function 'y = ax + b'.
    float wallSlope = (wallEnd.y - wallStart.y) / (wallEnd.x - wallStart.x);
    float wallIntercept = wallEnd.y - wallSlope * wallEnd.x;
    
    // We only want to compute the reflection if the point lineP is on the line, i.e.,
    // not when the reflection is about an extended part of the original line.
    float pointSlope = (vesselZ - Z) / (vesselX - X);
    float pointIntercept = vesselZ - pointSlope * vesselX;
    
    // Locate where the original line intercepts the orthogonal line. The following vector from P to lineP 
        // is by definition half the distance of the reflection.
    float linePx = (pointIntercept - wallIntercept) / (wallSlope - pointSlope);
    float linePy = wallSlope * linePx + wallIntercept;
    
    if (linePx > max(wallStart.x, wallEnd.x) || linePx < min(wallStart.x, wallEnd.x) ||
        linePy > max(wallStart.y, wallEnd.y) || linePy < min(wallStart.y, wallEnd.y))
    {
        return false;
    }
    return true;
}
#endif // __WALLREFLECTIONFUNCTIONS_HLSL__