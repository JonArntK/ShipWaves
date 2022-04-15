#ifndef __FINITEWATERDISPERSIONRELATION_HLSL__
#define __FINITEWATERDISPERSIONRELATION_HLSL__

#include "HLSLMath.hlsl"

double FiniteWaterDispersionRelationDummy(double k, double fnh, double h, double theta)
{
    // The 'k' provided is a guess, used to compute a new and updated value for 'k'.
    return (double) fnh * (double) fnh * (double) k * (double) h * (double) cos((float) theta) * (double) cos((float) theta) - (double) CustomTanh((float) k * h);
}

double FiniteWaterDispersionRelationDerivativeDummy(double k, double fnh, double h, double theta)
{
    // k is a guess, used to compute a new k. Central differences are used to approximate the derivative.
    return ((double) FiniteWaterDispersionRelationDummy((double) k + (double) 1e-3, (double) fnh, (double) h, (double) theta) - (double) FiniteWaterDispersionRelationDummy((double) k - (double) 1e-3, (double) fnh, (double) h, (double) theta)) / (double) 2e-3;
}

double FiniteWaterDispersionRelation(double fnh, double h, double theta)
{
    // The dispersion relation is solved using Newton's method. Settings are:
    int max_iter = 50;
    double epsilon = 1e-10;

    // Initialize for use in Newton's method.
    double fxn, dfxn;

    // Define initial guess for k, herby denoted as x.
    double xn = 10.0;

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