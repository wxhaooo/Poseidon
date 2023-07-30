#ifndef __STATISTICAL_OCEAN_MODEL_CGINC__
#define __STATISTICAL_OCEAN_MODEL_CGINC__

#include "Assets/Shader/Constant.cginc"
#include "Assets/Shader/MathHelper.cginc"

float Dispersion(float2 k)
{
	return sqrt(G * length(k));
}

float PhillipsSpectrum(float2 k, float windSpeed, float A, float windDirRadian, float dirDepend, float4 windAndSeed)
{
	float kLength = length(k);
	kLength = max(0.001f, kLength);
	// kLength = 1;
	float kLength2 = kLength * kLength;
	float kLength4 = kLength2 * kLength2;
	
	float windLength = length(windAndSeed.xy);
	float  l = windLength * windLength / G;
	float l2 = l * l;
	
	float damping = 0.001f;
	float L2 = l2 * damping * damping;
	
	//phillips spectrum
	return  A * exp(-1.0f / (kLength2 * l2)) / kLength4 * exp(-kLength2 * L2);
	
	// float kLength = length(k);
	// // if(kLength == 0.0f) return 0.0f;
	// kLength = max(0.001f,kLength);
	//
	// float kLength2 = kLength * kLength;
	// float kLength4 = kLength2 * kLength2;
	// float L = (windSpeed * windSpeed) / G;
	// float L2 = L * L;
	// float2 kNormalized = float2(k.x / kLength, k.y / kLength);
	// float wDotK = kNormalized.x * cos(windDirRadian) + kNormalized.y * sin(windDirRadian);
	//
	// float phillips = A * exp(-1.0f/(kLength2 * L2)) / kLength4;
	// if(wDotK < 0.0f) phillips*=dirDepend;
	//
	// return phillips;
}

float DonelanBannerDirectionalSpreading(float2 k, float windDirRadian, float windSpeed, float4 windAndSeed)
{
	float omega = Dispersion(k);
	float omegaP = 0.885f * G / length(windAndSeed.xy);
	float ratio = omega / omegaP;
	float betaS = 0.0f;
	if(ratio < 0.95f)
	{
		betaS = 2.61f * pow(ratio,1.3f);
	}
	else if(ratio >=0.95f && ratio < 1.6f)
	{
		betaS = 2.28f * pow(ratio,-1.3f);
	}
	else if(ratio >= 1.6f)
	{
		float eps = -0.4f + 0.8393f * exp(-0.567f * log(ratio * ratio));
		betaS = pow(10,eps);
	}

	float theta = atan2(k.y, k.x) - atan2(windAndSeed.y, windAndSeed.x);
	return betaS / max(0.0001f,2.0f * tanh(betaS * PI)) * pow(cosh(betaS * theta),2);
}

// float DonelanBannerDirectionalSpreading(float2 k,float windDirRadian,float windSpeed,float4 windAndSeed)
// {
// 	float2 windVec = float2(cos(windDirRadian),sin(windDirRadian)) * windSpeed;
// 	
// 	float omega = Dispersion(k);
//     float omegaP = 0.885f * G / windSpeed;
//     float ratio = omega / omegaP;
//     float betaS = 0.0f;
//     if(ratio < 0.95f)
//     {
//     	betaS = 2.61f * pow(ratio,1.3f);
//     }
//     else if(ratio >=0.95f && ratio < 1.6f)
//     {
//     	betaS = 2.28f * pow(ratio,-1.3f);
//     }
//     else if(ratio >= 1.6f)
//     {
//     	float eps = -0.4f + 0.8393f * exp(-0.567f * log(pow(ratio,2)));
//     	betaS = pow(10,eps);
//     }
//
//     float theta = atan2(k.y, k.x) - atan2(windVec.y, windVec.x);
//     return betaS / max(0.0001f,2.0f * tanh(betaS * PI)) * pow(cosh(betaS * theta),2);
// }

float PlainDirectionalSpreading(float2 k,float windDirRadian)
{
	float2 kNormalized = normalize(k);
	float wDotK = kNormalized.x * cos(windDirRadian) + kNormalized.y * sin(windDirRadian);
	return wDotK * wDotK;
}

float PhillipsSpectrumWithSpreading(int spreadingModelType, float2 k, float windSpeed, float A, float windDirRadian, float dirDepend,float4 windAndSeed)
{
	float phillipsSpectrumValue = PhillipsSpectrum(k,windSpeed,A,windDirRadian,dirDepend,windAndSeed);
	float directionalSpreading = 1.0f;

	if(spreadingModelType == 1)
		directionalSpreading = PlainDirectionalSpreading(k, windDirRadian);
	else if(spreadingModelType == 2)
		directionalSpreading = DonelanBannerDirectionalSpreading(k,windDirRadian,windSpeed, windAndSeed);

	return phillipsSpectrumValue * directionalSpreading;
}

float2 CalHeightSpectrum(int spreadingModelType, float2 k, float2 noise, float windSpeed, float A, float windDirRadian, float dirDepend,float time,float4 windAndSeed)
{
	float phillipsSpectrumValue0 = PhillipsSpectrumWithSpreading(spreadingModelType,k,windSpeed,A,windDirRadian,dirDepend,windAndSeed);
	float phillipsSpectrumValue1 = PhillipsSpectrumWithSpreading(spreadingModelType,-k,windSpeed,A,windDirRadian,dirDepend,windAndSeed);

	float2 h0 = noise * sqrt(abs(phillipsSpectrumValue0) / 2.0f);
	float2 h0Star = noise * sqrt(abs(phillipsSpectrumValue1) / 2.0f);
	h0Star = Conjugate(h0Star);

	float omega = Dispersion(k) * time;
	float c = cos(omega);
	float s = sin(omega);

	float2 hTilde = ComplexMultiply(h0,float2(c,s));
	float2 HTildeConjugate = ComplexMultiply(h0Star,float2(c,-s));

	return hTilde + HTildeConjugate;
}

#endif

