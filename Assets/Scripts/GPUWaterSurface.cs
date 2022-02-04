using System;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class GPUWaterSurface : MonoBehaviour
{
    public int xSize, zSize, xOrigin, zOrigin;
    public float xStep, zStep;
    public int xQuadCount, zQuadCount, QuadCount, TriangleCount;    // These should not be public, but want them visible in the inspector as of now.

    private GraphicsBuffer _VertexBuffer, _NormalBuffer, _TexcoordBuffer;
    private Material _Material;
    private Mesh _Mesh;

    [SerializeField] ComputeShader WaterSurfaceCS;
    [SerializeField] Shader WaterSurfaceShader;
    [SerializeField] Texture2D WaterSurfaceTexture;

    [SerializeField] GameObject[] vesselGOs;
    private Vessel[] vessels;
    private ComputeBuffer vesselCoord, vesselPath;
    private float time, vesselPathDeltaTime = 0.01f;


    static readonly int
        vesselCoordId = Shader.PropertyToID("_VesselCoord"),
        vesselPathId = Shader.PropertyToID("_VesselPath");

    private void Update()
    {
        xQuadCount = Mathf.RoundToInt((float)xSize / xStep);        // Number of quads in x-direction.
        zQuadCount = Mathf.RoundToInt((float)zSize / zStep);        // Number of quads in z-direction.
        xStep = (float)xSize / (float)xQuadCount;   // Updated xStep to ensure xSize is as defined.
        zStep = (float)zSize / (float)zQuadCount;   // Updated zStep to ensure zSize is as defined.

        QuadCount = xQuadCount * zQuadCount;    // Total number of quads needed (which are to be splitted into triangles).
        TriangleCount = QuadCount * 2;          // Total number of triangles needed (== number of quads * 2).

        if (_Mesh && _Mesh.vertexCount != TriangleCount * 3)    // If the mesh size have been changed while in play-mode.
        {
            Release();
        }

        if (_Mesh == null)  // If the mesh does not exist.
        {
            _Mesh = new Mesh();             // Create new mesh.
            _Mesh.name = "Water Surface";   // Name the mesh.

            _Mesh.vertexBufferTarget |= GraphicsBuffer.Target.Raw;  // x |= y is equivalent to x = x | y, where '|' is the logical OR operator
            VertexAttributeDescriptor[] attributes = new[]          // Specifying mesh attribute layout. (Not quite sure about the stream choices, what it is and how it matters).
            {
                new VertexAttributeDescriptor(VertexAttribute.Position, stream:0),
                new VertexAttributeDescriptor(VertexAttribute.Normal, stream:1),
                new VertexAttributeDescriptor(VertexAttribute.TexCoord0, stream:2)
            };
            _Mesh.SetVertexBufferParams(TriangleCount * 3, attributes);         // Setting parameters for the VertexBuffer according to attributes above. Is of length TriangleCount * 3 cause each triangle has three points.
            _Mesh.SetIndexBufferParams(TriangleCount * 3, IndexFormat.UInt32);  // Setting parameters for the IndexBuffer. Is of length TriangleCount * 3 cause each triangle has three points.
            NativeArray<int> indexBuffer = new NativeArray<int>(TriangleCount * 3, Allocator.Temp);     // Temporary allocating an array for storage of indices.
            for (int i = 0; i < TriangleCount * 3; ++i) indexBuffer[i] = i;                             // Filling the previously allocated indexBuffer as [1,2,3,...,TriangleCount*3].
            _Mesh.SetIndexBufferData(indexBuffer, 0, 0, indexBuffer.Length, MeshUpdateFlags.DontRecalculateBounds | MeshUpdateFlags.DontValidateIndices);   // Setting indexBuffer.
            indexBuffer.Dispose();  // No longer need the indexBuffer.

            SubMeshDescriptor submesh = new SubMeshDescriptor(0, TriangleCount * 3, MeshTopology.Triangles);    // Creating a submesh.
            submesh.bounds = new Bounds(Vector3.zero, new Vector3(2000, 2, 2000));  // Defining bounds of submesh. Half the size is used in each direction from the center.
            _Mesh.SetSubMesh(0, submesh);       // Setting submesh to mesh.
            _Mesh.bounds = submesh.bounds;      // Setting bounds of submesh.
            GetComponent<MeshFilter>().sharedMesh = _Mesh;
            _Material = new Material(WaterSurfaceShader);       // Creating new material.
            _Material.mainTexture = WaterSurfaceTexture;        // Setting material texture.
            GetComponent<MeshRenderer>().sharedMaterial = _Material;    // Setting material of MeshRenderer.
        }

        _VertexBuffer ??= _Mesh.GetVertexBuffer(0);     // If _VertexBuffer != null, then _VertexBuffer = _Mesh.GetVertexBuffer(0) (0 indicates vertices, see Descriptor above).
        _NormalBuffer ??= _Mesh.GetVertexBuffer(1);     // If _NormalBuffer != null, then _NormalBuffer = _Mesh.GetVertexBuffer(1) (1 indicates normals, see Descriptor above).
        _TexcoordBuffer ??= _Mesh.GetVertexBuffer(2);   // If _TexcoordBuffer != null, then _TexcoordBuffer = _Mesh.GetVertexBuffer(2) (2 indicates texture coordinates, see Descriptor above).

        WaterSurfaceCS.SetInt("_QuadCount", QuadCount);     // Set QuadCount in compute shader.
        WaterSurfaceCS.SetInt("_XQuadCount", xQuadCount);   // Set xQuadCount in compute shader.
        WaterSurfaceCS.SetInt("_ZQuadCount", zQuadCount);   // Set zQuadCount in compute shader.
        WaterSurfaceCS.SetInt("_XOrigin", xOrigin);         // Set xOrigin in compute shader.
        WaterSurfaceCS.SetInt("_ZOrigin", zOrigin);         // Set zOrigin in compute shader.
        WaterSurfaceCS.SetFloat("_XStep", xStep);           // Set xStep in compute shader.
        WaterSurfaceCS.SetFloat("_ZStep", zStep);           // Set zStep in compute shader.
        WaterSurfaceCS.SetBuffer(0, "_VertexBuffer", _VertexBuffer);        // Set VertexBuffer in compute shader.
        WaterSurfaceCS.SetBuffer(0, "_TexcoordBuffer", _TexcoordBuffer);    // Set TexcoordBuffer in compute shader.
        WaterSurfaceCS.SetBuffer(0, "_NormalBuffer", _NormalBuffer);        // Set NormalBuffer in compute shader.
        WaterSurfaceCS.SetFloat("_Time", Time.time);        // Set time in compute shader (used for animation).

        UpdateVesselPath();

        WaterSurfaceCS.Dispatch(0, (QuadCount + 64 - 1) / 64, 1, 1);    // Executes the compute shader.

        vesselPath.Release();
    }

    private void Release()
    {
        Destroy(_Material);
        Destroy(_Mesh);
        _Mesh = null;
        _Material = null;

        _VertexBuffer?.Dispose();
        _VertexBuffer = null;
        _TexcoordBuffer?.Dispose();
        _TexcoordBuffer = null;
        _NormalBuffer?.Dispose();
        _NormalBuffer = null;
    }

    private void OnDestroy()
    {
        Release();

        vesselCoord.Release();
        vesselCoord = null;

        vesselPath.Release();
        vesselPath = null;
    }

    private void UpdateVesselPath()
    {
        // Get number of vessels.
        int numVessels = vesselGOs.Length;

        int vesselPathLength = vessels[0].GetVesselPathLength();

        vesselPath = new ComputeBuffer(vesselPathLength * numVessels, 4 * sizeof(float));  // 'vesselPathArray' is a vector of float4 -> size = 4 * sizeof(float).

        // Update and get vessel path.
        time += Time.deltaTime;
        if (time >= vesselPathDeltaTime)
        {
            time -= vesselPathDeltaTime;
        }

        //vessel.UpdateVesselPath(Time.time);
        for (int i = 0; i < numVessels; i++)
        {
            Queue<float4> vesselPathQueue = vessels[i].GetVesselPathQueue();
            float4[] vesselPathArray = vesselPathQueue.ToArray();
            vesselPath.SetData(vesselPathArray, 0, i * vesselPathLength, vesselPathLength);
        }
        
        WaterSurfaceCS.SetBuffer(0, vesselPathId, vesselPath);  // Assign ComputeBuffer to ComputeShader
        WaterSurfaceCS.SetInt("_VesselPathNumPoints", vesselPathLength);
    }

    private void Start()
    {
        SetVessel();
    }

    private void SetVessel()
    {
        // Get number of vessels.
        int numVessels = vesselGOs.Length;
        vessels = new Vessel[numVessels];

        // Get length of vessel coordinate array for each vessel, assumed equal for all.
        int vesselCoordLength = vesselGOs[0].GetComponent<Vessel>().GetVesselNx() * vesselGOs[0].GetComponent<Vessel>().GetVesselNy();

        // Initialize computebuffer
        vesselCoord = new ComputeBuffer(vesselCoordLength * numVessels, 3 * sizeof(float));  // will store a vector of float3 -> size = 3 * sizeof(float).


        // Insert info of each vessel into the computebuffer.
        for (int i = 0; i < numVessels; i++)
        {
            vessels[i] = vesselGOs[i].GetComponent<Vessel>();

            float3[] points = vessels[i].GetVesselCoord();

            // Assign data to ComputeBuffer. 'computeBufferStartIndex' is dependent on vessel number, enabling mulitple vessels.
            vesselCoord.SetData(points, 0, i * vesselCoordLength, points.Length);    
        }

        WaterSurfaceCS.SetBuffer(0, vesselCoordId, vesselCoord);    // Assign ComputeBuffer to ComputeShader.

        WaterSurfaceCS.SetInt("_NumVessels", numVessels);
        WaterSurfaceCS.SetInt("_VesselNx", vessels[0].GetVesselNx());   // Defined as equal for all vessels.
        WaterSurfaceCS.SetInt("_VesselNy", vessels[0].GetVesselNy());   // Defined as equal for all vessels.
    }
}
