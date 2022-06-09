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
    // The values in 'aa' and 'bb' are fitted to match the shape of the ellipse for Fnh in range [0.4, 1.0] and [1.0, 1.3].
    // 
    // This simplification reduces the necessary computational effort signficantly.

    float a, b; // Initialize.
    if (fnh <= 1.0)  // Valid for Fnh in [0.4, 1.0].
    {
        float aa[5] = { -5.68386249, 17.51752173, -15.7408244, 5.60288223, 0.30324627 };
        float bb[5] = { -0.84655427, 6.64047585, -9.57806052, 4.99030651, 0.12666546 };
        a = aa[0] * pow(fnh, 4.0) + aa[1] * pow(fnh, 3.0) + aa[2] * pow(fnh, 2.0) + aa[3] * fnh + aa[4];
        b = bb[0] * pow(fnh, 4.0) + bb[1] * pow(fnh, 3.0) + bb[2] * pow(fnh, 2.0) + bb[3] * fnh + bb[4];
    }
    else {  // Valid for Fnh in [1.0, 1.3].
        float aa[6] = { 1.20982757e+04, -3.42756971e+03, 3.61976109e+02, 2.35844458e+01, 4.82020395e+00, 2.09440310e-02 };
        float bb[6] = { -6.99986025e+01, 5.49934890e+02, -1.55589753e+02, 2.43251754e+01, 1.00362626e+00, 4.76700487e-03 };

        float a0 = 2.0189910997505467;
        float b0 = 1.3237123674048987;

        fnh -= 1.0; // Was an assumption used when creating the polygons approximating 'a' and 'b' below.

        a = aa[0] * pow(fnh, 5.0) + aa[1] * pow(fnh, 4.0) + aa[2] * pow(fnh, 3.0) + aa[3] * pow(fnh, 2.0) + aa[4] * fnh + aa[5] + a0;
        b = bb[0] * pow(fnh, 5.0) + bb[1] * pow(fnh, 4.0) + bb[2] * pow(fnh, 3.0) + bb[3] * pow(fnh, 2.0) + bb[4] * fnh + bb[5] + b0;
    }
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
    // Get ellipse-shaped disk of disturbance for finite water in global coordinate system.
    float4 globalEllipse = GetEllipseGlobalFiniteWater(XP, ZP, U, t, tP, heading, fnh);

    float X0 = globalEllipse.x, Z0 = globalEllipse.y;
    float ellipseWidth = globalEllipse.z, ellipseHeight = globalEllipse.w;

    if (fnh <= 1.0 && IsPointInEllipse(X, Z, X0, Z0, ellipseWidth, ellipseHeight, heading))  // For Fnh <= 1.0, the ellipse-shaped region
        // of disturbance covers the whole ellipse.
    {
        return true;
    }
    else if (fnh >= 1.0 && IsPointInEllipse(X, Z, X0, Z0, ellipseWidth, ellipseHeight, heading)) // For Fnh > 1.0, a minimum angle theta
        // defines the part of the ellipse which holds the region of disturbance (ref. group velocity for Fnh > 1.0).
    {
        float thetaMark = atan2(Z - ZP, X - XP);
        float theta = heading - thetaMark;
        theta = Mod(theta, 2.0 * PI);   // Ensure that we are operating with a value below 2pi.
        float thetaMin = acos(1.0 / fnh);
        if (abs(theta) > thetaMin && abs(theta) < 2.0 * PI - thetaMin)
            return true;
    }
    return false;
}

#endif // __COMPUTEELEVATIONGLOBALFINITEWATERFUNCTIONS_HLSL__