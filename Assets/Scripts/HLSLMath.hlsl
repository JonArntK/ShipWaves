#ifndef __HLSLMATH_HLSL__
#define __HLSLMATH_HLSL__

#define PI 3.14159265358979323846
#define E 2.71828183
#define g 9.81

// Check if two numbers are equal.
bool IsClose(float a, float b)
{
    float eps = 1e-8;
    if (abs(a - b) < eps)
    {
        return true;
    }
    return false;
}

// Custom modulus function for floats.
float Mod(float x, float y)
{
    // Need to account for the floating point precision (32 bit (single type)) by adding 1e-5 to the number
    // being divided. If not, an error is seen for e.g. x = 126, y = 7 -> returning a positive number when 
    // it should be 0 exactly.
    return x - y * floor((x + 0.00001) / y);
}

// Standard rotation matrix about point (x0, z0) of given point (x, z).
float2 RotationMatrix(float x, float z, float theta, float x0, float z0)
{
    // Make (x0, z0) as origo to use the standard rotation matrix below.
    // Rotate the x- and z-coordinates theta radians in the clockwise direction.
    float xRotated = (x - x0) * cos(theta) - (z - z0) * sin(theta);
    float zRotated = (x - x0) * sin(theta) + (z - z0) * cos(theta);

    // Return to the original coordinate system where (x0, y0) is not origo.
    xRotated += x0;
    zRotated += z0;

    return float2(xRotated, zRotated);
}

// Complex number operations.
float2 c_add(float2 c1, float2 c2)
{
    float a = c1.x;
    float b = c1.y;
    float c = c2.x;
    float d = c2.y;
    return float2(a + c, b + d);
}
float2 c_sub(float2 c1, float2 c2)
{
    float a = c1.x;
    float b = c1.y;
    float c = c2.x;
    float d = c2.y;
    return float2(a - c, b - d);
}
float2 c_mul(float2 c1, float2 c2)
{
    float a = c1.x;
    float b = c1.y;
    float c = c2.x;
    float d = c2.y;
    return float2(a * c - b * d, b * c + a * d);
}
float2 c_div(float2 c1, float2 c2)
{
    float a = c1.x;
    float b = c1.y;
    float c = c2.x;
    float d = c2.y;
    float real = (a * c + b * d) / (c * c + d * d);
    float imag = (b * c - a * d) / (c * c + d * d);
    return float2(real, imag);
}
float c_abs(float2 c)
{
    return sqrt(c.x * c.x + c.y * c.y);
}
float2 c_pol(float2 c)
{
    float a = c.x;
    float b = c.y;
    float z = c_abs(c);
    float f = atan2(b, a);
    return float2(z, f);
}
float2 c_rec(float2 c)
{
    float z = abs(c.x);
    float f = c.y;
    float a = z * cos(f);
    float b = z * sin(f);
    return float2(a, b);
}
float2 c_pow(float2 base, float2 exp)
{
    float2 b = c_pol(base);
    float r = b.x;
    float f = b.y;
    float c = exp.x;
    float d = exp.y;
    float z = pow(r, c) * pow(E, -d * f);
    float fi = d * log(r) + c * f;
    float2 rpol = float2(z, fi);
    return c_rec(rpol);
}

float2 c_exp(float2 c)
{
    float a = exp(c.x) * cos(c.y);
    float b = exp(c.x) * sin(c.y);
    return float2(a, b);
}

#endif // __HLSLMATH_HLSL__