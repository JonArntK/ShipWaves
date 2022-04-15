#ifndef __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__
#define __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__

#include "ComputeElevationLocalDeepWater.hlsl"
#include "ComputeElevationGlobalFiniteWaterFunctions.hlsl"
#include "FiniteWaterDispersionRelation.hlsl"
#include "HLSLMath.hlsl"
#include "StationaryPhaseFiniteWater.hlsl"
#include "VesselGeometryStruct.hlsl"



double2 ComplexAmplitudeFunctionFiniteWater(int vesselNum, VesselGeometryStruct vgs, double theta, double U, double fnh)
{
    double h = (double) pow(U / fnh, 2.0) / g;

    int vesselNx = vgs.vesselNxNy[0];
    int vesselNy = vgs.vesselNxNy[1];

    int vesselCoordIndexStart = vesselNum * vesselNx * vesselNy;

    double dx = vgs.coord[vesselCoordIndexStart + vesselNy].x - vgs.coord[vesselCoordIndexStart + 0].x;
    double dy = abs(vgs.coord[vesselCoordIndexStart + 1].y - vgs.coord[vesselCoordIndexStart + 0].y);

    double k = FiniteWaterDispersionRelation(fnh, h, theta);
    double k0 = g / (double) pow(U, 2.0);

    double P = 0.0;
    double Q = 0.0;

    double K = k * dy;
    double omega0 = ((double) exp(K) - (double) 1.0 - K) / (double) pow(K, 2.0);
    double omegaNy = ((double) exp(-K) - (double) 1.0 + K) / (double) pow(K, 2.0);
    double omegaJ = ((double) exp(K) + (double) exp(-K) - 2.0) / (double) pow(K, 2.0);

    double K2 = k * (double) cos(theta) * dx;
    double omegaEven = (3.0 * K2 + K2 * (double) cos(2.0 * K2) - 2.0 * (double) sin(2.0 * K2)) / (double) pow(K2, 3.0);
    double omegaOdd = 4.0 * ((double) sin(K2) - K2 * (double) cos(K2)) / (double) pow(K2, 3.0);

    for (int i = 0; i < vesselNx; i++)
    {
        int refIndex = vesselCoordIndexStart + i * vesselNy;

        double F = 0.0;
        F += omega0 * vgs.coord[refIndex + vesselNy - 1].z * (double) cosh(k * (vgs.coord[refIndex + vesselNy - 1].y + h)) / (double) cosh(k * h) * dy;
        F += omegaNy * vgs.coord[refIndex + 0].z * (double) cosh(k * (vgs.coord[refIndex + 0].y + h)) / cosh(k * h) * dy;
        for (int j = 1; j < vesselNy - 1; j++)
        {
            F += omegaJ * vgs.coord[refIndex + j].z * (double) cosh(k * (vgs.coord[refIndex + j].y + h)) / cosh(k * h) * dy;
        }

        if (Mod(i, 2) == 0.0)
        {
            P += omegaEven * F * (double) cos(k * vgs.coord[refIndex].x * cos(theta)) * dx;
            Q += omegaEven * F * (double) sin(k * vgs.coord[refIndex].x * cos(theta)) * dx;
        }
        else
        {
            P += omegaOdd * F * (double) cos(k * vgs.coord[refIndex].x * cos(theta)) * dx;
            Q += omegaOdd * F * (double) sin(k * vgs.coord[refIndex].x * cos(theta)) * dx;
        }
    }
    
    double2 amp = double2(0.0, -2.0 / PI * (double) pow(k, 2.0) / (1.0 - k0 * h * (double) pow(1 / cos(theta), 2.0) * (double) pow(1.0 / cosh(k * h), 2.0)));
    return c_mul(amp, double2(P, Q));
}
double ComputeShipWaveElevationLocalFiniteWater(double x, double z, int vesselNum, VesselGeometryStruct vgs, double U, double h, VesselPathStruct vps)
{
    double fnh = Fnh(U, h);

    // Compute polar coordinate equivalent to (x, z).
    double r = sqrt(pow(x, 2.0) + pow(z, 2.0));
    double alpha = atan2(z, x);
    alpha = abs(alpha); // Solution is symmetric about the x-axis.

    // If alpha is above the Kelvin half angle, the wave elevation is zero.
    double deltaBoundary = 0.02; // To avoid singularities at boundary.

    if (alpha >= PI * 0.5 - deltaBoundary)     // No elevation is present ahead of the vessel.
    {
        return double(0.0);
    }
    
    double2 theta = GetPointsOfStationaryPhaseFiniteWater(double2(-PI * 0.5 + 0.02, 0.00), fnh, h, alpha); // GetPointsOfStationaryPhaseFiniteWaterBuffer(vps, fnh, h, alpha); // 

    if (theta.x > 0.0 || theta.y > 0.0)
    {
        return 2.0;
    }

    // Each theta has its own amplitude (transverse and divergent wave amplitude). Then compute wave elevation.
    double2 A1 = double2(0.0, 0.0), temp1 = double2(0.0, 0.0);
    if (fnh < 1.0)  // Only compute amplitude for the transverse waves when at subcritical depth Froude number.
    {
        A1 = ComplexAmplitudeFunctionFiniteWater(vesselNum, vgs, theta.x, U, fnh); // double2 since complex -> double2(real, imaginary)
        A1.x *= (double) sqrt(2.0 * PI / (r * abs(ddG(theta.x, fnh, h, alpha))));
        A1.y *= (double) sqrt(2.0 * PI / (r * abs(ddG(theta.x, fnh, h, alpha))));
        temp1 = c_mul(A1, c_exp(double2(0.0, r * G(theta.x, fnh, h, alpha) + PI / 4.0)));
    }
    double2 A2 = ComplexAmplitudeFunctionFiniteWater(vesselNum, vgs, theta.y, U, fnh); // double2 since complex -> double2(real, imaginary)
    A2.x *= (double) sqrt(2.0 * PI / (r * abs(ddG(theta.y, fnh, h, alpha))));
    A2.y *= (double) sqrt(2.0 * PI / (r * abs(ddG(theta.y, fnh, h, alpha))));
    double2 temp2 = c_mul(A2, c_exp(double2(0.0, r * G(theta.y, fnh, h, alpha) - PI / 4.0)));
    
    
    double zeta = temp2.x; // + temp2.x;  // Want the real part of the elevation. 
    return zeta;
}

#endif // __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__