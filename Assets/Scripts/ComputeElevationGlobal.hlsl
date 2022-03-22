#ifndef __COMPUTEELEVATIONGLOBAL_HLSL__
#define __COMPUTEELEVATIONGLOBAL_HLSL__

#include "ComputeElevationGlobalDeepWaterFunctions.hlsl"
#include "ComputeElevationGlobalFiniteWaterFunctions.hlsl"
#include "ComputeElevationLocalDeepWater.hlsl"
#include "ComputeElevationLocalFiniteWater.hlsl"
#include "VesselGeometryStruct.hlsl"
#include "VesselPathStruct.hlsl"

float ComputeShipWaveElevationGlobal(float X, float Z, int vesselNum, VesselGeometryStruct vgs, VesselPathStruct vps)
{
    // Define number of points in the vessel path.
    int vesselPathNumPoints = vps.numPoints;
    // Define starting index for current vessel: vesselNum.
    int vesselPathIndexStart = vesselNum * vesselPathNumPoints;

    // Initialize values.
    float X0, Z0, R, U, fnh;
    int index = 0;      // Used to store the index of the correct path point when found.
    bool flag = false;

    // Get vesselPathTime from the struct.
    float t = vps.time[vesselPathIndexStart + vesselPathNumPoints - 1];
    

    // Loop over all points in the vessel path, starting with the point closest to the vessel (placed at the back of the array).
    for (int i = vesselPathNumPoints - 2; i >= 0; i--)
    {
        int refIndex = vesselPathIndexStart + i;

        // Compute velocity based on the current and previous path locations and the time difference between them.
        U = sqrt(pow(vps.coord[refIndex].x - vps.coord[refIndex + 1].x, 2)
            + pow(vps.coord[refIndex].y - vps.coord[refIndex].y, 2)) /
            abs(vps.time[refIndex] - vps.time[refIndex + 1]);

        fnh = Fnh(U, vps.depth[refIndex]);

        // Check if point is inside the region of disturbance. The region is dependent on the water depth, hence separate functions for deep and finite water depths.
        if ((!IsFiniteWater(fnh) && IsPointInRegionDeepWater(X, Z, vps.coord[refIndex].x, vps.coord[refIndex].y, U, t, vps.time[refIndex], vps.heading[refIndex])) ||
            (IsFiniteWater(fnh) && IsPointInRegionFiniteWater(X, Z, vps.coord[refIndex].x, vps.coord[refIndex].y, U, t, vps.time[refIndex], vps.heading[refIndex], fnh)))
        {
            index = i;
            flag = true;
            break;
        }
    }

    if (flag)
    {
        // Find point P
        float XP = vps.coord[vesselPathIndexStart + index].x, ZP = vps.coord[vesselPathIndexStart + index].y, tP = vps.time[vesselPathIndexStart + index], heading = vps.heading[vesselPathIndexStart + index], depth = vps.depth[vesselPathIndexStart + index];

        float2 rotatedCoord = RotationMatrix(X, Z, -heading + PI, XP, ZP);   // 
        float XRotated = rotatedCoord.x, ZRotated = rotatedCoord.y;

        float x = (t - tP) * U + (XRotated - XP);
        float z = ZRotated - ZP;

        float y;
        if (IsFiniteWater(fnh))
        {
            y = ComputeShipWaveElevationLocalFiniteWater(x, z, vesselNum, vgs, U, depth, vps);
        }
        else
        {
            y = ComputeShipWaveElevationLocalDeepWater(x, z, vesselNum, vgs, U);
        }
        
        return y;
    }
    else
    {
        return 0;
    }
    
}

#endif // __COMPUTEELEVATIONGLOBAL_HLSL__