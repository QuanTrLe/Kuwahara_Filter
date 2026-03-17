// The shader of the basic Kuwahara filter is from Acerola / GarrettGunnell/s repo (https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/Kuwahara.shader) 
// as this was just for me to look into how the effect overall would look like and develop the other 2 variations from this base.

Shader "CustomRenderTexture/Generalized_Kuwahara" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader {

        Pass {
            CGPROGRAM
// Upgrade NOTE: excluded shader from DX11 because it uses wrong array syntax (type[size] name)
#pragma exclude_renderers d3d11
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

            struct QuadrantData {
                float4 colors[8];
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
            int _KernelSize, _MinKernelSize, _AnimateSize, _AnimateOrigin, _QuadrantWeightPower;
            float _GaussianSigma, _SizeAnimationSpeed, _NoiseFrequency;

            float luminance(float3 color) {
                // numbers are the formula for converting to greyscale, hence dot to transform value to luminence
                return dot(color, float3(0.299f, 0.587f, 0.114f));
            }

            float hash(uint n) {
                // integer hash copied from Hugo Elias
                n = (n << 13U) ^ n;
                n = n * (n * n * 15731U + 0x789221U) + 0x1376312589U;
                return float(n & uint(0x7fffffffU)) / float(0x7fffffff);
            }

            // Returns avg color in .rgb, variance in .a
            QuadrantData SampleQuadrant(float2 uv, int kernelSize) {
                QuadrantData outData;

                // constants
                float sigma_2 = _GaussianSigma * _GaussianSigma;
                float gaussian_weight_scalar = (1.0 / (2.0 * UNITY_PI *sigma_2));

                // each quadrant's data
                float luminance_sum[8] = {0, 0, 0, 0, 0, 0, 0, 0};
                float luminance_sum2[8] = {0, 0, 0, 0, 0, 0, 0, 0};
                float3 col_sum[8] = {(float3)0, (float3)0, (float3)0, (float3)0, (float3)0, (float3)0, (float3)0, (float3)0};
                float total_weight[8] = {0, 0, 0, 0, 0, 0, 0, 0};
                float variance[8] = {0, 0, 0, 0, 0, 0, 0, 0};
                float4 quadrant_colors[8] = {(float4)0, (float4)0, (float4)0, (float4)0, (float4)0, (float4)0, (float4)0, (float4)0};

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

                        // get color and take it to sum normal way
                        float3 sample = tex2D(_MainTex, uv + float2(x, y) * _MainTex_TexelSize.xy).rgb;
                        float l = luminance(sample);
                        // gaussian weight: (1 / 2 * PI * sigma^2) * Euler ^ [-(x^2 + y^2) / (2 * sigma^2)]
                        float gaussian_weight = gaussian_weight_scalar * exp(-(x * x + y * y) / (2.0 * sigma_2));

                        // get the angle of the pixel and see if it's in the quardrant or not
                        float pixel_angle = degrees(atan2(y, x));
                        pixel_angle = fmod(pixel_angle + 360.0, 360.0); // since it returns -180 to 180
                        int quadrant_num = 0;
                        quadrant_num = floor(fmod(pixel_angle + 22.5, 360.0) / 45.0); // get the quadrant number to array index, 0-7
                        
                        // in the case it's the center then it counts for all quadrants
                        if (x == 0 && y == 0) {
                            for(int i = 0; i < 8; i++) {
                                luminance_sum[i] += l * gaussian_weight;
                                luminance_sum2[i] += l * l * gaussian_weight;
                                col_sum[i] += sample * gaussian_weight;
                                total_weight[i] += gaussian_weight; // keep track of this for variance later
                            }
                        }
                        else {
                            // else it just belongs to one quadrant 
                            luminance_sum[quadrant_num] += l * gaussian_weight;
                            luminance_sum2[quadrant_num] += l * l * gaussian_weight;
                            col_sum[quadrant_num] += sample * gaussian_weight;
                            total_weight[quadrant_num] += gaussian_weight; // keep track of this for variance later
                        }
                    }
                }

                // calculate the avg color and variance of each quadrant
                for(int i = 0; i < 8; i++) {
                    float mean = luminance_sum[i] / total_weight[i];
                    variance[i] = abs(luminance_sum2[i] / total_weight[i] - mean * mean); // variance = (sum_L^2 / n) - (sum_L^2 / n^2) 
                    outData.colors[i] = float4(col_sum[i] / total_weight[i], variance[i]); 
                }

                return outData;
            }

            // The fragment program is where we do most of our work as to determine the color based on std deviations of the 4 quardrants
            float4 fp(v2f i) : SV_Target {
                // avg color and their variance of each 8 quadrance
                QuadrantData quardrant_data = SampleQuadrant(i.uv, _KernelSize);

                float3 combined_color = 0;
                float total_weight = 0;

                for (int i = 0; i < 8; i++) {
                    float quadrant_weighting = 1.0 / (pow(0.0001 + sqrt(quardrant_data.colors[i].a), _QuadrantWeightPower));
                    float3 quadrant_color = quardrant_data.colors[i].rgb;
                    
                    combined_color += quadrant_color * quadrant_weighting;
                    total_weight += quadrant_weighting;
                }

                return float4(combined_color / total_weight, 1.0);
            }
            ENDCG
        }
    }
}