Shader "Poseidon/Ocean"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Displace ("Displace", 2D) = "black" { }
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
                
            #include "UnityCG.cginc"
            
             struct appdata
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
            };
            
            struct v2f
            {
                float4 pos: SV_POSITION;
                float2 uv: TEXCOORD0;
                float3 worldPos: TEXCOORD1;
            };

            sampler2D _MainTex;
            sampler2D _Displace;
            float4 _Displace_ST;

             v2f vert(appdata v)
             {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _Displace);
                float4 displace = tex2Dlod(_Displace, float4(o.uv, 0, 0));
                v.vertex += float4(0.0f,displace.y,0.0f, 0);
                o.pos = UnityObjectToClipPos(v.vertex);
                
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

             fixed4 frag(v2f i): SV_Target
             {
                return fixed4(0.0429f,0.17578f,0.390f, 1);
             }
           
            ENDCG
        }
    }
}
