using System;
using System.IO;
using System.Net;
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(GradientGenerator))]
public class GradientGeneratorEditor:Editor
{
        private GradientGenerator gradientGenerator;

        private void OnEnable()
        {
                gradientGenerator = target as GradientGenerator;
        }

        public override void OnInspectorGUI()
        {
                base.DrawDefaultInspector();
                if (GUILayout.Button("生成纹理"))
                {
                        string path = EditorUtility.SaveFilePanel
                                ("保持纹理", Application.dataPath, "GraadientTex", "png");
                        File.WriteAllBytes(path,gradientGenerator.tex.EncodeToPNG());
                        AssetDatabase.Refresh();
                }
        }
}