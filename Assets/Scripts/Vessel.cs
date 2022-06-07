using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine;
using Unity.Mathematics;

public class Vessel : MonoBehaviour
{
    // Vessel characteristics
    private float L, B, D;
    private float dx, dz;


    public int Nx, Nz;
    public float U = 0, fnh = 0.3f, fn;

    private float3[] vesselCoord;

    // Vessel path
    float4[] vesselPath;
    Queue<float2> vesselPathCoordQueue;
    Queue<float> vesselPathTimeQueue, vesselPathHeadingQueue, vesselPathDepthQueue;
    private int vesselPathLength, vesselPathMaxLength = 1200;

    private void Awake()
    {
        L = 3f;
        B = (0.75f / 8f) * L;
        D = (1f / 16f) * L;

        CreateVesselCoord();

        CreateVesselPath();
    }

    private void Update()
    {
        if (this.transform.position.x >= 39f)
        {
            return;
        }

        // Accelerate when pressing up or down arrow.
        if (Input.GetKey(KeyCode.UpArrow))
            U += 1f * Time.deltaTime;

        if (Input.GetKey(KeyCode.DownArrow))
            U -= 0.4f * Time.deltaTime;
        
        // Move.
        this.transform.Translate(Vector3.forward * Time.deltaTime * U);

        // Rotate when pressing left or right arrow.
        if (Input.GetKey(KeyCode.LeftArrow))
            this.transform.Rotate(Vector3.up, -1);//- Time.deltaTime * U / 25f * 180f / Mathf.PI);

        if (Input.GetKey(KeyCode.RightArrow))
            this.transform.Rotate(Vector3.up, 1);

        UpdateVesselPath();
        fn = U / Mathf.Sqrt(9.81f * L);
    }

    // Vessel geometry.
    public float3[] GetVesselCoord() { return vesselCoord; }
    public int GetVesselNx() { return Nx; }
    public int GetVesselNy() { return Nz; }
    public int GetVesselPathLength() { return vesselPathLength; }

    private void CreateVesselCoord()
    {
        // According to Wigley parabolic hull.

        // Update dx and dz.
        dx = L / (Nx - 1);
        dz = D / (Nz - 1);

        // Preallocate points vector.
        vesselCoord = new float3[Nx * Nz];

        // Create points.
        for (int i = 0; i < Nx; i++)
        {
            for (int j = 0; j < Nz; j++)
            {
                float x = -L / 2f + i * dx;
                float z = j * dz;
                float y = B / 2f * (1 - Mathf.Pow(z / D, 2)) * (1 - Mathf.Pow(x / (0.5f * L), 2));
                vesselCoord[Nz * i + j] = new float3(x, -z, y);   // Note difference between coordinate system in Unity and defintion.
            }
        }
    }


    // Vessel path.
    public float4[] GetVesselPath() { return vesselPath; }
    public Queue<float2> GetVesselPathCoordQueue() { return vesselPathCoordQueue; }
    public Queue<float> GetVesselPathTimeQueue() { return vesselPathTimeQueue; }
    public Queue<float> GetVesselPathHeadingQueue() { return vesselPathHeadingQueue; }
    public Queue<float> GetVesselPathDepthQueue() { return vesselPathDepthQueue; }

    public void CreateVesselPath()
    {
        vesselPathCoordQueue = new Queue<float2>();
        vesselPathTimeQueue = new Queue<float>();
        vesselPathHeadingQueue = new Queue<float>();
        vesselPathDepthQueue = new Queue<float>();
        UpdateVesselPath();
    }
    public void UpdateVesselPath()
    {
        if (this.transform.position.x >= 39f)
        {
            return;
        }

        float angle = transform.rotation.eulerAngles.y - 90f;
        float2 newCoord = new float2(transform.position.x, transform.position.z);
        float newHeading = -angle * 2f * Mathf.PI / 360f;
        float newDepth = MathF.Pow(U / fnh, 2f) / 9.81f;

        vesselPathCoordQueue.Enqueue(newCoord);
        vesselPathTimeQueue.Enqueue(Time.time);
        vesselPathHeadingQueue.Enqueue(newHeading);
        vesselPathDepthQueue.Enqueue(newDepth);

        if (vesselPathTimeQueue.Count >= vesselPathMaxLength)
        {
            vesselPathCoordQueue.Dequeue();
            vesselPathTimeQueue.Dequeue();
            vesselPathHeadingQueue.Dequeue();
            vesselPathDepthQueue.Dequeue();
        }

        vesselPathLength = vesselPathTimeQueue.Count;
    }
}
