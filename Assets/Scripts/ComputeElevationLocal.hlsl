#include "HLSLMath.hlsl"

#define KELVIN_ANGLE 0.3398369095

float2 ComplexAmplitudeFunction(StructuredBuffer<float3> _VesselCoord, int _VesselNx, int _VesselNy, float theta, float U)
{
    float dx = _VesselCoord[_VesselNy].x - _VesselCoord[0].x;
    float dy = _VesselCoord[1].y - _VesselCoord[0].y;
    
    float P = 0.0;
    float Q = 0.0;

    float k0 = g / pow(U, 2.0);

    float K = k0 / pow(cos(theta), 2.0) * dy;
    float omega0 = (exp(K) - 1.0 - K) / pow(K, 2.0);
    float omegaNy = (exp(-K) - 1.0 + K) / pow(K, 2.0);
    float omegaJ = (exp(K) + exp(-K) - 2.0) / pow(K, 2.0);

    float K2 = k0 / cos(theta) * dx;
    float omegaEven = (3.0 * K2 + K2 * cos(2.0 * K2) - 2.0 * sin(2.0 * K2)) / pow(K2, 3.0);
    float omegaOdd = 4.0 * (sin(K2) - K2 * cos(K2)) / pow(K2, 3.0);

    for (int i = 0; i < _VesselNx; i++)
    {
        float F = 0.0;
        F += omega0 * _VesselCoord[i * _VesselNy + 0].z * exp(k0 * _VesselCoord[i * _VesselNy + 0].y / pow(cos(theta), 2.0)) * dy;
        F += omegaNy * _VesselCoord[i * _VesselNy + _VesselNy - 1].z * exp(k0 * _VesselCoord[i * _VesselNy + _VesselNy - 1].y / pow(cos(theta), 2.0)) * dy;
        for (int j = 1; j < _VesselNy - 1; j++)
        {
            F += omegaJ * _VesselCoord[i * _VesselNy + j].z * exp(k0 * _VesselCoord[i * _VesselNy + j].y / pow(cos(theta), 2.0)) * dy;
        }
        
        if (Mod(i, 2) == 0.0)
        {
            P += omegaEven * F * cos(k0 * _VesselCoord[i * _VesselNy].x / cos(theta)) * dx;
            Q += omegaEven * F * sin(k0 * _VesselCoord[i * _VesselNy].x / cos(theta)) * dx;
        }
        else
        {
            P += omegaOdd * F * cos(k0 * _VesselCoord[i * _VesselNy].x / cos(theta)) * dx;
            Q += omegaOdd * F * sin(k0 * _VesselCoord[i * _VesselNy].x / cos(theta)) * dx;
        }
    }

    float2 amp = float2(0.0, -2.0 / PI * pow(k0, 2.0) / pow(cos(theta), 4.0));
    float2 temp = c_mul(amp, float2(P, Q));
    return temp;
}

float ComputeShipWaveElevationLocal(float x, float z, StructuredBuffer<float3> _VesselCoord, int _VesselNx, int _VesselNy, float U)
{
    float k0 = g / pow(U, 2.0);

    // Compute polar coordinate equivalent to (x, z).
    float r = sqrt(pow(x, 2.0) + pow(z, 2.0));
    float alpha = atan2(z, x);
    alpha = abs(alpha);

    // If alpha is above the Kelvin half angle, the wave elevation is zero.
    float delta_boundary = 0.02;        // To avoid singularities at boundary equal to Kelvin angle.
    
    if (abs(alpha) >= KELVIN_ANGLE)
    {
        return float(0.0);
    }
    
    // For the method of stationary phase, dG/dtheta gives two solutions within the interval [-PI/2, PI/2] for theta;
    float2 theta = float2(alpha / 2.0 - 0.5 * asin(3.0 * sin(alpha)), 
                        -PI / 2.0 + alpha / 2.0 + 0.5 * asin(3.0 * sin(alpha)));


    // Each theta has its own amplitude (transverse and divergent wave amplitude)
    float2 A1 = ComplexAmplitudeFunction(_VesselCoord, _VesselNx, _VesselNy, theta.x, U);  // float2 since complex -> float2(real, imaginary)
    float2 A2 = ComplexAmplitudeFunction(_VesselCoord, _VesselNx, _VesselNy, theta.y, U);  // float2 since complex -> float2(real, imaginary)

    // Check if amplitude is nan (not a number) or inf (infinity). If so, set as zero.
    if (isnan(abs(A1.x)) || isnan(abs(A1.y)) || isinf(abs(A1.x)) || isinf(abs(A1.y)))
    {
        A1 = float2(0.0, 0.0);
    }
    if (isnan(abs(A2.x)) || isnan(abs(A2.y)) || isinf(abs(A2.x)) || isinf(abs(A2.y)))
    {
        A2 = float2(0.0, 0.0);
    }

    // Compute wave elevation.
    float amp = sqrt(2.0 * PI / k0 / r) * pow(abs(1.0 - 9.0 * pow(sin(alpha), 2.0)), -0.25);

    A1.x *= pow(abs(cos(theta.x)), 3.0 / 2.0);
    A1.y *= pow(abs(cos(theta.x)), 3.0 / 2.0);
    float2 temp1 = c_mul(A1, c_exp(float2(0.0, k0 * r * cos(theta.x - alpha) / pow(cos(theta.x), 2.0) + PI / 4.0)));

    A2.x *= pow(abs(cos(theta.y)), 3.0 / 2.0);
    A2.y *= pow(abs(cos(theta.y)), 3.0 / 2.0);
    float2 temp2 = c_mul(A2, c_exp(float2(0.0, k0 * r * cos(theta.y - alpha) / pow(cos(theta.y), 2.0) - PI / 4.0)));
    
    
    float zeta = amp * (temp1.x + temp2.x);     // Want the real part of the elevation.
    return zeta * 3.0;
}
