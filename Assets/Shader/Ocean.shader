Shader "Poseidon/Ocean"
{
    Properties
    {
        _OceanColor ("Color", Color) = (0.0429,0.17578,0.390,1)
        _Normal ("Normal", 2D) = "black" { }
        _Gradient ("Gradient", 2D) = "black" { }
    	_Spray("Spray",2D) = "White"{}
    	
    	_SpraySpeed("SpraySpeed",float) = 1
    	_SprayEdge("SprayEdge",float) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" }
		LOD 100
		Blend SrcAlpha OneMinusSrcAlpha 
        
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
                float4 projPos:TEXCOORD2;
            };

            sampler2D _Normal;
            sampler2D _Displace;
            sampler2D _Spray;

            float _SpraySpeed;
            float _SprayEdge;
            
            float4 _Displace_ST;
            float4 _FoamTex_ST;

            fixed4 cosine_gradient(float x,  fixed4 phase, fixed4 amp, fixed4 freq, fixed4 offset)
            {
				const float TAU = 2. * 3.14159265;
  				phase *= TAU;
  				x *= TAU;

  				return fixed4(
    				offset.r + amp.r * 0.5 * cos(x * freq.r + phase.r) + 0.5,
    				offset.g + amp.g * 0.5 * cos(x * freq.g + phase.g) + 0.5,
    				offset.b + amp.b * 0.5 * cos(x * freq.b + phase.b) + 0.5,
    				offset.a + amp.a * 0.5 * cos(x * freq.a + phase.a) + 0.5
  				);
			}
            
            float2 rand(float2 st, int seed)
			{
				float2 s = float2(dot(st, float2(127.1, 311.7)) + seed, dot(st, float2(269.5, 183.3)) + seed);
				return -1 + 2 * frac(sin(s) * 43758.5453123);
			}

            float noise(float2 st, int seed)
			{
				st.y += _Time[1];

				float2 p = floor(st);
				float2 f = frac(st);
 
				float w00 = dot(rand(p, seed), f);
				float w10 = dot(rand(p + float2(1, 0), seed), f - float2(1, 0));
				float w01 = dot(rand(p + float2(0, 1), seed), f - float2(0, 1));
				float w11 = dot(rand(p + float2(1, 1), seed), f - float2(1, 1));
				
				float2 u = f * f * (3 - 2 * f);
 
				return lerp(lerp(w00, w10, u.x), lerp(w01, w11, u.x), u.y);
			}

            float3 swell(float3 pos , float anisotropy){
            	// 生成的高度
				float height = noise(pos.xz * 0.1,0);
				height *= anisotropy;
            	// float3 swelledNormal = normalize(cross(ddy(pos),ddx(pos)));
				float3 swelledNormal = normalize(
					cross (
						// z方向，理解成对不同轴进行偏导数然后向量相加
						float3(0,ddy(height),1),
						// x方向
						float3(1,ddx(height),0)
					)
				);
				return swelledNormal;
			}

             v2f vert(appdata v)
             {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv, _Displace);
                float4 displace = tex2Dlod(_Displace, float4(o.uv, 0.0, 0.0));
                v.vertex += float4(displace.x,displace.y,displace.z, 0.0);
                o.pos = UnityObjectToClipPos(v.vertex);
                 
                o.projPos = ComputeScreenPos(o.pos);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

            	COMPUTE_EYEDEPTH(o.projPos.z);
                return o;
            }

            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            
             fixed4 frag(v2f i): SV_Target
             {
                const fixed4 phases = fixed4(0.28, 0.50, 0.07, 0.);
				const fixed4 amplitudes = fixed4(4.02, 0.34, 0.65, 0.);
				const fixed4 frequencies = fixed4(0.00, 0.48, 0.08, 0.);
				const fixed4 offsets = fixed4(0.00, 0.16, 0.00, 0.);
    
             	fixed3 color;
    
             	// 水深效果
             	// 读取写入的深度，因为水是半透明物体，所以写入的是水底的深度
             	float sceneZ = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.projPos)));
             	// 读出水面的深度，直接读的水面点的深度，所以是水面的深度
				float partZ = i.projPos.z;
             	float diffZ = sceneZ - partZ;
				float volmeZ = saturate(diffZ / 5.0f);
    
				fixed4 cos_grad = cosine_gradient(1.5-volmeZ, phases, amplitudes, frequencies, offsets);
  				cos_grad = clamp(cos_grad, 0., 1.);
  				color.rgb = cos_grad.rgb;
    
    			half3 worldViewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    			fixed3 worldNormal = UnityObjectToWorldNormal(tex2D(_Normal, i.uv).rgb);
    	
				// float3 v = i.worldPos - _WorldSpaceCameraPos;
				// float anisotropy = saturate(1/(ddy(length ( v.xz )))/5);
				// float3 swelledNormal = swell(i.worldPos , anisotropy);
             	float3 swelledNormal = worldNormal;
             	
				// 反射光
                half3 reflDir = reflect(-worldViewDir, swelledNormal);
             	fixed4 reflectionColor = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflDir, 0);
    
             	color = lerp(color , reflectionColor , reflDir);
    
             	// float height = i.projPos.y;
             	float height = noise(i.worldPos.xz * 0.1,0);
             	
             	//岸边浪花
                i.uv.y -= _Time.x * _SpraySpeed;
                fixed4 foamTexCol = tex2D(_Spray,i.uv);
                fixed4 foamCol = saturate((0.8-height) * (foamTexCol.r +foamTexCol.g)* diffZ) * step(diffZ,_SprayEdge);
                foamCol = step(0.5,foamCol);
                color += foamCol;
    
             	// 菲涅尔
             	float f0 = 0.02;
    			float vReflect = f0 + (1-f0) * pow((1 - dot(worldViewDir,swelledNormal)),5);
				vReflect = saturate(vReflect * 2.0);
    
    			color = lerp(color , reflectionColor , vReflect);
    
                // fixed3 worldLightDir = normalize(_WorldSpaceLightPos0);
                // fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                // fixed3 worldHalfViewDir = normalize(worldLightDir + worldViewDir);
             	  //
                //   fixed4 screenPos = ComputeScreenPos(i.pos);
                //  fixed4 screenPosNDC = screenPos / screenPos.w;
                //
                //  float depth = tex2D(_CameraDepthTexture,screenPosNDC.xy).r;
                //  
                //  half oDepthInViewSpace = LinearEyeDepth(depth);
                //  half tDepthInViewSpace = LinearEyeDepth(screenPosNDC.z);
                //
                //  half deltaDepthInViewSpace = oDepthInViewSpace - tDepthInViewSpace;
                 
                 // float NDotV = max(0.0f,dot(worldHalfViewDir,worldNormal));
                 // float NDotL = max(0.0f,dot(worldNormal,worldLightDir));
                 // fixed3 diffuse = _LightColor0.rgb * depthColor * saturate(dot(worldLightDir,worldNormal));
                 // fixed3 specular = pow(NDotV,_SpecularGloss) * _SpecularPower;
                 // fixed3 ambient = depthColor * UNITY_LIGHTMODEL_AMBIENT.xyz;
    
                 //深度 控制 颜色
			    // half water_w = min(_Range.w, deltaDepthInViewSpace)/_Range.w; 
    
                 // fixed3 color = NDotL * diffuse + specular;
                 // color * ambient;
    
                 return fixed4(color,volmeZ);
             }

           
           
            ENDCG
        }
    }
}
