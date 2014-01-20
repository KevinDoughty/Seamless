/*
 * Copyright (C) 2005, 2006 Apple Computer, Inc.  All rights reserved.
 * Copyright (C) 2009 Torch Mobile, Inc.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE COMPUTER, INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE COMPUTER, INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// This file has been heavily modified from the original WebKit source, TransformationMatrix.cpp

#import <QuartzCore/QuartzCore.h>

typedef struct {
    double scaleX, scaleY, scaleZ;
    double skewXY, skewXZ, skewYZ;
    double quaternionX, quaternionY, quaternionZ, quaternionW;
    double translateX, translateY, translateZ;
    double perspectiveX, perspectiveY, perspectiveZ, perspectiveW;
} SeamlessDecomposedType;

typedef double SeamlessVector4[4];
typedef double SeamlessVector3[3];
typedef double SeamlessMatrix4[4][4];

static const double SEAMLESS_SMALL_NUMBER = 1.e-8;

//void logTransform(CATransform3D t) {
//    NSLog(@"================= T");
//    NSLog(@"%f %f %f %f",t.m11,t.m21,t.m31,t.m41);
//    NSLog(@"%f %f %f %f",t.m12,t.m22,t.m32,t.m42);
//    NSLog(@"%f %f %f %f",t.m13,t.m23,t.m33,t.m43);
//    NSLog(@"%f %f %f %f",t.m14,t.m24,t.m34,t.m44);
//    NSLog(@"=================");
//}
//void logMatrix(SeamlessMatrix4 m) {
//    NSLog(@"================= M");
//    NSLog(@"%f %f %f %f",m[0][0],m[1][0],m[2][0],m[3][0]);
//    NSLog(@"%f %f %f %f",m[0][1],m[1][1],m[2][1],m[3][1]);
//    NSLog(@"%f %f %f %f",m[0][2],m[1][2],m[2][2],m[3][2]);
//    NSLog(@"%f %f %f %f",m[0][3],m[1][3],m[2][3],m[3][3]);
//    NSLog(@"=================");
//}
//void logDecomposed(SeamlessDecomposedType d) {
//    NSLog(@"================= D");
//    NSLog(@"scale %f %f %f",d.scaleX, d.scaleY, d.scaleZ);
//    NSLog(@"skew %f %f %f",d.skewXY, d.skewXZ, d.skewYZ);
//    NSLog(@"quat %f %f %f %f",d.quaternionX, d.quaternionY, d.quaternionZ, d.quaternionW);
//    NSLog(@"trans %f %f %f",d.translateX, d.translateY, d.translateZ);
//    NSLog(@"persp %f %f %f %f",d.perspectiveX, d.perspectiveY, d.perspectiveZ, d.perspectiveW);
//    NSLog(@"=================");
//}

static void seamlessMakeMatrix(CATransform3D t, SeamlessMatrix4 m_matrix) {
    m_matrix[0][0] = t.m11; m_matrix[0][1] = t.m12; m_matrix[0][2] = t.m13; m_matrix[0][3] = t.m14;
    m_matrix[1][0] = t.m21; m_matrix[1][1] = t.m22; m_matrix[1][2] = t.m23; m_matrix[1][3] = t.m24;
    m_matrix[2][0] = t.m31; m_matrix[2][1] = t.m32; m_matrix[2][2] = t.m33; m_matrix[2][3] = t.m34;
    m_matrix[3][0] = t.m41; m_matrix[3][1] = t.m42; m_matrix[3][2] = t.m43; m_matrix[3][3] = t.m44;
}

static CATransform3D seamlessMakeTransform(SeamlessMatrix4 m_matrix) {
    CATransform3D t;
    t.m11 = m_matrix[0][0]; t.m12 = m_matrix[0][1]; t.m13 = m_matrix[0][2]; t.m14 = m_matrix[0][3];
    t.m21 = m_matrix[1][0]; t.m22 = m_matrix[1][1]; t.m23 = m_matrix[1][2]; t.m24 = m_matrix[1][3];
    t.m31 = m_matrix[2][0]; t.m32 = m_matrix[2][1]; t.m33 = m_matrix[2][2]; t.m34 = m_matrix[2][3];
    t.m41 = m_matrix[3][0]; t.m42 = m_matrix[3][1]; t.m43 = m_matrix[3][2]; t.m44 = m_matrix[3][3];
    return t;
}

static void seamlessAssignMatrix(SeamlessMatrix4 m_matrix, SeamlessMatrix4 m) {
    m_matrix[0][0] = m[0][0]; m_matrix[0][1] = m[0][1]; m_matrix[0][2] = m[0][2]; m_matrix[0][3] = m[0][3];
    m_matrix[1][0] = m[1][0]; m_matrix[1][1] = m[1][1]; m_matrix[1][2] = m[1][2]; m_matrix[1][3] = m[1][3];
    m_matrix[2][0] = m[2][0]; m_matrix[2][1] = m[2][1]; m_matrix[2][2] = m[2][2]; m_matrix[2][3] = m[2][3];
    m_matrix[3][0] = m[3][0]; m_matrix[3][1] = m[3][1]; m_matrix[3][2] = m[3][2]; m_matrix[3][3] = m[3][3];
}

static void seamlessSetMatrix(SeamlessMatrix4 m_matrix, double m11, double m12, double m13, double m14,
                              double m21, double m22, double m23, double m24,
                              double m31, double m32, double m33, double m34,
                              double m41, double m42, double m43, double m44) {
    m_matrix[0][0] = m11; m_matrix[0][1] = m12; m_matrix[0][2] = m13; m_matrix[0][3] = m14;
    m_matrix[1][0] = m21; m_matrix[1][1] = m22; m_matrix[1][2] = m23; m_matrix[1][3] = m24;
    m_matrix[2][0] = m31; m_matrix[2][1] = m32; m_matrix[2][2] = m33; m_matrix[2][3] = m34;
    m_matrix[3][0] = m41; m_matrix[3][1] = m42; m_matrix[3][2] = m43; m_matrix[3][3] = m44;
}

static void seamlessMakeIdentity(SeamlessMatrix4 m) {
    seamlessSetMatrix(m, 1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0,  0, 0, 0, 1);
}

static bool seamlessIsIdentityMatrix(SeamlessMatrix4 m_matrix) {
    return m_matrix[0][0] == 1 && m_matrix[0][1] == 0 && m_matrix[0][2] == 0 && m_matrix[0][3] == 0 &&
    m_matrix[1][0] == 0 && m_matrix[1][1] == 1 && m_matrix[1][2] == 0 && m_matrix[1][3] == 0 &&
    m_matrix[2][0] == 0 && m_matrix[2][1] == 0 && m_matrix[2][2] == 1 && m_matrix[2][3] == 0 &&
    m_matrix[3][0] == 0 && m_matrix[3][1] == 0 && m_matrix[3][2] == 0 && m_matrix[3][3] == 1;
}

static inline void seamlessBlendFloat(double *from, double to, double progress) {
    if (*from != to) *from = *from + (to - *from) * progress;
}

static void seamlessSlerp(double qa[4], const double qb[4], double t) {
    double ax, ay, az, aw;
    double bx, by, bz, bw;
    double cx, cy, cz, cw;
    double angle;
    double th, invth, scale, invscale;
    
    ax = qa[0]; ay = qa[1]; az = qa[2]; aw = qa[3];
    bx = qb[0]; by = qb[1]; bz = qb[2]; bw = qb[3];
    
    angle = ax * bx + ay * by + az * bz + aw * bw;
    
    if (angle < 0.0) {
        ax = -ax; ay = -ay;
        az = -az; aw = -aw;
        angle = -angle;
    }
    
    if (angle + 1.0 > .05) {
        if (1.0 - angle >= .05) {
            th = acos (angle);
            invth = 1.0 / sin (th);
            scale = sin (th * (1.0 - t)) * invth;
            invscale = sin (th * t) * invth;
        } else {
            scale = 1.0 - t;
            invscale = t;
        }
    } else {
        bx = -ay;
        by = ax;
        bz = -aw;
        bw = az;
        scale = sin(M_PI * (.5 - t));
        invscale = sin (M_PI * t);
    }
    
    cx = ax * scale + bx * invscale;
    cy = ay * scale + by * invscale;
    cz = az * scale + bz * invscale;
    cw = aw * scale + bw * invscale;
    
    qa[0] = cx; qa[1] = cy; qa[2] = cz; qa[3] = cw;
}

static void seamlessTranslate3d(SeamlessMatrix4 m_matrix, double tx, double ty, double tz) {
    m_matrix[3][0] += tx * m_matrix[0][0] + ty * m_matrix[1][0] + tz * m_matrix[2][0];
    m_matrix[3][1] += tx * m_matrix[0][1] + ty * m_matrix[1][1] + tz * m_matrix[2][1];
    m_matrix[3][2] += tx * m_matrix[0][2] + ty * m_matrix[1][2] + tz * m_matrix[2][2];
    m_matrix[3][3] += tx * m_matrix[0][3] + ty * m_matrix[1][3] + tz * m_matrix[2][3];
}

static void seamlessMultiply(SeamlessMatrix4 m_matrix, SeamlessMatrix4 mat_m_matrix, SeamlessMatrix4 tmp) { // old, new, result
    
    
    tmp[0][0] = (mat_m_matrix[0][0] * m_matrix[0][0] + mat_m_matrix[0][1] * m_matrix[1][0]
                 + mat_m_matrix[0][2] * m_matrix[2][0] + mat_m_matrix[0][3] * m_matrix[3][0]);
    tmp[0][1] = (mat_m_matrix[0][0] * m_matrix[0][1] + mat_m_matrix[0][1] * m_matrix[1][1]
                 + mat_m_matrix[0][2] * m_matrix[2][1] + mat_m_matrix[0][3] * m_matrix[3][1]);
    tmp[0][2] = (mat_m_matrix[0][0] * m_matrix[0][2] + mat_m_matrix[0][1] * m_matrix[1][2]
                 + mat_m_matrix[0][2] * m_matrix[2][2] + mat_m_matrix[0][3] * m_matrix[3][2]);
    tmp[0][3] = (mat_m_matrix[0][0] * m_matrix[0][3] + mat_m_matrix[0][1] * m_matrix[1][3]
                 + mat_m_matrix[0][2] * m_matrix[2][3] + mat_m_matrix[0][3] * m_matrix[3][3]);
    
    tmp[1][0] = (mat_m_matrix[1][0] * m_matrix[0][0] + mat_m_matrix[1][1] * m_matrix[1][0]
                 + mat_m_matrix[1][2] * m_matrix[2][0] + mat_m_matrix[1][3] * m_matrix[3][0]);
    tmp[1][1] = (mat_m_matrix[1][0] * m_matrix[0][1] + mat_m_matrix[1][1] * m_matrix[1][1]
                 + mat_m_matrix[1][2] * m_matrix[2][1] + mat_m_matrix[1][3] * m_matrix[3][1]);
    tmp[1][2] = (mat_m_matrix[1][0] * m_matrix[0][2] + mat_m_matrix[1][1] * m_matrix[1][2]
                 + mat_m_matrix[1][2] * m_matrix[2][2] + mat_m_matrix[1][3] * m_matrix[3][2]);
    tmp[1][3] = (mat_m_matrix[1][0] * m_matrix[0][3] + mat_m_matrix[1][1] * m_matrix[1][3]
                 + mat_m_matrix[1][2] * m_matrix[2][3] + mat_m_matrix[1][3] * m_matrix[3][3]);
    
    tmp[2][0] = (mat_m_matrix[2][0] * m_matrix[0][0] + mat_m_matrix[2][1] * m_matrix[1][0]
                 + mat_m_matrix[2][2] * m_matrix[2][0] + mat_m_matrix[2][3] * m_matrix[3][0]);
    tmp[2][1] = (mat_m_matrix[2][0] * m_matrix[0][1] + mat_m_matrix[2][1] * m_matrix[1][1]
                 + mat_m_matrix[2][2] * m_matrix[2][1] + mat_m_matrix[2][3] * m_matrix[3][1]);
    tmp[2][2] = (mat_m_matrix[2][0] * m_matrix[0][2] + mat_m_matrix[2][1] * m_matrix[1][2]
                 + mat_m_matrix[2][2] * m_matrix[2][2] + mat_m_matrix[2][3] * m_matrix[3][2]);
    tmp[2][3] = (mat_m_matrix[2][0] * m_matrix[0][3] + mat_m_matrix[2][1] * m_matrix[1][3]
                 + mat_m_matrix[2][2] * m_matrix[2][3] + mat_m_matrix[2][3] * m_matrix[3][3]);
    
    tmp[3][0] = (mat_m_matrix[3][0] * m_matrix[0][0] + mat_m_matrix[3][1] * m_matrix[1][0]
                 + mat_m_matrix[3][2] * m_matrix[2][0] + mat_m_matrix[3][3] * m_matrix[3][0]);
    tmp[3][1] = (mat_m_matrix[3][0] * m_matrix[0][1] + mat_m_matrix[3][1] * m_matrix[1][1]
                 + mat_m_matrix[3][2] * m_matrix[2][1] + mat_m_matrix[3][3] * m_matrix[3][1]);
    tmp[3][2] = (mat_m_matrix[3][0] * m_matrix[0][2] + mat_m_matrix[3][1] * m_matrix[1][2]
                 + mat_m_matrix[3][2] * m_matrix[2][2] + mat_m_matrix[3][3] * m_matrix[3][2]);
    tmp[3][3] = (mat_m_matrix[3][0] * m_matrix[0][3] + mat_m_matrix[3][1] * m_matrix[1][3]
                 + mat_m_matrix[3][2] * m_matrix[2][3] + mat_m_matrix[3][3] * m_matrix[3][3]);
    
}

static void seamlessScaleNonUniform(SeamlessMatrix4 m_matrix, double sx, double sy) {
    m_matrix[0][0] *= sx;
    m_matrix[0][1] *= sx;
    m_matrix[0][2] *= sx;
    m_matrix[0][3] *= sx;
    m_matrix[1][0] *= sy;
    m_matrix[1][1] *= sy;
    m_matrix[1][2] *= sy;
    m_matrix[1][3] *= sy;
}

static void seamlessScale3d(SeamlessMatrix4 m_matrix, double sx, double sy, double sz) {
    seamlessScaleNonUniform(m_matrix, sx, sy);
    m_matrix[2][0] *= sz;
    m_matrix[2][1] *= sz;
    m_matrix[2][2] *= sz;
    m_matrix[2][3] *= sz;
}

static void seamlessRecompose(const SeamlessDecomposedType decomp, SeamlessMatrix4 m_matrix) {
    seamlessMakeIdentity(m_matrix);
    
    // first apply perspective
    m_matrix[0][3] = decomp.perspectiveX;
    m_matrix[1][3] = decomp.perspectiveY;
    m_matrix[2][3] = decomp.perspectiveZ;
    m_matrix[3][3] = decomp.perspectiveW;
    
    // now translate
    seamlessTranslate3d(m_matrix, decomp.translateX, decomp.translateY, decomp.translateZ);
    
    // apply rotation
    double xx = decomp.quaternionX * decomp.quaternionX;
    double xy = decomp.quaternionX * decomp.quaternionY;
    double xz = decomp.quaternionX * decomp.quaternionZ;
    double xw = decomp.quaternionX * decomp.quaternionW;
    double yy = decomp.quaternionY * decomp.quaternionY;
    double yz = decomp.quaternionY * decomp.quaternionZ;
    double yw = decomp.quaternionY * decomp.quaternionW;
    double zz = decomp.quaternionZ * decomp.quaternionZ;
    double zw = decomp.quaternionZ * decomp.quaternionW;
    
    // Construct a composite rotation matrix from the quaternion values
    SeamlessMatrix4 rotationMatrix;
    seamlessSetMatrix(rotationMatrix, 1 - 2 * (yy + zz), 2 * (xy - zw), 2 * (xz + yw), 0,
                      2 * (xy + zw), 1 - 2 * (xx + zz), 2 * (yz - xw), 0,
                      2 * (xz - yw), 2 * (yz + xw), 1 - 2 * (xx + yy), 0,
                      0, 0, 0, 1);
    
    
    SeamlessMatrix4 value;
    seamlessMultiply(m_matrix,rotationMatrix,value);
    seamlessAssignMatrix(m_matrix, value);
    
    // now apply skew
    if (decomp.skewYZ) {
        SeamlessMatrix4 tmp;
        seamlessMakeIdentity(tmp);
        tmp[2][1] = decomp.skewYZ;
        seamlessMultiply(m_matrix,tmp,value);
        seamlessAssignMatrix(m_matrix, value);
    }
    if (decomp.skewXZ) {
        SeamlessMatrix4 tmp;
        seamlessMakeIdentity(tmp);
        tmp[2][0] = decomp.skewXZ;
        seamlessMultiply(m_matrix,tmp,value);
        seamlessAssignMatrix(m_matrix, value);
    }
    if (decomp.skewXY) {
        SeamlessMatrix4 tmp;
        seamlessMakeIdentity(tmp);
        tmp[1][0] = decomp.skewXY;
        seamlessMultiply(m_matrix,tmp,value);
        seamlessAssignMatrix(m_matrix, value);
    }
    
    // finally, apply scale
    seamlessScale3d(m_matrix,decomp.scaleX, decomp.scaleY, decomp.scaleZ);
}


static double seamlessDeterminant2x2(double a, double b, double c, double d) {
    return a * d - b * c;
}

//  double = determinant3x3(a1, a2, a3, b1, b2, b3, c1, c2, c3)
//
//  Calculate the determinant of a 3x3 matrix
//  in the form
//
//      | a1,  b1,  c1 |
//      | a2,  b2,  c2 |
//      | a3,  b3,  c3 |

static double seamlessDeterminant3x3(double a1, double a2, double a3, double b1, double b2, double b3, double c1, double c2, double c3) {
    return a1 * seamlessDeterminant2x2(b2, b3, c2, c3)
    - b1 * seamlessDeterminant2x2(a2, a3, c2, c3)
    + c1 * seamlessDeterminant2x2(a2, a3, b2, b3);
}
static inline double seamlessDeterminant4x4(const SeamlessMatrix4 m) {
    // Assign to individual variable names to aid selecting
    // correct elements
    
    double a1 = m[0][0];
    double b1 = m[0][1];
    double c1 = m[0][2];
    double d1 = m[0][3];
    
    double a2 = m[1][0];
    double b2 = m[1][1];
    double c2 = m[1][2];
    double d2 = m[1][3];
    
    double a3 = m[2][0];
    double b3 = m[2][1];
    double c3 = m[2][2];
    double d3 = m[2][3];
    
    double a4 = m[3][0];
    double b4 = m[3][1];
    double c4 = m[3][2];
    double d4 = m[3][3];
    
    return a1 * seamlessDeterminant3x3(b2, b3, b4, c2, c3, c4, d2, d3, d4)
    - b1 * seamlessDeterminant3x3(a2, a3, a4, c2, c3, c4, d2, d3, d4)
    + c1 * seamlessDeterminant3x3(a2, a3, a4, b2, b3, b4, d2, d3, d4)
    - d1 * seamlessDeterminant3x3(a2, a3, a4, b2, b3, b4, c2, c3, c4);
}


static void seamlessAdjoint(SeamlessMatrix4 *matrix, SeamlessMatrix4 *result) {
    // Assign to individual variable names to aid
    // selecting correct values
    double a1 = *matrix[0][0];
    double b1 = *matrix[0][1];
    double c1 = *matrix[0][2];
    double d1 = *matrix[0][3];
    
    double a2 = *matrix[1][0];
    double b2 = *matrix[1][1];
    double c2 = *matrix[1][2];
    double d2 = *matrix[1][3];
    
    double a3 = *matrix[2][0];
    double b3 = *matrix[2][1];
    double c3 = *matrix[2][2];
    double d3 = *matrix[2][3];
    
    double a4 = *matrix[3][0];
    double b4 = *matrix[3][1];
    double c4 = *matrix[3][2];
    double d4 = *matrix[3][3];
    
    // Row column labeling reversed since we transpose rows & columns
    *result[0][0]  =   seamlessDeterminant3x3(b2, b3, b4, c2, c3, c4, d2, d3, d4);
    *result[1][0]  = - seamlessDeterminant3x3(a2, a3, a4, c2, c3, c4, d2, d3, d4);
    *result[2][0]  =   seamlessDeterminant3x3(a2, a3, a4, b2, b3, b4, d2, d3, d4);
    *result[3][0]  = - seamlessDeterminant3x3(a2, a3, a4, b2, b3, b4, c2, c3, c4);
    
    *result[0][1]  = - seamlessDeterminant3x3(b1, b3, b4, c1, c3, c4, d1, d3, d4);
    *result[1][1]  =   seamlessDeterminant3x3(a1, a3, a4, c1, c3, c4, d1, d3, d4);
    *result[2][1]  = - seamlessDeterminant3x3(a1, a3, a4, b1, b3, b4, d1, d3, d4);
    *result[3][1]  =   seamlessDeterminant3x3(a1, a3, a4, b1, b3, b4, c1, c3, c4);
    
    *result[0][2]  =   seamlessDeterminant3x3(b1, b2, b4, c1, c2, c4, d1, d2, d4);
    *result[1][2]  = - seamlessDeterminant3x3(a1, a2, a4, c1, c2, c4, d1, d2, d4);
    *result[2][2]  =   seamlessDeterminant3x3(a1, a2, a4, b1, b2, b4, d1, d2, d4);
    *result[3][2]  = - seamlessDeterminant3x3(a1, a2, a4, b1, b2, b4, c1, c2, c4);
    
    *result[0][3]  = - seamlessDeterminant3x3(b1, b2, b3, c1, c2, c3, d1, d2, d3);
    *result[1][3]  =   seamlessDeterminant3x3(a1, a2, a3, c1, c2, c3, d1, d2, d3);
    *result[2][3]  = - seamlessDeterminant3x3(a1, a2, a3, b1, b2, b3, d1, d2, d3);
    *result[3][3]  =   seamlessDeterminant3x3(a1, a2, a3, b1, b2, b3, c1, c2, c3);
}

static bool seamlessInverse(SeamlessMatrix4 *matrix, SeamlessMatrix4 *result) {
    // Calculate the adjoint matrix
    seamlessAdjoint(matrix, result);
    
    // Calculate the 4x4 determinant
    // If the determinant is zero,
    // then the inverse matrix is not unique.
    double det = seamlessDeterminant4x4(*matrix);
    
    if (fabs(det) < SEAMLESS_SMALL_NUMBER)
        return false;
    
    // Scale the adjoint matrix to get the inverse
    
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            *result[i][j] = *result[i][j] / det;
    
    return true;
}

// End of code adapted from Matrix Inversion by Richard Carling

// Perform a decomposition on the passed matrix, return false if unsuccessful
// From Graphics Gems: unmatrix.c

// Transpose rotation portion of matrix a, return b
static void seamlessTransposeMatrix4(SeamlessMatrix4* a, SeamlessMatrix4* b) {
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++)
            *b[i][j] = *a[j][i];
}

// Multiply a homogeneous point by a matrix and return the transformed point
static void seamlessV4MulPointByMatrix(const SeamlessVector4 p, const SeamlessMatrix4 *m, SeamlessVector4 result) {
    result[0] = (p[0] * *m[0][0]) + (p[1] * *m[1][0]) +
    (p[2] * *m[2][0]) + (p[3] * *m[3][0]);
    result[1] = (p[0] * *m[0][1]) + (p[1] * *m[1][1]) +
    (p[2] * *m[2][1]) + (p[3] * *m[3][1]);
    result[2] = (p[0] * *m[0][2]) + (p[1] * *m[1][2]) +
    (p[2] * *m[2][2]) + (p[3] * *m[3][2]);
    result[3] = (p[0] * *m[0][3]) + (p[1] * *m[1][3]) +
    (p[2] * *m[2][3]) + (p[3] * *m[3][3]);
}


static double seamlessV3Length(SeamlessVector3 a) {
    return sqrt((a[0] * a[0]) + (a[1] * a[1]) + (a[2] * a[2]));
}

static void seamlessV3Scale(SeamlessVector3 v, double desiredLength) {
    double len = seamlessV3Length(v);
    if (len != 0) {
        double l = desiredLength / len;
        v[0] *= l;
        v[1] *= l;
        v[2] *= l;
    }
}

static double seamlessV3Dot(const SeamlessVector3 a, const SeamlessVector3 b) {
    return (a[0] * b[0]) + (a[1] * b[1]) + (a[2] * b[2]);
}

// Make a linear combination of two vectors and return the result.
// result = (a * ascl) + (b * bscl)
static void seamlessV3Combine(const SeamlessVector3 a, const SeamlessVector3 b, SeamlessVector3 result, double ascl, double bscl) {
    result[0] = (ascl * a[0]) + (bscl * b[0]);
    result[1] = (ascl * a[1]) + (bscl * b[1]);
    result[2] = (ascl * a[2]) + (bscl * b[2]);
}

// Return the cross product result = a cross b
static void seamlessV3Cross(const SeamlessVector3 a, const SeamlessVector3 b, SeamlessVector3 result) {
    result[0] = (a[1] * b[2]) - (a[2] * b[1]);
    result[1] = (a[2] * b[0]) - (a[0] * b[2]);
    result[2] = (a[0] * b[1]) - (a[1] * b[0]);
}

static bool seamlessDecompose(SeamlessDecomposedType *decomp, SeamlessMatrix4 m_matrix) {
    if (seamlessIsIdentityMatrix(m_matrix)) {
        memset(decomp, 0, sizeof(&decomp));
        decomp->perspectiveW = 1;
        decomp->scaleX = 1;
        decomp->scaleY = 1;
        decomp->scaleZ = 1;
    }
    
    SeamlessDecomposedType *result = decomp;
    
    SeamlessMatrix4 localMatrix;
    memcpy(*localMatrix, *m_matrix, sizeof(SeamlessMatrix4));
    
    // Normalize the matrix.
    if (localMatrix[3][3] == 0) {
        return false;
    }
    int i, j;
    for (i = 0; i < 4; i++)
        for (j = 0; j < 4; j++)
            localMatrix[i][j] /= localMatrix[3][3];
    
    // perspectiveMatrix is used to solve for perspective, but it also provides
    // an easy way to test for singularity of the upper 3x3 component.
    SeamlessMatrix4 perspectiveMatrix;
    memcpy(&perspectiveMatrix, &localMatrix, sizeof(SeamlessMatrix4));
    for (i = 0; i < 3; i++)
        perspectiveMatrix[i][3] = 0;
    perspectiveMatrix[3][3] = 1;
    
    if (seamlessDeterminant4x4(perspectiveMatrix) == 0) {
        return false;
    }
    // First, isolate perspective.  This is the messiest.
    if (localMatrix[0][3] != 0 || localMatrix[1][3] != 0 || localMatrix[2][3] != 0) {
        // rightHandSide is the right hand side of the equation.
        SeamlessVector4 rightHandSide;
        rightHandSide[0] = localMatrix[0][3];
        rightHandSide[1] = localMatrix[1][3];
        rightHandSide[2] = localMatrix[2][3];
        rightHandSide[3] = localMatrix[3][3];
        
        // Solve the equation by inverting perspectiveMatrix and multiplying
        // rightHandSide by the inverse.  (This is the easiest way, not
        // necessarily the best.)
        SeamlessMatrix4 inversePerspectiveMatrix, transposedInversePerspectiveMatrix;
        seamlessInverse(&perspectiveMatrix, &inversePerspectiveMatrix);
        seamlessTransposeMatrix4(&inversePerspectiveMatrix, &transposedInversePerspectiveMatrix);
        
        SeamlessVector4 perspectivePoint;
        seamlessV4MulPointByMatrix(rightHandSide, &transposedInversePerspectiveMatrix, perspectivePoint);
        
        result->perspectiveX = perspectivePoint[0];
        result->perspectiveY = perspectivePoint[1];
        result->perspectiveZ = perspectivePoint[2];
        result->perspectiveW = perspectivePoint[3];
        
        // Clear the perspective partition
        localMatrix[0][3] = localMatrix[1][3] = localMatrix[2][3] = 0;
        localMatrix[3][3] = 1;
    } else {
        // No perspective.
        result->perspectiveX = result->perspectiveY = result->perspectiveZ = 0;
        result->perspectiveW = 1;
    }
    
    
    
    // Next take care of translation (easy).
    result->translateX = localMatrix[3][0];
    localMatrix[3][0] = 0;
    result->translateY = localMatrix[3][1];
    localMatrix[3][1] = 0;
    result->translateZ = localMatrix[3][2];
    localMatrix[3][2] = 0;
    
    // Vector4 type and functions need to be added to the common set.
    SeamlessVector3 row[3], pdum3;
    
    // Now get scale and shear.
    for (i = 0; i < 3; i++) {
        row[i][0] = localMatrix[i][0];
        row[i][1] = localMatrix[i][1];
        row[i][2] = localMatrix[i][2];
    }
    
    // Compute X scale factor and normalize first row.
    result->scaleX = seamlessV3Length(row[0]);
    seamlessV3Scale(row[0], 1.0);
    
    // Compute XY shear factor and make 2nd row orthogonal to 1st.
    result->skewXY = seamlessV3Dot(row[0], row[1]);
    seamlessV3Combine(row[1], row[0], row[1], 1.0, -result->skewXY);
    
    // Now, compute Y scale and normalize 2nd row.
    result->scaleY = seamlessV3Length(row[1]);
    seamlessV3Scale(row[1], 1.0);
    result->skewXY /= result->scaleY;
    
    // Compute XZ and YZ shears, orthogonalize 3rd row.
    result->skewXZ = seamlessV3Dot(row[0], row[2]);
    seamlessV3Combine(row[2], row[0], row[2], 1.0, -result->skewXZ);
    result->skewYZ = seamlessV3Dot(row[1], row[2]);
    seamlessV3Combine(row[2], row[1], row[2], 1.0, -result->skewYZ);
    
    // Next, get Z scale and normalize 3rd row.
    result->scaleZ = seamlessV3Length(row[2]);
    seamlessV3Scale(row[2], 1.0);
    result->skewXZ /= result->scaleZ;
    result->skewYZ /= result->scaleZ;
    
    // At this point, the matrix (in rows[]) is orthonormal.
    // Check for a coordinate system flip.  If the determinant
    // is -1, then negate the matrix and the scaling factors.
    seamlessV3Cross(row[1], row[2], pdum3);
    if (seamlessV3Dot(row[0], pdum3) < 0) {
        
        result->scaleX *= -1;
        result->scaleY *= -1;
        result->scaleZ *= -1;
        
        for (i = 0; i < 3; i++) {
            row[i][0] *= -1;
            row[i][1] *= -1;
            row[i][2] *= -1;
        }
    }
    
    // Now, get the rotations out, as described in the gem.
    
    // FIXME - Add the ability to return either quaternions (which are
    // easier to recompose with) or Euler angles (rx, ry, rz), which
    // are easier for authors to deal with. The latter will only be useful
    // when we fix https://bugs.webkit.org/show_bug.cgi?id=23799, so I
    // will leave the Euler angle code here for now.
    
    // ret.rotateY = asin(-row[0][2]);
    // if (cos(ret.rotateY) != 0) {
    //     ret.rotateX = atan2(row[1][2], row[2][2]);
    //     ret.rotateZ = atan2(row[0][1], row[0][0]);
    // } else {
    //     ret.rotateX = atan2(-row[2][0], row[1][1]);
    //     ret.rotateZ = 0;
    // }
    
    double s, t, x, y, z, w;
    
    t = row[0][0] + row[1][1] + row[2][2] + 1.0;
    
    if (t > 1e-4) {
        s = 0.5 / sqrt(t);
        w = 0.25 / s;
        x = (row[2][1] - row[1][2]) * s;
        y = (row[0][2] - row[2][0]) * s;
        z = (row[1][0] - row[0][1]) * s;
    } else if (row[0][0] > row[1][1] && row[0][0] > row[2][2]) {
        s = sqrt (1.0 + row[0][0] - row[1][1] - row[2][2]) * 2.0; // S=4*qx
        x = 0.25 * s;
        y = (row[0][1] + row[1][0]) / s;
        z = (row[0][2] + row[2][0]) / s;
        w = (row[2][1] - row[1][2]) / s;
    } else if (row[1][1] > row[2][2]) {
        s = sqrt (1.0 + row[1][1] - row[0][0] - row[2][2]) * 2.0; // S=4*qy
        x = (row[0][1] + row[1][0]) / s;
        y = 0.25 * s;
        z = (row[1][2] + row[2][1]) / s;
        w = (row[0][2] - row[2][0]) / s;
    } else {
        s = sqrt(1.0 + row[2][2] - row[0][0] - row[1][1]) * 2.0; // S=4*qz
        x = (row[0][2] + row[2][0]) / s;
        y = (row[1][2] + row[2][1]) / s;
        z = 0.25 * s;
        w = (row[1][0] - row[0][1]) / s;
    }
    
    result->quaternionX = x;
    result->quaternionY = y;
    result->quaternionZ = z;
    result->quaternionW = w;
    return true;
}

static SeamlessDecomposedType seamlessEmpty() {
    SeamlessDecomposedType theEmpty = {0};
    theEmpty.scaleX = 1;
    theEmpty.scaleY = 1;
    theEmpty.scaleZ = 1;
    return theEmpty;
}

CATransform3D seamlessBlend(CATransform3D fromTransform, CATransform3D toTransform, double progress) {
    
    SeamlessMatrix4 from;
    seamlessMakeMatrix(fromTransform, from);
    
    SeamlessMatrix4 to;
    seamlessMakeMatrix(toTransform, to);
    
    if (seamlessIsIdentityMatrix(from) && seamlessIsIdentityMatrix(to)) return CATransform3DIdentity;
    
    // decompose
    SeamlessDecomposedType fromDecomp = seamlessEmpty();
    SeamlessDecomposedType toDecomp = seamlessEmpty();
    
    seamlessDecompose(&fromDecomp,from);
    seamlessDecompose(&toDecomp,to);
    
    // interpolate
    seamlessBlendFloat(&fromDecomp.scaleX, toDecomp.scaleX, progress);
    seamlessBlendFloat(&fromDecomp.scaleY, toDecomp.scaleY, progress);
    seamlessBlendFloat(&fromDecomp.scaleZ, toDecomp.scaleZ, progress);
    seamlessBlendFloat(&fromDecomp.skewXY, toDecomp.skewXY, progress);
    seamlessBlendFloat(&fromDecomp.skewXZ, toDecomp.skewXZ, progress);
    seamlessBlendFloat(&fromDecomp.skewYZ, toDecomp.skewYZ, progress);
    seamlessBlendFloat(&fromDecomp.translateX, toDecomp.translateX, progress);
    seamlessBlendFloat(&fromDecomp.translateY, toDecomp.translateY, progress);
    seamlessBlendFloat(&fromDecomp.translateZ, toDecomp.translateZ, progress);
    seamlessBlendFloat(&fromDecomp.perspectiveX, toDecomp.perspectiveX, progress);
    seamlessBlendFloat(&fromDecomp.perspectiveY, toDecomp.perspectiveY, progress);
    seamlessBlendFloat(&fromDecomp.perspectiveZ, toDecomp.perspectiveZ, progress);
    seamlessBlendFloat(&fromDecomp.perspectiveW, toDecomp.perspectiveW, progress);
    
    seamlessSlerp(&fromDecomp.quaternionX, &toDecomp.quaternionX, progress);
    // recompose
    
    seamlessRecompose(fromDecomp, from);
    
    return seamlessMakeTransform(from);
}