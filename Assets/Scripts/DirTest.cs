using System;
using AmplifyShaderEditor;
using UnityEngine;

public class DirTest: MonoBehaviour
{
    private Vector3 forward;
    private Vector3 startPos;
    private Vector3 endPos;
    private float distance;
    
    private void Init()
    {
        
    }

    public void SetDrawLine(Vector3 _startPos,Vector3 _endPos)
    {
        this.startPos = _startPos;
        this.endPos = _endPos;
        
    }

    public void SetDrawRay(Vector3 _forward,float _distance)
    {
        this.forward = _forward;
         this.distance = _distance;
    }

    private void OnDrawGizmos()
    {
        //Gizmos.DrawRay();
        //Gizmos.DrawMesh();
        Gizmos.DrawLine(startPos,endPos);

        float size = 0.1f;
        Gizmos.color = Color.blue;
        Gizmos.DrawCube(new Vector3(-2.5f,4.5f,-4),
            new Vector3(size,size,size));
        Gizmos.DrawLine(startPos,new Vector3(-2.5f,4.5f,-4));
        Vector3 dir = Vector3.Normalize(new Vector3(-2.5f, 4.5f, -4) - startPos);
        
        //绘制射线
        Vector3 light_x = Vector3.Normalize(endPos - startPos);
        Vector3 light_z = Vector3.Normalize(Vector3.Cross(light_x, dir));
        Vector3 light_y = Vector3.Normalize(Vector3.Cross(light_z, light_x));
        Gizmos.color = Color.red;
        Gizmos.DrawRay(startPos,light_z*2);
        Gizmos.color = Color.red;
        Gizmos.DrawRay(startPos,light_y*2);

        Matrix4x4 matrix = new Matrix4x4();
        matrix.SetRow(0, light_x);
        matrix.SetRow(1, light_y);
        matrix.SetRow(2, light_z);
        matrix.SetRow(3, Vector4.zero);
        Vector3 newDir = matrix.MultiplyVector(dir);
        newDir.y *= -1;
        
        Matrix4x4 matrix2 = new Matrix4x4();
        matrix.SetColumn(0, light_x);
        matrix.SetColumn(1, light_y);
        matrix.SetColumn(2, light_z);
        matrix.SetColumn(3, Vector4.zero);
        Vector3 newDir2 = matrix.MultiplyVector(newDir).normalized;
        Gizmos.color = Color.blue;
        Gizmos.DrawRay(startPos,newDir2*2);


        float dot1 = Vector3.Dot(dir, light_x);
        float dot2 = Vector3.Dot(newDir2, light_x);

    }
}