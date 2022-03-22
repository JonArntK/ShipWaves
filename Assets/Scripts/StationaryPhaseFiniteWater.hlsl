#ifndef __STATIONARYPHASEFINITEWATER_HLSL__
#define __STATIONARYPHASEFINITEWATER_HLSL__

#include "FiniteWaterDispersionRelation.hlsl"
#include "VesselPathStruct.hlsl"

float G(float theta, float fnh, float h, float alpha)
{
    float k = FiniteWaterDispersionRelation(fnh, h, theta);
    return k * cos(theta - alpha);
}

float dG(float theta, float fnh, float h, float alpha)
{
    // Using central differences to approximate the derivative of G.
    return (G(theta + 0.001, fnh, h, alpha) - G(theta - 0.001, fnh, h, alpha)) / 0.002;
}

float2 GetPointsOfStationaryPhaseFiniteWater(float2 thetaInterval, float fnh, float h, float alpha)
{
    int nRoots = 2;
    if (fnh > 1.0)
    {
        nRoots = 1;
    }

    float tol = 1e-3;
    int N = (thetaInterval.y - thetaInterval.x) / tol;
    float2 thetaStationary = float2(0.0, 0.0);

    float thetaCurrent, dGCurrent, dGPrev = dG(thetaInterval.x, fnh, h, alpha);
    bool flag = false;  // Used when two roots are to be found.

    for (int i = 1; i < N; i++)
    {
        thetaCurrent = thetaInterval.x + i * tol;
        dGCurrent = dG(thetaCurrent, fnh, h, alpha);
        
        if (dGPrev * dGCurrent < 0.0)
        {
            if (nRoots == 1)
            {
                return float2(0.0, thetaCurrent - tol / 2.0);
            }
            else
            {
                if (flag)
                {
                    thetaStationary.y = thetaCurrent - tol / 2.0;
                    return thetaStationary;
                }
                else
                {
                    flag = true;
                    thetaStationary.x = thetaCurrent - tol / 2.0;
                }
            }
        }

        dGPrev = dGCurrent;
    }
    return thetaStationary;
}


int GetIndex(float value, float4 info)
{
    int index = (int) ((value - info.x) / info.z) - 1;

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