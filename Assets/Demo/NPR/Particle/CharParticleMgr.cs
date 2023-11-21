using System.Collections;
using System.Collections.Generic;
using UnityEditor.Rendering;
using UnityEngine;

public class CharParticleMgr : MonoBehaviour
{
    public GameObject Enemy;
    public ParticleSystem Particle;
    private Material _material;
    
    // Start is called before the first frame update
    void Start()
    {
        _material = Enemy.GetComponent<Renderer>().material;
    }

    // Update is called once per frame
    void Update()
    {
        
    }

    private void Die()
    {
        Particle.Play();
    }
}
