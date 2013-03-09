//
//  NSView+Seamless.m
//  Seamless
//
//  Created by Kevin Doughty on 3/8/13.
//  Copyright (c) 2013 Kevin Doughty. All rights reserved.
//

#import "NSView+Seamless.h"
#import "Seamless.h"
#import <QuartzCore/QuartzCore.h>

@implementation NSView (Seamless)

+(void) load {
	SeamlessSwizzle(self, @selector(animationForKey:), @selector(seamlessViewSwizzleAnimationForKey:));
}

- (id)seamlessViewSwizzleAnimationForKey:(NSString *)theKey {
    CAAnimation *theAnimation = [self seamlessViewSwizzleAnimationForKey:theKey]; // assumes CAAnimation, but return type is id.
    if ([theAnimation isKindOfClass:[CABasicAnimation class]]) { // id does not respond to isKindOfClass...
        [theAnimation setValue:[NSNumber numberWithBool:YES] forKey:@"seamless"];
    }
    return theAnimation;
}

@end
