using UnityEngine;
using UnityEngine.Serialization;
using PlanarReflectionSettings = MyPlanarReflections.PlanarReflectionSettings;

public class WaterManager : MonoBehaviour
{
    [SerializeField] private PlanarReflectionSettings m_settings =
        new MyPlanarReflections.PlanarReflectionSettings();

    [FormerlySerializedAs("_planarReflections")] [SerializeField] private MyPlanarReflections myPlanarReflections;
}