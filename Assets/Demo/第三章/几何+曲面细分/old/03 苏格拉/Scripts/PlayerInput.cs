using System;
using UnityEngine;


public class UpdatePlayerInfo : MonoBehaviour
{
    private void Update()
    {
        Shader.SetGlobalVector("_PositionMoving", transform.position);
    }
}