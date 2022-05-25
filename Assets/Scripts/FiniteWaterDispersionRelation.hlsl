#ifndef __FINITEWATERDISPERSIONRELATION_HLSL__
#define __FINITEWATERDISPERSIONRELATION_HLSL__

#include "HLSLMath.hlsl"

float FiniteWaterDispersionRelationDummy(float k, float fnh, float h, float theta)
{
    // The 'k' provided is a guess, used to compute a new and updated value for 'k'.
    return (float) fnh * (float) fnh * (float) k * (float) h * (float) cos((float) theta) * (float) cos((float) theta) - (float) CustomTanh((float) k * h);
}

float FiniteWaterDispersionRelationDerivativeDummy(float k, float fnh, float h, float theta)
{
    // k is a guess, used to compute a new k. Central differences are used to approximate the derivative.
    return ((float) FiniteWaterDispersionRelationDummy((float) k + (float) 1e-3, (float) fnh, (float) h, (float) theta) - (float) FiniteWaterDispersionRelationDummy((float) k - (float) 1e-3, (float) fnh, (float) h, (float) theta)) / (float) 2e-3;
}

float FiniteWaterDispersionRelation(float fnh, float h, float theta)
{
    // The dispersion relation is solved using Newton's method. Settings are:
    int max_iter = 50;
    float epsilon = 1e-10;

    // Initialize for use in Newton's method.
    float fxn, dfxn;

    // Define initial guess for k, herby denoted as x.
    float xn = 10.0;

    for (int n = 0; n < max_iter; n++)
    {
        fxn = FiniteWaterDispersionRelationDummy(xn, fnh, h, theta);
        if (abs(fxn) < epsilon)     // A solution is found.
            return xn;
        
        dfxn = FiniteWaterDispersionRelationDerivativeDummy(xn, fnh, h, theta);
        if (dfxn == 0.0)    // No solution found.
            return xn;

        xn = xn - fxn / dfxn;
    }

    // No solution found.
    return xn;
}

#endif // __FINITEWATERDISPERSIONRELATION_HLSL__