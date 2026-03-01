Shader "Hidden/ToonShading"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ColorSteps ("Color Steps", Float) = 4.0
        _ColorSmoothing ("Color Smoothing", Float) = 0.05
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "ToonShading"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            float _ColorSteps;
            float _ColorSmoothing;

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);

                // RGB → HSV 変換
                float3 rgb = color.rgb;
                float cmax = max(rgb.r, max(rgb.g, rgb.b));
                float cmin = min(rgb.r, min(rgb.g, rgb.b));
                float delta = cmax - cmin;

                // Hue
                float hue = 0.0;
                if (delta > 0.0001)
                {
                    if (cmax == rgb.r)
                        hue = fmod((rgb.g - rgb.b) / delta + 6.0, 6.0) / 6.0;
                    else if (cmax == rgb.g)
                        hue = ((rgb.b - rgb.r) / delta + 2.0) / 6.0;
                    else
                        hue = ((rgb.r - rgb.g) / delta + 4.0) / 6.0;
                }

                // Saturation
                float sat = (cmax > 0.0001) ? delta / cmax : 0.0;

                // Value（明度）を段階化
                float val = cmax;
                float quantizedVal = floor(val * _ColorSteps + 0.5) / _ColorSteps;

                // 彩度も軽く段階化
                float quantizedSat = floor(sat * (_ColorSteps * 0.5) + 0.5) / (_ColorSteps * 0.5);

                // HSV → RGB 変換
                float h = hue * 6.0;
                float c = quantizedVal * quantizedSat;
                float x = c * (1.0 - abs(fmod(h, 2.0) - 1.0));
                float m = quantizedVal - c;

                float3 result;
                if      (h < 1.0) result = float3(c, x, 0);
                else if (h < 2.0) result = float3(x, c, 0);
                else if (h < 3.0) result = float3(0, c, x);
                else if (h < 4.0) result = float3(0, x, c);
                else if (h < 5.0) result = float3(x, 0, c);
                else              result = float3(c, 0, x);
                result += m;

                return half4(result, color.a);
            }
            ENDHLSL
        }
    }
}