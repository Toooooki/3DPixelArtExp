#ifndef LINEARIZE_DEPTH_INCLUDED
#define LINEARIZE_DEPTH_INCLUDED

void LinearizeDepth_float(float RawDepth, float FarPlane, out float LinearDepth)
{
    // Scene Depth (Eye) と同等の処理
    // ビルトイン変数を使わないバージョン
    #if UNITY_REVERSED_Z
        RawDepth = 1.0 - RawDepth;
    #endif
    
    // 0-1に正規化
    LinearDepth = RawDepth / FarPlane;
}

#endif