using System.Collections;
using System.Collections.Generic;
using Autodesk.Fbx;
using UnityEngine;
using UnityEditor;
using UnityEngine.Rendering;


public class ChangeMeshNormalInUV : MonoBehaviour
{
    public Mesh mesh;
    [Range(0, 180)] public float rangeAngel = 100.0f;

    [ContextMenu("导计算平滑法线到uv")]
    void ExportSharedNormalsToTangent()
    {
        //EditorCoroutineRunner.StartLoop(this, ExportSharedNormalsToTangentCo());
        StartCoroutine(ExportSharedNormalsToTangentCo());
    }

    public IEnumerator ExportSharedNormalsToTangentCo()
    {
        //获取Mesh

        Transform[] bones = new Transform[] { };
        if (GetComponent<SkinnedMeshRenderer>())
        {
            mesh = GetComponent<SkinnedMeshRenderer>().sharedMesh;
        }

        if (GetComponent<MeshFilter>())
        {
            mesh = GetComponent<MeshFilter>().sharedMesh;
        }

        Debug.Log(mesh.name);
        yield return null;

        //声明一个Vector3数组，长度与mesh.normals一样，用于存放
        //与mesh.vertices中顶点一一对应的光滑处理后的法线值
        Vector2[] avgNormals_xy = new Vector2[mesh.normals.Length];
        Vector2[] avgNormals_zw = new Vector2[mesh.normals.Length];
        Vector4[] avgNormalsV4 = new Vector4[mesh.normals.Length];
        Vector3[] meshVerts = mesh.vertices;
        Vector3[] meshNormals = mesh.normals;

        //把距离相等的点（重合的点）放到同一个表中
        SortedList<float, List<int>> sl = new SortedList<float, List<int>>();
        for (int i = 0; i < meshVerts.Length; i++)
        {
            Vector3 v = meshVerts[i];
            float f = Vector3.Magnitude(v);
            if (!sl.ContainsKey(f))
            {
                sl[f] = new List<int>();
            }

            sl[f].Add(i);
        }

        //int maxIndex = 500;
        //开始一个循环，循环的次数 = mesh.normals.Length = mesh.vertices.Length = meshNormals.Length
        int len = avgNormals_xy.Length;
        for (int i = 0; i < len; i++)
        {
            // if(i>=maxIndex)
            //     break;
            //取当前索引的法线
            Vector3 normal = meshVerts[i].normalized;

            //取这些顶点的下标们
            var slIndices = sl[Vector3.Magnitude(meshVerts[i])];

            //遍历这些顶点的下标，把重合的顶点的法线给混合起来
            int shareCnt = 0; //记录混合了多少法线
            for (int j = 0; j < slIndices.Count; j++)
            {
                Vector3 vj = meshVerts[slIndices[j]];

                if (Vector3.Distance(vj, meshVerts[i]) < 0.0001f)
                {
                    float dotProduct = Vector3.Dot(normal.normalized, meshNormals[slIndices[j]].normalized);
                    float radian = Mathf.Acos(dotProduct); // 计算反余弦值（弧度）
                    float angle = Mathf.Abs(radian * Mathf.Rad2Deg); // 将弧度转换为角度
                    if (angle >= 0 && angle <= rangeAngel)
                    {
                        normal += meshNormals[slIndices[j]].normalized;
                        shareCnt++;
                    }
                }
            }

            normal.Normalize();
            avgNormals_xy[i] = new Vector2(normal.x, normal.y);
            avgNormals_zw[i] = new Vector2(normal.z, 0);
            avgNormalsV4[i] = new Vector4(normal.x, normal.y, normal.z, 0);

            //每遍历10次挂起
            if (i % 10 != 0)
                continue;

            Debug.LogFormat("平滑法线进度 {0} / {1}", i, avgNormals_xy.Length);

            yield return null;
        }

        mesh.tangents = avgNormalsV4;

        //
        // //构建模型空间→切线空间的转换矩阵
        // ArrayList OtoTMatrixs = new ArrayList();
        // for (int i = 0; i < mesh.normals.Length; i++)
        // {
        //     Vector3[] OtoTMatrix = new Vector3[3];
        //     OtoTMatrix[0] = new Vector3(mesh.tangents[i].x, mesh.tangents[i].y, mesh.tangents[i].z);
        //     OtoTMatrix[1] = Vector3.Cross(mesh.normals[i], OtoTMatrix[0]);
        //     OtoTMatrix[1] = new Vector3(OtoTMatrix[1].x * mesh.tangents[i].w, OtoTMatrix[1].y * mesh.tangents[i].w,
        //         OtoTMatrix[1].z * mesh.tangents[i].w);
        //     OtoTMatrix[2] = mesh.normals[i];
        //     OtoTMatrixs.Add(OtoTMatrix);
        // }

        //将meshNormals数组中的法线值一一与矩阵相乘，求得切线空间下的法线值
        // for (int i = 0; i < meshNormals.Length; i++)
        // {
        //     Vector3 tNormal;
        //     tNormal = Vector3.zero;
        //     tNormal.x = Vector3.Dot(((Vector3[]) OtoTMatrixs[i])[0], meshNormals[i]);
        //     tNormal.y = Vector3.Dot(((Vector3[]) OtoTMatrixs[i])[1], meshNormals[i]);
        //     tNormal.z = Vector3.Dot(((Vector3[]) OtoTMatrixs[i])[2], meshNormals[i]);
        //     meshNormals[i] = tNormal;
        // }
        //
        // //新建一个颜色数组把光滑处理后的法线值存入其中
        // Color[] meshColors = new Color[mesh.colors.Length];
        // for (int i = 0; i < meshColors.Length; i++)
        // {
        //     meshColors[i].r = meshNormals[i].x * 0.5f + 0.5f;
        //     meshColors[i].g = meshNormals[i].y * 0.5f + 0.5f;
        //     meshColors[i].b = meshNormals[i].z * 0.5f + 0.5f;
        //     meshColors[i].a = mesh.colors[i].a;
        // }

        // //新建一个mesh，将之前mesh的所有信息copy过去
        Mesh newMesh = new Mesh();
        newMesh.vertices = mesh.vertices;
        newMesh.triangles = mesh.triangles;
        newMesh.normals = mesh.normals;
        //newMesh.tangents = mesh.tangents;
        newMesh.uv = mesh.uv;
        newMesh.uv2 = mesh.uv2;
        newMesh.uv3 = mesh.uv3;
        newMesh.uv4 = mesh.uv4;
        newMesh.uv5 = mesh.uv5;
        newMesh.uv6 = mesh.uv6;
        newMesh.vertexBufferTarget = mesh.vertexBufferTarget;
        newMesh.indexBufferTarget = mesh.indexBufferTarget;
        //将新模型的颜色赋值为计算好的颜色
        newMesh.colors32 = mesh.colors32;
        newMesh.bounds = mesh.bounds;
        newMesh.indexFormat = mesh.indexFormat;
        newMesh.bindposes = mesh.bindposes;
        newMesh.boneWeights = mesh.boneWeights;
        newMesh.triangles = mesh.triangles;
        newMesh.tangents = avgNormalsV4;
        // for (int i = 0; i < mesh.subMeshCount; i++)
        // {
        //     newMesh.SetSubMesh(i,mesh.GetSubMesh(i));
        // }
        Debug.LogFormat("newMesh triangles:{0}", newMesh.triangles.Length);

        //设置模型的
        SubMeshDescriptor[] sub = new SubMeshDescriptor[mesh.subMeshCount];
        for (int i = 0; i < mesh.subMeshCount; i++)
        {
            sub[i] = mesh.GetSubMesh(i);
        }

        newMesh.SetSubMeshes(sub);
        Debug.Log(nameof(newMesh.subMeshCount) + ":" + newMesh.subMeshCount);


        // for (int i = 0; i < mesh.blendShapeCount; i++)
        // {
        //     int frameCount = mesh.GetBlendShapeFrameCount(i);
        //     string name = mesh.GetBlendShapeName(i);
        //
        //     for (int j = 0; j < frameCount; j++)
        //     {
        //         Vector3[] normal = new Vector3[mesh.vertexCount];
        //         Vector3[] tangent = new Vector3[mesh.vertexCount];
        //         Vector3[] vertice = new Vector3[mesh.vertexCount];
        //         mesh.GetBlendShapeFrameVertices(i, j, vertice, normal, tangent);
        //
        //         float weight = mesh.GetBlendShapeFrameWeight(i, j);
        //         newMesh.AddBlendShapeFrame(name, weight, normal, vertice, tangent);
        //     }
        //
        //     Debug.LogFormat("骨骼动画复制进度 {0} / {1}", i, mesh.blendShapeCount);
        // }
        //
        Vector3[] dVertices = new Vector3[mesh.vertexCount];
        Vector3[] dNormals = new Vector3[mesh.vertexCount];
        Vector3[] dTangents = new Vector3[mesh.vertexCount];
        for (int shape = 0; shape < mesh.blendShapeCount; shape++)
        {
            for (int frame = 0; frame < mesh.GetBlendShapeFrameCount(shape); frame++)
            {
                string shapeName = mesh.GetBlendShapeName(shape);
                float frameWeight = mesh.GetBlendShapeFrameWeight(shape, frame);
                mesh.GetBlendShapeFrameVertices(shape, frame, dVertices, dNormals, dTangents);
                newMesh.AddBlendShapeFrame(shapeName, frameWeight, dVertices, dNormals, dTangents);
            }
        }

        Debug.LogFormat("newMesh triangles:{0}", newMesh.triangles.Length);

        // string assetPath = AssetDatabase.GetAssetPath(mesh);
        // AssetDatabase.ImportAsset(assetPath);
        string NewMeshPath = "Assets/Demo/NPR/Tools/mesh4.0/newMesh.asset";
        AssetDatabase.CreateAsset(newMesh, NewMeshPath);
        AssetDatabase.SaveAssets();
        Debug.Log("Done");

        // //将新mesh保存为.asset文件，路径可以是"Assets/Character/Shader/VertexColorTest/TestMesh2.asset"                          
        // AssetDatabase.CreateAsset(newMesh, NewMeshPath);
        // AssetDatabase.SaveAssets();
        // Debug.Log("Done");

        yield return null;
    }
}