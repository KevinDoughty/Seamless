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

typedef enum { // In addAnimation:forKey: nil or unique keys are critical to allow multiple additive animations running at the same time. Unique keys are required if you want to recall and copy animations, useful for inserting new layers animating in sync with existing layers that have running animations.
    seamlessKeyDefault, // If seamlessNegativeDelta == YES default is to use a nil key, otherwise use Core Animation default behavior of using the exact key as passed.
    seamlessKeyExact, // Use the exact key as passed to addAnimation:forKey: (Useful if you have your own scheme for creating unique keys, for recalling them, most likely to copy animations)
    seamlessKeyNil, // Use a nil key regardless of what was passed in addAnimation:forKey:
    seamlessKeyIncrement, // Deprecated. Just a number. Key passed in addAnimation:forKey: is ignored.
    seamlessKeyIncrementKey, // The key plus a number appended. If the key passed in addAnimation:forKey: is nil you get just a number.
    seamlessKeyIncrementKeyPath // The key path plus a number appended.
} SeamlessKeyBehavior;

-(void)setSeamlessTimingBlock:(double(^)(double))theBlock;
-(double(^)(double))seamlessTimingBlock;
-(void)setSeamlessSteps:(NSUInteger)theSteps;
-(NSUInteger)seamlessSteps;
-(void)setSeamlessNegativeDelta:(BOOL)theSeamless;
-(BOOL)seamlessNegativeDelta;
-(void)setSeamlessKeyBehavior:(SeamlessKeyBehavior)theBehavior;
-(SeamlessKeyBehavior)seamlessKeyBehavior;

@end
