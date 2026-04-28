float2 grid = floor(ScreenUV * grid_size + UV_offset);
float2 localUV = frac(ScreenUV * grid_size + UV_offset);

float2 ratio = View.ViewSizeAndInvSize.xy * View.BufferSizeAndInvSize.zw;

// UV's
float2 sampleUV = ViewportUVToSceneTextureUV(localUV, 14); // reserved
float2 originalUV = ViewportUVToSceneTextureUV(ScreenUV, 14);
float2 gBufferUV = localUV * ratio;

float2 probeUV = ViewportUVToSceneTextureUV(float2(.5, .5),TexIndex);
float4 probeColor = SceneTextureLookup(probeUV, TexIndex, false);

float2 InvScreenSize = View.ViewSizeAndInvSize.zw;
const float barHeight = 50 * InvScreenSize.y; // Высота полосы (5% от экрана)
const float barBottomOffset = 30 * InvScreenSize.y; // Отступ от нижнего края (5% от экрана)

float2 AtlasSize;
CurveTex.GetDimensions(AtlasSize.x, AtlasSize.y);


float3 FinalColor = float3(0, 0, 0);

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

    // --- ИСПРАВЛЕННЫЙ 7-СЕГМЕНТНЫЙ ДИСПЛЕЙ ---
    float PrintDigit(float2 uv, int num)
    {
        int segments[10] = { 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F };
        int bits = segments[num];
        
        float d = 0.0;
        float t = 0.2; // Толщина линий (20% от размера цифры)
        
        // Четкая привязка к координатам Unreal (0,0 - это левый верхний угол)
        if ((bits & 1)  && uv.y < t) d = 1.0;                                  // Верх
        if ((bits & 2)  && uv.x > 1.0 - t && uv.y < 0.5 + t/2.0) d = 1.0;      // Правый верх
        if ((bits & 4)  && uv.x > 1.0 - t && uv.y > 0.5 - t/2.0) d = 1.0;      // Правый низ
        if ((bits & 8)  && uv.y > 1.0 - t) d = 1.0;                            // Низ
        if ((bits & 16) && uv.x < t && uv.y > 0.5 - t/2.0) d = 1.0;            // Левый низ
        if ((bits & 32) && uv.x < t && uv.y < 0.5 + t/2.0) d = 1.0;            // Левый верх
        if ((bits & 64) && abs(uv.y - 0.5) < t/2.0) d = 1.0;                   // Центр
        
        return d;
    }

    float4 CreateCellBar(float2 barUV, float grid_size, float sliderValue, Texture2D CurveTex, SamplerState CurveTexSampler, float2 AtlasSize, uint curve_index)
    {
        // Базовые отступы
        float marginX = 0.05f; 
        float marginY = 0.02f; 
        float baseZoneY = 0.85f; 

        float barMinY = baseZoneY + marginY;
        float barMaxY = 1.0f - marginY;
        float barMinX = marginX;
        float barMaxX = 1.0f - marginX;

        // Физическая позиция ползунка
        float sliderPhysicalX = lerp(barMinX, barMaxX, saturate(sliderValue));

        // --- 1. ОТРИСОВКА ЦИФР С УЧЕТОМ АСПЕКТА ЭКРАНА ---
        float textZoneMaxY = barMinY - 0.01f;
        float textZoneMinY = textZoneMaxY - 0.05f; // Высота текста (5% от ячейки)

        if (barUV.y >= textZoneMinY && barUV.y <= textZoneMaxY)
        {
            // Получаем соотношение сторон экрана, чтобы цифры не плющило
            float aspect = View.ViewSizeAndInvSize.x / View.ViewSizeAndInvSize.y;
            
            // Физическая ширина одной цифры (половина её высоты)
            float digitW = (0.05f / aspect) * 0.5f; 
            float spacing = digitW * 0.2f;
            float dotW = digitW * 0.3f;
            
            // Общая ширина всего блока "0.00"
            float totalW = digitW * 3.0f + dotW + spacing * 3.0f;
            
            float textMinX = sliderPhysicalX - (totalW / 2.0f);
            float textMaxX = sliderPhysicalX + (totalW / 2.0f);

            // Если мы находимся внутри коробочки для текста
            if (barUV.x >= textMinX && barUV.x <= textMaxX)
            {
                // Локальные координаты внутри текстового блока
                float lx = barUV.x - textMinX;
                float ny = (barUV.y - textZoneMinY) / 0.05f; // Нормализуем Y от 0 до 1
                
                float mask = 0.0;
                
                // Разбиваем число на цифры (например, 0.18 -> 0, 1, 8)
                int v = min(int(round(abs(sliderValue) * 100.0)), 999);
                int d1 = clamp(v / 100, 0, 9);
                int d2 = clamp((v / 10) % 10, 0, 9);
                int d3 = clamp(v % 10, 0, 9);
                
                // Отрисовываем первую цифру
                if (lx < digitW) mask = PrintDigit(float2(lx / digitW, ny), d1);
                lx -= (digitW + spacing);
                
                // Отрисовываем точку
                if (lx > 0.0 && lx < dotW && ny > 0.85) mask = 1.0;
                lx -= (dotW + spacing);
                
                // Отрисовываем вторую цифру
                if (lx > 0.0 && lx < digitW) mask = PrintDigit(float2(lx / digitW, ny), d2);
                lx -= (digitW + spacing);
                
                // Отрисовываем третью цифру
                if (lx > 0.0 && lx < digitW) mask = PrintDigit(float2(lx / digitW, ny), d3);
                
                // Возвращаем белые цифры или темно-серую подложку (альфа = 1.0 обязательно)
                if (mask > 0.0) return float4(1.0, 1.0, 1.0, 1.0); 
                return float4(0.1, 0.1, 0.1, 1.0); // Фон блока цифр
            }
        }

        // --- 2. ОТРИСОВКА САМОЙ ПОЛОСКИ И ИНДИКАТОРА ---
        if (barUV.y >= barMinY && barUV.y <= barMaxY && barUV.x >= barMinX && barUV.x <= barMaxX)
        {
            float localX = (barUV.x - barMinX) / (barMaxX - barMinX);
            float3 barColor = RemapValue(CurveTex, CurveTexSampler, AtlasSize, curve_index, localX).rgb;
            float lineThickness = 2.0f * View.ViewSizeAndInvSize.z * grid_size; 
            
            // Оранжевый ползунок
            if (abs(localX - sliderValue) < lineThickness)
            {
                return float4(1.0, 0.5, 0.0, 1.0);
            }

            return float4(barColor, 1.0);
        }
        
        return float4(0.0, 0.0, 0.0, 0.0);
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
float sliderValue = 0; 
//float2 probeUV = ViewportUVToSceneTextureUV(float2(0.5, 0.5), 14); 

// --- Назначение логики (твои проверки) ---
if (bIsCenter) 
{
    my_curve = 0; 
    sliderValue = Tools.ColorToLuminance(SceneTextureLookup(probeUV, 14, false).rgb);

    if (full_view) {
        float2 centerUV = ViewportUVToSceneTextureUV(((ScreenUV - 0.25) * 2.0), 14);
        FinalColor = SceneTextureLookup(centerUV, 14, false).rgb;
    } else {
        FinalColor = SceneTextureLookup(originalUV, 14, false).rgb;
    }
}
else if (grid.x == 0 && grid.y == 3) 
{
    my_curve = 1; 
    FinalColor = SceneTextureLookup(gBufferUV, 3, false).rgb; 
    sliderValue = SceneTextureLookup(probeUV, 3, false).r; 
}
else if (grid.x == 1 && grid.y == 3) 
{
    my_curve = 2; 
    FinalColor = SceneTextureLookup(gBufferUV, 7, false).rgb;
    sliderValue = SceneTextureLookup(probeUV, 7, false).r;
}
else if (grid.x == 2 && grid.y == 3) 
{
    my_curve = 3; 
    FinalColor = SceneTextureLookup(gBufferUV, 11, false).rgb;
    sliderValue = SceneTextureLookup(probeUV, 11, false).r;
}
// Добавь сюда остальные свои буферы...

// --- Финальная отрисовка виджета ---
float4 BarResult = Tools.CreateCellBar(barUV, grid_size, sliderValue, CurveTex, CurveTexSampler, AtlasSize, my_curve);

if (BarResult.a > 0.5f)
{
    FinalColor = BarResult.rgb;
}

return float4(FinalColor, 1.0);