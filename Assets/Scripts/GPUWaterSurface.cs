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

    private GraphicsBuffer _VertexBuffer;
    private GraphicsBuffer _NormalBuffer;
    private GraphicsBuffer _TexcoordBuffer;
    private Material _Material;
    private Mesh _Mesh;

    [SerializeField] ComputeShader WaterSurfaceCS;
    [SerializeField] Shader WaterSurfaceShader;
    [SerializeField] Texture2D WaterSurfaceTexture;

    [SerializeField] GameObject vesselGO;
    private Vessel vessel;
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

    private void SetVessel()
    {
        // Create vessel.
        vessel = vesselGO.GetComponent<Vessel>();
        float3[] points = vessel.GetVesselCoord();

        vesselCoord = new ComputeBuffer(points.Length, 3 * sizeof(float));  // 'points' is a vector of float3 -> size = 3 * sizeof(float).
        vesselCoord.SetData(points);    // Assign data to ComputeBuffer.
        WaterSurfaceCS.SetBuffer(0, vesselCoordId, vesselCoord);    // Assign ComputeBuffer to ComputeShader.
        WaterSurfaceCS.SetInt("_VesselNx", vessel.GetVesselNxNy().x);
        WaterSurfaceCS.SetInt("_VesselNy", vessel.GetVesselNxNy().y);
    }

    private void UpdateVesselPath()
    {
        // Update and get vessel path.
        time += Time.deltaTime;
        if (time >= vesselPathDeltaTime)
        {
            time -= vesselPathDeltaTime;

            
        }
        //vessel.UpdateVesselPath(Time.time);
        Queue<float4> vesselPathQueue = vessel.GetVesselPathQueue();
        float4[] vesselPathArray = vesselPathQueue.ToArray();

        vesselPath = new ComputeBuffer(vesselPathArray.Length, 4 * sizeof(float));  // 'vesselPathArray' is a vector of float4 -> size = 4 * sizeof(float).
        vesselPath.SetData(vesselPathArray);
        WaterSurfaceCS.SetBuffer(0, vesselPathId, vesselPath);  // Assign ComputeBuffer to ComputeShader
        WaterSurfaceCS.SetInt("_VesselPathNumPoints", vesselPathArray.Length);
    }

    private void Start()
    {
        SetVessel();
    }
}
