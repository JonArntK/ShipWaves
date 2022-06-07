#ifndef __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__
#define __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__

#include "ComputeElevationLocalDeepWater.hlsl"
#include "ComputeElevationGlobalFiniteWaterFunctions.hlsl"
#include "FiniteWaterDispersionRelation.hlsl"
#include "HLSLMath.hlsl"
#include "StationaryPhaseFiniteWater.hlsl"
#include "VesselGeometryStruct.hlsl"



float2 ComplexAmplitudeFunctionFiniteWater(int vesselNum, VesselGeometryStruct vgs, float theta, float U, float fnh)
{
    // Computes the complex amplitude function for a vessel on a straight path in finite water depth
    
    float h = (float) pow(U / fnh, 2.0) / g;

    int vesselNx = vgs.vesselNxNy[0];
    int vesselNy = vgs.vesselNxNy[1];

    int vesselCoordIndexStart = vesselNum * vesselNx * vesselNy;

    float dx = vgs.coord[vesselCoordIndexStart + vesselNy].x - vgs.coord[vesselCoordIndexStart + 0].x;
    float dy = abs(vgs.coord[vesselCoordIndexStart + 1].y - vgs.coord[vesselCoordIndexStart + 0].y);

    float k = FiniteWaterDispersionRelation(fnh, h, theta);
    float k0 = g / (float) pow(U, 2.0);

    float P = 0.0;
    float Q = 0.0;

    float K = k * dy;
    float omega0 = ((float) exp(K) - (float) 1.0 - K) / (float) pow(K, 2.0);
    float omegaNy = ((float) exp(-K) - (float) 1.0 + K) / (float) pow(K, 2.0);
    float omegaJ = ((float) exp(K) + (float) exp(-K) - 2.0) / (float) pow(K, 2.0);

    float K2 = k * (float) cos(theta) * dx;
    float omegaEven = (3.0 * K2 + K2 * (float) cos(2.0 * K2) - 2.0 * (float) sin(2.0 * K2)) / (float) pow(K2, 3.0);
    float omegaOdd = 4.0 * ((float) sin(K2) - K2 * (float) cos(K2)) / (float) pow(K2, 3.0);

    for (int i = 0; i < vesselNx; i++)
    {
        int refIndex = vesselCoordIndexStart + i * vesselNy;

        float F = 0.0;
        F += omega0 * vgs.coord[refIndex + vesselNy - 1].z * (float) cosh(k * (vgs.coord[refIndex + vesselNy - 1].y + h)) / (float) cosh(k * h) * dy;
        F += omegaNy * vgs.coord[refIndex + 0].z * (float) cosh(k * (vgs.coord[refIndex + 0].y + h)) / cosh(k * h) * dy;
        for (int j = 1; j < vesselNy - 1; j++)
        {
            F += omegaJ * vgs.coord[refIndex + j].z * (float) cosh(k * (vgs.coord[refIndex + j].y + h)) / cosh(k * h) * dy;
        }

        if (Mod(i, 2) == 0.0)
        {
            P += omegaEven * F * (float) cos(k * vgs.coord[refIndex].x * cos(theta)) * dx;
            Q += omegaEven * F * (float) sin(k * vgs.coord[refIndex].x * cos(theta)) * dx;
        }
        else
        {
            P += omegaOdd * F * (float) cos(k * vgs.coord[refIndex].x * cos(theta)) * dx;
            Q += omegaOdd * F * (float) sin(k * vgs.coord[refIndex].x * cos(theta)) * dx;
        }
    }
    
    float2 amp = float2(0.0, -2.0 / PI * (float) pow(k, 2.0) / (1.0 - k0 * h * (float) pow(1 / cos(theta), 2.0) * (float) pow(1.0 / cosh(k * h), 2.0)));
    return c_mul(amp, float2(P, Q));
}
float ComputeShipWaveElevationLocalFiniteWater(float x, float z, int vesselNum, VesselGeometryStruct vgs, float U, float h, VesselPathStruct vps)
{
    float fnh = Fnh(U, h);

    // Compute polar coordinate equivalent to (x, z).
    float r = sqrt(pow(x, 2.0) + pow(z, 2.0));
    float alpha = atan2(z, x);
    alpha = abs(alpha); // Solution is symmetric about the x-axis.

    // If alpha is above the Kelvin half angle, the wave elevation is zero.
    float deltaBoundary = 0.02; // To avoid singularities at boundary.

    if (alpha >= PI * 0.5 - deltaBoundary)     // No elevation is present ahead of the vessel.
    {
        return float(0.0);
    }
    
    //float2 theta = GetPointsOfStationaryPhaseFiniteWaterBuffer(vps, fnh, h, alpha); // 
    float2 theta = GetPointsOfStationaryPhaseFiniteWater(float2(-PI * 0.5 + 0.02, 0.00), fnh, h, alpha); // 

    
    // Each theta has its own amplitude (transverse and divergent wave amplitude). Then compute wave elevation.
    float2 A1 = float2(0.0, 0.0), temp1 = float2(0.0, 0.0);
    if (fnh < 1.0)  // Only compute amplitude for the transverse waves when at subcritical depth Froude number.
    {
        A1 = ComplexAmplitudeFunctionFiniteWater(vesselNum, vgs, theta.x, U, fnh); // float2 since complex -> float2(real, imaginary)
        A1.x *= (float) sqrt(2.0 * PI / (r * abs(ddG(theta.x, fnh, h, alpha))));
        A1.y *= (float) sqrt(2.0 * PI / (r * abs(ddG(theta.x, fnh, h, alpha))));
        temp1 = c_mul(A1, c_exp(float2(0.0, r * G(theta.x, fnh, h, alpha) + PI / 4.0)));
    }
    float2 A2 = ComplexAmplitudeFunctionFiniteWater(vesselNum, vgs, theta.y, U, fnh); // float2 since complex -> float2(real, imaginary)
    A2.x *= (float) sqrt(2.0 * PI / (r * abs(ddG(theta.y, fnh, h, alpha))));
    A2.y *= (float) sqrt(2.0 * PI / (r * abs(ddG(theta.y, fnh, h, alpha))));
    float2 temp2 = c_mul(A2, c_exp(float2(0.0, r * G(theta.y, fnh, h, alpha) - PI / 4.0)));
    
    // Check for singularities or NaN and remove if present.
    if (isnan(temp1.x) || isinf(temp1.x))
        temp1.x = 0.0;
    else if ((isnan(temp2.x) || isinf(temp2.x)))
        temp2.x = 0.0;
    
    // Include viscous correction factor.
    float nu = 0.0002;
    
    float k1 = FiniteWaterDispersionRelation(fnh, h, theta.x);
    float v1 = exp(-4.0 * nu * U * pow(k1, 3) * cos(theta.x) * (x + z * tan(theta.x)));
    
    float k2 = FiniteWaterDispersionRelation(fnh, h, theta.y);
    float v2 = exp(-4.0 * nu * U * pow(k2, 3) * cos(theta.y) * (x + z * tan(theta.y)));
    
    
    float zeta = v1 * temp1.x + v2 * temp2.x; // Want the real part of the elevation. 
    return zeta;
}

#endif // __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__