#include "ComputeElevationLocal.hlsl"

float3 GetCircleGlobal(float XP, float ZP, float U, float t, float tP, float heading)
{
    float dt = t - tP;  // Time difference from when at point P and now.

    float R = 0.25 * U * dt;    // Circle radius.

    float X0 = XP + R * cos(heading); // Center of circle in global coordinate system, x-component.
    float Z0 = ZP + R * sin(heading); // Center of circle in global coordinate system, z-component.

    return float3(X0, Z0, R);
}


float ComputeShipWaveElevationGlobal(float X, float Z, StructuredBuffer<float3> _VesselCoord, int _VesselNx, int _VesselNy, StructuredBuffer <float4>_VesselPath, int _VesselPathNumPoints)
{
    // VesselPath = X, Y, t, heading
    float t = _VesselPath[_VesselPathNumPoints - 1].z;
    
    float X0, Z0, R, U;
    int index = 0;
    bool flag = false;
    for (int i = _VesselPathNumPoints - 2; i >= 0; i--)
    {
        U = sqrt(pow(_VesselPath[i].x - _VesselPath[i + 1].x, 2) + pow(_VesselPath[i].y - _VesselPath[i + 1].y, 2)) / abs(_VesselPath[i].z - _VesselPath[i + 1].z);
        float3 globalCircle = GetCircleGlobal(_VesselPath[i].x, _VesselPath[i].y, U, t, _VesselPath[i].z, _VesselPath[i].w);
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
        float XP = _VesselPath[index].x, ZP = _VesselPath[index].y, tP = _VesselPath[index].z, heading = _VesselPath[index].w;

        float2 rotatedCoord = RotationMatrix(X, Z, -heading + PI, XP, ZP);   // 
        float XRotated = rotatedCoord.x, ZRotated = rotatedCoord.y;

        float x = (t - tP) * U + (XRotated - XP);
        float z = ZRotated - ZP;

        float y = ComputeShipWaveElevationLocal(x, z, _VesselCoord, _VesselNx, _VesselNy, U);

        return y;
    }
    else
    {
        return 0;
    }
    
}