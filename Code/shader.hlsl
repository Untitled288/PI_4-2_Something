float2 grid = floor(ScreenUV * grid_size + UV_offset);
float2 localUV = frac(ScreenUV * grid_size + UV_offset);

float2 ratio = GetPrimaryView().ViewSizeAndInvSize.xy * GetPrimaryView().BufferSizeAndInvSize.zw;

// UV's
float2 sampleUV = ViewportUVToSceneTextureUV(localUV, 14); // reserved
float2 originalUV = ViewportUVToSceneTextureUV(ScreenUV, 14);
float2 gBufferUV = localUV * ratio;

float2 probeUV = ViewportUVToSceneTextureUV(float2(.5, .5),TexIndex);
float3 probeColor = SceneTextureLookup(probeUV, 5, false);

float2 InvScreenSize = GetPrimaryView().ViewSizeAndInvSize.zw;

// ЧИТАЕМ РАЗМЕРЫ ОБЕИХ ТЕКСТУР НАПРЯМУЮ
float2 AtlasSize;
CurveTex.GetDimensions(AtlasSize.x, AtlasSize.y);

float2 LabelAtlasSize;
LabelTex.GetDimensions(LabelAtlasSize.x, LabelAtlasSize.y);

bool bIsColorLegend = ColorLegend > 0.0f;


//OutTextColor = float3(1.0f, 1.0f, 1.0f);
float3 FinalColor = float3(0, 0, 0);
float3 rawColor = float3(0, 0, 0);

struct FTools
{
    float ColorToLuminance(float3 color)
    {
        return dot(color, float3(0.299, 0.587, 0.114));
    }

    float4 RemapValue(Texture2D CurveTex, SamplerState CurveTexSampler, float2 AtlasSize, uint curve_index, float value)
    {
        float V = (curve_index + 0.5f) / AtlasSize.y;
        return Texture2DSample(CurveTex, CurveTexSampler, float2(value, V));
    }
};

FTools Tools;

// --- Подготовка UV и переменных ---
bool bIsCenter = (grid.x > 0 && grid.x < (grid_size - 1) && grid.y > 0 && grid.y < (grid_size - 1));
float2 barUV = localUV; 

if (bIsCenter) 
{
    float minEdge = 1.0f / grid_size;
    float maxEdge = (grid_size - 1.0f) / grid_size;
    barUV = (ScreenUV - minEdge) / (maxEdge - minEdge);
}

uint my_curve = 0; 
uint my_label_index = 0; // ИНДЕКС СЛОВА ИЗ ТВОЕГО АТЛАСА
float sliderValue = 0;
float resolution_factor = 2.0f;

// --- Назначение логики (твои проверки) ---
// Вычисляем 1D индекс текущей ячейки (от 0 до 15)
int cellIndex = int(grid.y) * int(grid_size) + int(grid.x);

if (grid_size == 1.0f)
{
    cellIndex = ViewModeIndex;
}


// if (bIsCenter) 
// {
//     my_curve = 1; 
//     my_label_index = 0; // "FINAL"
//     resolution_factor = 1.0f;
//     bIsColorLegend = 0;
    
//     probeColor = SceneTextureLookup(probeUV, 14, false).rgba;

//     if (full_view) {
//         float2 centerUV = ViewportUVToSceneTextureUV(((ScreenUV - 0.25) * 2.0), 14);
//         FinalColor = SceneTextureLookup(centerUV, 14, false).rgb;
//     } else {
//         FinalColor = SceneTextureLookup(originalUV, 14, false).rgb;
//     }
// }
// else 
// {
// Распределяем логику по номерам ячеек
//return gBufferUV.rgrr;
switch (cellIndex)
{
    case -1:
        my_curve = 1; 
        my_label_index = 0;
        resolution_factor = 0.7f;
        FinalColor = SceneTextureLookup(originalUV, TexIndex, false).rgb; 
        probeColor = SceneTextureLookup(probeUV, TexIndex, false).rgb;
        break;

    case 0: // Albedo
        my_curve = 1; 
        my_label_index = 1;
        rawColor = SceneTextureLookup(gBufferUV, 5, false).rgb;
        FinalColor = LinearToSrgb(rawColor); 
        probeColor = SceneTextureLookup(probeUV, 5, false).rgb;
        break;

    case 1: // Final (false color)
        my_curve = 7;
        my_label_index = 8; 
        FinalColor = SceneTextureLookup(gBufferUV, 14, false).rgb; 
        probeColor = SceneTextureLookup(probeUV, 14, false).rgb; 
        break;

    case 2: // Translucent
        bIsColorLegend = 0;
        my_label_index = 9;
        FinalColor = SceneTextureLookup(gBufferUV, 15, false).rgb;
        break;

    case 3: // World Normal
        bIsColorLegend = 0;
        my_label_index = 10;
        FinalColor = SceneTextureLookup(gBufferUV, 8, false).rgb;
        break;

    case 4: // Albedo Greyscale
        my_curve = 1; 
        my_label_index = 2; 
        FinalColor = LinearToSrgb(Tools.ColorToLuminance(SceneTextureLookup(gBufferUV, 5, false).rgb)); 
        probeColor = SceneTextureLookup(probeUV, 5, false).rgba;
        break;

    case 7: // World Tangent
        bIsColorLegend = 0;
        my_label_index = 11; 
        FinalColor = SceneTextureLookup(gBufferUV, 29, false).rgb; 
        break;

    case 8: // Specular Color
        my_curve = 1; 
        my_label_index = 3; 
        FinalColor = SceneTextureLookup(gBufferUV, 3, false).rgb; 
        probeColor = SceneTextureLookup(probeUV, 3, false).rgba;
        break;

    case 11: // Material AO
        bIsColorLegend = 0;
        my_label_index = 12; 
        FinalColor = SceneTextureLookup(gBufferUV, 12, false).rgb; 
        probeColor = SceneTextureLookup(probeUV, 12, false).rgba;
        break;

    case 12: // Specular (from metallic)
        my_curve = 2; 
        my_label_index = 4; 
        FinalColor = SceneTextureLookup(gBufferUV, 7, false).rgb;
        probeColor = SceneTextureLookup(probeUV, 7, false).rgba;
        break;

    case 13: // Specular Level
        my_curve = 2;
        my_label_index = 5; 
        FinalColor = SceneTextureLookup(gBufferUV, 6, false).rgb;
        probeColor = SceneTextureLookup(probeUV, 6, false).rgba;
        break;

    case 14: // Metallic
        my_curve = 3; 
        my_label_index = 6; 
        FinalColor = SceneTextureLookup(gBufferUV, 7, false).rgb;
        probeColor = SceneTextureLookup(probeUV, 7, false).rgba;
        break;

    case 15: // Roughness
        bIsColorLegend = 0;
        my_label_index = 7;
        FinalColor = SceneTextureLookup(gBufferUV, 11, false).rgb;
        probeColor = SceneTextureLookup(probeUV, 11, false).rgba;
        break;

    // Если ячейка пустая, ничего не делаем (останется черный цвет)
    default:
        my_curve = 1; 
        my_label_index = 0; // "FINAL"
        resolution_factor = 1.0f;
        bIsColorLegend = 0;
        
        probeColor = SceneTextureLookup(probeUV, 14, false).rgba;

        if (full_view) {
            float2 centerUV = ViewportUVToSceneTextureUV(((ScreenUV - 0.25) * 2.0), 14);
            FinalColor = SceneTextureLookup(centerUV, 14, false).rgb;
        } else {
            FinalColor = SceneTextureLookup(originalUV, 14, false).rgb;
        }

        break;
}
//}

float luminance = Tools.ColorToLuminance(FinalColor);
float4 remapedLuminance = Tools.RemapValue(CurveTex, CurveTexSampler, AtlasSize, my_curve, luminance);

if (!remapedLuminance.a)
{
    //FinalColor = SceneTextureLookup(originalUV, 14, false).rgb;
    FinalColor = remapedLuminance.rgb;
}

//probeColor += 0.015f; // Color offset
sliderValue = Tools.ColorToLuminance(probeColor);
OutTextColor = (Tools.RemapValue(CurveTex, CurveTexSampler, AtlasSize, my_curve, LinearToSrgb(sliderValue).r)) * 2.0f;
//return sliderValue;
// --- ОТРИСОВКА И ПЕРЕДАЧА ДАННЫХ НАРУЖУ ---

float aspect = GetPrimaryView().ViewSizeAndInvSize.x / GetPrimaryView().ViewSizeAndInvSize.y;
float marginX = 0.01f; 
float marginY = 0.01f; 

// =======================================================
// РАСКЛАДКА СНИЗУ ВВЕРХ:
// =======================================================
// 1. Зона имени буфера (Label)
float totalLabels = 13.0f; // Количество надписей в атласе

// АВТОМАТИКА: Шейдер сам считает пропорции на основе реальной картинки!
float singleRowHeight = LabelAtlasSize.y / totalLabels;
float autoLabelAspect = LabelAtlasSize.x / singleRowHeight; 


// то, что мы сами задаём
float labelSize = 1.0f; // масштаб стандартного размера. 1x по стандарту.

float labelHeight = 0.03f * labelSize * resolution_factor; // мы задаём высоту
float labelWidth = (labelHeight * autoLabelAspect) / aspect; // ширина считается сама ((ширину * соотношение картинки) / соотношение вьюпорта)

float labelPosMinX = marginX * resolution_factor;
float labelPosMaxY = 1.0f - marginY * resolution_factor;

// для удобства. Шейдер сам считает ширину/высоту относительно позиии
float labelPosMinY = labelPosMaxY - labelHeight; // шейдер сам считает свою высоты для координат. (из позиции Y вычитаем нашу высоту)
float labelPosMaxX = labelPosMinX + labelWidth; // шейдер сам считает свою ширину для координат. (из позиции X вычитаем посчитанную ширину)

if (barUV.y >= labelPosMinY && barUV.y <= labelPosMaxY && barUV.x >= labelPosMinX && barUV.x <= labelPosMaxX)
{
    float labelU = (barUV.x - labelPosMinX) / labelWidth;
    float labelV = (barUV.y - labelPosMinY) / labelHeight;
    //return float4(labelU, labelV, 0.f, 0.f); 
    
    float atlasV = (my_label_index + labelV) / totalLabels;
    float labelMask = Texture2DSample(LabelTex, LabelTexSampler, float2(labelU, atlasV)).r;
    
    FinalColor = lerp(FinalColor, float3(0.9, 0.8, 0.0), labelMask);
}


// 2. Зона полоски градиента (Bar)
float barHeight = 0.06f;

float barPosMinX = marginX * resolution_factor; // отступ от левого края
float barPosMaxX = 1.0f - marginX * resolution_factor; // отступ от правого края

float barPosMaxY = labelPosMinY - marginY; // отступ от label
float barPosMinY = barPosMaxY - barHeight * resolution_factor;
float barPosMinY2 = barPosMaxY - (barHeight * 0.6f) * resolution_factor;
float barPosMinY3 = barPosMaxY - (barHeight * 0.2f) * resolution_factor;

float sliderPos = lerp(barPosMinX, barPosMaxX, saturate(LinearToSrgb(sliderValue))); // считаем позицию слайдера

if (barUV.y >= barPosMinY && barUV.y <= barPosMaxY && barUV.x >= barPosMinX && barUV.x <= barPosMaxX && bIsColorLegend)
{
    float barU = (barUV.x - barPosMinX) / (barPosMaxX - barPosMinX);

    float sliderThickness = 2.0f * GetPrimaryView().ViewSizeAndInvSize.z * resolution_factor; 
    
    if (abs(barU - LinearToSrgb(sliderValue).r) < sliderThickness)
    {
        FinalColor = float3(1.0, 1.0, 1.0); 
    }
    
    else if (barUV.y >= barPosMinY3)
    {
        // pass
    }

    else if (barUV.y >= barPosMinY2)
    {
        FinalColor = LinearToSrgb(barU.rrr); 
    }

    else
    {
        float3 barColor = Tools.RemapValue(CurveTex, CurveTexSampler, AtlasSize, my_curve, barU).rgb;
        FinalColor = barColor; 
    }
}


// 3. Зона текста ползунка (Text)
float textHeight = 0.06f; 
float textWidth = (textHeight * resolution_factor) / (aspect + 1.4f);

float textPosMaxY = barPosMinY - marginY * resolution_factor; 
float textPosMinY = textPosMaxY - textHeight * resolution_factor;

// Если режим 0-255, сжимаем черную рамку наполовину, чтобы скрыть ".00"
float byteCropScale = 0.5f;

bool bIsFloatToByte = FloatToByte > 0.0f;

if (bIsFloatToByte)
{
    textWidth *= byteCropScale; 
}

float textPosMinX = sliderPos - (textWidth / 1.0f);
float textPosMaxX = sliderPos + (textWidth / 1.0f);

OutTextUV = float2(-1.0f, -1.0f);

if (barUV.y >= textPosMinY && barUV.y <= textPosMaxY && barUV.x >= textPosMinX && barUV.x <= textPosMaxX && bIsColorLegend)
{
    float uvX = (barUV.x - textPosMinX) / (textPosMaxX - textPosMinX);
    float uvY = (barUV.y - textPosMinY) / (textPosMaxY - textPosMinY);
    //return float4(uvX, uvY, 0.f, 0.f);
    // Растягиваем UV для обрезки
    if (bIsFloatToByte)
    {
        // В режиме 0-255 растягиваем текстуру так, чтобы правая половина (".00") ушла за пределы рамки
        uvX = uvX * byteCropScale;

        OutValue = round(sliderValue * 255.0f) + 1000;
    }

    else
    {
        // В обычном режиме отрезаем единицу слева
        float cropOffset = 0.35f; 
        float cropScale = 1.0f - cropOffset;  
        uvX = (uvX * cropScale) + cropOffset;

        OutValue = sliderValue + 10.0f;
    }

    OutTextUV = float2(uvX, uvY);
    FinalColor = lerp(FinalColor, float3(0.05, 0.05, 0.05), 0.65f);
}

bool skyMask = SceneTextureLookup(originalUV, 23, false).r;
if (!skyMask)
{
    FinalColor = SceneTextureLookup(originalUV, 14, false).rgb;
}

return float4(FinalColor, 1.0);