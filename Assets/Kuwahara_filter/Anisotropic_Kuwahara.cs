using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Anisotropic_Kuwahara : MonoBehaviour {
    public Shader anisotropicKuwaharaShader;
    
    [Range(1, 20)] // circular kernel radius to use in filter
    public int kernelSize = 2;

    [Range(1.0f, 18.0f)]
    public float sharpness = 8;
    [Range(1.0f, 100.0f)]
    public float hardness = 8;

    [Range(0.01f, 2.0f)]
    public float alpha = 1.0f; // alpha > 0 is a tuning parameter for the ellipse matrix (if a -> inf then it becomes an identity matrix) 
    
    [Range(0.01f, 2.0f)]
    public float zeroCrossing = 0.58f; // for calculating eta (sector boundary overlap), from this and zeta

    public bool useZeta = false; // how much sectors overlap at origin
    [Range(0.01f, 3.0f)]
    public float zeta = 1.0f;
    
    [Range(1, 4)]
    public int passes = 1; // how many times we run the image through the filter

    private Material kuwaharaMat;
    
    void OnEnable() {
        kuwaharaMat = new Material(anisotropicKuwaharaShader); // make a new temp material, sicne this is mainly testing
        kuwaharaMat.hideFlags = HideFlags.HideAndDontSave;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        // set all the variables of the shader we've had above from the editor 
        kuwaharaMat.SetInt("_KernelSize", kernelSize); // how big the kernel is
        kuwaharaMat.SetInt("_SectorCount", 8);
        kuwaharaMat.SetFloat("_Q", sharpness);
        kuwaharaMat.SetFloat("_Hardness", hardness);
        kuwaharaMat.SetFloat("_Alpha", alpha);
        kuwaharaMat.SetFloat("_ZeroCrossing", zeroCrossing);
        kuwaharaMat.SetFloat("_Zeta", useZeta ? zeta : 2.0f / (kernelSize / 2.0f));

        // make a new rendertexture for how many passes we will have
        RenderTexture[] kuwaharaPasses = new RenderTexture[passes];

        for (int i = 0; i < passes; ++i) {
            kuwaharaPasses[i] = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        }

        Graphics.Blit(source, kuwaharaPasses[0], kuwaharaMat);

        for (int i = 1; i < passes; ++i) {
            // give the next pass the last pass's info, Blit copies texture
            Graphics.Blit(kuwaharaPasses[i - 1], kuwaharaPasses[i], kuwaharaMat);
        }

        Graphics.Blit(kuwaharaPasses[passes - 1], destination);
        for (int i = 0; i < passes; ++i) {
            // temporary in case we reuse the texture again 
            RenderTexture.ReleaseTemporary(kuwaharaPasses[i]);
        }
    }

    void OnDisable() {
        kuwaharaMat = null;
    }
}