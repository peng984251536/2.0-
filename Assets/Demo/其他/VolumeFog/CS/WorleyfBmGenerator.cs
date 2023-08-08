using UnityEngine;
using System;
using UnityEditor.Rendering;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// [ExecuteAlways]
// public class WorleyfBmGenerator : MonoBehaviour
// {
//     private void OnEnable()
//     {
//         //RenderPipelineManager.beginCameraRendering += OnRenderImage;
//     }
//     
//     private void OnDisable()
//     {
//         Cleanup();
//     }
//
//     private void Cleanup()
//     {
//         //RenderPipelineManager.beginCameraRendering -= OnRenderImage;
//     }
//
//     private void OnDestroy()
//     {
//         Cleanup();
//     }
//
//     private void OnRenderImage(ScriptableRenderContext context, Camera camera)
//     {
//         
//         // Noise
//         var noise = FindObjectOfType<NoiseGenerator> ();
//         noise.UpdateNoise ();
//     }
//
// }
