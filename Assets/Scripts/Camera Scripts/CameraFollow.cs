using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CameraFollow : MonoBehaviour
{
    [Range(0f, 10f)] public float smoothness;
    public Transform targetObject;

    private Vector3 initialTransformOffset, initialRotationOffset;
    private float radiusOffset;

    void Start()
    {
        // Compute intial transform offset (including radius in xz-plane), rotation offset.
        initialTransformOffset = transform.position - targetObject.position;
        initialRotationOffset = transform.localEulerAngles - targetObject.localEulerAngles;
        radiusOffset = Mathf.Sqrt(initialTransformOffset.x * initialTransformOffset.x + initialTransformOffset.z * initialTransformOffset.z);
    }

    void FixedUpdate()
    {
        RotateCamera();
        MoveCamera();
    }

    private void RotateCamera()
    {
        // Rotate camera with target.
        float cameraRotationY = targetObject.localEulerAngles.y + initialRotationOffset.y;

        // Rotate the cube by converting the angles into a quaternion.
        Quaternion target = Quaternion.Euler(initialRotationOffset.x, cameraRotationY, initialRotationOffset.z);

        // Dampen towards the target rotation.
        transform.rotation = Quaternion.Slerp(transform.rotation, target, Time.deltaTime * smoothness);
    }

    private void MoveCamera()
    {
        // Move camera with target.
        float angle = (targetObject.localEulerAngles.y + initialRotationOffset.y - 90f) / 360f * 2f * Mathf.PI;
        float dx = radiusOffset * -Mathf.Cos(angle);
        float dz = radiusOffset * Mathf.Sin(angle);

        // Compute new position based on updated position and rotation of target.
        Vector3 cameraPosition = targetObject.position + new Vector3(dx, initialTransformOffset.y, dz);

        // Dampen towards the target position.
        transform.position = Vector3.Lerp(transform.position, cameraPosition, smoothness * Time.fixedDeltaTime);
    }
}