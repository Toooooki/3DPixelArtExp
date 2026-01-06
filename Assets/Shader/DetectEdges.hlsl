#ifndef EDGE_DETECTION_INCLUDED
#define EDGE_DETECTION_INCLUDED
void DetectEdges_float(
    float2 UV, 
    float Width, 
    float Height, 
    float DepthThreshold, 
    float NormalThreshold, 
    out float ConvexEdge, 
    out float ConcaveEdge
)
{
    float2 texelSize = float2(1.0 / Width, 1.0 / Height);

    float2 offset[4] = {
        float2(0, texelSize.y),
        float2(0, -texelSize.y),
        float2(texelSize.x, 0),
        float2(-texelSize.x, 0)
    };

    // 【修正点】sampler_CameraNormalsTexture を sampler_CameraDepthTexture に変更
    // これで「未定義エラー」を回避しつつ、法線テクスチャ(_CameraNormalsTexture)を読み込めます
    float3 nC = _CameraNormalsTexture.Sample(sampler_CameraDepthTexture, UV).xyz;
    float dC = _CameraDepthTexture.Sample(sampler_CameraDepthTexture, UV).r;

    float convex = 0;
    float concave = 0;

    float dThresholdAdjusted = DepthThreshold * (1.0 + dC * 100.0); 

    for(int i = 0; i < 4; i++)
    {
        float2 uvN = UV + offset[i];
        
        // 【修正点】ここも同様に変更
        float3 nN = _CameraNormalsTexture.Sample(sampler_CameraDepthTexture, uvN).xyz;
        float dN = _CameraDepthTexture.Sample(sampler_CameraDepthTexture, uvN).r;
        
        float3 nDiff = nC - nN;
        float depthDelta = dC - dN;

        // 1. 深度差（シルエット）の判定
        if (abs(depthDelta) > dThresholdAdjusted)
        {
            concave += 1.0;
        }
        // 2. 法線差（内部の角）の判定
        else if (length(nDiff) > NormalThreshold)
        {
            if (dC > dN) 
            {
                convex += length(nDiff);
            }
            else 
            {
                concave += length(nDiff);
            }
        }
    }

    ConvexEdge = saturate(convex);
    ConcaveEdge = saturate(concave);
}
#endif