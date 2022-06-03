#ifndef __COMPUTEELEVATIONLOCALDEEPWATER_HLSL__
#define __COMPUTEELEVATIONLOCALDEEPWATER_HLSL__

#include "HLSLMath.hlsl"
#include "VesselGeometryStruct.hlsl"

#define KELVIN_ANGLE 0.3398369095

float2 ComplexAmplitudeFunctionDeepWater(int vesselNum, VesselGeometryStruct vgs, float theta, float U)
{
    int vesselNx = vgs.vesselNxNy[0];
    int vesselNy = vgs.vesselNxNy[1];

    int vesselCoordIndexStart = vesselNum * vesselNx * vesselNy;

    float dx = vgs.coord[vesselCoordIndexStart + vesselNy].x - vgs.coord[vesselCoordIndexStart + 0].x;
    float dy = abs(vgs.coord[vesselCoordIndexStart + 1].y - vgs.coord[vesselCoordIndexStart + 0].y);
    
    float P = 0.0;
    float Q = 0.0;

    float k0 = g / pow(U, 2.0);

    float K = k0 / pow(cos(theta), 2.0) * dy;
    float omega0 = (exp(K) - 1.0 - K) / pow(K, 2.0);
    float omegaNy = (exp(-K) - 1.0 + K) / pow(K, 2.0);
    float omegaJ = (exp(K) + exp(-K) - 2.0) / pow(K, 2.0);

    float K2 = k0 / cos(theta) * dx;
    float omegaEven = (3.0 * K2 + K2 * cos(2.0 * K2) - 2.0 * sin(2.0 * K2)) / pow(K2, 3.0);
    float omegaOdd = 4.0 * (sin(K2) - K2 * cos(K2)) / pow(K2, 3.0);

    for (int i = 0; i < vesselNx; i++)
    {
        int refIndex = vesselCoordIndexStart + i * vesselNy;

        float F = 0.0;
        F += omega0 * vgs.coord[refIndex + vesselNy - 1].z * exp(k0 * vgs.coord[refIndex + vesselNy - 1].y / pow(cos(theta), 2.0)) * dy;
        F += omegaNy * vgs.coord[refIndex + 0].z * exp(k0 * vgs.coord[refIndex + 0].y / pow(cos(theta), 2.0)) * dy;
        for (int j = 1; j < vesselNy - 1; j++)
        {
            F += omegaJ * vgs.coord[refIndex + j].z * exp(k0 * vgs.coord[refIndex + j].y / pow(cos(theta), 2.0)) * dy;
        }
        
        if (Mod(i, 2) == 0.0)
        {
            P += omegaEven * F * cos(k0 * vgs.coord[refIndex].x / cos(theta)) * dx;
            Q += omegaEven * F * sin(k0 * vgs.coord[refIndex].x / cos(theta)) * dx;
        }
        else
        {
            P += omegaOdd * F * cos(k0 * vgs.coord[refIndex].x / cos(theta)) * dx;
            Q += omegaOdd * F * sin(k0 * vgs.coord[refIndex].x / cos(theta)) * dx;
        }
    }

    float2 amp = float2(0.0, -2.0 / PI * pow(k0, 2.0) / pow(cos(theta), 4.0));  // The amplitude is imaginary.
    return c_mul(amp, float2(P, Q));
}

float ComputeShipWaveElevationLocalDeepWater(float x, float z, int vesselNum, VesselGeometryStruct vgs, float U)
{
    float k0 = g / pow(U, 2.0);

    // Compute polar coordinate equivalent to (x, z).
    float r = sqrt(pow(x, 2.0) + pow(z, 2.0));
    float alpha = atan2(z, x);
    alpha = abs(alpha);     // Solution is symmetric about the x-axis.

    // If alpha is above the Kelvin half angle, the wave elevation is zero.
    float deltaBoundary = 0.01;        // To avoid singularities at boundary equal to Kelvin angle.
    
    if (alpha >= KELVIN_ANGLE - deltaBoundary)     // In deep water, no elevation is assumed outside the Kelvin angle.
    {
        alpha = KELVIN_ANGLE - deltaBoundary;
    }
    
    // For the method of stationary phase, dG/dtheta gives two solutions within the interval [-PI/2, PI/2] for theta.
    float2 theta = float2(alpha / 2.0 - 0.5 * asin(3.0 * sin(alpha)), 
                        -PI / 2.0 + alpha / 2.0 + 0.5 * asin(3.0 * sin(alpha)));


    // Each theta has its own amplitude (transverse and divergent wave amplitude).
    float2 A1 = ComplexAmplitudeFunctionDeepWater(vesselNum, vgs, theta.x, U); // float2 since complex -> float2(real, imaginary)
    float2 A2 = ComplexAmplitudeFunctionDeepWater(vesselNum, vgs, theta.y, U); // float2 since complex -> float2(real, imaginary)

    // Check if amplitude is nan (not a number) or inf (infinite). If so, set as zero.
    if (isnan(abs(A1.x)) || isnan(abs(A1.y)) || isinf(abs(A1.x)) || isinf(abs(A1.y)))
    {
        A1 = float2(0.0, 0.0);
    }
    if (isnan(abs(A2.x)) || isnan(abs(A2.y)) || isinf(abs(A2.x)) || isinf(abs(A2.y)))
    {
        A2 = float2(0.0, 0.0);
    }

    // Compute wave elevation.
    float amp = sqrt(2.0 * PI / k0 / r) * pow(abs(1.0 - 9.0 * pow(sin(alpha), 2.0)), -0.25);

    A1.x *= pow(abs(cos(theta.x)), 3.0 / 2.0);
    A1.y *= pow(abs(cos(theta.x)), 3.0 / 2.0);
    float2 temp1 = c_mul(A1, c_exp(float2(0.0, k0 * r * cos(theta.x - alpha) / pow(cos(theta.x), 2.0) + PI / 4.0)));

    A2.x *= pow(abs(cos(theta.y)), 3.0 / 2.0);
    A2.y *= pow(abs(cos(theta.y)), 3.0 / 2.0);
    float2 temp2 = c_mul(A2, c_exp(float2(0.0, k0 * r * cos(theta.y - alpha) / pow(cos(theta.y), 2.0) - PI / 4.0)));

    // Include viscous correction factor
    float nu = 0.0002;
    float v1 = exp(-4.0 * pow(k0, 2.0) / U * nu / pow(cos(theta.x), 4.0) * (x + z * tan(theta.x)));
    float v2 = exp(-4.0 * pow(k0, 2.0) / U * nu / pow(cos(theta.y), 4.0) * (x + z * tan(theta.y)));
    
    float zeta = amp * (v1 * temp1.x + v2 * temp2.x);     // Want the real part of the elevation.
    return zeta;
}

#endif // __COMPUTEELEVATIONLOCALDEEPWATER_HLSL__