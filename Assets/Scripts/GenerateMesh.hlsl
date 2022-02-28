#ifndef __GENERATEMESH_HLSL__
#define __GENERATEMESH_HLSL__

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

#endif // __GENERATEMESH_HLSL__