// The shader of the basic Kuwahara filter is from Acerola / GarrettGunnell/s repo (https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/Kuwahara.shader) 
// as this was just for me to look into how the effect overall would look like and develop the other 2 variations from this base.

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Generalized_Kuwahara : MonoBehaviour {
    public Shader generalizedKuwaharaShader;
    
    [Range(1, 20)] // kernel size to use in filter, if animated then this will be the stopping poine
    public int kernelSize = 1;

    public bool animateKernelSize = false;

    [Range(1, 20)] // starting kernel size when animating
    public int minKernelSize = 1;

    [Range(0.1f, 5.0f)]
    public float sizeAnimationSpeed = 1.0f;
    
    [Range(0.0f, 30.0f)]
    public float noiseFrequency = 10.0f;

    public bool animateKernelOrigin = false; // as far as i know, doesnt do anything
    
    [Range(1, 4)]
    public int passes = 1;

    private Material kuwaharaMat;
    
    void OnEnable() {
        kuwaharaMat = new Material(generalizedKuwaharaShader); // make a new temp material, sicne this is mainly testing
        kuwaharaMat.hideFlags = HideFlags.HideAndDontSave;
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination) {
        // set all the variables of the shader we've had above from the editor 
        kuwaharaMat.SetInt("_KernelSize", kernelSize);
        kuwaharaMat.SetInt("_MinKernelSize", minKernelSize);
        kuwaharaMat.SetInt("_AnimateSize", animateKernelSize ? 1 : 0);
        kuwaharaMat.SetFloat("_SizeAnimationSpeed", sizeAnimationSpeed);
        kuwaharaMat.SetFloat("_NoiseFrequency", noiseFrequency);
        kuwaharaMat.SetInt("_AnimateOrigin", animateKernelOrigin ? 1 : 0);

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