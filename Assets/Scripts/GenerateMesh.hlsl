#ifndef __GENERATEMESH_HLSL__
#define __GENERATEMESH_HLSL__

#include "HLSLMath.hlsl"

// Custom Store2 function -> enabling storage of float2.
void Store2(RWByteAddressBuffer buffer, int index, float2 v)
{
    uint2 data = asuint(v); // Convert to uint2 from float. 
    buffer.Store2((index * 3) << 2, data); // Insert two positions left of index * 3.
}
 
// Custom Store3 function -> enabling storage of float3.
void Store3(RWByteAddressBuffer buffer, int index, float3 v)
{
    uint3 data = asuint(v); // Convert to uint3 from float. 
    buffer.Store3((index * 3) << 2, data); // Insert two positions left of index * 3.
}


// Define a Vertex struct.
struct Vertex
{
    float3 position;
    float2 texcoord;
};

// Generate vertex for grid of quads, from 1D array index (branchless version).
Vertex GenerateQuad(uint id, int _XQuadCount, float _XStep, float _ZStep, int _XOrigin, int _ZOrigin)
{
    float instance = floor(float(id + 0.00001) / 6.0); // Index of current quad.
    float3 center = float3(floor(Mod(instance, _XQuadCount)), 0.0, floor(instance / _XQuadCount)); // Center of current quad.

    Vertex vertex;
    float u = Mod(float(id), 2.0); // Local x-position of quad.
    float v = sign(Mod(126.0, Mod(float(id), 6.0) + 6.0)); // Local z-position of quad.
    float3 localPos = float3(u, 0, v);

    vertex.position = (localPos + center) * float3(_XStep, 1, _ZStep) + float3(_XOrigin, 0, _ZOrigin); // Assigning position to vertex.
    vertex.texcoord = float2(u, v);
    return vertex;
}

// Store triangular element in buffers.
void StoreTriangle(uint idx1, uint idx2, uint idx3, Vertex v1, Vertex v2, Vertex v3, 
    RWByteAddressBuffer _VertexBuffer, RWByteAddressBuffer _NormalBuffer, RWByteAddressBuffer _TexcoordBuffer)
{
    // Triangle vertices (v1, v2, v3) should be given in a counter clock-wise direction to 
    // ensure consistent computation of normal vectors.

    float3 p1 = v1.position;
    float3 p2 = v2.position;
    float3 p3 = v3.position;

    float2 uv1 = v1.texcoord;
    float2 uv2 = v2.texcoord;
    float2 uv3 = v3.texcoord;

    // Compute normal vector.
    float3 normal = -normalize(cross(p2 - p1, p3 - p2));

    // Store vertex position.
    Store3(_VertexBuffer, idx1, p1);
    Store3(_VertexBuffer, idx2, p2);
    Store3(_VertexBuffer, idx3, p3);

    // Store vertex texture coordinate.
    Store2(_TexcoordBuffer, idx1, uv1);
    Store2(_TexcoordBuffer, idx2, uv2);
    Store2(_TexcoordBuffer, idx3, uv3);

    // Store vertex normal vector.
    Store3(_NormalBuffer, idx1, normal);
    Store3(_NormalBuffer, idx2, normal);
    Store3(_NormalBuffer, idx3, normal);
}

#endif // __GENERATEMESH_HLSL__