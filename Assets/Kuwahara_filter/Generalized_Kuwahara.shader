// The shader of the basic Kuwahara filter is from Acerola / GarrettGunnell/s repo (https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/Kuwahara.shader) 
// as this was just for me to look into how the effect overall would look like and develop the other 2 variations from this base.

Shader "CustomRenderTexture/Generalized_Kuwahara" {
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
            int _KernelSize, _GaussianSigma, _MinKernelSize, _AnimateSize, _AnimateOrigin;
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

            // Returns avg color in .rgb, variance in .a
            float4 SampleQuadrant(float2 uv, int kernelSize, int quadrantNum) {
                float luminance_sum = 0.0f;
                float luminance_sum2 = 0.0f;
                float3 col_sum = 0.0f;
                float total_weight = 0;

                // loop through all the rows and cols 
                [loop]
                for (int x = -kernelSize; x <= kernelSize; ++x) {
                    [loop]
                    for (int y = -kernelSize; y <= kernelSize; ++y) {
                        // check if it's even within the circular kernel
                        float pixelDistance = distance(float2(0, 0), float2(x, y));
                        if (pixelDistance > kernelSize) {
                            continue; // pixel outside circular kernel
                        }

                        // get the angle of the pixel and see if it's in the quardrant or not
                        float pixelAngle = degrees(atan2(y, x));
                        pixelAngle = fmod(pixelAngle + 360.0, 360.0); // since it returns -180 to 180
                        int pixelQuadrant = 0;
                        pixelQuadrant = floor(fmod(pixelAngle + 22.5, 360.0) / 45.0) + 1; // get the quadrant number outright
                        if (x == 0 && y == 0) { // in the case it's the center then it counts for all quadrants
                            pixelQuadrant = quadrantNum;
                        }
                        if (pixelQuadrant != quadrantNum) {
                            continue; // if not in the right quadrant just skip all ahead
                        }

                        // gaussian weight to take into account when adding the color / luminence
                        float gaussian_weight = (1.0 / (2.0 * UNITY_PI * _GaussianSigma * _GaussianSigma)) * exp(-(pixelDistance * pixelDistance) / (2.0 * _GaussianSigma * _GaussianSigma));

                        // get color and take it to sum normal way
                        float3 sample = tex2D(_MainTex, uv + float2(x, y) * _MainTex_TexelSize.xy).rgb;
                        float l = luminance(sample);
                        luminance_sum += l * gaussian_weight;
                        luminance_sum2 += l * l * gaussian_weight;
                        col_sum += sample * gaussian_weight; // saturate clamps input between 0 - 1
                        total_weight += gaussian_weight; // keep track of this for variance later
                    }
                }

                float mean = luminance_sum / total_weight;
                float std = abs(luminance_sum2 / total_weight - mean * mean); // variance = (sum_L^2 / n) - (sum_L^2 / n^2)

                return float4(col_sum / total_weight, std);
            }

            // The fragment program is where we do most of our work as to determine the color based on std deviations of the 4 quardrants
            float4 fp(v2f i) : SV_Target {
                // take variance of each quadrant and choose min
                float4 q1 = SampleQuadrant(i.uv, _KernelSize, 1);
                float4 q1_weight = 1 / (1 + q1.a);
                float4 q2 = SampleQuadrant(i.uv, _KernelSize, 2);
                float4 q2_weight = 1 / (1 + q2.a);
                float4 q3 = SampleQuadrant(i.uv, _KernelSize, 3);
                float4 q3_weight = 1 / (1 + q3.a);
                float4 q4 = SampleQuadrant(i.uv, _KernelSize, 4);
                float4 q4_weight = 1 / (1 + q4.a);
                float4 q5 = SampleQuadrant(i.uv, _KernelSize, 5);
                float4 q5_weight = 1 / (1 + q5.a);
                float4 q6 = SampleQuadrant(i.uv, _KernelSize, 6);
                float4 q6_weight = 1 / (1 + q6.a);
                float4 q7 = SampleQuadrant(i.uv, _KernelSize, 7);
                float4 q7_weight = 1 / (1 + q7.a);
                float4 q8 = SampleQuadrant(i.uv, _KernelSize, 8);
                float4 q8_weight = 1 / (1 + q8.a);

                // calculate the total weight and the combined color
                float total_weight = q1_weight + q2_weight + q3_weight + q4_weight + q5_weight + q6_weight + q7_weight + q8_weight;
                float3 combined_color = q1.rgb * q1_weight + q2.rgb * q2_weight + q3.rgb * q3_weight + q4.rgb * q4_weight;
                combined_color += q5.rgb * q5_weight + q6.rgb * q6_weight + q7.rgb * q7_weight + q8.rgb * q8_weight;

                return saturate(float4(combined_color / total_weight, 1.0f));
            }
            ENDCG
        }
    }
}