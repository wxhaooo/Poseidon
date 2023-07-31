#include "Assets/Shader/Constant.cginc"

uint rngState;

// https://www.reedbeta.com/blog/hash-functions-for-gpu-rendering/
uint PcgHash(uint input)
{
    uint state = input * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

//随机种子
uint WangHash(uint seed)
{
    seed = (seed ^ 61) ^(seed >> 16);
    seed *= 9;
    seed = seed ^(seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^(seed >> 15);
    return seed;
}

// https://gamedev.stackexchange.com/questions/32681/random-number-hlsl
float rand_1_05(in float2 uv)
{
    float2 noise = (frac(sin(dot(uv ,float2(12.9898,78.233)*2.0)) * 43758.5453));
    return abs(noise.x + noise.y) * 0.5;
}

float2 rand_2_10(in float2 uv) {
    float noiseX = (frac(sin(dot(uv, float2(12.9898,78.233) * 2.0)) * 43758.5453));
    float noiseY = sqrt(1 - noiseX * noiseX);
    return float2(noiseX, noiseY);
}

float2 rand_2_0004(in float2 uv)
{
    float noiseX = (frac(sin(dot(uv, float2(12.9898,78.233)      )) * 43758.5453));
    float noiseY = (frac(sin(dot(uv, float2(12.9898,78.233) * 2.0)) * 43758.5453));
    return float2(noiseX, noiseY) * 0.004;
}

//计算均匀分布随机数[0,1)
float UniformRandom()
{
    // Xorshift算法
    rngState ^= (rngState << 13);
    rngState ^= (rngState >> 17);
    rngState ^= (rngState << 5);
    return rngState / 4294967296.0f;
}

// https://en.wikipedia.org/wiki/Normal_distribution#Generating_values_from_normal_distribution
float2 GaussianNoise_BoxMullerMethod(float2 input,float domainSize)
{
    rngState = WangHash(input.y * domainSize + input.x);
    // rngState = PcgHash(input.y * domainSize + input.x);
	
    float x1 = UniformRandom();
    float x2 = UniformRandom();

    float u = max(1e-6f,x1);
    float v = max(1e-6f,x2);
	
    float g1 = sqrt(-2.0f * log(u)) * cos(2.0f * PI * v);
    float g2 = sqrt(-2.0f * log(u)) * sin(2.0f * PI * v);
	
    return float2(g1,g2);
}