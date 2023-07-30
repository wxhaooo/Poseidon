using JetBrains.Annotations;
using UnityEngine;

namespace Ocean
{
    public static class RenderExtend
    {
        //创建渲染纹理
        // public static bool CreateRT(this RenderTexture rt, int size, RenderTextureFormat format)
        // {
        //     if (rt != null && rt.IsCreated())
        //         rt.Release();
        //
        //     rt = new RenderTexture(size, size, 0, format);
        //     rt.enableRandomWrite = true;
        //     return rt.Create();
        // }
    }

    public static class RenderHelper
    {
        public static RenderTexture CreateRT(int size, RenderTextureFormat format)
        {
            RenderTexture rt = new RenderTexture(size, size, 0, format);
            rt.enableRandomWrite = true;
            rt.Create();
            return rt;
        }

        // public static void SwapTexture(RenderTexture rtIn, RenderTexture rtOut)
        // {
        //     Graphics.CopyTexture(rtOut, rtIn);
        // }
        
        public static Texture2D GetRTPixels(RenderTexture rt)
        {
            // Remember currently active render texture
            RenderTexture currentActiveRT = RenderTexture.active;

            // Set the supplied RenderTexture as the active one
            RenderTexture.active = rt;

            // Create a new Texture2D and read the RenderTexture image into it
            Texture2D tex = new Texture2D(rt.width, rt.height);
            tex.ReadPixels(new Rect(0, 0, tex.width, tex.height), 0, 0);

            // Restorie previously active render texture
            RenderTexture.active = currentActiveRT;
            return tex;
        }
    }
}