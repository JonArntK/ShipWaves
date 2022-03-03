#ifndef __COMPUTEELEVATIONGLOBALFINITEWATERFUNCTIONS_HLSL__
#define __COMPUTEELEVATIONGLOBALFINITEWATERFUNCTIONS_HLSL__

#include "HLSLMath.hlsl"

// Compute depth Froude number.
float Fnh(float U, float h)
{
    return U / sqrt(g * h);
}

// Check if the depth satisfies criteria for finite water.
bool IsFiniteWater(float fnh)
{
    if (fnh > 0.4)
    {
        return true;
    }
    return false;
}

// Check if a point (x, z) is inside an ellipse with width 2a, height 2b, rotated at 'angle' radians with center at (x0, z0).
bool IsPointInEllipse(float x, float z, float x0, float z0, float a, float b, float angle)
{
    return pow((cos(angle) * (x - x0) + sin(angle) * (z - z0)), 2.0) / pow(a, 2.0) + 
           pow((sin(angle) * (x - x0) - cos(angle) * (z - z0)), 2.0) / pow(b, 2.0) <= 1.0;
}

float2 GetEllipseWidthHeight(float fnh, float rDeepWater)
{
    // The ellipse width and height is defined relative to the radius of the corresponding circle for deep water.
    // The values in 'aa' and 'bb' are fitted to match the shape of the ellipse for Fnh in range [0.4, 1.0].
    float aa[5] = { -5.68386249, 17.51752173, -15.7408244, 5.60288223, 0.30324627 };
    float bb[5] = { -0.84655427, 6.64047585, -9.57806052, 4.99030651, 0.12666546 };
    float a = aa[0] * pow(fnh, 4.0) + aa[1] * pow(fnh, 3.0) + aa[2] * pow(fnh, 2.0) + aa[3] * fnh + aa[4];
    float b = bb[0] * pow(fnh, 4.0) + bb[1] * pow(fnh, 3.0) + bb[2] * pow(fnh, 2.0) + bb[3] * fnh + bb[4];
    return float2(a * rDeepWater, b * rDeepWater);
}

float4 GetEllipseGlobalFiniteWater(float XP, float ZP, float U, float t, float tP, float heading, float fnh)
{
    float dt = t - tP; // Time difference from when at point P and now.

    float rDeepWater = 0.25 * U * dt; // Circle radius for deep water, equal to half the group velocity with theta = 0.

    float2 ellipseWidthHeight = GetEllipseWidthHeight(fnh, rDeepWater);

    float X0 = XP + ellipseWidthHeight.x * cos(heading); // Center of circle in global coordinate system, x-component.
    float Z0 = ZP + ellipseWidthHeight.x * sin(heading); // Center of circle in global coordinate system, z-component.

    return float4(X0, Z0, ellipseWidthHeight.x, ellipseWidthHeight.y);
}

bool IsPointInRegionFiniteWater(float X, float Z, float XP, float ZP, float U, float t, float tP, float heading, float fnh)
{
    float4 globalEllipse = GetEllipseGlobalFiniteWater(XP, ZP, U, t, tP, heading, fnh);

    float X0 = globalEllipse.x, Z0 = globalEllipse.y;
    float ellipseWidth = globalEllipse.z, ellipseHeight = globalEllipse.w;

    if (IsPointInEllipse(X, Z, X0, Z0, ellipseWidth, ellipseHeight, heading))
    {
        return true;
    }
    return false;
}

#endif // __COMPUTEELEVATIONGLOBALFINITEWATERFUNCTIONS_HLSL__