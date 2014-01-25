//
//  CABasicAnimation+Seamless.h
//  Seamless
//
//  Created by Kevin Doughty on 1/21/14.
//  Copyright (c) 2014 Kevin Doughty. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "CATransaction+Seamless.h"

@interface CABasicAnimation (Seamless)

-(void)setSeamlessTimingBlock:(double(^)(double))theBlock;
-(double(^)(double))seamlessTimingBlock;
-(void)setSeamlessSteps:(NSUInteger)theSteps;
-(NSUInteger)seamlessSteps;
-(void)setSeamlessNegativeDelta:(BOOL)theSeamless;
-(BOOL)seamlessNegativeDelta;

@end
