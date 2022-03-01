#ifndef __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__
#define __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__

#include "ComputeElevationLocalDeepWater.hlsl"
#include "HLSLMath.hlsl"
#include "VesselGeometryStruct.hlsl"

float FiniteWaterDispersionRelationDummy(float k, float fnh, float h, float theta)
{
    // k is a guess, used to compute a new k.
    return pow(fnh, 2) * k * h * pow(cos(theta), 2) - tanh(k * h);
}

float FiniteWaterDispersionRelationDerivativeDummy(float k, float fnh, float h, float theta)
{
    // k is a guess, used to compute a new k. Central differences are used to approximate the derivative.
    return (FiniteWaterDispersionRelationDummy(k + 0.001, fnh, h, theta) - FiniteWaterDispersionRelationDummy(k - 0.001, fnh, h, theta)) / 0.002;
}

float FiniteWaterDispersionRelation(float fnh, float h, float theta)
{
    // The dispersion relation is solved using Newton's method. Settings are:
    int max_iter = 50;
    float epsilon = 1e-6;

    // Initialize for use in Newton's method.
    float fxn, dfxn;

    // Define initial guess for k, herby denoted as x.
    float xn = 10.0;  

    for (int n = 0; n < max_iter; n++)
    {
        fxn = FiniteWaterDispersionRelationDummy(xn, fnh, h, theta);
        if (abs(fxn) < epsilon)     // A solution is found.
        {
            return xn;
        }
        dfxn = FiniteWaterDispersionRelationDerivativeDummy(xn, fnh, h, theta);
        if (IsClose(dfxn, 0.0))     // Zero derivative. No solution is found.
        {
            return 0.0;  
        }
        xn = xn - fxn / dfxn;
    }
    float k = xn;
    return k;
}

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
float ComputeShipWaveElevationLocalFiniteWater(float x, float z, int vesselNum, VesselGeometryStruct vgs, float U)
{
    return 1.0;
}

#endif // __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__