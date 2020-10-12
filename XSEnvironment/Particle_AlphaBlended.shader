Shader "Xiexe/Environment/Particle_AlphaBlended"
{
    Properties
    {
        [HDR]_Color("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        _Mask("Texture Mask", 2D) = "white" {} 
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite off
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 randomStableVector : TEXCOORD1;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 color : COLOR;
                float2 uv : TEXCOORD0;
                float2 randomStableVector : TEXCOORD1;
                UNITY_FOG_COORDS(2)
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            sampler2D _Mask;
            float4 _Mask_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.color = v.color;
                o.randomStableVector = v.randomStableVector;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {   
                float offset = 0;
                float2 uv = i.uv * _MainTex_ST.xy + (_MainTex_ST.zw + i.randomStableVector);
                fixed4 col = tex2D(_MainTex, uv + _Time.y * -0.2);
                fixed4 col1 = tex2D(_MainTex, uv * 0.5 + _Time.y * -0.1);
                fixed4 col2 = tex2D(_MainTex, uv + _Time.y * -0.3);
                float alpha = col * col1 * col2 * 3;
                fixed4 particleColor = i.color * _Color;
                particleColor.a = tex2D(_Mask, i.uv * _Mask_ST.xy + _Mask_ST.zw).x * alpha * i.color.a;

                UNITY_APPLY_FOG(i.fogCoord, particleColor);
                return particleColor;
            }
            ENDCG
        }
    }
}
