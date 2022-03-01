#ifndef __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__
#define __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__

#include "ComputeElevationLocalDeepWater.hlsl"
#include "HLSLMath.hlsl"
#include "VesselGeometryStruct.hlsl"

float2 ComplexAmplitudeFunctionFiniteWater(int vesselNum, VesselGeometryStruct vgs, float theta, float U)
{
    return float2(1.0, 1.0);
}

float ComputeShipWaveElevationLocalFiniteWater(float x, float z, int vesselNum, VesselGeometryStruct vgs, float U)
{
    return 1.0;
}

#endif // __COMPUTEELEVATIONLOCALFINITEWATER_HLSL__