using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PixelPerfectCamera : MonoBehaviour
{
    [SerializeField] private int PPU = 32; // Pixels Per Unit
    [SerializeField] private int VerticalResolution = 360;
    private Camera _cam;

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

        float pixelSize = 1.0f / PPU;
        Vector3 parentPos = transform.parent ? transform.parent.position : transform.position;

        // 本来の位置に近い「グリッド上の点」を計算
        float snappedX = Mathf.Round(parentPos.x / pixelSize) * pixelSize;
        float snappedY = Mathf.Round(parentPos.y / pixelSize) * pixelSize;
        float snappedZ = Mathf.Round(parentPos.z / pixelSize) * pixelSize;

        // カメラをスナップ位置に移動
        transform.position = new Vector3(snappedX, snappedY, snappedZ);

        // スナップで切り捨てられた「小数点以下の移動量」を計算
        Vector3 subPixelOffset = parentPos - transform.position;

        // Perspective 用のサブピクセルシフト
        // NDC空間でのオフセットを計算
        Matrix4x4 m = camera.projectionMatrix;

        // Perspective の場合: m[0][0] = 2n/(r-l), m[1][1] = 2n/(t-b)
        // スクリーン上の1ピクセル分のNDCオフセットを算出
        float screenWidth = Screen.width;
        float screenHeight = Screen.height;

        // ワールド空間のオフセットをビュー空間に変換
        Vector3 viewOffset = camera.worldToCameraMatrix.MultiplyVector(subPixelOffset);

        // ビュー空間のオフセットをNDC空間に変換（Perspective投影考慮）
        // near plane上での比率として適用
        m.m02 += viewOffset.x * m.m00;
        m.m12 += viewOffset.y * m.m11;

        camera.projectionMatrix = m;
    }

    // レンダリング後にリセット（エディタの挙動をおかしくしないため）
    void OnEndCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (camera != _cam) return;
        camera.ResetProjectionMatrix();
    }
}