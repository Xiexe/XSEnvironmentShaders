//This file contains the vertex and fragment functions for both the ForwardBase and Forward Add pass.
v2f vert (appdata v)
{
    v2f o;
    float3 worldNormal = UnityObjectToWorldNormal(v.normal);
    float3 tangent = UnityObjectToWorldDir(v.tangent);
    float3 bitangent = cross(tangent, worldNormal);

    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv = v.uv;
    
    #if !defined(UNITY_PASS_SHADOWCASTER)
        #if !defined(UNITY_PASS_FORWARDADD)
            o.uv1 = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
            o.uv2 = v.uv2;
        #endif

        o.btn[0] = bitangent;
        o.btn[1] = tangent;
        o.btn[2] = worldNormal;
        o.worldPos = mul(unity_ObjectToWorld, v.vertex);
        o.objPos = v.vertex;
        o.objNormal = v.normal;
        
        UNITY_TRANSFER_SHADOW(o, o.uv);
        UNITY_TRANSFER_FOG(o,o.pos);
    #else
        TRANSFER_SHADOW_CASTER_NOPOS(o, o.pos);
    #endif

    return o;
}
			
fixed4 frag (v2f i) : SV_Target
{
    //Return only this if in the shadowcaster
    #if defined(UNITY_PASS_SHADOWCASTER)
        if(_CastShadowsToLightmap == 1)
        {
            #if defined(alphaToMask) 
                float4 albedo = tex2D(_MainTex, i.uv) * _Color;
                clip(albedo.a - _Cutoff);
            #endif

            #if defined(alphablend)
                float4 albedo = tex2D(_MainTex, i.uv) * _Color;
            #endif
        }
        SHADOW_CASTER_FRAGMENT(i);
        
    #elif defined(UNITY_PASS_META)
        UnityMetaInput o;
        UNITY_INITIALIZE_OUTPUT(UnityMetaInput, o);
        o.Albedo = texTP(_MainTex, _MainTex_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv) * _Color;
        o.Albedo.a = 0;
        o.Emission = texTP(_EmissionMap, _EmissionMap_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv) * _EmissionColor;
        return UnityMetaFragment(o);
    #else
        //LIGHTING PARAMS
        UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
        float3 lightDir = getLightDir(i.worldPos);
        float4 lightCol = _LightColor0;

        //NORMAL
        float3 normalMap = texTPNorm(_BumpMap, _BumpMap_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv);
        float3 worldNormal = getNormal(normalMap, i.btn[0], i.btn[1], i.btn[2]);

        //METALLIC SMOOTHNESS
        float4 metallicGlossMap = texTP(_MetallicGlossMap, _MetallicGlossMap_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv);
        float4 metallicSmoothness = getMetallicSmoothness(metallicGlossMap, i.btn[2]);

        //EMISSION
        float4 emissionMap = texTP(_EmissionMap, _EmissionMap_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv);
        float4 emission = emissionMap * _EmissionColor;

        //OCCLUSION
        float4 occlusionMap = texTP(_OcclusionMap, _OcclusionMap_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv);

        //THICKNESS
        float4 thicknessMap = texTP(_ThicknessMap, _ThicknessMap_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv);

        //DIFFUSE
        fixed4 diffuse = texTP(_MainTex, _MainTex_ST, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff, i.uv) * _Color;
        fixed4 diffuseColor = diffuse; //Store for later use, we alter it after.
        diffuse.rgb *= (1-metallicSmoothness.x);
        
        //LIGHTING VECTORS
        float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
        float3 halfVector = normalize(lightDir + viewDir);
        float3 reflViewDir = reflect(-viewDir, worldNormal);
        float3 reflLightDir = reflect(lightDir, worldNormal);
        
        //DOT PRODUCTS FOR LIGHTING
        float ndl = saturate(dot(lightDir, worldNormal));
        float vdn = abs(dot(viewDir, worldNormal));
        float rdv = saturate(dot(reflLightDir, float4(-viewDir, 0)));

        //LIGHTING
        float3 lighting = float3(0,0,0);
        float3 indirectDiffuse = float3(0,0,0);
        float3 directDiffuse = float3(0,0,0);
        float3 indirectSpecular = float3(0,0,0);
        float3 directSpecular = float3(0,0,0);
        float2 lmUV = float2(0,0);

        #if defined(LIGHTMAP_ON)
            lmUV = i.uv1;
            indirectDiffuse = 0;
            directDiffuse = getLightmaps(lmUV, worldNormal);
            #if defined(DIRLIGHTMAP_COMBINED)
                indirectSpecular += DirectionalLMSpecular(lmUV, worldNormal, -viewDir, metallicSmoothness.a) * directDiffuse * (metallicSmoothness.a) * _LightMapSpecularStrength;
                indirectSpecular *= max(0, lerp(1, pow(length(directDiffuse), _SpecLMOcclusionAdjust), _SpecularLMOcclusion));
            #endif
            #if defined(DYNAMICLIGHTMAP_ON)
                float3 realtimeLM = getRealtimeLightmap(i.uv2, worldNormal);
                directDiffuse += realtimeLM;
            #endif
        #else
            #if defined(UNITY_PASS_FORWARDBASE)
                if(_LightProbeMethod == 0)
                {
                    indirectDiffuse = ShadeSH9(float4(worldNormal, 1));
                }
                else
                {
                    float3 L0 = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
                    indirectDiffuse.r = shEvaluateDiffuseL1Geomerics(L0.r, unity_SHAr.xyz, worldNormal);
                    indirectDiffuse.g = shEvaluateDiffuseL1Geomerics(L0.g, unity_SHAg.xyz, worldNormal);
                    indirectDiffuse.b = shEvaluateDiffuseL1Geomerics(L0.b, unity_SHAb.xyz, worldNormal);
                }
            #endif
            directDiffuse = ndl * attenuation * _LightColor0;
        #endif

        float transmissionMask = 0;
        float3 transmission = calcSubsurfaceScattering(attenuation, ndl, diffuseColor.rgb, thicknessMap.x, lightDir, viewDir, i.btn[2], lightCol, indirectDiffuse, transmissionMask);

        indirectSpecular += getIndirectSpecular(i.worldPos, diffuseColor, vdn, metallicSmoothness, reflViewDir, indirectDiffuse, viewDir, directDiffuse, lmUV, worldNormal);
        directSpecular += getDirectSpecular(lightCol, diffuseColor, metallicSmoothness, rdv, attenuation);

        #if defined(SnowCoverage)
            float dist = distance(_WorldSpaceCameraPos, i.worldPos);
            float snowMask = getSnowMask(worldNormal);
            float snowSparkles = getSnowSparkles(vdn, rdv, dist, i.uv, i.worldPos, i.objPos, i.btn[2], i.objNormal, _TriplanarFalloff);
            float snowShine = getSnowShine(vdn, rdv);

            float snow = (snowSparkles * snowMask * 10);
            diffuse = lerp(diffuse, snowMask + (snowShine * 0.5), snowMask);
            directSpecular += snow;
        #endif

        lighting = lerp(diffuse, float3(1,1,1), _DebugLightmapView) * (directDiffuse + indirectDiffuse); 
        lighting += directSpecular; 
        lighting += indirectSpecular;
        lighting *= lerp(1, occlusionMap, saturate(_OcclusionStrength));
        lighting += transmission; 
        lighting += emission;

        float al = 1;
        #if defined(alphablend) 
            al = diffuseColor.a;
        #endif

        #if defined(alphaToMask)
            clip(diffuseColor.a - _Cutoff);
        #endif

        UNITY_APPLY_FOG(i.fogCoord, lighting);

        // return float4(metallicSmoothness.aaa, al);
        return float4(lighting, al);
    #endif
}