// Source: https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/AnisotropicKuwahara.cs

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Anisotropic_Kuwahara : MonoBehaviour {
    public Shader kuwaharaShader;
    
    [Range(2, 20)] // circular kernel radius to use in filter
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
        kuwaharaMat = new Material(kuwaharaShader); // make a new temp material, sicne this is mainly testing
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
        kuwaharaMat.SetFloat("_Zeta", useZeta ? zeta : 2.0f / 2.0f / (kernelSize / 2.0f));

        // RenderTexture.GetTemporary() gives you a quick renderTexture
        // Graphics.Blit uses a shader to copy pixel data from a texture into a render target
        var structureTensor = RenderTexture.GetTemporary(source.width, source.height, 0, source.format); // width, heigh, depth buffer, format
        Graphics.Blit(source, structureTensor, kuwaharaMat, 0); // source, destination, material, passes
        var eigenvectors1 = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        Graphics.Blit(structureTensor, eigenvectors1, kuwaharaMat, 1);
        var eigenvectors2 = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        Graphics.Blit(eigenvectors1, eigenvectors2, kuwaharaMat, 2);
        kuwaharaMat.SetTexture("_TFM", eigenvectors2);


        // make a new rendertexture for how many passes we will have
        RenderTexture[] kuwaharaPasses = new RenderTexture[passes];

        for (int i = 0; i < passes; ++i) {
            kuwaharaPasses[i] = RenderTexture.GetTemporary(source.width, source.height, 0, source.format);
        }
        Graphics.Blit(source, kuwaharaPasses[0], kuwaharaMat, 3);

        for (int i = 1; i < passes; ++i) {
            // give the next pass the last pass's info, Blit copies texture
            Graphics.Blit(kuwaharaPasses[i - 1], kuwaharaPasses[i], kuwaharaMat, 3);
        }
        Graphics.Blit(kuwaharaPasses[passes - 1], destination);

        RenderTexture.ReleaseTemporary(structureTensor);
        RenderTexture.ReleaseTemporary(eigenvectors1);
        RenderTexture.ReleaseTemporary(eigenvectors2);

        for (int i = 0; i < passes; ++i) { 
            RenderTexture.ReleaseTemporary(kuwaharaPasses[i]);
        }
    }

    void OnDisable() {
        kuwaharaMat = null;
    }
}