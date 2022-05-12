using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Mathematics;

public class Wall
{

    //private float4[] walls = new float4[2] { new float4(0f, 3f, 50f, 3f),
    //                                         new float4(0f, -3f, 50f, -3f) };
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


