using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraFollow : MonoBehaviour
{
    public float smoothness;
    public Transform targetObject;

    private Vector3 initialTransformOffset;
    private float initialRotationYOffset, radiusOffset;

    private Vector3 cameraPosition;
    private float cameraRotationY;

    void Start()
    {
        initialTransformOffset = transform.position - targetObject.position;
        initialRotationYOffset = transform.localEulerAngles.y - targetObject.localEulerAngles.y;
        radiusOffset = Mathf.Sqrt(initialTransformOffset.x * initialTransformOffset.x + initialTransformOffset.z * initialTransformOffset.z);
    }

    void FixedUpdate()
    {
        // Move camera with target.
        //cameraPosition = targetObject.position + initialTransformOffset;
        float dx = radiusOffset * Mathf.Cos(targetObject.localEulerAngles.y - initialRotationYOffset);
        float dz = radiusOffset * Mathf.Sin(targetObject.localEulerAngles.y - initialRotationYOffset);
        Debug.Log(dx + ":" + dz + "InitialRotationYOffset = " + initialRotationYOffset);
        cameraPosition = targetObject.position + new Vector3(dx, initialTransformOffset.y, dz);
        //transform.position = Vector3.Lerp(transform.position, cameraPosition, smoothness * Time.fixedDeltaTime);


        // Rotate camera with target.
        cameraRotationY = targetObject.localEulerAngles.y + initialRotationYOffset;

        // Rotate the cube by converting the angles into a quaternion.
        Quaternion target = Quaternion.Euler(0, cameraRotationY, 0);

        // Dampen towards the target rotation
        //transform.rotation = Quaternion.Slerp(transform.rotation, target, Time.deltaTime * smoothness);

        transform.RotateAround(targetObject.position, Vector3.up, 10 * Time.deltaTime);
    }
}