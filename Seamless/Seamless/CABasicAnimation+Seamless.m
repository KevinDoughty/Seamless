//
//  CABasicAnimation+Seamless.m
//  Seamless
//
//  Created by Kevin Doughty on 1/21/14.
//  Copyright (c) 2014 Kevin Doughty. All rights reserved.
//

#import "Seamless.h" // This imports CABasicAnimation+Seamless.h. Poor style.

@implementation CABasicAnimation (Seamless)

-(void)setSeamlessTimingBlock:(double(^)(double))theBlock {
	[self setValue:[theBlock copy] forKey:@"seamlessSeamlessTimingBlock"];
}
-(double(^)(double))seamlessTimingBlock {
    return [self valueForKey:@"seamlessSeamlessTimingBlock"];
}
-(void)setSeamlessSteps:(NSUInteger)theSteps {
	[self setValue:@(theSteps) forKey:@"seamlessSeamlessSteps"];
}
-(NSUInteger)seamlessSteps {
    return [[self valueForKey:@"seamlessSeamlessSteps"] unsignedIntegerValue];
}
-(void)setSeamlessNegativeDelta:(BOOL)theSeamless {
	[self setValue:@(theSeamless) forKey:@"seamlessSeamlessNegativeDelta"];
}
-(BOOL)seamlessNegativeDelta {
    return [[self valueForKey:@"seamlessSeamlessNegativeDelta"] boolValue];
}
-(void)setSeamlessKeyBehavior:(SeamlessKeyBehavior)theBehavior {
    [self setValue:@(theBehavior) forKey:@"seamlessSeamlessKeyBehavior"];
}
-(SeamlessKeyBehavior)seamlessKeyBehavior {
    return (SeamlessKeyBehavior)[[self valueForKey:@"seamlessSeamlessKeyBehavior"] integerValue];
}

@end
