using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PixelPerfectCamera : MonoBehaviour
{
    [SerializeField] private int PPU = 32; // Pixels Per Unit
    [SerializeField] private int VerticalResolution = 360;
    private Camera _cam;
    // Start is called before the first frame update
    void OnEnable()
    {
        _cam = GetComponent<Camera>();
        RenderPipelineManager.beginCameraRendering += OnBeginCameraRendering;
        RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
    }

    void OnDisable()
    {
        RenderPipelineManager.beginCameraRendering -= OnBeginCameraRendering;
        RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;
    }

    void OnBeginCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (camera != _cam) return;

        camera.orthographic = true; //平行投影に設定
        camera.orthographicSize = (float)VerticalResolution / (PPU * 2.0f);

        float pixelSize = 1.0f / PPU;
        Vector3 parentPos = transform.parent ? transform.parent.position : transform.position;
        // 本来の位置に近い「グリッド上の点」を計算
        float snappedX = Mathf.Round(parentPos.x / pixelSize) * pixelSize;
        float snappedY = Mathf.Round(parentPos.y / pixelSize) * pixelSize;
        float snappedZ = Mathf.Round(parentPos.z / pixelSize) * pixelSize;

        // カメラをスナップ位置に移動
        transform.position = new Vector3(snappedX, snappedY, snappedZ);

        // 3. サブピクセルシフト（滑らかさを出すためのズレ補正）
        // スナップで切り捨てられた「小数点以下の移動量」を計算
        Vector3 subPixelOffset = parentPos - transform.position;

        // 投影行列をずらして、見た目だけ滑らかに戻す
        Matrix4x4 m = camera.projectionMatrix;
        m.m03 += subPixelOffset.x * (2.0f * PPU / VerticalResolution * (float)Screen.height / Screen.width); // アスペクト比考慮が必要な場合あり
        m.m13 += subPixelOffset.y * (2.0f * PPU / VerticalResolution);
        camera.projectionMatrix = m;
    }

    // レンダリング後にリセット（エディタの挙動をおかしくしないため）
    void OnEndCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (camera != _cam) return;
        camera.ResetProjectionMatrix();
    }
}
