#ifndef __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__
#define __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__

#include "ComputeElevationLocalDeepWater.hlsl"
#include "ComputeElevationGlobalFiniteWaterFunctions.hlsl"
#include "FiniteWaterDispersionRelation.hlsl"
#include "HLSLMath.hlsl"
#include "StationaryPhaseFiniteWater.hlsl"
#include "VesselGeometryStruct.hlsl"



float2 ComplexAmplitudeFunctionFiniteWater(int vesselNum, VesselGeometryStruct vgs, float theta, float U, float fnh, float h)
{
    int vesselNx = vgs.vesselNxNy[0];
    int vesselNy = vgs.vesselNxNy[1];

    int vesselCoordIndexStart = vesselNum * vesselNx * vesselNy;

    float dx = vgs.coord[vesselCoordIndexStart + vesselNy].x - vgs.coord[vesselCoordIndexStart + 0].x;
    float dy = vgs.coord[vesselCoordIndexStart + 1].y - vgs.coord[vesselCoordIndexStart + 0].y;

    float k = FiniteWaterDispersionRelation(fnh, h, theta);
    float k0 = g / pow(U, 2.0);

    float P = 0.0;
    float Q = 0.0;

    float K = k * dy;
    float omega0 = (exp(K) - 1.0 - K) / pow(K, 2.0);
    float omegaNy = (exp(-K) - 1.0 + K) / pow(K, 2.0);
    float omegaJ = (exp(K) + exp(-K) - 2.0) / pow(K, 2.0);

    float K2 = k * cos(theta * dx);
    float omegaEven = (3.0 * K2 + K2 * cos(2.0 * K2) - 2.0 * sin(2.0 * K2)) / pow(K2, 3.0);
    float omegaOdd = 4.0 * (sin(K2) - K2 * cos(K2)) / pow(K2, 3.0);

    for (int i = 0; i < vesselNx; i++)
    {
        int refIndex = vesselCoordIndexStart + i * vesselNy;

        float F = 0.0;
        F += omega0 * vgs.coord[refIndex + 0].z * cosh(k * (vgs.coord[refIndex + 0].y + h) / cosh(k * h)) * dy;
        F += omegaNy * vgs.coord[refIndex + vesselNy - 1].z * cosh(k * (vgs.coord[refIndex + vesselNy - 1].y + h) / cosh(k * h)) * dy;
        for (int j = 1; j < vesselNy - 1; j++)
        {
            F += omegaJ * vgs.coord[refIndex + j].z * cosh(k * (vgs.coord[refIndex + j].y + h) / cosh(k * h)) * dy;
        }

        if (Mod(i, 2) == 0.0)
        {
            P += omegaEven * F * cos(k * vgs.coord[refIndex].x / cos(theta)) * dx;
            Q += omegaEven * F * sin(k * vgs.coord[refIndex].x / cos(theta)) * dx;
        }
        else
        {
            P += omegaOdd * F * cos(k * vgs.coord[refIndex].x / cos(theta)) * dx;
            Q += omegaOdd * F * sin(k * vgs.coord[refIndex].x / cos(theta)) * dx;
        }
    }

    float2 amp = float2(0.0, -2.0 / PI * pow(k, 2.0) / (1.0 - k0 * h * pow(1 / cos(theta), 2.0) * pow(1.0 / cosh(k * h), 2.0)));
    return c_mul(amp, float2(P, Q));
}
float ComputeShipWaveElevationLocalFiniteWater(float x, float z, int vesselNum, VesselGeometryStruct vgs, float U, float h)
{
    float fnh = Fnh(U, h);
    float k0 = g / pow(U, 2.0);

    // Compute polar coordinate equivalent to (x, z).
    float r = sqrt(pow(x, 2.0) + pow(z, 2.0));
    float alpha = atan2(z, x);
    alpha = abs(alpha); // Solution is symmetric about the x-axis.

    // If alpha is above the Kelvin half angle, the wave elevation is zero.
    float deltaBoundary = 0.02; // To avoid singularities at boundary.

    if (abs(alpha) >= PI * 0.5 - deltaBoundary)     // No elevation is present ahead of the vessel.
    {
        return float(0.0);
    }

    float2 theta = GetPointsOfStationaryPhaseFiniteWater(float2(-PI * 0.5 + 0.001, 0.0), fnh, h, alpha);

    // Each theta has its own amplitude (transverse and divergent wave amplitude). Then compute wave elevation.
    float2 A1 = float2(0.0, 0.0), temp1 = float2(0.0, 0.0);
    if (fnh < 1.0)  // Only compute amplitude for the transverse waves when at subcritical depth Froude number.
    {
        A1 = ComplexAmplitudeFunctionDeepWater(vesselNum, vgs, theta.x, U); // float2 since complex -> float2(real, imaginary)
        A1.x *= pow(abs(cos(theta.x)), 3.0 / 2.0);
        A1.y *= pow(abs(cos(theta.x)), 3.0 / 2.0);
        temp1 = c_mul(A1, c_exp(float2(0.0, k0 * r * cos(theta.x - alpha) / pow(cos(theta.x), 2.0) + PI / 4.0)));
    }
    float2 A2 = ComplexAmplitudeFunctionDeepWater(vesselNum, vgs, theta.y, U); // float2 since complex -> float2(real, imaginary)
    A2.x *= pow(abs(cos(theta.y)), 3.0 / 2.0);
    A2.y *= pow(abs(cos(theta.y)), 3.0 / 2.0);
    float2 temp2 = c_mul(A2, c_exp(float2(0.0, k0 * r * cos(theta.y - alpha) / pow(cos(theta.y), 2.0) - PI / 4.0)));
    
    float amp = sqrt(2.0 * PI / k0 / r) * pow(abs(1.0 - 9.0 * pow(sin(alpha), 2.0)), -0.25);
    
    float zeta = amp * (temp1.x + temp2.x); // Want the real part of the elevation.
    return zeta;
}

#endif // __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__