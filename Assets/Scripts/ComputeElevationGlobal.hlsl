#ifndef __COMPUTEELEVATIONGLOBAL_HLSL__
#define __COMPUTEELEVATIONGLOBAL_HLSL__

#include "ComputeElevationGlobalDeepWaterFunctions.hlsl"
#include "ComputeElevationGlobalFiniteWaterFunctions.hlsl"
#include "ComputeElevationLocalDeepWater.hlsl"
#include "ComputeElevationLocalFiniteWater.hlsl"
#include "VesselGeometryStruct.hlsl"
#include "VesselPathStruct.hlsl"
#include "WallReflectionFunctions.hlsl"


float GetVelocity(VesselPathStruct vps, int index)
{
    // U = dS / dt, i.e., distance divided by time.
    float U = sqrt(pow(vps.coord[index].x - vps.coord[index + 1].x, 2) + pow(vps.coord[index].y - vps.coord[index + 1].y, 2))
        / abs(vps.time[index] - vps.time[index + 1]);
    return U;
}

float2 GlobalToLocalCoord(float2 XZ, float t, VesselPathStruct vps, int index, float U)
{
    // Find point P.
    float XP = vps.coord[index].x, ZP = vps.coord[index].y, tP = vps.time[index], heading = vps.heading[index];

    // Transform point P from the global coordinate system to the local.
    float2 rotatedCoord = RotationMatrix(XZ.x, XZ.y, -heading + PI, XP, ZP); // 
    float XRotated = rotatedCoord.x, ZRotated = rotatedCoord.y;

    float x = (t - tP) * U + (XRotated - XP);
    float z = ZRotated - ZP;
    
    // Return the local coordinate equivalent of (X, Z).
    return float2(x, z);
}

bool IsPointValid(float X, float Z, float U, float t, float fnh, VesselPathStruct vps, float index, 
    bool isWallReflection, StructuredBuffer<float4> walls, int currentWall, int numWalls)
{
    // A regular point is valid if it is:
        // - within the region of disturbance, which is dependent on water depth.
        // - is not obstructed by any wall wrt. to the source point.
    // A wall reflection point is valid if it is:
        // - within the region of disturbance, which is dependent on water depth.
        // - special consideration for obstructions by walls.
    
    if (!IsFiniteWater(fnh) && 
        IsPointInRegionDeepWater(X, Z, vps.coord[index].x, vps.coord[index].y, U, t, vps.time[index], vps.heading[index]) &&
        !IsPointObstructedByWall(float2(X, Z), float2(vps.coord[index].x, vps.coord[index].y), walls, currentWall, numWalls, isWallReflection))
    {
        return true;
    }
    else if (IsFiniteWater(fnh) && 
        IsPointInRegionFiniteWater(X, Z, vps.coord[index].x, vps.coord[index].y, U, t, vps.time[index], vps.heading[index], fnh) &&
        !IsPointObstructedByWall(float2(X, Z), float2(vps.coord[index].x, vps.coord[index].y), walls, currentWall, numWalls, isWallReflection))
    {
        return true;
    }
    
    return false;
}


float ComputeShipWaveElevationGlobal(float2 XZ, int vesselNum, VesselGeometryStruct vgs, VesselPathStruct vps, 
    bool isWallReflection, StructuredBuffer<float4> walls, int currentWall, int numWalls)
{
    // Define number of points in the vessel path.
    int vesselPathNumPoints = vps.numPoints;
    
    // Define starting index for current vessel: vesselNum.
    int vesselPathIndexStart = vesselNum * vesselPathNumPoints;

    // Initialize values.
    float X0, Z0, R, U, fnh;
    int index = 0;      // Used to store the index of the correct path point when found.
    bool computeElevationFlag = false;

    // Get vesselPathTime from the struct.
    float t = vps.time[vesselPathIndexStart + vesselPathNumPoints - 1];

    // Loop over all points in the vessel path, starting with the point closest to the vessel (placed at the back of the array).
    for (int i = vesselPathNumPoints - 2; i >= 0; i--)
    {
        int refIndex = vesselPathIndexStart + i;

        // Compute velocity based on the current and previous path locations and the time difference between them.
        U = GetVelocity(vps, refIndex);

        // Compute the depth Froude number for the current vessel path point (is dependent on U and h).
        fnh = Fnh(U, vps.depth[refIndex]);

        // Check if point is valid, i.e., if it is inside the region on disturbance and not obstructed by any walls w.r.t. the source point. 
        if (IsPointValid(XZ.x, XZ.y, U, t, fnh, vps, refIndex, isWallReflection, walls, currentWall, numWalls))
        {
            if (!isWallReflection || 
                (isWallReflection && isWallReflectionValid(XZ, vps.coord[refIndex].xy, walls[currentWall])))
            {
                index = i;
                computeElevationFlag = true;
                break;
            }
        }
    }

    // Initalize elevation 'y' as 0;
    float y = 0;
    
    if (computeElevationFlag)   // If a point is found, meaning that the elevation should be computed.
    {
        // Get local coordinate equivalent to (X, Z).
        float2 xz = GlobalToLocalCoord(XZ, t, vps, vesselPathIndexStart + index, U);
        
        // Compute the elevation using the local coordinate system.
        if (IsFiniteWater(fnh))
        {
            float depth = vps.depth[vesselPathIndexStart + index];
            y = ComputeShipWaveElevationLocalFiniteWater(xz.x, xz.y, vesselNum, vgs, U, depth, vps);
        }
        else
        {
            y = ComputeShipWaveElevationLocalDeepWater(xz.x, xz.y, vesselNum, vgs, U);
        }
    }

    return y;
}

#endif // __COMPUTEELEVATIONGLOBAL_HLSL__