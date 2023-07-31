#ifndef __MATH_HELPER_CGINC__
#define __MATH_HELPER_CGINC__

#include "Assets/Shader/Constant.cginc"

float2 Conjugate(float2 c)
{
    return float2(c.x,-c.y);
}

float2 ComplexMultiply(float2 c1, float2 c2)
{
    return float2(c1.x * c2.x - c1.y * c2.y,
    c1.x * c2.y + c1.y * c2.x);
}

float2 ExpTheta(float theta)
{
    return float2(cos(theta),sin(theta));
}

bool IsEven(float number)
{
    return (number % 2) < 1;
}

int RealPow(float a, float b)
{
    if(a > 0) return pow(a,b);
    bool isEven = IsEven(b);
    float tmp = pow(abs(a),b);
    return isEven ? tmp : -tmp;
}
#endif