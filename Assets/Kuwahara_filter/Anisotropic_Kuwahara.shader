// Source: https://github.com/GarrettGunnell/Post-Processing/blob/main/Assets/Kuwahara%20Filter/AnisotropicKuwahara.shader

Shader "CustomRenderTexture/Anisotropic_Kuwahara" {
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

        // vars: renamed but for comparison reasons, Q is sharpness and N is the amount of sectors in the kernel
        #define PI 3.14159265358979323846f
        sampler2D _MainTex, _TFM; // _TFM is the eigenvectors2 (3rd) pass
        float4 _MainTex_TexelSize; // Vector4(1 / width, 1 / height, width, height)
        int _KernelSize, _SectorCount, _Size;
        float _Hardness, _Sharpness, _Alpha, _ZeroCrossing, _Zeta;

        float gaussian(float sigma, float pos) {
            return (1.0f / sqrt(2.0f * PI * sigma * sigma)) * exp(-(pos * pos) / (2.0f * sigma * sigma));
        }

        ENDCG
        
        // Calculating eigenvectors
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i): SV_TARGET {
                float2 d = _MainTex_TexelSize.xy; // how much to move when inspecting each texel

                // horizontal sobel operator with normalization
                float3 Sx = (
                    1.0f * tex2D(_MainTex, i.uv + float2(-d.x, -d.y)).rgb +
                    2.0f * tex2D(_MainTex, i.uv + float2(-d.x, 0.0)).rgb +
                    1.0f * tex2D(_MainTex, i.uv + float2(-d.x, d.y)).rgb +
                    -1.0f * tex2D(_MainTex, i.uv + float2(d.x, -d.y)).rgb +
                    -2.0f * tex2D(_MainTex, i.uv + float2(d.x, 0.0)).rgb +
                    -1.0f * tex2D(_MainTex, i.uv + float2(d.x, d.y)).rgb
                ) / 4.0f;

                // vertical sobel operator
                float3 Sy = (
                    1.0f * tex2D(_MainTex, i.uv + float2(-d.x, -d.y)).rgb +
                    2.0f * tex2D(_MainTex, i.uv + float2(0.0, -d.y)).rgb +
                    1.0f * tex2D(_MainTex, i.uv + float2(d.x, -d.y)).rgb +
                    -1.0f * tex2D(_MainTex, i.uv + float2(-d.x, d.y)).rgb +
                    -2.0f * tex2D(_MainTex, i.uv + float2(0.0, d.y)).rgb +
                    -1.0f * tex2D(_MainTex, i.uv + float2(d.x, d.y)).rgb
                ) / 4.0f;

                // data needed for the structure tensor matrix
                return float4(dot(Sx, Sx), dot(Sy, Sy), dot(Sx, Sy), 1.0f);
            }

            ENDCG
        }

        // Blur pass 1
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp
            
            float4 fp(v2f i): SV_TARGET {
                int kernelRadius = 5;

                float4 col = 0;
                float kernelSum = 0.0f;

                // go over the row and get the texel at the point + the gaussian weighted of it
                for (int x = -kernelRadius; x <= kernelRadius; ++x) {
                    float4 c = tex2D(_MainTex, i.uv + float2(x, 0) * _MainTex_TexelSize.xy);
                    float gauss = gaussian(2.0f, x);

                    // add to total and total weight for later
                    col += c * gauss;
                    kernelSum += gauss;
                }

                // return total divided by gauss weight
                return col / kernelSum;
            }

            ENDCG
        }

        // Blur pass 2
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i): SV_Target {
                int kernelRadius = 5;

                float4 col = 0;
                float kernelSum = 0.0f;

                // go over the column and get the texel at the point + the gaussian weighted of it
                for (int y = -kernelRadius; y <= kernelRadius; ++y) {
                    float4 c = tex2D(_MainTex, i.uv + float2(0, y) * _MainTex_TexelSize.xy);
                    float gauss = gaussian(2.0f, y);

                    // add to total and total weight for later
                    col += c * gauss;
                    kernelSum += gauss;
                }

                // at this point it shoulda been gaussian blurred both vertical and horizontal
                float3 g = col.rgb / kernelSum;

                // lambda calculatuions for eigen vector that points in dir of minimal change
                float sum_eg = g.y + g.x;
                float inner_sqrt = sqrt(g.y * g.y - 2.0f * g.x * g.y + g.x * g.x + 4.0f * g.z * g.z);
                float lambda1 = 0.5f * (sum_eg + inner_sqrt);
                float lambda2 = 0.5f * (sum_eg - inner_sqrt);

                // eigenvector directed in dir of min change
                float v = float2(lambda1 - g.x, -g.z);
                float2 t = length(v) > 0.0 ? normalize(v) : float2(0.0f, 1.0f);
                float phi = -atan2(t.y, t.x); // local orientation

                
                // the anisotropy
                float Anisotropy = 0.0f;
                if (lambda1 + lambda2 > 0.0f) {
                    Anisotropy = (lambda1 - lambda2) / (lambda1 + lambda2);
                }

                return float4(t, phi, Anisotropy);
            }

            ENDCG
        }

        // Final Kuwahara pass
        Pass {
            CGPROGRAM
            #pragma vertex vp
            #pragma fragment fp

            float4 fp(v2f i) : SV_Target {
                float alpha = _Alpha; // tunning param for ellipse matrix
                float4 t = tex2D(_TFM, i.uv);

                int kernelRadius = _KernelSize / 2;
                float a = float((kernelRadius)) * clamp((alpha + t.w) / alpha, 0.1f, 2.0f); // ellipse major axis
                float b = float((kernelRadius)) * clamp(alpha / (alpha + t.w), 0.1f, 2.0f); // ellipse minor axis

                // angles to make the ellipse matrix
                // the t from the last pass are t-eigenvec (rg/xy), phi-change dir (b/z), and anisotropy (a/w)
                float cos_phi = cos(t.z);
                float sin_phi = sin(t.z);

                // matrix handling rotation, using phi
                float2x2 R = {cos_phi, -sin_phi,
                              sin_phi, cos_phi};
                
                // matrix handling axis scaling, using alpha and anisotropy
                float2x2 S = {0.5f / a, 0.0f,
                              0.0f, 0.5f / b};
                
                // complete matrix for controlling ellipse
                float2x2 SR = mul(S, R);

                // bounds of the ellipse to check pixels for
                int max_x = int(sqrt(a * a * cos_phi * cos_phi + b * b * sin_phi * sin_phi));
                int max_y = int(sqrt(a * a * sin_phi * sin_phi + b * b * cos_phi * cos_phi));

                // origin overlap of sectors, think how offset the parabola is to the center
                float zeta = _Zeta;

                float zeroCross = _ZeroCrossing;
                float sinZeroCross = sin(zeroCross);

                // boundary overlap of sectors, the higher eta is the more quickly the parabola weight curves towards the side
                float eta = (zeta + cos(zeroCross)) / (sinZeroCross * sinZeroCross);

                int sector;
                float4 m[8];
                float3 s[8];

                for (sector = 0; sector < _SectorCount; ++sector) {
                    m[sector] = 0.0f;
                    s[sector] = 0.0f;
                }

                // loop to calc the std deviation and avg color of all sectors within ellipse kernel
                [loop]
                for (int y = -max_y; y <= max_y; ++y) {
                    [loop]
                    for (int x = -max_x; x <= max_x; ++x) {

                        // map an actual point to filter space
                        float2 v = mul(SR, float2(x, y));

                        // making sure point after mapping is within kernel radius, else skip
                        if (dot(v, v) <= 0.25f) {
                           
                            // get corresponding texel and calculate
                            float3 color = tex2D(_MainTex, i.uv + float2(x, y) * _MainTex_TexelSize.xy).rgb;
                            color = saturate(color); // clamp input between 0 and 1

                            // polynomial weight calculations time wooooooo, similar to optimized general ver
                            float sum = 0;
                            float sector_weights[8];
                            float current_weight, vxx, vyy;

                            vxx = zeta - eta * v.x * v.x; // for sectors pointing up and down
                            vyy = zeta - eta * v.y * v.y; // for sectors pointing left and right

                            current_weight = max(0, v.y + vxx); // weight positive when pixel inside leaf / weight curve
                            sector_weights[0] = current_weight * current_weight; // top quardrant of kernel
                            sum += sector_weights[0];

                            current_weight = max(0, -v.x + vyy); // left quardrant of kernel
                            sector_weights[2] = current_weight * current_weight;
                            sum += sector_weights[2];

                            current_weight = max(0, -v.y + vxx); // bottom quardrant of kernel 
                            sector_weights[4] = current_weight * current_weight;
                            sum += sector_weights[4];

                            current_weight = max(0, v.x + vyy); // right quardrant of kernel
                            sector_weights[6] = current_weight * current_weight;
                            sum += sector_weights[6];

                            // recalculating weight modifiers for quardrants rotated 45deg
                            v = sqrt(2.0f) / 2.0f * float2(v.x - v.y, v.x + v.y);
                            vxx = zeta - eta * v.x * v.x;
                            vyy = zeta - eta * v.y * v.y;

                            current_weight = max(0, v.y + vxx); // north east quardrant
                            sector_weights[1] = current_weight * current_weight;
                            sum += sector_weights[1];

                            current_weight = max(0, -v.x + vyy); // south east quardrant
                            sector_weights[3] = current_weight * current_weight;
                            sum += sector_weights[3];

                            current_weight = max(0, -v.y + vxx); // south west quardrant
                            sector_weights[5] = current_weight * current_weight;
                            sum += sector_weights[5];

                            current_weight = max(0, v.x + vyy); // north west quardrant
                            sector_weights[7] = current_weight * current_weight;
                            sum += sector_weights[7];

                            float g = exp(-3.125f * dot(v,v)) / sum; // radial falloff for the weight

                            for (int sector = 0; sector < 8; ++sector) {
                                float wk = sector_weights[sector] * g;
                                m[sector] += float4(color * wk, wk);
                                s[sector] += color * color * wk;
                            }
                        }
                    }
                }

                // calculating the final color of the pixel
                float4 output = 0;
                for (sector = 0; sector < _SectorCount; ++sector) {
                    m[sector].rgb /= m[sector].w;
                    s[sector] = abs(s[sector] / m[sector].w - m[sector].rgb * m[sector].rgb);

                    float sigma2 = s[sector].r + s[sector].g + s[sector].b;
                    float w = 1.0f / (1.0f + pow(_Hardness * 1000.0f * sigma2, 0.5f * _Sharpness));

                    output += float4(m[sector].rgb * w, w);
                }

                return saturate(output / output.w);
            }

            ENDCG
        }
    }
}