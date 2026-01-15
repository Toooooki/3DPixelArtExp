using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

// 法線テクスチャの生成を強制するだけの機能
public class ForceNormalsFeature : ScriptableRendererFeature
{
    class NormalsPass : ScriptableRenderPass
    {
        // 何もしないパスだが、入力として法線を要求する
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            ConfigureInput(ScriptableRenderPassInput.Normal);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData) { }
    }

    NormalsPass m_Pass;

    public override void Create()
    {
        m_Pass = new NormalsPass();
        m_Pass.renderPassEvent = RenderPassEvent.BeforeRenderingTransparents;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_Pass);
    }
}