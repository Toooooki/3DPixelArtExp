Shader "Hidden/OutlinesFixed"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineScale ("Outline Scale", Float) = 1.0
        _DepthThreshold ("Depth Threshold", Float) = 0.1
        _RobertsCrossMultiplier ("Depth Multiplier", Float) = 10.0
        _NormalThreshold ("Normal Threshold", Float) = 0.4
        _SteepAngleThreshold ("Steep Angle Threshold", Float) = 0.3
        _SteepAngleMultiplier ("Steep Angle Multiplier", Float) = 0.0
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Name "OutlinesFixed"
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

            TEXTURE2D(_SceneViewSpaceNormals);
            SAMPLER(sampler_SceneViewSpaceNormals);

            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);

            float4 _OutlineColor;
            float _OutlineScale;
            float _DepthThreshold;
            float _RobertsCrossMultiplier;
            float _NormalThreshold;
            float _SteepAngleThreshold;
            float _SteepAngleMultiplier;

            float SampleRawDepth(float2 uv)
            {
                return SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uv).r;
            }

            float GetLinearDepth(float rawDepth)
            {
                return Linear01Depth(rawDepth, _ZBufferParams);
            }

            bool IsSkybox(float rawDepth)
            {
                #if UNITY_REVERSED_Z
                    return rawDepth < 0.0001;
                #else
                    return rawDepth > 0.9999;
                #endif
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 texelSize = float2(1.0 / _ScreenParams.x, 1.0 / _ScreenParams.y);
                float2 o = texelSize * _OutlineScale;

                // ===== Sobel 用 9点サンプル =====
                //  TL  T  TR
                //  L   C  R
                //  BL  B  BR

                float2 uvTL = IN.uv + float2(-o.x,  o.y);
                float2 uvT  = IN.uv + float2( 0.0,  o.y);
                float2 uvTR = IN.uv + float2( o.x,  o.y);
                float2 uvL  = IN.uv + float2(-o.x,  0.0);
                float2 uvC  = IN.uv;
                float2 uvR  = IN.uv + float2( o.x,  0.0);
                float2 uvBL = IN.uv + float2(-o.x, -o.y);
                float2 uvB  = IN.uv + float2( 0.0, -o.y);
                float2 uvBR = IN.uv + float2( o.x, -o.y);

                // ===== 深度: 9点サンプル → 線形化 =====
                float rawTL = SampleRawDepth(uvTL);
                float rawT  = SampleRawDepth(uvT);
                float rawTR = SampleRawDepth(uvTR);
                float rawL  = SampleRawDepth(uvL);
                float rawC  = SampleRawDepth(uvC);
                float rawR  = SampleRawDepth(uvR);
                float rawBL = SampleRawDepth(uvBL);
                float rawB  = SampleRawDepth(uvB);
                float rawBR = SampleRawDepth(uvBR);

                // Skybox 境界検出
                int skyCount = (int)IsSkybox(rawTL) + (int)IsSkybox(rawT) + (int)IsSkybox(rawTR)
                             + (int)IsSkybox(rawL)  + (int)IsSkybox(rawR)
                             + (int)IsSkybox(rawBL) + (int)IsSkybox(rawB) + (int)IsSkybox(rawBR);
                bool skyCenter = IsSkybox(rawC);
                float skyEdge = (!skyCenter && skyCount > 0) || (skyCenter && skyCount < 8) ? 1.0 : 0.0;

                float dTL = GetLinearDepth(rawTL);
                float dT  = GetLinearDepth(rawT);
                float dTR = GetLinearDepth(rawTR);
                float dL  = GetLinearDepth(rawL);
                float dC  = GetLinearDepth(rawC);
                float dR  = GetLinearDepth(rawR);
                float dBL = GetLinearDepth(rawBL);
                float dB  = GetLinearDepth(rawB);
                float dBR = GetLinearDepth(rawBR);

                // Sobel フィルタ
                // 横方向 (Gx): 右 - 左
                float sobelX = (-1.0 * dTL + 1.0 * dTR
                              + -2.0 * dL  + 2.0 * dR
                              + -1.0 * dBL + 1.0 * dBR);

                // 縦方向 (Gy): 上 - 下
                float sobelY = (-1.0 * dTL + -2.0 * dT + -1.0 * dTR
                              +  1.0 * dBL +  2.0 * dB +  1.0 * dBR);

                float depthEdge = sqrt(sobelX * sobelX + sobelY * sobelY);

                // 中心深度で正規化（距離に依存しない）
                float depthScale = max(dC, 0.0001);
                depthEdge = (depthEdge / depthScale) * _RobertsCrossMultiplier;
                depthEdge = depthEdge > _DepthThreshold ? 1.0 : 0.0;
                depthEdge = max(depthEdge, skyEdge);

                // ===== 法線: Sobel =====
                float3 nTL = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvTL).rgb;
                float3 nT  = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvT).rgb;
                float3 nTR = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvTR).rgb;
                float3 nL  = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvL).rgb;
                float3 nR  = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvR).rgb;
                float3 nBL = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvBL).rgb;
                float3 nB  = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvB).rgb;
                float3 nBR = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvBR).rgb;

                float3 nSobelX = -1.0 * nTL + 1.0 * nTR
                               + -2.0 * nL  + 2.0 * nR
                               + -1.0 * nBL + 1.0 * nBR;

                float3 nSobelY = -1.0 * nTL + -2.0 * nT + -1.0 * nTR
                               +  1.0 * nBL +  2.0 * nB +  1.0 * nBR;

                float normalEdge = sqrt(dot(nSobelX, nSobelX) + dot(nSobelY, nSobelY));
                normalEdge = normalEdge > _NormalThreshold ? 1.0 : 0.0;

                // Steep Angle 補正
                float3 centerNormal = SAMPLE_TEXTURE2D(_SceneViewSpaceNormals, sampler_SceneViewSpaceNormals, uvC).rgb;
                float viewAngle = abs(centerNormal.z);
                float steepMask = smoothstep(_SteepAngleThreshold - 0.1, _SteepAngleThreshold + 0.2, viewAngle);
                normalEdge *= steepMask;

                // ===== 合成 =====
                float outline = saturate(max(depthEdge, normalEdge));

                half4 sceneColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                half4 finalColor = lerp(sceneColor, _OutlineColor, outline);

                return finalColor;
            }
            ENDHLSL
        }
    }
}