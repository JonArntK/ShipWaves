#ifndef __COMPUTEELEVATIONGLOBALFINITEWATERFUNCTIONS_HLSL__
#define __COMPUTEELEVATIONGLOBALFINITEWATERFUNCTIONS_HLSL__

#include "HLSLMath.hlsl"

// Check if a point is inside a circle with given origo at (x0, z0).
bool IsPointInEllipse(float x, float z, float x0, float z0, float r)
{
    return false;
}

float3 GetCircleGlobalFiniteWater(float XP, float ZP, float U, float t, float tP, float heading)
{
    float dt = t - tP; // Time difference from when at point P and now.

    float Vg = 0.25 * U * dt; // Circle radius, equal to the group velocity with theta = 0.

    float X0 = XP + Vg * cos(heading); // Center of circle in global coordinate system, x-component.
    float Z0 = ZP + Vg * sin(heading); // Center of circle in global coordinate system, z-component.

    return float3(X0, Z0, Vg);
}

bool IsPointInRegionFiniteWater()
{
    return false;
}

#endif // __COMPUTEELEVATIONGLOBALFINITEWATERFUNCTIONS_HLSL__