#ifndef __COMPUTEELEVATIONGLOBAL_HLSL__
#define __COMPUTEELEVATIONGLOBAL_HLSL__

#include "ComputeElevationLocal.hlsl"

float3 GetCircleGlobal(float XP, float ZP, float U, float t, float tP, float heading)
{
    float dt = t - tP;  // Time difference from when at point P and now.

    float R = 0.25 * U * dt;    // Circle radius.

    float X0 = XP + R * cos(heading); // Center of circle in global coordinate system, x-component.
    float Z0 = ZP + R * sin(heading); // Center of circle in global coordinate system, z-component.

    return float3(X0, Z0, R);
}


float ComputeShipWaveElevationGlobal(float X, float Z, int vesselNum, StructuredBuffer<float3> _VesselCoord, int2 _VesselNxNy, StructuredBuffer <float4>_VesselPath, int _VesselPathNumPoints)
{
    int vesselPathIndexStart = vesselNum * _VesselPathNumPoints;

    // VesselPath = X, Y, t, heading
    float t = _VesselPath[vesselPathIndexStart + _VesselPathNumPoints - 1].z;
    
    float X0, Z0, R, U;
    int index = 0;
    bool flag = false;
    for (int i = _VesselPathNumPoints - 2; i >= 0; i--)
    {
        U = sqrt(pow(_VesselPath[vesselPathIndexStart + i].x - _VesselPath[vesselPathIndexStart + i + 1].x, 2) 
            + pow(_VesselPath[vesselPathIndexStart + i].y - _VesselPath[vesselPathIndexStart + i + 1].y, 2)) / 
            abs(_VesselPath[vesselPathIndexStart + i].z - _VesselPath[vesselPathIndexStart + i + 1].z);

        float3 globalCircle = GetCircleGlobal(_VesselPath[vesselPathIndexStart + i].x, _VesselPath[vesselPathIndexStart + i].y, U, t, _VesselPath[vesselPathIndexStart + i].z, _VesselPath[vesselPathIndexStart + i].w);
        X0 = globalCircle.x, Z0 = globalCircle.y, R = globalCircle.z;
        if (IsPointInCircle(X, Z, X0, Z0, R))
        {
            index = i;
            flag = true;
            break;
        }
    }

    if (flag)
    {
        // Find point P
        float XP = _VesselPath[vesselPathIndexStart + index].x, ZP = _VesselPath[vesselPathIndexStart + index].y, tP = _VesselPath[vesselPathIndexStart + index].z, heading = _VesselPath[vesselPathIndexStart + index].w;

        float2 rotatedCoord = RotationMatrix(X, Z, -heading + PI, XP, ZP);   // 
        float XRotated = rotatedCoord.x, ZRotated = rotatedCoord.y;

        float x = (t - tP) * U + (XRotated - XP);
        float z = ZRotated - ZP;

        float y = ComputeShipWaveElevationLocal(x, z, vesselNum, _VesselCoord, _VesselNxNy[0], _VesselNxNy[1], U);

        return y;
    }
    else
    {
        return 0;
    }
    
}

#endif // __COMPUTEELEVATIONGLOBAL_HLSL__