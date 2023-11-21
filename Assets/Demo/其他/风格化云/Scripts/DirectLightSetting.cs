using System;
using UnityEngine;
using UnityEngine.Serialization;

[ExecuteAlways]
public class DirectLightSetting : MonoBehaviour
{
    [FormerlySerializedAs("sunLight")] 
    [SerializeField] private Light sunDirectLight;
    [FormerlySerializedAs("moonLight")] 
    [SerializeField] private Light moonDirectLight;
    [SerializeField] private GameObject Moon;
    [SerializeField] private float MoonDistance=1000.0f;

    public Color moonLineColor = Color.grey;
    public Transform _sunTransform;
    public Transform _moonTransform;

    private void OnDrawGizmos()
    {
        if (_sunTransform != null)
        {
            Vector3 dir = -sunDirectLight.transform.forward;
            _sunTransform.position = Vector3.zero + dir * 2;
            Gizmos.color = Color.red;
            Gizmos.DrawRay(Vector3.zero, dir * 2);
        }
        
        if (_moonTransform != null)
        {
            Vector3 dir = sunDirectLight.transform.forward;
            moonDirectLight.transform.forward = -dir;
            _moonTransform.position = Vector3.zero + dir * 2;
            Gizmos.color = moonLineColor;
            Gizmos.DrawRay(Vector3.zero, dir * 2);
        }
    }

    private void Update()
    {
        if(Moon==null)
            return;
        if (sunDirectLight != null)
        {
            if (sunDirectLight.transform.forward.y > 0)
            {
                sunDirectLight.GetComponent<Light>().enabled = false;
            }
            else
            {
                sunDirectLight.GetComponent<Light>().enabled = true;
            }
        }
        
        if (moonDirectLight != null)
        {
            if (moonDirectLight.transform.forward.y > 0.3f)
            {
                moonDirectLight.GetComponent<Light>().enabled = false;
                Moon.SetActive(false);
            }
            else
            {
                moonDirectLight.GetComponent<Light>().enabled = true;
                Moon.SetActive(true);
            }
        }

        if (Moon != null)
        {
            Moon.transform.position = -moonDirectLight.transform.forward * MoonDistance;
            Moon.transform.forward = moonDirectLight.transform.forward;
        }
    }
}