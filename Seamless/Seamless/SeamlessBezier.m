/*
 * Copyright (C) 2008 Apple Inc. All Rights Reserved.
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
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

// This file has been heavily modified from the original WebKit source, UnitBezier.h

#import "SeamlessBezier.h"

@interface SeamlessBezier()
@property (assign,readonly) double ax;
@property (assign,readonly) double bx;
@property (assign,readonly) double cx;
@property (assign,readonly) double ay;
@property (assign,readonly) double by;
@property (assign,readonly) double cy;
@end

@implementation SeamlessBezier
+(double(^)(double))perfectBezier {
    return [self bezierWithControlPoints:.5 :0 :.5 :1];
}
+(double(^)(double))bezierWithControlPoints:(double)p1x :(double)p1y :(double)p2x :(double)p2y {
    SeamlessBezier *bezier = [[[self class] alloc] initWithSeamlessControlPoints:p1x :p1y :p2x :p2y];
    return ^ (double progress) {
        return [bezier solveX:progress epsilon:1];
    };
}
-(instancetype)initWithSeamlessControlPoints:(double)p1x :(double)p1y :(double)p2x :(double)p2y {
    if ((self = [super init])) {
        // Calculate the polynomial coefficients, implicit first and last control points are (0,0) and (1,1).
        _cx = 3.0 * p1x;
        _bx = 3.0 * (p2x - p1x) - _cx;
        _ax = 1.0 - _cx - _bx;
        
        _cy = 3.0 * p1y;
        _by = 3.0 * (p2y - p1y) - _cy;
        _ay = 1.0 - _cy - _by;
    }
    return self;
}

-(double)sampleCurveX:(double)t {
    // `ax t^3 + bx t^2 + cx t' expanded using Horner's rule.
    return ((_ax * t + _bx) * t + _cx) * t;
}

-(double)sampleCurveY:(double)t {
    return ((_ay * t + _by) * t + _cy) * t;
}

-(double)sampleCurveDerivativeX:(double)t {
    return (3.0 * _ax * t + 2.0 * _bx) * t + _cx;
}

// Given an x value, find a parametric value it came from.
-(double)solveCurveX:(double)x epsilon:(double)epsilon {
    double t0;
    double t1;
    double t2;
    double x2;
    double d2;
    int i;
    
    // First try a few iterations of Newton's method -- normally very fast.
    for (t2 = x, i = 0; i < 8; i++) {
        x2 = [self sampleCurveX:t2] - x;
        if (fabs (x2) < epsilon)
            return t2;
        d2 = [self sampleCurveDerivativeX:t2];
        if (fabs(d2) < 1e-6)
            break;
        t2 = t2 - x2 / d2;
    }
    
    // Fall back to the bisection method for reliability.
    t0 = 0.0;
    t1 = 1.0;
    t2 = x;
    
    if (t2 < t0)
        return t0;
    if (t2 > t1)
        return t1;
    
    while (t0 < t1) {
        x2 = [self sampleCurveX:t2];
        if (fabs(x2 - x) < epsilon)
            return t2;
        if (x > x2)
            t0 = t2;
        else
            t1 = t2;
        t2 = (t1 - t0) * .5 + t0;
    }
    
    // Failure.
    return t2;
}

-(double)solveX:(double)x epsilon:(double)epsilon {
    return [self sampleCurveY:[self solveCurveX:x epsilon:epsilon]];
}
@end
