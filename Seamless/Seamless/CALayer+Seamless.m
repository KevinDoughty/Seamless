/*
 Copyright (c) 2014, Kevin Doughty
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "CALayer+Seamless.h"
#import "Seamless.h"
#import <objc/runtime.h>
#import "CATransaction+Seamless.h"
#import "Inslerpolate.h"


#define kSeamlessSteps 100

@interface CALayer ()
@property (readonly) CALayer *seamlessPreviousLayer;
@end


static NSUInteger seamlessAnimationCount = 0;

@implementation CALayer (Seamless)

+(void) load {
    seamlessSwizzle(self, @selector(willChangeValueForKey:), @selector(seamlessLayerSwizzleWillChangeValueForKey:));
    seamlessSwizzle(self, @selector(addAnimation:forKey:), @selector(seamlessLayerSwizzleAddAnimation:forKey:));
}

+(NSString*) seamlessAnimationKey {
    return [NSString stringWithFormat:@"seamlessAnimation%lu",(unsigned long)seamlessAnimationCount++];
}

-(CALayer*)seamlessPreviousLayer { // It would be bad to add this as a sublayer in a layer tree, and nothing prevents you from doing so. That's why this is private now.
	CALayer *theLayer = objc_getAssociatedObject(self, @"seamlessPreviousLayer");
	if (theLayer == nil) {
		theLayer = [CALayer layer]; // You don't want initWithLayer, and you don't want any class other than CALayer.
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
        [theLayer setValue:@YES forKey:@"isSeamlessPreviousLayer"];
		[CATransaction commit];
        objc_setAssociatedObject(self, @"seamlessPreviousLayer",theLayer, OBJC_ASSOCIATION_RETAIN);
	}
	return theLayer;
}

-(void)seamlessLayerSwizzleWillChangeValueForKey:(NSString*)theKey { // in ML, this happens after actionForKey. In Lion it happened before actionForKey:
    if ((self.modelLayer == nil || self.modelLayer == self) && ![[self valueForKey:@"isSeamlessPreviousLayer"] boolValue]) {// View animation in Lion and below will need to figure out another place to set previousValueForKey, because of view to layer geometry glue code.
        id theValue = [self valueForKeyPath:theKey];
        if ([theValue respondsToSelector:@selector(objCType)]) {
            const char *objCType = [theValue objCType];
            if (strcmp(objCType,@encode(CGPoint))==0 || strcmp(objCType,@encode(CGSize))==0 || strcmp(objCType,@encode(CGRect))==0 || strcmp(objCType,@encode(CATransform3D))==0 || strcmp(objCType,@encode(CGFloat))==0 || strcmp(objCType,@encode(float))==0 || strcmp(objCType,@encode(double))==0) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self.seamlessPreviousLayer setValue:[self valueForKey:theKey] forKey:theKey];
                [CATransaction commit];
            }
        }
	}
	[self seamlessLayerSwizzleWillChangeValueForKey:theKey];
}

-(void)seamlessLayerSwizzleAddAnimation:(CAAnimation*)theAnimation forKey:(NSString*)theKey { // I do this here because in animationForKey: and actionForKey: the fromValue is set to the presentationLayer value, but keyPath, toValue, and byValue are null. Key is known but conversions to keyPath are not, for example frameOrigin to layer.position.
    BOOL theSeamless = ([theAnimation isKindOfClass:[CABasicAnimation class]] && [[(CABasicAnimation*)theAnimation valueForKey:@"seamless"] boolValue]);
    BOOL isSeamlessClass = [theAnimation isKindOfClass:[SeamlessAnimation class]];

    SeamlessTimingBlock theTimingBlock = [CATransaction seamlessTimingBlock];
    SeamlessTimingBlock theSeamlessBlock = nil;
    if (isSeamlessClass) theSeamlessBlock = [(SeamlessAnimation*)theAnimation timingBlock];
    if (theSeamless || isSeamlessClass || theTimingBlock) {
        NSString *theKeyPath = nil;
        if (isSeamlessClass) theKeyPath = [(SeamlessAnimation*)theAnimation keyPath];
        else theKeyPath = [(CABasicAnimation*)theAnimation keyPath];
        if (theKeyPath == nil) theKeyPath = theKey; // At one point some appKit default animations had a keyPath of nil, is this still true?
        id theOldValue = [self.seamlessPreviousLayer valueForKeyPath:theKeyPath];
        if (isSeamlessClass && [(SeamlessAnimation*)theAnimation oldValue] != nil) theOldValue = [(SeamlessAnimation*)theAnimation oldValue];
        
        if (theOldValue != nil && [theOldValue respondsToSelector:@selector(objCType)]) {
            const char *objCType = [theOldValue objCType];
            id theNewValue = [self valueForKeyPath:theKeyPath];
            if (isSeamlessClass && [(SeamlessAnimation*)theAnimation nuValue] != nil) theNewValue = [(SeamlessAnimation*)theAnimation nuValue];
            CAKeyframeAnimation *theKeyframeAnimation = [CAKeyframeAnimation animationWithKeyPath:theKeyPath];
            CAMediaTimingFunction *perfectTimingFunction = [CAMediaTimingFunction functionWithControlPoints:0.5 :0.0 :0.5 :1.0f];
            theKeyframeAnimation.fillMode = kCAFillModeBackwards; // In case mediaTiming is off by a small amount. It can happen post 10.5 Leopard
            theKeyframeAnimation.additive = YES;
            NSUInteger steps = [CATransaction seamlessSteps];
            if (!theTimingBlock) steps = 2;
            else if (steps < 2) steps = kSeamlessSteps;
            
            NSArray *(^keyframeValues)(NSValue *(^theValueBlock)(double)) = ^(NSValue *(^theValueBlock)(double)) { // A block that takes a block as an argument.
                NSMutableArray *theValues = @[].mutableCopy;
                for (NSUInteger i=0; i<steps; i++) {
                    double offset = (1.0/(steps-1))*i;
                    if (theSeamlessBlock) offset = theSeamlessBlock(offset);
                    if (theTimingBlock) offset = theTimingBlock(offset); // should I enforce 0 and 1 for first and last?
                    double progress = 1.0 - offset; // This is a private implementation detail. Convert from 0 - 1 to 1 - 0. Timing block is in expected order.
                    NSValue *theFrame = theValueBlock(progress);
                    [theValues addObject:theFrame];
                }
                return theValues;
            };
            
            if (strcmp(objCType,@encode(CATransform3D))==0) {
                CATransform3D o = [theOldValue CATransform3DValue];
                CATransform3D n = [theNewValue CATransform3DValue];
                CATransform3D d = CATransform3DConcat(o,CATransform3DInvert(n));

                if (!CATransform3DIsIdentity(d)) {
                    theKeyframeAnimation.values = keyframeValues(^(CGFloat progress) {
                        CATransform3D t = [self seamlessBlendTransform:d to:CATransform3DIdentity progress:1-progress]; // 1-progress because passed argument is from 1 to 0. This is a private implementation detail, other types are easy to interpolate so progress is converted to 1 - 0 which is multiplied by the negative delta.
                        return [NSValue valueWithCATransform3D:t];
                    });
                    [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:[CALayer seamlessAnimationKey]];
                    return;
                }
                
            } else if (strcmp(objCType,@encode(CGPoint))==0) {
                CGPoint oldPoint, newPoint;
#if TARGET_OS_IPHONE
                oldPoint = [theOldValue CGPointValue];
                newPoint = [theNewValue CGPointValue];
#else
                oldPoint = [theOldValue pointValue];
                newPoint = [theNewValue pointValue];
#endif
                if (oldPoint.x-newPoint.x || oldPoint.y-newPoint.y) {
                    theKeyframeAnimation.values = keyframeValues(^(CGFloat progress) {
#if TARGET_OS_IPHONE
                        return [NSValue valueWithCGPoint:CGPointMake(progress * (oldPoint.x-newPoint.x), progress * (oldPoint.y-newPoint.y))];
#else
                        return [NSValue valueWithPoint:NSMakePoint(progress * (oldPoint.x-newPoint.x), progress * (oldPoint.y-newPoint.y))];
#endif
                    });
                    [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:[CALayer seamlessAnimationKey]];
                    return;
                }
            } else if (strcmp(objCType,@encode(CGRect))==0) {
                CGRect oldRect, newRect;
#if TARGET_OS_IPHONE
                oldRect = [theOldValue CGRectValue];
                newRect = [theNewValue CGRectValue];
#else
                oldRect = [theOldValue rectValue];
                newRect = [theNewValue rectValue];
#endif
                BOOL rectAnimationIsBroken = YES; // Rect animation was not broken in 10.5 Leopard
                if (rectAnimationIsBroken) { // create a group animation with position and size sub animations. This cannot be handled in actionForKey because of other problems.
                    CAKeyframeAnimation *theOriginAnimation = nil;
                    CAKeyframeAnimation *theSizeAnimation = nil;
                    CGFloat deltaX = oldRect.origin.x-newRect.origin.x;
                    CGFloat deltaY = oldRect.origin.y-newRect.origin.y;
                    if (deltaX || deltaY) {
                        theOriginAnimation = [CAKeyframeAnimation animationWithKeyPath:[theKeyPath stringByAppendingString:@".origin"]];
                        theOriginAnimation.values = keyframeValues(^(CGFloat progress) {
#if TARGET_OS_IPHONE
                            return [NSValue valueWithCGPoint:CGPointMake(progress * deltaX, progress * deltaY)];
#else
                            return [NSValue valueWithPoint:NSMakePoint(progress * deltaX, progress * deltaY)];
#endif
                        });
                        theOriginAnimation.fillMode = kCAFillModeBackwards;
                        theOriginAnimation.additive = YES;
                    }
                    CGFloat deltaW = oldRect.size.width-newRect.size.width;
                    CGFloat deltaH = oldRect.size.height-newRect.size.height;
                    if (deltaW || deltaH) {
                        theSizeAnimation = [CAKeyframeAnimation animationWithKeyPath:[theKeyPath stringByAppendingString:@".size"]];
                        theSizeAnimation.values = keyframeValues(^(CGFloat progress) {
#if TARGET_OS_IPHONE
                            return [NSValue valueWithCGSize:CGSizeMake(progress * deltaW, progress * deltaH)];
#else
                            return [NSValue valueWithSize:NSMakeSize(progress * deltaW, progress * deltaH)];
#endif
                        });
                        theOriginAnimation.fillMode = kCAFillModeBackwards;
                        theOriginAnimation.additive = YES;
                    }
                    if (theOriginAnimation != nil && theSizeAnimation != nil) {
                        CAAnimationGroup *theGroupAnimation = [CAAnimationGroup animation];
                        if (!theTimingBlock) theGroupAnimation.timingFunction = perfectTimingFunction;
                        theGroupAnimation.fillMode = kCAFillModeBoth;
                        theGroupAnimation.animations = [NSArray arrayWithObjects:theOriginAnimation, theSizeAnimation, nil];
                        [self seamlessLayerSwizzleAddAnimation:theGroupAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    } else if (theSizeAnimation != nil) {
                        if (!theTimingBlock) theSizeAnimation.timingFunction = perfectTimingFunction;
                        [self seamlessLayerSwizzleAddAnimation:theSizeAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    } else if (theOriginAnimation != nil) {
                        if (!theTimingBlock) theOriginAnimation.timingFunction = perfectTimingFunction;
                        [self seamlessLayerSwizzleAddAnimation:theOriginAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    }
                } else { // rect animation was not broken in 10.5 Leopard:
                    CGRect oldRect,newRect;
#if TARGET_OS_IPHONE
                    oldRect = [theOldValue CGRectValue];
                    newRect = [theNewValue CGRectValue];
#else
                    oldRect = [theOldValue rectValue];
                    newRect = [theNewValue rectValue];
#endif
                    CGFloat deltaX = oldRect.origin.x-newRect.origin.x;
                    CGFloat deltaY = oldRect.origin.y-newRect.origin.y;
                    CGFloat deltaW = oldRect.size.width-oldRect.size.height;
                    CGFloat deltaH = oldRect.size.height-newRect.size.height;
                    if (deltaX || deltaY || deltaW || deltaH) {
                        theKeyframeAnimation.values = keyframeValues(^(CGFloat progress) {
#if TARGET_OS_IPHONE
                            return [NSValue valueWithCGRect:CGRectMake(progress * deltaX, progress * deltaY, progress * deltaW, progress * deltaH)];
#else
                            return [NSValue valueWithRect:NSMakeRect(progress * deltaX, progress * deltaY, progress * deltaW, progress * deltaH)];
#endif
                    
                        });
                        [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:[CALayer seamlessAnimationKey]];
                        return;
                    }
                }
            } else if (strcmp(objCType,@encode(CGSize))==0) {
                CGSize oldSize, newSize;
#if TARGET_OS_IPHONE
                oldSize = [theOldValue CGSizeValue];
                newSize = [theNewValue CGSizeValue];
#else
                oldSize = [theOldValue sizeValue];
                newSize = [theNewValue sizeValue];
#endif
                CGFloat deltaW = oldSize.width-newSize.width;
                CGFloat deltaH = oldSize.height-newSize.height;
                if (deltaW || deltaH) {
                    theKeyframeAnimation.values = keyframeValues(^(CGFloat progress) {
#if TARGET_OS_IPHONE
                        return [NSValue valueWithCGSize:CGSizeMake(progress * deltaW, progress * deltaH)];
#else
                        return [NSValue valueWithSize:NSMakeSize(progress * deltaW, progress * deltaH)];
#endif
                    });
                    [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:[CALayer seamlessAnimationKey]];
                    return;
                }
            } else if (strcmp(objCType,@encode(CGFloat))==0 || strcmp(objCType,@encode(float))==0) {
                CGFloat oldFloat = [theOldValue floatValue];
                CGFloat newFloat = [theNewValue floatValue];
                CGFloat deltaFloat = oldFloat-newFloat;
                if (deltaFloat) {
                    theKeyframeAnimation.values = keyframeValues(^(CGFloat progress) {
                        NSNumber *theReturnValue = [NSNumber numberWithFloat:progress * deltaFloat];
                        return theReturnValue;
                    });
                    [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:[CALayer seamlessAnimationKey]];
                    return;
                }
            } else if (strcmp(objCType,@encode(double))==0) {
                CGFloat oldDouble = [theOldValue doubleValue];
                CGFloat newDouble = [theNewValue doubleValue];
                CGFloat deltaDouble = oldDouble-newDouble;
                if (deltaDouble) {
                    theKeyframeAnimation.values = keyframeValues(^(CGFloat progress) {
                        NSNumber *theReturnValue = [NSNumber numberWithDouble:progress * deltaDouble];
                        return theReturnValue;
                    });
                    [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:[CALayer seamlessAnimationKey]];
                    return;
                }
            } else {
                //NSLog(@"unknown objCType:%@;",[[NSString alloc] initWithCString:objCType encoding:NSASCIIStringEncoding]);
            }
            
        }
    }
    
    [self seamlessLayerSwizzleAddAnimation:theAnimation forKey:theKey];
}

-(CATransform3D)seamlessBlendTransform:(CATransform3D)fromTransform to:(CATransform3D)toTransform progress:(double)progress {
    CATransform3D final = seamlessBlend(fromTransform,toTransform,progress);
    return final;
}



@end
