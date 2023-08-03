Shader "Poseidon/Ocean"
{
    Properties
    {
        _OceanColor ("Color", Color) = (0.0429,0.17578,0.390,1)
        _Normal ("Normal", 2D) = "black" { }
        _Displace ("Displace", 2D) = "black" { }
        _Gradient ("Gradient", 2D) = "black" { }
        _SpecularGloss ("SpecularGloss",float) = 2.0
        _SpecularPower ("SpecularPower",float) = 10.0
        _Range ("Range",vector) = (0.13, 1.53, 0.37, 0.78)
    }
    SubShader
    {
        Tags 
		{ 
		    "RenderType"="Transparent"
		    "Queue"="Transparent"
		}
        
        LOD 100
        Cull off
        
        GrabPass{}
        
        zwrite off

        Pass
        {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
                
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            
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

            sampler2D _Normal;
            sampler2D _Displace;
            sampler2D _Gradient;
            
            sampler2D _CameraDepthTexture;
            
            float _SpecularGloss;
            float _SpecularPower;
            float4 _Range;
            
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
                fixed3 worldNormal = UnityObjectToWorldNormal(tex2D(_Normal, i.uv).rgb);
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0);
                fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 worldHalfViewDir = normalize(worldLightDir + worldViewDir);

                  fixed4 screenPos = ComputeScreenPos(i.pos);
                 fixed4 screenPosNDC = screenPos / screenPos.w;

                 float depth = tex2D(_CameraDepthTexture,screenPosNDC.xy).r;
                 
                 half oDepthInViewSpace = LinearEyeDepth(depth);
                 half tDepthInViewSpace = LinearEyeDepth(screenPosNDC.z);

                 half deltaDepthInViewSpace = oDepthInViewSpace - tDepthInViewSpace;
                 fixed3 depthColor = tex2D(_Gradient,float2(sin(min(_Range.y,deltaDepthInViewSpace) / _Range.y),1.0));
                 
                 float NDotV = max(0.0f,dot(worldHalfViewDir,worldNormal));
                 float NDotL = max(0.0f,dot(worldNormal,worldLightDir));
                 fixed3 diffuse = _LightColor0.rgb * depthColor * saturate(dot(worldLightDir,worldNormal));
                 fixed3 specular = pow(NDotV,_SpecularGloss) * _SpecularPower;
                 fixed3 ambient = depthColor * UNITY_LIGHTMODEL_AMBIENT.xyz;

                 //深度 控制 颜色
			    // half water_w = min(_Range.w, deltaDepthInViewSpace)/_Range.w;  

                 fixed3 color = NDotL * diffuse + specular;
                 color * ambient;

                 fixed alpha = min(_Range.x,deltaDepthInViewSpace) / _Range.x;
                 return fixed4(color,alpha);
             }
           
            ENDCG
        }
    }
}
