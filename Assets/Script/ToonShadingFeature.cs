using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class ToonShadingFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        public Shader toonShader;
        [Range(2, 16)]
        public int colorSteps = 4;
        [Range(0.0f, 0.2f)]
        public float colorSmoothing = 0.05f;
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public Settings settings = new Settings();
    private ToonShadingPass _pass;
    private Material _material;

    public override void Create()
    {
        if (settings.toonShader == null) return;
        _material = CoreUtils.CreateEngineMaterial(settings.toonShader);
        _pass = new ToonShadingPass(_material, settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (_material == null) return;
        _pass.renderPassEvent = settings.renderPassEvent;
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(_material);
    }

    class ToonShadingPass : ScriptableRenderPass
    {
        private Material _material;
        private Settings _settings;
        private RenderTargetHandle _tempTexture;

        public ToonShadingPass(Material material, Settings settings)
        {
            _material = material;
            _settings = settings;
            _tempTexture.Init("_TempToonTexture");
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_material == null) return;

            CommandBuffer cmd = CommandBufferPool.Get("ToonShading");

            RenderTargetIdentifier source = renderingData.cameraData.renderer.cameraColorTarget;
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            cmd.GetTemporaryRT(_tempTexture.id, desc);

            _material.SetFloat("_ColorSteps", _settings.colorSteps);
            _material.SetFloat("_ColorSmoothing", _settings.colorSmoothing);

            cmd.Blit(source, _tempTexture.Identifier(), _material);
            cmd.Blit(_tempTexture.Identifier(), source);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(_tempTexture.id);
        }
    }
}