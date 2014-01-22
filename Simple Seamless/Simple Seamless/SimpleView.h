//
//  SimpleView.h
//  Simple Additive
//
//  Created by Kevin Doughty on 4/7/11.
//  Copyright 2011 Kevin Doughty. All rights reserved.
//
//  This is a from scratch re-implementation of "Follow Me" by Matt Long 10/22/08
//  My original version used explicit additive animations.
//  This version uses implicit animation and seamless.framework.

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>

@interface SimpleView : NSView {
    CALayer *ball;
	CAMediaTimingFunction *timingFunction;
}

@end
