float2 grid = floor(ScreenUV * grid_size + UV_offset);
float2 localUV = frac(ScreenUV * grid_size + UV_offset);

float2 ratio = View.ViewSizeAndInvSize.xy * View.BufferSizeAndInvSize.zw;

// UV's
float2 sampleUV = ViewportUVToSceneTextureUV(localUV, 14); // reserved
float2 originalUV = ViewportUVToSceneTextureUV(ScreenUV, 14);
float2 gBufferUV = localUV * ratio;


float3 FinalColor = float3(0, 0, 0);

if (grid.x > 0 && grid.x < (grid_size - 1) && grid.y > 0 && grid.y < (grid_size - 1)) {
    
    if (full_view)
    {
        float2 centerUV = ViewportUVToSceneTextureUV(((ScreenUV - 0.25) * 2.0), 14);

        FinalColor = SceneTextureLookup(centerUV, 14, false).rgb;
    }
    
    else {
        FinalColor = SceneTextureLookup(originalUV, 14, false).rgb;
    }

}

else if (grid.x == 0 && grid.y == 1) 
{
    FinalColor = SceneTextureLookup(gBufferUV, 5, false).rgb; // Base Color (for lighting)
}

else if (grid.x == 0 && grid.y == 2) 
{
    FinalColor = SceneTextureLookup(gBufferUV, 3, false).rgb; // Specular
}

else if (grid.x == 0 && grid.y == 3) 
{
    FinalColor = SceneTextureLookup(gBufferUV, 7, false).rgb; // Metallic
}

else if (grid.x == 1 && grid.y == 3) 
{
    FinalColor = SceneTextureLookup(gBufferUV, 11, false).rgb; // Roughness
}




return float4(FinalColor, 1.);
//return FinalColor;
//return Scene + frac(float4(ScreenUV, 0., .4) * 3);