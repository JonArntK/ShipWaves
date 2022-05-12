#ifndef __HLSLMATH_HLSL__
#define __HLSLMATH_HLSL__

#define PI 3.14159265358979323846
#define E 2.71828183
#define g 9.81

// Check if two numbers are equal.
bool IsClose(float a, float b)
{
    float eps = 1e-7;
    if (abs(a - b) < eps)
    {
        return true;
    }
    return false;
}

float CustomTanh(float x)
{
    // Custom tanh function to ensure validity for large absolute values of 'x'.
    // Built-in 'tanh' returns 0 for large (negative) x.
    if (x > 10.0)
    {
        return 1.0;
    }
    else if (x < -10.0)
    {
        return -1.0;
    }
    else
    {
        return tanh(x);
    }
}

float slope(float2 p1, float2 p2)
{
    // Returns the slope computed from points p1 and p2 (slope 'a', where 'y = ax + b').
    return (p1.y - p2.y) / (p1.x - p2.x);
}

float intercept(float2 p1, float slope)
{
    // Returns the intercept computed from point p1 and its slope (intercept 'b', where 'y = ax + b').
    return p1.y - slope * p1.x;
}

float2 intersection(float2 p11, float2 p12, float2 p21, float2 p22)
{
    // Returns the intersection of the lines defined by the projections 'p11 - p12' and 'p21 - p22'.
    // Does not consider the interval limits.
    float px, py;
    
    // Compute the line corresponding to [p11, p12] as a linear function 'y = ax + b'.
    float line1Slope = slope(p11, p12);
    float line1Intercept = intercept(p12, line1Slope);
    
    float line2Slope = slope(p21, p22);
    float line2Intercept = intercept(p21, line2Slope);
    
    
    if (p11.x == p12.x)         // If slope of [p11, p12] is inifite (vertical line)
    {
        px = p11.x;
        py = line2Slope * px + line2Intercept;
    }
    else if (p21.x == p22.x)    // If slope of [p21, p22] is inifite (vertical line)
    {
        px = p21.x;
        py = line1Slope * px + line1Intercept;
    }
    else
    {
        // Locate where the original line intercepts the orthogonal line. The following vector from P to lineP 
        // is by definition half the distance of the reflection.
        px = (line2Intercept - line1Intercept) / (line1Slope - line2Slope);
        py = line1Slope * px + line1Intercept;
    }
    
    return float2(px, py);
}

float Mod(float x, float y)
{
    // Custom modulus function for floats.
    
    // Need to account for the floating point precision (32 bit (single type)) by adding 1e-5 to the number
    // being divided. If not, an error is seen for e.g. x = 126, y = 7 -> returning a positive number when 
    // it should be 0 exactly.
    return x - y * floor((x + 0.00001) / y);
}

bool IsEven(int x)
{
    float xf = float(x);
    while (xf > 0.1)
    {
        xf -= 2.0;
    }
    
    if (abs(xf) < 0.1)
        return true;
    else
        return false;
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

// Convert an index in 1D to 3D.
int3 Matrix1DTo3D(int index, int D1, int D2, int D3)
{
    int x = (int) Mod(index, D1);
    int y = (int) Mod((index - x) / D1, D2);
    int z = (int) Mod((index - y * D1 - x) / (D1 * D2), D3);
    return int3(x, y, z);
}

// Convert an index in 3D to 1D.
int Matrix3DTo1D(int x, int y, int z, int D1, int D2, int D3)
{
    return (int) (x + y * D1 + z * D1 * D2);
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