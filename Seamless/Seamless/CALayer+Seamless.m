//
//  CALayer+Seamless.m
//  Seamless
//
//  Created by Kevin Doughty on 3/8/13.
//  Copyright (c) 2013 Kevin Doughty. All rights reserved.
//

#import "CALayer+Seamless.h"
#import "Seamless.h"
#import <objc/objc-runtime.h>

@interface CALayer ()
@property (readonly) CALayer *previousLayer;
@end



static NSUInteger seamlessAnimationCount = 0;

@implementation CALayer (Seamless)

+(void) load {
    SeamlessSwizzle(self, @selector(actionForKey:), @selector(seamlessLayerSwizzleActionForKey:));
	SeamlessSwizzle(self, @selector(willChangeValueForKey:), @selector(seamlessLayerSwizzleWillChangeValueForKey:));
    SeamlessSwizzle(self, @selector(addAnimation:forKey:), @selector(seamlessLayerSwizzleAddAnimation:forKey:));
}

+(NSString*) seamlessAnimationKey {
    return [NSString stringWithFormat:@"seamlessAnimation%lu",seamlessAnimationCount++];
}

-(CALayer*)previousLayer { // It would be bad to add this as a sublayer in a layer tree, and nothing prevents you from doing so... except maybe initWithLayer. That's why this is private now.
	CALayer *theLayer = objc_getAssociatedObject(self, @"previousLayer");
	if (theLayer == nil) {
		theLayer = [CALayer layer]; // You don't want initWithLayer, and you don't want any class other than CALayer.
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
        [theLayer setValue:@YES forKey:@"isPreviousLayer"];
		[CATransaction commit];
        objc_setAssociatedObject(self, @"previousLayer",theLayer, OBJC_ASSOCIATION_RETAIN);
	}
	return theLayer;
}

-(void)seamlessLayerSwizzleWillChangeValueForKey:(NSString*)theKey { // in ML, this happens after actionForKey. In Lion it happened before actionForKey:
    if ((self.modelLayer == nil || self.modelLayer == self) && ![[self valueForKey:@"isPreviousLayer"] boolValue]) {//&& !self.hasHostingOrBackingView) { // View animation in Lion and below will need to figure out another place to set previousValueForKey, because of view to layer geometry glue code.
        id theValue = [self valueForKeyPath:theKey];
        if ([theValue respondsToSelector:@selector(objCType)]) {
            const char *objCType = [theValue objCType];
            if (strcmp(objCType,@encode(NSPoint))==0 || strcmp(objCType,@encode(NSSize))==0 || strcmp(objCType,@encode(NSRect))==0 || strcmp(objCType,@encode(CATransform3D))==0 || strcmp(objCType,@encode(CGFloat))==0 || strcmp(objCType,@encode(float))==0 || strcmp(objCType,@encode(double))==0) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self.previousLayer setValue:[self valueForKey:theKey] forKey:theKey];
                [CATransaction commit];
            }
        }
	}
	[self seamlessLayerSwizzleWillChangeValueForKey:theKey];
}

-(id<CAAction>)seamlessLayerSwizzleActionForKey:(NSString*)theKey {
    id<CAAction> theAction = [self seamlessLayerSwizzleActionForKey:theKey];
    if ([(NSObject*)theAction isKindOfClass:[CABasicAnimation class]]) { // id does not respond to isKindOfClass...
        [(CABasicAnimation*)theAction setValue:@YES forKey:@"seamless"];
    }
    return theAction;
}

-(void)seamlessLayerSwizzleAddAnimation:(CAAnimation*)theAnimation forKey:(NSString*)theKey { // This is where the magic happens.
    BOOL verbose = NO;
    if ([theAnimation isKindOfClass:[CABasicAnimation class]]) {
        BOOL theSeamless = [[(CABasicAnimation*)theAnimation valueForKey:@"seamless"] boolValue];
        if (theSeamless) {
            CABasicAnimation *theBasicAnimation = [(CABasicAnimation*)theAnimation copy]; // theAnimation is already read-only.
            if (verbose) NSLog(@"key:%@; keyPath:%@; from:%@; to:%@;",theKey, theBasicAnimation.keyPath, theBasicAnimation.fromValue, theBasicAnimation.toValue);
            id theOldValue = [self.previousLayer valueForKeyPath:theKey];
            if (theOldValue != nil) {
                id theNewValue = [self valueForKeyPath:theKey];
                if (theBasicAnimation.keyPath == nil) theBasicAnimation.keyPath = theKey; // This is very important for implicit seamless view animation, because it seems most if not all appKit default animations have a keyPath of nil, but most user defined animations will probably have it already set.
                CAMediaTimingFunction *theTimingFunction = [CAMediaTimingFunction functionWithControlPoints:0.5 :0.0 :0.5 :1.0f];
                theBasicAnimation.timingFunction = theTimingFunction;
                theBasicAnimation.fillMode = kCAFillModeBoth; // In case mediaTiming is off by a small positive or negative amount. It can happen post 10.5 Leopard
                theBasicAnimation.additive = YES;
                if ([theOldValue respondsToSelector:@selector(objCType)]) {
                    const char *objCType = [theOldValue objCType];
                    if (strcmp(objCType,@encode(NSPoint))==0) {
                        NSPoint oldPoint = [theOldValue pointValue];
                        NSPoint newPoint = [theNewValue pointValue];
                        theBasicAnimation.fromValue = [NSValue valueWithPoint:NSMakePoint(oldPoint.x-newPoint.x, oldPoint.y-newPoint.y)];
                        theBasicAnimation.toValue = [NSValue valueWithPoint:NSZeroPoint];
                        [self seamlessLayerSwizzleAddAnimation:theBasicAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    } else if (strcmp(objCType,@encode(NSRect))==0) {
                        NSRect oldRect = [theOldValue rectValue];
                        NSRect newRect = [theNewValue rectValue];
                        BOOL rectAnimationIsBroken = YES; // Rect animation was not broken in 10.5 Leopard
                        if (rectAnimationIsBroken) { // create a group animation with position and size sub animations. Perhaps this should be handled in actionForKey:
                            CABasicAnimation *theOriginAnimation = nil;
                            CABasicAnimation *theSizeAnimation = nil;
                            NSPoint deltaPoint = NSMakePoint(oldRect.origin.x-newRect.origin.x, oldRect.origin.y-newRect.origin.y);
                            if (!NSEqualPoints(deltaPoint, NSZeroPoint)) {
                                theOriginAnimation = [CABasicAnimation animation];
                                theOriginAnimation.keyPath = [theBasicAnimation.keyPath stringByAppendingString:@".origin"];
                                theOriginAnimation.fromValue = [NSValue valueWithPoint:deltaPoint];
                                theOriginAnimation.toValue = [NSValue valueWithPoint:NSZeroPoint];
                                theOriginAnimation.fillMode = kCAFillModeBoth;
                                theOriginAnimation.additive = YES;
                            }
                            NSSize deltaSize = NSMakeSize(oldRect.size.width-newRect.size.width, oldRect.size.height-newRect.size.height);
                            if (!NSEqualSizes(deltaSize, NSZeroSize)) {
                                theSizeAnimation = [CABasicAnimation animation];
                                theSizeAnimation.keyPath = [theBasicAnimation.keyPath stringByAppendingString:@".size"];
                                theSizeAnimation.fromValue = [NSValue valueWithSize:deltaSize];
                                theSizeAnimation.toValue = [NSValue valueWithSize:NSZeroSize];
                                theSizeAnimation.fillMode = kCAFillModeBoth;
                                theSizeAnimation.additive = YES;
                            }
                            if (theOriginAnimation != nil && theSizeAnimation != nil) {
                                CAAnimationGroup *theGroupAnimation = [CAAnimationGroup animation];
                                theGroupAnimation.timingFunction = theTimingFunction;
                                theGroupAnimation.fillMode = kCAFillModeBoth;
                                theGroupAnimation.animations = [NSArray arrayWithObjects:theOriginAnimation, theSizeAnimation, nil];
                                [self seamlessLayerSwizzleAddAnimation:theGroupAnimation forKey:[CALayer seamlessAnimationKey]];
                                return;
                            } else if (theSizeAnimation != nil) {
                                theSizeAnimation.timingFunction = theTimingFunction;
                                [self seamlessLayerSwizzleAddAnimation:theSizeAnimation forKey:[CALayer seamlessAnimationKey]];
                                return;
                            } else if (theOriginAnimation != nil) {
                                theOriginAnimation.timingFunction = theTimingFunction;
                                [self seamlessLayerSwizzleAddAnimation:theOriginAnimation forKey:[CALayer seamlessAnimationKey]];
                                return;
                            }
                        } else { // rect animation was not broken in 10.5 Leopard:
                            theBasicAnimation.fromValue = [NSValue valueWithRect:NSMakeRect(oldRect.origin.x-newRect.origin.x, oldRect.origin.y-newRect.origin.y, oldRect.size.width-newRect.size.width, oldRect.size.height-newRect.size.height)];
                            theBasicAnimation.toValue = [NSValue valueWithRect:NSZeroRect];
                            [self seamlessLayerSwizzleAddAnimation:theBasicAnimation forKey:[CALayer seamlessAnimationKey]];
                            return;
                        }
                    } else if (strcmp(objCType,@encode(CATransform3D))==0) {
                        CATransform3D oldTransform = [theOldValue CATransform3DValue];
                        CATransform3D newTransform = [theNewValue CATransform3DValue];
                        theBasicAnimation.fromValue = [NSValue valueWithCATransform3D:CATransform3DConcat(oldTransform,CATransform3DInvert(newTransform))];
                        theBasicAnimation.toValue = [NSValue valueWithCATransform3D:CATransform3DIdentity];
                        [self seamlessLayerSwizzleAddAnimation:theBasicAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    } else if (strcmp(objCType,@encode(NSSize))==0) {
                        NSSize oldSize = [theOldValue sizeValue];
                        NSSize newSize = [theNewValue sizeValue];
                        theBasicAnimation.fromValue = [NSValue valueWithSize:NSMakeSize(oldSize.width-newSize.width, oldSize.height-newSize.height)];
                        theBasicAnimation.toValue = [NSValue valueWithSize:NSZeroSize];
                        [self seamlessLayerSwizzleAddAnimation:theBasicAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    } else if (strcmp(objCType,@encode(CGFloat))==0 || strcmp(objCType,@encode(float))==0) {
                        CGFloat oldFloat = [theOldValue floatValue];
                        CGFloat newFloat = [theNewValue floatValue];
                        theBasicAnimation.fromValue = @(oldFloat - newFloat);
                        theBasicAnimation.toValue = @0;
                        [self seamlessLayerSwizzleAddAnimation:theBasicAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    } else if (strcmp(objCType,@encode(double))==0) {
                        CGFloat oldDouble = [theOldValue doubleValue];
                        CGFloat newDouble = [theNewValue doubleValue];
                        theBasicAnimation.fromValue = @(oldDouble - newDouble);
                        theBasicAnimation.toValue = @0;
                        [self seamlessLayerSwizzleAddAnimation:theBasicAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    } else {
                        if (verbose) NSLog(@"unknown objCType:%@;",[[NSString alloc] initWithCString:objCType encoding:NSASCIIStringEncoding]);
                    }
                }
            }
        }
    }
    [self seamlessLayerSwizzleAddAnimation:theAnimation forKey:theKey];
}
@end
