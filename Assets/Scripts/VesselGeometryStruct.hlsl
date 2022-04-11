#ifndef __VESSELGEOMETRYSTRUCT_HLSL__
#define __VESSELGEOMETRYSTRUCT_HLSL__

// Store information regarding the vessel geometries.
struct VesselGeometryStruct
{
    StructuredBuffer<float3> coord;
    int2 vesselNxNy;
};

// Initialize VesselGeometryStruct
VesselGeometryStruct InitializeVesselGeometry(StructuredBuffer<float3> coord, int2 vesselNxNy)
{
    VesselGeometryStruct vgs;
    vgs.coord = coord;
    vgs.vesselNxNy = vesselNxNy;
    
    return vgs;
}

#endif // __VESSELGEOMETRYSTRUCT_HLSL__