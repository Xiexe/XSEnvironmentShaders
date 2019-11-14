sampler2D _MainTex; float4 _MainTex_ST;
sampler2D _MetallicGlossMap; float4 _MetallicGlossMap_ST;
sampler2D _BumpMap; float4 _BumpMap_ST;
sampler2D _EmissionMap; float4 _EmissionMap_ST;
float4 _EmissionColor;
float4 _Color;
float _Metallic;
float _Glossiness;
float _BumpScale;

float _GILightmapScalar;
float _SpecularLMOcclusion;
float _SpecLMOcclusionAdjust;
float _TriplanarFalloff;
float _LMStrength;
float _RTLMStrength;
int _TextureSampleMode;