#ifndef __STATIONARYPHASEFINITEWATER_HLSL__
#define __STATIONARYPHASEFINITEWATER_HLSL__

#include "FiniteWaterDispersionRelation.hlsl"
#include "HLSLMath.hlsl"
#include "VesselPathStruct.hlsl"

float G(float theta, float fnh, float h, float alpha)
{
    float k = FiniteWaterDispersionRelation(fnh, h, theta);
    return k * (float) cos(theta - alpha);
}

float dG(float theta, float fnh, float h, float alpha)
{
    // Using central differences to approximate the derivative of G.
    return (G(theta + 1e-3, fnh, h, alpha) - G(theta - 1e-3, fnh, h, alpha)) / 2e-3;
}

float ddG(float theta, float fnh, float h, float alpha)
{
    // Using central differences to approximate the derivative of G.
    return (dG(theta + 1e-3, fnh, h, alpha) - dG(theta - 1e-3, fnh, h, alpha)) / 2e-3;
}

float2 GetPointsOfStationaryPhaseFiniteWater2(float fnh, float h, float alpha)
{
    if (alpha > 0.6)
        return float2(1.0, 1.0);
    
    
    float a1[7] = { -3.14541283e+02, 6.07643732e+02, -4.68613568e+02, 1.82625520e+02, -3.77455293e+01, 3.65870757e+00, -1.54308890e-01};
    float a2[7] = { -127.67414369, 319.67615585, -279.63011277, 105.4909492, -16.81786871, 3.11088322, -1.59058049};
    
    float theta1 = pow(alpha, 6.0) * a1[0] + pow(alpha, 5.0) * a1[1] + pow(alpha, 4.0) * a1[2] + pow(alpha, 3.0) * a1[3] + pow(alpha, 2.0) * a1[4] + pow(alpha, 1.0) * a1[5] + a1[6];
    float theta2 = pow(alpha, 6.0) * a2[0] + pow(alpha, 5.0) * a2[1] + pow(alpha, 4.0) * a2[2] + pow(alpha, 3.0) * a2[3] + pow(alpha, 2.0) * a2[4] + pow(alpha, 1.0) * a2[5] + a2[6];

    
    return float2(theta1, theta2);
}

float2 GetPointsOfStationaryPhaseFiniteWater(float2 thetaInterval, float fnh, float h, float alpha)
{

    int nRoots = 2;
    if (fnh > 1.0)
    {
        nRoots = 1;
    }

    //float tol = 1e-3;
    //int N = (int) ((thetaInterval.y - thetaInterval.x) / tol);
    float2 thetaStationary = float2(1.0, 1.0);
    
    int N = 1500;
    float tol = (float) ((thetaInterval.y - thetaInterval.x) / N);
    
    float thetaCurrent, dGCurrent, dGPrev = dG(thetaInterval.x, fnh, h, alpha);

    for (int i = 1; i < N; i++)
    {
        thetaCurrent = thetaInterval.x + (float) i * tol;
        dGCurrent = dG(thetaCurrent, fnh, h, alpha);
        
        if (dGPrev * dGCurrent < 0.0)
        {
            if (nRoots == 1)
            {
                if (thetaStationary.y > 0.0)
                    thetaStationary.y = thetaCurrent - tol / 2.0;
                else
                
                thetaStationary.x = thetaCurrent - tol / 2.0;

                return thetaStationary;
            }
            else
            {
                nRoots = 1;
                thetaStationary.y = thetaCurrent - tol / 2.0;
            }
        }

        dGPrev = dGCurrent;
    }
    return thetaStationary;
}


int GetIndex(float value, float4 info)
{
    int index = (int) ((value - info.x) / info.z);

    if (index < 0)
    {
        return 0;
    }
    else if (index >= info.w)
    {
        return info.w - 1;
    }
    else
    {
        return index;
    }
}

float2 GetPointsOfStationaryPhaseFiniteWaterBuffer(VesselPathStruct vps, float fnh, float h, float alpha)
{
    int fnhIndex = GetIndex(fnh, vps.fnhInfo);
    int hIndex = GetIndex(h, vps.hInfo);
    int alphaIndex = GetIndex(alpha, vps.alphaInfo);

    int index = Matrix3DTo1D(fnhIndex, hIndex, alphaIndex, vps.fnhInfo.w, vps.hInfo.w, vps.alphaInfo.w);
    return vps.finiteWaterStationaryPoints[index];
}

#endif // __STATIONARYPHASEFINITEWATER_HLSL__