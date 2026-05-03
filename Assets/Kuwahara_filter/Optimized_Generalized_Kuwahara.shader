// https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/GeneralizedKuwahara.shader

Shader "CustomRenderTexture/Optimized_Generalized_Kuwahara" {
    Properties {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader {

        CGINCLUDE
        #include "UnityCG.cginc"

        // struct holding vertex and the uv data
        struct VertexData {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };


        // struct holding both uv and vertex, specifically for dealing between vertex and fragment processing
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

        // vars: Q is sharpness and N is the amount of sectors in the kernel
        #define PI 3.14159265358979323846f
        sampler2D _MainTex, _K0;
        float4 _MainTex_TexelSize;
        int _KernelSize, _N, _Size;
        float _Hardness, _Q, _ZeroCrossing, _Zeta;

        ENDCG

        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                int k;
                float4 m[8];
                float3 s[8];

                int kernelRadius = _KernelSize / 2;

                //float zeta = 2.0f / (kernelRadius / 2);
                // origin overlap of sectors, think how offset the parabola is to the center
                float zeta = _Zeta;

                float zeroCross = _ZeroCrossing;
                float sinZeroCross = sin(zeroCross);
                // boundary overlap of sectors, the higher eta is the more quickly the parabola weight curves towards the side
                float eta = (zeta + cos(zeroCross)) / (sinZeroCross * sinZeroCross);

                for (k = 0; k < _N; ++k) {
                    m[k] = 0.0f;
                    s[k] = 0.0f;
                }

                [loop]
                for (int y = -kernelRadius; y <= kernelRadius; ++y) {
                    [loop]
                    for (int x = -kernelRadius; x <= kernelRadius; ++x) {
                        float2 v = float2(x, y) / kernelRadius; // normalizing from pixel cords to [-1, 1]
                        float3 c = tex2D(_MainTex, i.uv + float2(x, y) * _MainTex_TexelSize.xy).rgb;
                        c = saturate(c); // saturate clamps between 0 and 1
                        float sum = 0; // total weight for calc the final color
                        float quardrant_weights[8]; // weight for each quardrant
                        float sector_weight, vxx, vyy;
                        
                        /* Calculate Polynomial Weights */
                        // try to think of these as thresholds of how fast the parabola weight curves
                        vxx = zeta - eta * v.x * v.x; // for sectors pointing up and down
                        vyy = zeta - eta * v.y * v.y; // for sectors pointing left and right

                        /* calculating the weights of each quardrant of the 8 sector circle kernel */
                        // the sector_weight calcs are for ex if v.y + vxx are positive then the pixel is inside the leaf / the weight curve 
                        sector_weight = max(0, v.y + vxx); // top quardrant of kernel
                        quardrant_weights[0] = sector_weight * sector_weight;
                        sum += quardrant_weights[0];

                        sector_weight = max(0, -v.x + vyy); // right quardrant of kernel
                        quardrant_weights[2] = sector_weight * sector_weight;
                        sum += quardrant_weights[2];

                        sector_weight = max(0, -v.y + vxx); // bottom quardrant of kernel 
                        quardrant_weights[4] = sector_weight * sector_weight;
                        sum += quardrant_weights[4];

                        sector_weight = max(0, v.x + vyy); // left quardrant of kernel
                        quardrant_weights[6] = sector_weight * sector_weight;
                        sum += quardrant_weights[6];

                        /* recalculating the weight modifiers for quardrants that are rotated 45 */
                        v = sqrt(2.0f) / 2.0f * float2(v.x - v.y, v.x + v.y);
                        vxx = zeta - eta * v.x * v.x;
                        vyy = zeta - eta * v.y * v.y;

                        sector_weight = max(0, v.y + vxx); // north east quardrant
                        quardrant_weights[1] = sector_weight * sector_weight;
                        sum += quardrant_weights[1];

                        sector_weight = max(0, -v.x + vyy); // south east quardrant
                        quardrant_weights[3] = sector_weight * sector_weight;
                        sum += quardrant_weights[3];

                        sector_weight = max(0, -v.y + vxx); // south west quardrant
                        quardrant_weights[5] = sector_weight * sector_weight;
                        sum += quardrant_weights[5];

                        sector_weight = max(0, v.x + vyy); // north west quardrant
                        quardrant_weights[7] = sector_weight * sector_weight;
                        sum += quardrant_weights[7];
                        
                        float g = exp(-3.125f * dot(v,v)) / sum; // radial falloff for the weight
                        
                        for (int k = 0; k < 8; ++k) {
                            float wk = quardrant_weights[k] * g;
                            m[k] += float4(c * wk, wk);
                            s[k] += c * c * wk;
                        }
                    }
                }

                float4 output = 0;
                for (k = 0; k < _N; ++k) {
                    m[k].rgb /= m[k].w;
                    s[k] = abs(s[k] / m[k].w - m[k].rgb * m[k].rgb);

                    float sigma2 = s[k].r + s[k].g + s[k].b;
                    float w = 1.0f / (1.0f + pow(_Hardness * 1000.0f * sigma2, 0.5f * _Q));

                    output += float4(m[k].rgb * w, w);
                }

                return saturate(output / output.w);
            }

            ENDCG
        }
    }
}