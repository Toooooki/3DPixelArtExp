Shader "Hidden/Pixelize"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "Pixelize"
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
            SAMPLER(sampler_point_clamp);  // Point フィルタ！重要
            float2 _PixelCount;            // (320, 180) など

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                // UV をグリッドにスナップ
                float2 snappedUV = floor(IN.uv * _PixelCount + 0.5) / _PixelCount;

                // スナップしたUVでサンプリング（Point フィルタ）
                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_point_clamp, snappedUV);

                return color;
            }
            ENDHLSL
        }
    }
}