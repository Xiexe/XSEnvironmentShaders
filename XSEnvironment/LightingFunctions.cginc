//This file contains all of the neccisary functions for lighting to work a'la standard shading.
//Feel free to add to this.


// Rotation with angle (in radians) and axis
float3x3 AngleAxis3x3(float angle, float3 axis)
{
    float c, s;
    sincos(angle, s, c);

    float t = 1 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;

    return float3x3(
        t * x * x + c,      t * x * y - s * z,  t * x * z + s * y,
        t * x * y + s * z,  t * y * y + c,      t * y * z - s * x,
        t * x * z - s * y,  t * y * z + s * x,  t * z * z + c
    );
}

float2 rotateUV(float2 uv, float rotation)
{
    float mid = 0.5;
    return float2(
        cos(rotation) * (uv.x - mid) + sin(rotation) * (uv.y - mid) + mid,
        cos(rotation) * (uv.y - mid) - sin(rotation) * (uv.x - mid) + mid
    );
}
//

half4 getMetallicSmoothness(float4 metallicGlossMap, float3 worldNormal)
{
	half roughness = 1-(_Glossiness * metallicGlossMap.a);
	roughness *= 1.7 - 0.7 * roughness;
	half metallic = metallicGlossMap.r * _Metallic;

    //GeometricSpecularAA
    // float3 vNormalWsDdx = ddx( worldNormal );
    // float3 vNormalWsDdy = ddy( worldNormal );
    // float flGeometricRoughnessFactor = (pow( saturate( max( dot( vNormalWsDdx, vNormalWsDdx ), dot( vNormalWsDdy, vNormalWsDdy ) ) ), 0.333 ));
    // roughness = roughness * (1-flGeometricRoughnessFactor);

	return half4(metallic, 0, 0, roughness);
}

//Reflection direction, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
float3 getReflectionUV(float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax) 
{
	//#if UNITY_SPECCUBE_BOX_PROJECTION
		if (cubemapPosition.w > 0) {
			float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
			float scalar = min(min(factors.x, factors.y), factors.z);
			direction = direction * scalar + (position - cubemapPosition);
		}
	//#endif
	return direction;
}

half3 getIndirectSpecular(float3 worldPos, float3 diffuseColor, float vdn, float4 metallicSmoothness, half3 reflDir, half3 indirectLight, float3 viewDir, float3 lighting)
{	//This function handls Unity style reflections, Matcaps, and a baked in fallback cubemap.
	half3 spec = half3(0,0,0);
    #if defined(UNITY_PASS_FORWARDBASE)
        float3 reflectionUV1 = getReflectionUV(reflDir, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
        half4 probe0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, reflectionUV1, metallicSmoothness.w * 6);
        half3 probe0sample = DecodeHDR(probe0, unity_SpecCube0_HDR);

        float3 indirectSpecular;
        float interpolator = unity_SpecCube0_BoxMin.w;
        
        UNITY_BRANCH
        if (interpolator < 0.99999) 
        {
            float3 reflectionUV2 = getReflectionUV(reflDir, worldPos, unity_SpecCube1_ProbePosition, unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax);
            half4 probe1 = UNITY_SAMPLE_TEXCUBE_SAMPLER_LOD(unity_SpecCube1, unity_SpecCube0, reflectionUV2, metallicSmoothness.w * 6);
            half3 probe1sample = DecodeHDR(probe1, unity_SpecCube1_HDR);
            indirectSpecular = lerp(probe1sample, probe0sample, interpolator);
        }
        else 
        {
            indirectSpecular = probe0sample;
        }

        half3 metallicColor = indirectSpecular * lerp(0.05,diffuseColor.rgb, metallicSmoothness.x);
        spec = lerp(indirectSpecular, metallicColor, pow(vdn, 0.05));
		spec = lerp(spec, spec * lighting, metallicSmoothness.w); // should only not see shadows on a perfect mirror.
        
        #if defined(LIGHTMAP_ON)
            float specMultiplier = max(0, lerp(1, pow(length(lighting), _SpecLMOcclusionAdjust), _SpecularLMOcclusion));
            spec *= specMultiplier;
        #endif
    #endif
	return spec;
}

half3 getDirectSpecular(half4 lightCol, half3 diffuseColor, half4 metallicSmoothness, float rdv, float atten)
{	
	half smoothness = max(0.0001, 1-metallicSmoothness.w);
	smoothness *= 1.7 - 0.7 * smoothness;
	
    half3 specularReflection = saturate(pow(rdv, smoothness * 128)) * lightCol;
	specularReflection = lerp(specularReflection, specularReflection * diffuseColor, metallicSmoothness.x);
    specularReflection *= lerp(0,5, smoothness * 0.05); //Artificially brighten to be as bright as standard
    return specularReflection * atten;
}

float3 getNormal(float3 normalMap, float3 bitangent, float3 tangent, float3 worldNormal)
{
    half3 tspace0 = half3(tangent.x, bitangent.x, worldNormal.x);
	half3 tspace1 = half3(tangent.y, bitangent.y, worldNormal.y);
	half3 tspace2 = half3(tangent.z, bitangent.z, worldNormal.z);

	half3 nMap = normalMap;
	nMap.xy *= _BumpScale;

	half3 calcedNormal;
	calcedNormal.x = dot(tspace0, nMap);
	calcedNormal.y = dot(tspace1, nMap);
	calcedNormal.z = dot(tspace2, nMap);

    return normalize(calcedNormal);
}

half3 getRealtimeLightmap(float2 uv, float3 worldNormal)
{
    float2 realtimeUV = uv * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    float4 bakedCol = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, realtimeUV);
    float3 realtimeLightmap = DecodeRealtimeLightmap(bakedCol);

    #ifdef DIRLIGHTMAP_COMBINED
        half4 realtimeDirTex = UNITY_SAMPLE_TEX2D_SAMPLER(unity_DynamicDirectionality, unity_DynamicLightmap, realtimeUV);
        realtimeLightmap += DecodeDirectionalLightmap (realtimeLightmap, realtimeDirTex, worldNormal);
    #endif
    
    return realtimeLightmap * _RTLMStrength;
}

half3 getLightmap(float2 uv, float3 worldNormal, float3 worldPos)
{
    float2 lightmapUV = uv * unity_LightmapST.xy + unity_LightmapST.zw;
    half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, lightmapUV);
    half3 lightMap = DecodeLightmap(bakedColorTex);
    
    #ifdef DIRLIGHTMAP_COMBINED
        fixed4 bakedDirTex = UNITY_SAMPLE_TEX2D_SAMPLER (unity_LightmapInd, unity_Lightmap, lightmapUV);
        lightMap = DecodeDirectionalLightmap(lightMap, bakedDirTex, worldNormal);
    #endif
    return lightMap * _LMStrength;
}

half3 getLightDir(float3 worldPos)
{
	half3 lightDir = UnityWorldSpaceLightDir(worldPos);
    
	half3 probeLightDir = unity_SHAr.xyz + unity_SHAg.xyz + unity_SHAb.xyz;
	lightDir = (lightDir + probeLightDir); //Make light dir the average of the probe direction and the light source direction.

		#if !defined(POINT) && !defined(SPOT) // if the average length of the light probes is null, and we don't have a directional light in the scene, fall back to our fallback lightDir
			if(length(unity_SHAr.xyz*unity_SHAr.w + unity_SHAg.xyz*unity_SHAg.w + unity_SHAb.xyz*unity_SHAb.w) == 0 && ((_LightColor0.r+_LightColor0.g+_LightColor0.b) / 3) < 0.1)
			{
				lightDir = float4(1, 1, 1, 0);
			}
		#endif

	return normalize(lightDir);
}

float4 texTPLod( sampler2D tex, float4 tillingOffset, float3 worldPos, float3 objPos, float3 worldNormal, float3 objNormal, float falloff, float2 uv, float lod)
{
	// if(_TextureSampleMode != 0){
        worldPos = lerp(worldPos, objPos, _TextureSampleMode - 1);
        worldNormal = lerp(worldNormal, objNormal, _TextureSampleMode - 1);

        float3 projNormal = pow(abs(worldNormal),falloff);
        projNormal /= projNormal.x + projNormal.y + projNormal.z;
        float3 nsign = sign(worldNormal);
        half4 xNorm = half4(0,0,0,0); half4 yNorm = half4(0,0,0,0); half4 zNorm = half4(0,0,0,0);


        float2 uvx = worldPos.zy * float2( nsign.x, 1.0 );
        float2 uvy = worldPos.xz * float2( nsign.y, 1.0 );
        float2 uvz = worldPos.xy * float2( -nsign.z, 1.0 );

        if(projNormal.x > 0)
            xNorm = tex2Dlod( tex, float4(tillingOffset.xy * uvx + tillingOffset.zw, 0, lod));

        if(projNormal.y > 0)
            yNorm = tex2Dlod( tex, float4(tillingOffset.xy * uvy + tillingOffset.zw, 0, lod));

        if(projNormal.z > 0)
            zNorm = tex2Dlod( tex, float4(tillingOffset.xy * uvz + tillingOffset.zw, 0, lod));

        return xNorm * projNormal.x + yNorm * projNormal.y + zNorm * projNormal.z;
    //}
    // else{
    //     return tex2D(tex, uv * tillingOffset.xy + tillingOffset.zw);
    // } 
}

//Triplanar map a texture (Object or World space), or sample it normally.
float4 texTP( sampler2D tex, float4 tillingOffset, float3 worldPos, float3 objPos, float3 worldNormal, float3 objNormal, float falloff, float2 uv)
{
	if(_TextureSampleMode != 0){

        worldPos = lerp(worldPos, objPos, _TextureSampleMode - 1);
        worldNormal = lerp(worldNormal, objNormal, _TextureSampleMode - 1);

        AngleAxis3x3(worldNormal.x, _RotationAxes);

        float3 projNormal = pow(abs(worldNormal),falloff);
        projNormal /= projNormal.x + projNormal.y + projNormal.z;
        float3 nsign = sign(worldNormal);
        half4 xNorm = half4(0,0,0,0); half4 yNorm = half4(0,0,0,0); half4 zNorm = half4(0,0,0,0);

        float2 uvx = worldPos.zy * float2( nsign.x, 1.0 );
        float2 uvy = worldPos.xz * float2( nsign.y, 1.0 );
        float2 uvz = worldPos.xy * float2( -nsign.z, 1.0 );

        if(projNormal.x > 0)
            xNorm = tex2D( tex, tillingOffset.xy * uvx + tillingOffset.zw);

        if(projNormal.y > 0)
            yNorm = tex2D( tex, tillingOffset.xy * uvy + tillingOffset.zw);

        if(projNormal.z > 0)
            zNorm = tex2D( tex, tillingOffset.xy * uvz + tillingOffset.zw);

        return xNorm * projNormal.x + yNorm * projNormal.y + zNorm * projNormal.z;
    }
    else{
        rotateUV(uv, _RotationAxes.x);
        return tex2D(tex, uv * tillingOffset.xy + tillingOffset.zw);
    } 
}
//same as above but for normal maps
float3 texTPNorm( sampler2D tex, float4 tillingOffset, float3 worldPos, float3 objPos, float3 worldNormal, float3 objNormal, float falloff, float2 uv)
{
    if(_TextureSampleMode != 0){
        
        worldPos = lerp(worldPos, objPos, _TextureSampleMode - 1);
        worldNormal = lerp(worldNormal, objNormal, _TextureSampleMode - 1);

        float3 projNormal = pow(abs(worldNormal), falloff);
        projNormal /= projNormal.x + projNormal.y + projNormal.z;
        float3 nsign = sign(worldNormal);
        half4 xNorm = half4(0,0,0,0); half4 yNorm = half4(0,0,0,0); half4 zNorm = half4(0,0,0,0);
        
        float2 uvx = worldPos.zy * float2( nsign.x, 1.0 );
        float2 uvy = worldPos.xz * float2( nsign.y, 1.0 );
        float2 uvz = worldPos.xy * float2( -nsign.z, 1.0 );

        if(projNormal.x > 0)
            xNorm = tex2D( tex, tillingOffset.xy * uvx + tillingOffset.zw);

        if(projNormal.y > 0)
            yNorm = tex2D( tex, tillingOffset.xy * uvy + tillingOffset.zw);

        if(projNormal.z > 0)
            zNorm = tex2D( tex, tillingOffset.xy * uvz + tillingOffset.zw);

        xNorm.xyz = UnpackNormal(xNorm);
        yNorm.xyz = UnpackNormal(yNorm);
        zNorm.xyz = UnpackNormal(zNorm);
		
        return (xNorm.xyz * projNormal.x + yNorm.xyz * projNormal.y + zNorm.xyz * projNormal.z);
    }
    else{
        return UnpackNormal(tex2D(tex, uv * tillingOffset.xy + tillingOffset.zw));
    }
}

#if defined(SnowCoverage)
float getSnowMask(float3 worldNormal)
{
    _SnowCoverage = 1-_SnowCoverage;
    _SnowCoverage *= 5;
    float3 snowColor = float3(1,1,1);
    float ndu = dot(float3(0,1,0), worldNormal); 
    ndu = smoothstep(_SnowCoverage - 0.5, _SnowCoverage + 0.5, ndu);

    snowColor *= lerp(ndu, 1-ndu, _InvertSnowCoverage);
    return snowColor;
}

float getSnowSparkles(float vdn, float rdv, float dist, float2 uv, float3 worldPos, float3 objPos, float3 worldNormal, float3 objNormal, float falloff)
{
    float lod = lerp( 0, 9, smoothstep( 1, 300, dist)) ;
    float4 noise = texTPLod(_SnowNoise, float4(_SnowNoise_ST.xy, 0, 0), worldPos, objPos, worldNormal, objNormal, falloff, uv, lod);
    noise = pow(noise, 7);

    float reflectMask = saturate(pow(rdv, 6));
    float snowSparkles = reflectMask * noise.x;

    return snowSparkles;
}

float getSnowShine(float vdn, float rdv)
{
    float reflectMask = saturate(pow(rdv, 2));
    float snowSparkles = reflectMask;
    return snowSparkles;
}
#endif