Shader "Poseidon/Ocean"
{
    Properties
    {
        _OceanColor ("Color", Color) = (0.0429,0.17578,0.390,1)
        _Normal ("Normal", 2D) = "black" { }
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

            fixed4 _OceanColor;
            sampler2D _MainTex;
            sampler2D _Displace;
            sampler2D _Normal;
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
                fixed3 normal = UnityObjectToWorldNormal(tex2D(_Normal, i.uv).rgb);
                 fixed3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 reflectDir = reflect(-viewDir, normal);

                fixed3 oceanDiffuse = _OceanColor * saturate(dot(lightDir, normal));
                 
                return fixed4(oceanDiffuse,1.0f);
             }
           
            ENDCG
        }
    }
}
