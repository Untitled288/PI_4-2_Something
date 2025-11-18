float2 InvScreenSize = View.ViewSizeAndInvSize.zw;
float2 ScreenUVFix = ViewportUVToSceneTextureUV(ScreenUV,TexIndex); // fix UV's
float2 CenterUVFix = ViewportUVToSceneTextureUV(float2(.5, .5),TexIndex); // fix UV's
float4 CenterPixelValue = SceneTextureLookup(CenterUVFix, TexIndex, false);
//CenterPixelValue = SceneTexture2;
float4 Scene = SceneTextureLookup(ScreenUVFix, TexIndex, false);
//Scene = float4(SceneTexture);


Out_InvScreenSize = InvScreenSize;
// Размеры и позиция полосы
const float BarHeight = 50 * InvScreenSize.y; // Высота полосы 
const float BarBottomOffset = 30 * InvScreenSize.y; // Отступ от нижнего края 
PixelColor = CenterPixelValue;

float4 BarColor = float4(0, 0, 0, 1.0);

// UV-координаты для полосы
float BarMinY = 1.0 - BarBottomOffset - BarHeight;
float BarMaxY = 1.0 - BarBottomOffset;
float BarUVY = (ScreenUV.y - BarMinY) / (BarMaxY - BarMinY); // UV по вертикали в пределах полосы [0, 1]

RemapValues.x = RemapValues.x / 255;
RemapValues.y = RemapValues.y / 255;
RemapValues.z = RemapValues.z / 255;
RemapValues.w = RemapValues.w / 255;

struct Remapper
{
    float R;
    float G;
    float B;


    float4 Albedo(float Pixel, float4 T)
    {
        if (Pixel <= T.x) // Too Dark
        {
            R = 1.0;
            G = 0.0;
            B = 0.0;
        }

        else if (Pixel <= T.y) // Exceptions
        {
            float Range = T.y - T.x;

            R = 1,0;
            G = (Pixel - T.x) / Range;
            B = 0.0;
        }

        else if (Pixel <= T.z) // Right
        {
            R = 0.1;
            G = 0.7;
            B = 0.1;
        }

        else if (Pixel <= T.w) // Exceptions
        {
            float Range = T.w - T.z;
        
            R = 0.0;
            G = 1 - ((Pixel - T.z) / Range);
            B = 1.0;
        }

        else // Too Bright
        {
            R = 0.0;
            G = 0.0;
            B = 1.0;
        }

        return float4(R, G, B, 1.0);
    }

    float4 Albedo_alpha(float3 Pixel, float4 T)
    {
        float PixelLuma = dot(Pixel, float3(0.299, 0.587, 0.114));
        if (PixelLuma <= T.x) // Too Dark
        {
            R = 1.0;
            G = 0.0;
            B = 0.0;
        }

        else if (PixelLuma <= T.y) // Exceptions
        {
            float Range = T.y - T.x;

            R = 1,0;
            G = (Pixel - T.x) / Range;
            B = 0.0;
        }

        else if (PixelLuma <= T.z) // Right
        {
            R = Pixel.r;
            G = Pixel.g;
            B = Pixel.b;
        }

        else if (PixelLuma <= T.w) // Exceptions
        {
            float Range = T.w - T.z;
        
            R = 0.0;
            G = 1 - ((PixelLuma - T.z) / Range);
            B = 1.0;
        }

        else // Too Bright
        {
            R = 0.0;
            G = 0.0;
            B = 1.0;
        }

        return float4(R, G, B, 1.0);
    }
    float4 Specular()
    {
        
    }
};



Remapper Check;
//return BarUVY;
// Проверка, находимся ли мы в области полосы
if (ScreenUV.y >= BarMinY && ScreenUV.y <= BarMaxY)
{
    // Расчет значения яркости (Albedo) пикселя в центре
    // Используем Luminance для получения скалярного значения от 0 до 1
    // (Luminance = 0.2126 * R + 0.7152 * G + 0.0722 * B - Rec. 709)
    float CenterLuminance = dot(CenterPixelValue, float3(0.299, 0.587, 0.114));

    // Преобразуем Luminance (0-1) в позицию на полосе (0-1)
    // Эта позиция будет "стрелкой"
    float IndicatorPosition = CenterLuminance;
    
    // Расчет цвета градиента для полосы (имитация референса)
    float R = 0.0;
    float G = 0.0;
    float B = 0.0;
    
    // Упрощенный градиент: Красный (0-30), Желтый/Зеленый (30-232), Синий (232-255)
    float Value = ScreenUV.x; // Горизонтальная позиция на полосе [0, 1]    
    
    //BarColor = float4(R, G, B, 1.0);
    BarColor = Check.Albedo(Value, RemapValues);
    
    // --- Рисование Индикатора (Стрелки) ---
    float IndicatorWidth = 1.5 * InvScreenSize.x; // Ширина индикатора
    
    // Расстояние от центра индикатора
    float DistanceFromIndicator = abs(ScreenUV.x - IndicatorPosition);
    
    if (DistanceFromIndicator < IndicatorWidth)
    {
        // Индикатор: вертикальная белая линия
        float IndicatorAlpha = 1.0 - (DistanceFromIndicator / IndicatorWidth);
        return BarColor; // Белый цвет для индикатора
    }
    
    // Границы полосы
    float BorderThickness = .3;
    if (BarUVY > (1.0 - BorderThickness))
    {
        return Scene;
    }
    else if (BarUVY < 0.325)
    {
        return Value;
    }

    // Если не индикатор, возвращаем цвет полосы
    return BarColor;
}

// Crosshair -------------------------------------------------------------------------------------
float2 CrosshairSize = float2(10 * InvScreenSize.x, 10 * InvScreenSize.y); // Размер каждой линии прицела
float2 CrosshairThickness = float2(1 * InvScreenSize.x, 1 * InvScreenSize.y); // Толщина линии прицела
float2 Center = float2(0.5, 0.5);
float CenterLuma = dot(CenterPixelValue, float3(0.299, 0.587, 0.114));
// Горизонтальная линия
if (abs(ScreenUV.y - Center.y) < CrosshairThickness.y && abs(ScreenUV.x - Center.x) < CrosshairSize.x)
{
    float result = 1 - Scene; // Белый прицел
    if ((CenterLuma > .3) || (CenterLuma < .6))
    {
        result = result - float4(.15, .15, .15, 1.);
        //result = 1;
    }
    return result;
}
// Вертикальная линия
if (abs(ScreenUV.x - Center.x) < CrosshairThickness.x && abs(ScreenUV.y - Center.y) < CrosshairSize.y)
{
    float result = 1 - Scene; // Белый прицел
    if ((CenterLuma > .3) || (CenterLuma < .6)) 
    {       
        result = result - float4(.15, .15, .15, 1.);
        //result = 1;
    }
    return result;
}

// Если не в области полосы, пропускаем сцену
return Scene;