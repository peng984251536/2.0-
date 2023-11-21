using UnityEngine;

#if UNITY_EDITOR

[ExecuteAlways]
public class NormalDisplay : MonoBehaviour
{
    public bool showNormals = false;
    public bool showTangents = false;

    public float dirLength = 0.5f;
    public Mesh mesh;

    private void OnDrawGizmos()
    {
        //获取Mesh
        if (this.mesh == null)
        {
            if (GetComponent<SkinnedMeshRenderer>())
            {
                this.mesh = GetComponent<SkinnedMeshRenderer>().sharedMesh;
            }

            if (GetComponent<MeshFilter>())
            {
                this.mesh = GetComponent<MeshFilter>().sharedMesh;
            }
        }

        if (mesh == null)
            return;
        //Debug.Log(this.mesh.name);

        if (showNormals)
        {
            Vector3[] vertices = mesh.vertices;
            Vector3[] normals = mesh.normals;

            for (int i = 0; i < vertices.Length; i++)
            {
                Gizmos.DrawRay(vertices[i], vertices[i] + normals[i]*dirLength);
            }
        }

        if (showTangents)
        {
            Vector4[] tangents = mesh.tangents;

            for (int i = 0; i < tangents.Length; i++)
            {
                Vector3[] vertices = mesh.vertices;
                Vector3[] normals = mesh.normals;
                Vector4 tangent = tangents[i];

                tangent = (Vector3)tangent - normals[i] * Vector3.Dot(normals[i], tangent);
                tangent.Normalize();

                Gizmos.DrawRay(vertices[i], (Vector3)vertices[i] + (Vector3)tangent*dirLength);
            }
        }
    }
}
#endif