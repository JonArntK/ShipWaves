using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Mathematics;

public class Wall
{
    // Example wall setup
    //private float4[] walls = new float4[4] { new float4(0f, 10f, 500f, 10f),
    //                                         new float4(0f, -10f, 500f, -10f),
    //                                         new float4(0f, 10f, 0f, 40f),
    //                                         new float4(0f, -10f, 0f, -40f), };

    //Used as default when no walls are wanted, as it is currently not possible to have no walls at all.
    private float4[] walls = new float4[1] { new float4(1000f, 1000f, 1001f, 1001f) };


    public float4[] getWalls()
    {
        return walls;
    }

    public ComputeBuffer setWallsToCS(ComputeShader CS, int kernel, string name)
    {
        ComputeBuffer wallsCB = new ComputeBuffer(walls.Length, 4 * sizeof(float));
        wallsCB.SetData(walls);
        CS.SetBuffer(kernel, name, wallsCB);
        CS.SetInt("_NumWalls", walls.Length);

        return wallsCB;
    }
}


