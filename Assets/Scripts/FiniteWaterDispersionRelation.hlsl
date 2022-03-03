#ifndef __FINITEWATERDISPERSIONRELATION_HLSL__
#define __FINITEWATERDISPERSIONRELATION_HLSL__

#include "HLSLMath.hlsl"

float FiniteWaterDispersionRelationDummy(float k, float fnh, float h, float theta)
{
    // k is a guess, used to compute a new k.
    return pow(fnh, 2) * k * h * pow(cos(theta), 2) - tanh(k * h);
}

float FiniteWaterDispersionRelationDerivativeDummy(float k, float fnh, float h, float theta)
{
    // k is a guess, used to compute a new k. Central differences are used to approximate the derivative.
    return (FiniteWaterDispersionRelationDummy(k + 0.001, fnh, h, theta) - FiniteWaterDispersionRelationDummy(k - 0.001, fnh, h, theta)) / 0.002;
}

float FiniteWaterDispersionRelation(float fnh, float h, float theta)
{
    // The dispersion relation is solved using Newton's method. Settings are:
    int max_iter = 50;
    float epsilon = 1e-6;

    // Initialize for use in Newton's method.
    float fxn, dfxn;

    // Define initial guess for k, herby denoted as x.
    float xn = 10.0;

    for (int n = 0; n < max_iter; n++)
    {
        fxn = FiniteWaterDispersionRelationDummy(xn, fnh, h, theta);
        if (abs(fxn) < epsilon)     // A solution is found.
        {
            return xn;
        }
        dfxn = FiniteWaterDispersionRelationDerivativeDummy(xn, fnh, h, theta);
        if (IsClose(dfxn, 0.0))     // Zero derivative. No solution is found.
        {
            return 0.0;
        }
        xn = xn - fxn / dfxn;
    }
    float k = xn;
    return k;
}

#endif // __FINITEWATERDISPERSIONRELATION_HLSL__