#ifndef __COMPUTEELEVATIONGLOBALDEEPWATERFUNCTIONS_HLSL__
#define __COMPUTEELEVATIONGLOBALDEEPWATERFUNCTIONS_HLSL__

// Check if a point (x, z) is inside a circle with radius r and origo at (x0, z0).
bool IsPointInCircle(float x, float z, float x0, float z0, float r)
{
    return pow(x - x0, 2) + pow(z - z0, 2) < pow(r, 2);
}

float3 GetCircleGlobalDeepWater(float XP, float ZP, float U, float t, float tP, float heading)
{
    float dt = t - tP; // Time difference from when at point P and now.

    float r = 0.25 * U * dt; // Circle radius, equal to half the group velocity with theta = 0.

    float X0 = XP + r * cos(heading); // Center of circle in global coordinate system, x-component.
    float Z0 = ZP + r * sin(heading); // Center of circle in global coordinate system, z-component.

    return float3(X0, Z0, r);
}

bool IsPointInRegionDeepWater(float X, float Z, float XP, float ZP, float U, float t, float tP, float heading)
{
    float3 globalCircle = GetCircleGlobalDeepWater(XP, ZP, U, t, tP, heading);
    float X0 = globalCircle.x, Z0 = globalCircle.y, R = globalCircle.z;
    if (IsPointInCircle(X, Z, X0, Z0, R))
    {
        return true;
    }
    return false;
}

#endif // __COMPUTEELEVATIONGLOBALDEEPWATERFUNCTIONS_HLSL__