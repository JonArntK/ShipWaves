using System;
using System.Collections.Generic;
using Unity.Collections;
using Unity.Mathematics;
using UnityEngine;
using UnityEngine.Rendering;

[RequireComponent(typeof(MeshFilter), typeof(MeshRenderer))]
public class GPUWaterSurface : MonoBehaviour
{
    // Mesh properties.
    public int xSize, zSize, xOrigin, zOrigin;
    public float xStep, zStep;
    public int xQuadCount, zQuadCount, QuadCount, TriangleCount;    // These should not be public, but want them visible in the inspector as of now.

    private GraphicsBuffer _VertexBuffer, _NormalBuffer, _TexcoordBuffer;
    private Material _Material;
    private Mesh _Mesh;

    [SerializeField] ComputeShader WaterSurfaceCS;
    [SerializeField] Shader WaterSurfaceShader;
    [SerializeField] Texture2D WaterSurfaceTexture;

    // Vessel properties, including vessel geometry and vessel path.
    [SerializeField] GameObject[] vesselGOs;
    private Vessel[] vessels;
    private ComputeBuffer vesselCoord, vesselPathCoord, vesselPathTime, vesselPathHeading, vesselPathDepth;
    private float time, vesselPathDeltaTime = 0.01f;

    // Points of stationary phase for use in computation of ship waves in finite water depth.
    [SerializeField] ComputeShader StationaryPointsCS;
    private ComputeBuffer finiteWaterStationaryPoints;

    // Wall properties.
    private Wall walls;
    private ComputeBuffer wallsCB;


    static readonly int
        vesselCoordId = Shader.PropertyToID("_VesselCoord"),
        vesselPathCoordId = Shader.PropertyToID("_VesselPathCoord"),
        vesselPathTimeId = Shader.PropertyToID("_VesselPathTime"),
        vesselPathHeadingId = Shader.PropertyToID("_VesselPathHeading"),
        vesselPathDepthId = Shader.PropertyToID("_VesselPathDepth"),
        finiteWaterStationaryPointsId = Shader.PropertyToID("_FiniteWaterStationaryPoints"),
        testId = Shader.PropertyToID("_Test");

    private void Update()
    {
        // Define mesh properties according to used-specified size and step.
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


        vesselPathCoord.Release();
        vesselPathTime.Release();
        vesselPathHeading.Release();
        vesselPathDepth.Release();
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

        vesselPathCoord.Release();
        vesselPathTime.Release();
        vesselPathHeading.Release();
        vesselPathDepth.Release();
        vesselPathCoord = null;
        vesselPathTime = null;
        vesselPathHeading = null;
        vesselPathDepth = null;

        wallsCB.Release();
        walls = null;

        finiteWaterStationaryPoints.Release();
        finiteWaterStationaryPoints = null;
    }

    private void UpdateVesselPath()
    {
        // Get number of vessels.
        int numVessels = vesselGOs.Length;

        int vesselPathLength = vessels[0].GetVesselPathLength();

        vesselPathCoord = new ComputeBuffer(vesselPathLength * numVessels, 2 * sizeof(float));
        vesselPathTime = new ComputeBuffer(vesselPathLength * numVessels, sizeof(float));
        vesselPathHeading = new ComputeBuffer(vesselPathLength * numVessels, sizeof(float));
        vesselPathDepth = new ComputeBuffer(vesselPathLength * numVessels, sizeof(float));

        // Update and get vessel path.
        time += Time.deltaTime;
        if (time >= vesselPathDeltaTime)
        {
            time -= vesselPathDeltaTime;
        }

        //vessel.UpdateVesselPath(Time.time);
        for (int i = 0; i < numVessels; i++)
        {
            Queue<float2> vesselPathCoordQueue = vessels[i].GetVesselPathCoordQueue();
            Queue<float> vesselPathTimeQueue = vessels[i].GetVesselPathTimeQueue();
            Queue<float> vesselPathHeadingQueue = vessels[i].GetVesselPathHeadingQueue();
            Queue<float> vesselPathDepthQueue = vessels[i].GetVesselPathDepthQueue();

            float2[] vesselPathCoordArray = vesselPathCoordQueue.ToArray();
            float[] vesselPathTimeArray = vesselPathTimeQueue.ToArray();
            float[] vesselPathHeadingArray = vesselPathHeadingQueue.ToArray();
            float[] vesselPathDepthArray = vesselPathDepthQueue.ToArray();

            vesselPathCoord.SetData(vesselPathCoordArray, 0, i * vesselPathLength, vesselPathLength);
            vesselPathTime.SetData(vesselPathTimeArray, 0, i * vesselPathLength, vesselPathLength);
            vesselPathHeading.SetData(vesselPathHeadingArray, 0, i * vesselPathLength, vesselPathLength);
            vesselPathDepth.SetData(vesselPathDepthArray, 0, i * vesselPathLength, vesselPathLength);
        }
        
        WaterSurfaceCS.SetBuffer(0, vesselPathCoordId, vesselPathCoord);  // Assign ComputeBuffer to ComputeShader
        WaterSurfaceCS.SetBuffer(0, vesselPathTimeId, vesselPathTime);  // Assign ComputeBuffer to ComputeShader
        WaterSurfaceCS.SetBuffer(0, vesselPathHeadingId, vesselPathHeading);  // Assign ComputeBuffer to ComputeShader
        WaterSurfaceCS.SetBuffer(0, vesselPathDepthId, vesselPathDepth);  // Assign ComputeBuffer to ComputeShader
        WaterSurfaceCS.SetInt("_VesselPathNumPoints", vesselPathLength);
    }

    private void Start()
    {
        SetVessel();

        walls = new Wall();
        wallsCB = walls.setWallsToCS(WaterSurfaceCS, 0, "_Walls");

        ComputeFiniteWaterStationaryPoints();
    }

    private void SetVessel()
    {
        // Get number of vessels.
        int numVessels = vesselGOs.Length;
        vessels = new Vessel[numVessels];

        // Get length of vessel coordinate array for each vessel, assumed equal for all.
        int vesselCoordLength = vesselGOs[0].GetComponent<Vessel>().GetVesselNx() * vesselGOs[0].GetComponent<Vessel>().GetVesselNy();

        // Initialize computebuffer
        vesselCoord = new ComputeBuffer(vesselCoordLength * numVessels, 3 * sizeof(float));  // will store a vector of float3 -> size = 3 * sizeof(float).    // Useful when debugging


        // Insert info of each vessel into the computebuffer.
        for (int i = 0; i < numVessels; i++)
        {
            vessels[i] = vesselGOs[i].GetComponent<Vessel>();

            float3[] points = vessels[i].GetVesselCoord();

            // Assign data to ComputeBuffer. 'computeBufferStartIndex' is dependent on vessel number, enabling multiple vessels.
            vesselCoord.SetData(points, 0, i * vesselCoordLength, points.Length);    
        }

        WaterSurfaceCS.SetBuffer(0, vesselCoordId, vesselCoord);    // Assign ComputeBuffer to ComputeShader.

        WaterSurfaceCS.SetInt("_NumVessels", numVessels);
        WaterSurfaceCS.SetInts("_VesselNxNy", vessels[0].GetVesselNx(), vessels[0].GetVesselNy());   // Defined as equal for all vessels.
    }

    private void ComputeFiniteWaterStationaryPoints()
    {
        float2 fnhInterval = new float2(0.4f, 1.6f);    // Deep water for Fnh < 0.4. Shallow water for Fnh > 2.0.
        float2 hInterval = new float2(1f, 60f);    // Assuming U_max == 13 m/s ~= 25 knop -> h_max becomes 108 m for Fnh = 0.4.
        float2 alphaInterval = new float2(0, MathF.PI * 0.5f);

        float fnhStep = 0.01f;
        float hStep = 1f;
        float alphaStep = MathF.PI / 180f / 8f;

        int fnhSize = (int)((fnhInterval.y - fnhInterval.x) / fnhStep);
        int hSize = (int)((hInterval.y - hInterval.x) / hStep);
        int alphaSize = (int)((alphaInterval.y - alphaInterval.x) / alphaStep);

        fnhStep = (fnhInterval.y - fnhInterval.x) / fnhSize;
        hStep = (hInterval.y - hInterval.x) / hSize;
        alphaStep = (alphaInterval.y - alphaInterval.x) / alphaSize;

        finiteWaterStationaryPoints = new ComputeBuffer(fnhSize * hSize * alphaSize, 2 * sizeof(float));

        StationaryPointsCS.SetInt("_BufferLength", fnhSize * hSize * alphaSize);
        StationaryPointsCS.SetFloats("_FnhInfo", fnhInterval.x, fnhInterval.y, fnhStep, (float)fnhSize);
        StationaryPointsCS.SetFloats("_HInfo", hInterval.x, hInterval.y, hStep, (float)hSize);
        StationaryPointsCS.SetFloats("_AlphaInfo", alphaInterval.x, alphaInterval.y, alphaStep, (float)alphaSize);
        StationaryPointsCS.SetBuffer(0, finiteWaterStationaryPointsId, finiteWaterStationaryPoints);

        StationaryPointsCS.Dispatch(0, (fnhSize * hSize * alphaSize + 128 - 1) / 128, 1, 1);    // Executes the compute shader.

        WaterSurfaceCS.SetFloats("_FnhInfo", fnhInterval.x, fnhInterval.y, fnhStep, (float)fnhSize);
        WaterSurfaceCS.SetFloats("_HInfo", hInterval.x, hInterval.y, hStep, (float)hSize);
        WaterSurfaceCS.SetFloats("_AlphaInfo", alphaInterval.x, alphaInterval.y, alphaStep, (float)alphaSize);
        WaterSurfaceCS.SetBuffer(0, finiteWaterStationaryPointsId, finiteWaterStationaryPoints);
    }
}
