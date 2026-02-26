using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PixelizeFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class Settings
    {
        [Header("ピクセル化解像度（ドット絵の解像度）")]
        public int pixelWidth = 320;
        public int pixelHeight = 180;

        [Header("実行タイミング")]
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public Settings settings = new Settings();
    private PixelizePass _pass;
    private Material _material;

    public override void Create() //初期化
    {
        _material = CoreUtils.CreateEngineMaterial(Shader.Find("Hidden/Pixelize"));
        _pass = new PixelizePass(_material, settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) //毎フレーム呼び出される。レンダラーにパスを追加する。
    {
        if (_material == null) return;
        _pass.renderPassEvent = settings.renderPassEvent;
        renderer.EnqueuePass(_pass);
    }

    protected override void Dispose(bool disposing)
    {
        CoreUtils.Destroy(_material);
    }

    class PixelizePass : ScriptableRenderPass
    {
        private Material _material;
        private Settings _settings;
        private RenderTargetIdentifier _source;
        private RenderTargetHandle _tempTexture;

        public PixelizePass(Material material, Settings settings)
        {
            _material = material;
            _settings = settings;
            _tempTexture.Init("_TempPixelizeTexture");
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            _source = renderingData.cameraData.renderer.cameraColorTarget;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (_material == null) return;

            CommandBuffer cmd = CommandBufferPool.Get("Pixelize");

            // ピクセル数をシェーダーに渡す
            _material.SetVector("_PixelCount",
                new Vector2(_settings.pixelWidth, _settings.pixelHeight));

            // 一時テクスチャを取得（元の解像度）
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            cmd.GetTemporaryRT(_tempTexture.id, desc);

            // ピクセル化シェーダーを適用
            cmd.Blit(_source, _tempTexture.Identifier(), _material);
            cmd.Blit(_tempTexture.Identifier(), _source);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(_tempTexture.id);
        }
    }
}