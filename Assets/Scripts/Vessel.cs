using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine;
using Unity.Mathematics;

public class Vessel : MonoBehaviour
{
    // Vessel characteristics
    private float L, B, D;
    private int Nx, Nz;

    public float dx, dz, U;

    private float3[] vesselCoord;

    // Vessel path
    float4[] vesselPath;
    Queue<float4> vesselPathQueue;

    private void Awake()
    {
        L = 8f;
        B = (0.75f / 8f) * L;
        D = (1f / 16f) * L;
        dx = 2f;
        dz = 0.5f;

        CreateVesselCoord();

        CreateVesselPath();
    }

    private void Update()
    {
        if (Input.GetKey(KeyCode.UpArrow))
        {
            this.transform.Translate(Vector3.forward * Time.deltaTime * Mathf.Sqrt(9.81f));
        }

        if (Input.GetKey(KeyCode.DownArrow))
        {
            this.transform.Translate(Vector3.back * Time.deltaTime * Mathf.Sqrt(9.81f));
        }

        if (Input.GetKey(KeyCode.LeftArrow))
        {
            this.transform.Rotate(Vector3.up, -1);
        }

        if (Input.GetKey(KeyCode.RightArrow))
        {
            this.transform.Rotate(Vector3.up, 1);
        }

        UpdateVesselPath();
    }

    // Vessel geometry.
    public float3[] GetVesselCoord() { return vesselCoord; }
    public int2 GetVesselNxNy() { return new int2(Nx, Nz); }

    private void CreateVesselCoord()
    {
        // According to Wigley parabolic hull.

        // Number of points in x- and z-direction.
        Nx = Mathf.FloorToInt(L / dx) + 1;
        Nz = Mathf.FloorToInt(D / dz) + 1;

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
                float z = -j * dz;
                float y = B / 2f * (1 - Mathf.Pow(z / D, 2)) * (1 - Mathf.Pow(x / (0.5f * L), 2));
                vesselCoord[Nz * i + j] = new float3(x, z, y);   // Note difference between coordinate system in Unity and defintion. CHANGE THIS LATER!
            }
        }
    }


    // Vessel path.
    public float4[] GetVesselPath() { return vesselPath; }
    public Queue<float4> GetVesselPathQueue() { return vesselPathQueue; }

    private float VesselPathFunction(float x)
    {
        return x / (Mathf.Sin(x / 40f) - 2);
    }
    public void UpdateVesselPath2()
    {
        float U = Mathf.Sqrt(9.81f);
        float dt = 1f;
        float S = 100f;
        float x0 = 0f;
        float y0 = 0f;

        float dS = U * dt;
        int nPoints = Mathf.FloorToInt(S / dS);

        vesselPath = new float4[nPoints];


        float heading, x, y, tP;
        for (int i = 0; i < nPoints; i++)
        {
            x = x0 + dS * i;
            y = y0 + VesselPathFunction(x);

            if (i == 0)
            {
                heading = Mathf.Atan2(y, x);
                tP = 0.0f; 
            }
            else
            {
                heading = Mathf.Atan2(y - vesselPath[i - 1].y, x - vesselPath[i - 1].x);

                tP = vesselPath[i - 1].z - Mathf.Sqrt(Mathf.Pow(vesselPath[i - 1].x - x, 2) + Mathf.Pow(vesselPath[i - 1].y - y, 2)) / U;
            }

            vesselPath[i] = new float4(x, y, tP, heading + Mathf.PI);
        }
        for (int i = 0; i < nPoints; i++)
        {
            vesselPath[i].z += Mathf.Abs(vesselPath[nPoints - 1].z);
        }

        System.Array.Reverse(vesselPath);
    }
    public void CreateVesselPath()
    {
        vesselPathQueue = new Queue<float4>();
        UpdateVesselPath();
    }
    public void UpdateVesselPath()
    {
        float U = Mathf.Sqrt(9.81f);
        //float4 newPoint = new float4(-70 + Time.time * U, 0f, Time.time, 0f);
        float angle = transform.rotation.eulerAngles.y;// * 2f * Mathf.PI / 360f + Mathf.PI / 2f;
        float4 newPoint = new float4(transform.position.x, transform.position.z, Time.time, (-angle + 90f) * 2f * Mathf.PI / 360f);
        vesselPathQueue.Enqueue(newPoint);

        if (vesselPathQueue.Count >= 1200)
        {
            vesselPathQueue.Dequeue();
        }
    }
}