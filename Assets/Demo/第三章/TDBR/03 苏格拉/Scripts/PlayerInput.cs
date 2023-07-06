using System;
using UnityEngine;

public class PlayerInput : MonoBehaviour
{
    private void Update()
    {
        Shader.SetGlobalVector("_PositionMoving", transform.position);
    }
}