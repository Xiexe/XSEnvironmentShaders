Shader "Xiexe/Environment/Cutout_A2C"
{
	Properties
	{
        [Header(TRIPLANAR SETTINGS)]
        [Enum(UVs, 0, Triplanar World, 1, Triplanar Object, 2)]_TextureSampleMode("Texture Mode", Int) = 0
		_TriplanarFalloff("Triplanar Blend", Range(0,1)) = 1
        // _RotationAxes("Triplanar Rotation", Vector) = (0,0,0,0)

        [Header(MAIN)]
        _MainTex ("Main Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
        _Cutoff("Cutoff", Range(0,1)) = 0.5

        [Space(16)]
        [Header(NORMALS)]
        _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Normal Scale", Float) = 1
        
        [Space(16)]
        [Header(METALLIC)]
        _MetallicGlossMap("Metallic Map", 2D) = "white" {}
        _Metallic("Metallic", Range(0,1)) = 0
        _Glossiness("Smoothness", Range(0,1)) = 0

        [Space(16)]
        [Header(OCCLUSION)]
        _OcclusionMap("Occlusion Map", 2D) = "white" {}
        _OcclusionStrength("Occlusion Strength", Float) = 1

        [Space(16)]
        [Header(EMISSION)]
        _EmissionMap("Emission Map", 2D) = "white" {}
        [HDR]_EmissionColor("Emission Color", Color) = (0,0,0,1)

        [Space(16)]
        [Header(LIGHTMAPPING HACKS)]
        _SpecularLMOcclusion("Specular Occlusion", Range(0,1)) = 0
        _SpecLMOcclusionAdjust("Spec Occlusion Sensitiviy", Range(0,1)) = 0.2

        _LMStrength("Lightmap Strength", Range(0,1)) = 1
        _RTLMStrength("Realtime Lightmap Strength", Range(0,1)) = 1

    }
	SubShader
	{
		Tags { "Queue"="AlphaTest" }

		Pass
		{
            Tags {"LightMode"="ForwardBase"}
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdbase 
            #pragma multi_compile_fog
            #define alphaToMask

            #ifndef UNITY_PASS_FORWARDBASE
                #define UNITY_PASS_FORWARDBASE
            #endif
			
			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float2 uv2 : TEXCOORD2;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
			};

			struct v2f
			{
                float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
                centroid float2 uv1 : TEXCOORD1;
                centroid float2 uv2 : TEXCOORD2;
                float3 btn[3] : TEXCOORD3; //TEXCOORD2, TEXCOORD3 | bitangent, tangent, worldNormal
                float3 worldPos : TEXCOORD6;
                float3 objPos : TEXCOORD7;
                float3 objNormal : TEXCOORD8;
                SHADOW_COORDS(9)
                UNITY_FOG_COORDS(10)
			};

            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
			#include "VertFrag.cginc"
			
			ENDCG
		}

        Pass
		{
            Tags {"LightMode"="ForwardAdd"}
            Blend One One
            ZWrite Off
            
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            #define alphaToMask
            
            #ifndef UNITY_PASS_FORWARDADD
                #define UNITY_PASS_FORWARDADD
            #endif

			#include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            
			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
			};

			struct v2f
			{
                float4 pos : SV_POSITION;
				centroid float2 uv : TEXCOORD0;
                centroid float3 btn[3] : TEXCOORD1; //TEXCOORD2, TEXCOORD3 | bitangent, tangent, worldNormal
                float3 worldPos : TEXCOORD4;
                float3 objPos : TEXCOORD5;
                float3 objNormal : TEXCOORD6;
                SHADOW_COORDS(7)
                UNITY_FOG_COORDS(8)
			};

            #include "Defines.cginc"
            #include "LightingFunctions.cginc"
			#include "VertFrag.cginc"
			
			ENDCG
		}

        Pass
        {
            Tags{"LightMode" = "ShadowCaster"} //Removed "DisableBatching" = "True". If issues arise re-add this.
            Cull Off
            CGPROGRAM
            #include "UnityCG.cginc" 
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #define alphaToMask
            
            #ifndef UNITY_PASS_SHADOWCASTER
                #define UNITY_PASS_SHADOWCASTER
            #endif
            
            struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float3 tangent : TANGENT;
			};

			struct v2f
			{
                float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};

            #include "Defines.cginc"
            #include "VertFrag.cginc"
            ENDCG
        }

        Pass
        {
            Name "META"
            Tags {"LightMode"="Meta"}
            Cull Off
            CGPROGRAM
  
            #ifndef UNITY_PASS_META
                #define UNITY_PASS_META
            #endif

            #include"UnityStandardMeta.cginc"
            #include "Defines.cginc"
            #include "VertFrag.cginc"

            ENDCG
        }

	}
}