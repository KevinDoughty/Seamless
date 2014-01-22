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

-(void)setSeamlessTimingBlock:(SeamlessTimingBlock)theBlock;
-(SeamlessTimingBlock)seamlessTimingBlock;
-(void)setSeamlessSteps:(NSUInteger)theSteps;
-(NSUInteger)seamlessSteps;
-(void)setSeamless:(BOOL)theSeamless;
-(BOOL)seamless;

@end
