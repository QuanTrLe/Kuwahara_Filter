// The shader of the basic Kuwahara filter is from Acerola / GarrettGunnell/s repo (https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/Kuwahara.shader) 
// as this was just for me to look into how the effect overall would look like and develop the other 2 variations from this base.

Shader "CustomRenderTexture/Kuwahara" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader {

        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            #include "UnityCG.cginc"

            // Struct that contains the vertex and the uv data
            struct VertexData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };


            struct v2f { 
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            // Vertex program that just sets the ClipPos of the vertex and the uv data of the struct
            v2f vp(VertexData v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            sampler2D _MainTex;
            float4 _MainTex_TexelSize;
            int _KernelSize, _MinKernelSize, _AnimateSize, _AnimateOrigin;
            float _SizeAnimationSpeed, _NoiseFrequency;

            float luminance(float3 color) {
                // numbers are the formula for converting to greyscale, hence dot to transform value to luminence
                // remember the dot formula can also be jsut components of the vec multipled and summed
                return dot(color, float3(0.299f, 0.587f, 0.114f));
            }

            float hash(uint n) {
                // integer hash copied from Hugo Elias
                n = (n << 13U) ^ n;
                n = n * (n * n * 15731U + 0x789221U) + 0x1376312589U;
                return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
            }

            // Returns avg color in .rgb, std in .a
            // pair of x and y coordinate is to know where the quardrant is
            // n is how many samples / pixels in the quadrant
            float4 SampleQuadrant(float2 uv, int x1, int x2, int y1, int y2, float n) {
                float luminance_sum = 0.0f;
                float luminance_sum2 = 0.0f;
                float3 col_sum = 0.0f;

                // loop through all the rows and cols 
                [loop]
                for (int x = x1; x <= x2; ++x) {
                    [loop]
                    for (int y = y1; y <= y2; ++y) {
                        // _MainTex_TexelSize is size of texel of the texture, like 1 / resolution ish, easy way to get 0 to 1 uv range
                        // so basically from uv center move to that cord 
                        float3 sample = tex2D(_MainTex, uv + float2(x, y) * _MainTex_TexelSize.xy).rgb;
                        float l = luminance(sample);
                        luminance_sum += l;
                        luminance_sum2 += l * l;
                        col_sum += saturate(sample); // saturate clamps input between 0 - 1
                    }
                }

                float mean = luminance_sum / n;
                float std = abs(luminance_sum2 / n - mean * mean); // variance = (sum_L^2 / n) - (sum_L^2 / n^2)

                return float4(col_sum / n, std);
            }

            // The fragment program is where we do most of our work as to determine the color based on std deviations of the 4 quardrants
            float4 fp(v2f i) : SV_Target {
                // if we need to animate the pass process then iterate through each kernel size
                if (_AnimateSize) {
                    uint seed = i.uv.x + _MainTex_TexelSize.z * i.uv.y + _MainTex_TexelSize.z * _MainTex_TexelSize.w;
                    seed = i.uv.y * _MainTex_TexelSize.z * _MainTex_TexelSize.w;
                    float kernelRange = (sin(_Time.y * _SizeAnimationSpeed + hash(seed) * _NoiseFrequency) * 0.5f + 0.5f) * _KernelSize + _MinKernelSize;
                    int minKernelSize = floor(kernelRange);
                    int maxKernelSize = ceil(kernelRange);
                    float t = frac(kernelRange);

                    float windowSize = 2.0f * minKernelSize + 1;
                    int quadrantSize = int(ceil(windowSize / 2.0f));
                    int numSamples = quadrantSize * quadrantSize;

                    float4 q1 = SampleQuadrant(i.uv, -minKernelSize, 0, -minKernelSize, 0, numSamples);
                    float4 q2 = SampleQuadrant(i.uv, 0, minKernelSize, -minKernelSize, 0, numSamples);
                    float4 q3 = SampleQuadrant(i.uv, 0, minKernelSize, 0, minKernelSize, numSamples);
                    float4 q4 = SampleQuadrant(i.uv, -minKernelSize, 0, 0, minKernelSize, numSamples);

                    float minstd = min(q1.a, min(q2.a, min(q3.a, q4.a)));
                    int4 q = float4(q1.a, q2.a, q3.a, q4.a) == minstd;
    
                    float4 result1 = 0;
                    if (dot(q, 1) > 1)
                        result1 = saturate(float4((q1.rgb + q2.rgb + q3.rgb + q4.rgb) / 4.0f, 1.0f));
                    else
                        result1 = saturate(float4(q1.rgb * q.x + q2.rgb * q.y + q3.rgb * q.z + q4.rgb * q.w, 1.0f));

                    windowSize = 2.0f * maxKernelSize + 1;
                    quadrantSize = int(ceil(windowSize / 2.0f));
                    numSamples = quadrantSize * quadrantSize;

                    q1 = SampleQuadrant(i.uv, -maxKernelSize, 0, -maxKernelSize, 0, numSamples);
                    q2 = SampleQuadrant(i.uv, 0, maxKernelSize, -maxKernelSize, 0, numSamples);
                    q3 = SampleQuadrant(i.uv, 0, maxKernelSize, 0, maxKernelSize, numSamples);
                    q4 = SampleQuadrant(i.uv, -maxKernelSize, 0, 0, maxKernelSize, numSamples);

                    minstd = min(q1.a, min(q2.a, min(q3.a, q4.a)));
                    q = float4(q1.a, q2.a, q3.a, q4.a) == minstd;
    
                    float4 result2 = 0;
                    if (dot(q, 1) > 1)
                        result2 = saturate(float4((q1.rgb + q2.rgb + q3.rgb + q4.rgb) / 4.0f, 1.0f));
                    else
                        result2 = saturate(float4(q1.rgb * q.x + q2.rgb * q.y + q3.rgb * q.z + q4.rgb * q.w, 1.0f));

                    return lerp(result1, result2, t);
                } 

                // if there is no animation need then just calculate normally 
                else {
                    float windowSize = 2.0f * _KernelSize + 1; // the area we're investigating / all quadrants combined 
                    int quadrantSize = int(ceil(windowSize / 2.0f)); // kernel ~= quadrant 
                    int numSamples = quadrantSize * quadrantSize; // how many samples / pixels we have in total

                    // take variance of each quadrant and choose min
                    float4 q1 = SampleQuadrant(i.uv, -_KernelSize, 0, -_KernelSize, 0, numSamples);
                    float4 q2 = SampleQuadrant(i.uv, 0, _KernelSize, -_KernelSize, 0, numSamples);
                    float4 q3 = SampleQuadrant(i.uv, 0, _KernelSize, 0, _KernelSize, numSamples);
                    float4 q4 = SampleQuadrant(i.uv, -_KernelSize, 0, 0, _KernelSize, numSamples);

                    // creates a mask where the quadrant w the lowest variance is a 1 and the rest is 0
                    // bc we can also have cases where two quardrants have the same variance
                    float minstd = min(q1.a, min(q2.a, min(q3.a, q4.a)));
                    int4 q = float4(q1.a, q2.a, q3.a, q4.a) == minstd;
    
                    // if all 2 or more quardrants have the same variance then just choose all of them
                    if (dot(q, 1) > 1) // dot of q here would be the amount of 1 in the mask
                        return saturate(float4((q1.rgb + q2.rgb + q3.rgb + q4.rgb) / 4.0f, 1.0f));
                    else// else return the lowest quardrant's avg color using the mask we made
                        return saturate(float4(q1.rgb * q.x + q2.rgb * q.y + q3.rgb * q.z + q4.rgb * q.w, 1.0f));
                }
            }
            ENDCG
        }
    }
}