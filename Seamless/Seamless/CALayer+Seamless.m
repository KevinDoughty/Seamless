/*
 Copyright (c) 2014, Kevin Doughty
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "CALayer+Seamless.h"
#import "SeamlessDelegate.h"
#import "CABasicAnimation+Seamless.h"
#import "CATransaction+Seamless.h"
#import "SeamlessAnimation.h"
#import "Inslerpolate.h"
#import <objc/runtime.h>
#import "SeamlessEasedAnimation.h"

#define kSeamlessSteps 100


@interface SeamlessDelegate ()
+(instancetype)singleton; // Animations are replaced. This acts as animation delegate if set in original animation, passing message along.
@end


@interface CALayer ()
@property (readonly) CALayer *seamlessPreviousLayer;
@end


static NSUInteger seamlessAnimationCount = 0;

void seamlessSwizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else method_exchangeImplementations(origMethod, newMethod);
}


@implementation CALayer (Seamless)

+(void) load {
    seamlessSwizzle(self, @selector(willChangeValueForKey:), @selector(seamlessLayerSwizzleWillChangeValueForKey:));
    seamlessSwizzle(self, @selector(addAnimation:forKey:), @selector(seamlessLayerSwizzleAddAnimation:forKey:));
}
+(NSString*) seamlessAnimationKey {
    return [NSString stringWithFormat:@"%lu",(unsigned long)seamlessAnimationCount++];
}

-(CALayer*)seamlessPreviousLayer { // It would be bad to add this as a sublayer in a layer tree, and nothing prevents you from doing so. That's why this is private now.
	CALayer *theLayer = [self valueForKey:@"seamlessSeamlessPreviousLayer"];
	if (theLayer == nil) {
		theLayer = [CALayer layer]; // You don't want initWithLayer, and you don't want any class other than CALayer.
		[CATransaction begin];
		[CATransaction setDisableActions:YES];
        [theLayer setValue:@YES forKey:@"isSeamlessPreviousLayer"];
        [self setValue:theLayer forKey:@"seamlessSeamlessPreviousLayer"];
		[CATransaction commit];
    }
	return theLayer;
}

-(void)seamlessLayerSwizzleWillChangeValueForKey:(NSString*)theKey { // in ML, this happens after actionForKey. In Lion it happened before actionForKey:
    if ((self.modelLayer == nil || self.modelLayer == self) && ![[self valueForKey:@"isSeamlessPreviousLayer"] boolValue] && ![theKey isEqualToString:@"delegate"] && ![theKey isEqualToString:@"contents"] && ![theKey isEqualToString:@"mask"]) { // @"delegate" sometimes can crash. @"contents" and @"mask" are just in case. // View animation in Lion and below will need to figure out another place to set previousValueForKey, because of view to layer geometry glue code.
        id theValue = [self valueForKeyPath:theKey];
        if ([theValue respondsToSelector:@selector(objCType)]) {
            const char *objCType = [theValue objCType];
            //if (strcmp(objCType,@encode(CGPoint))==0 || strcmp(objCType,@encode(CGSize))==0 || strcmp(objCType,@encode(CGRect))==0 || strcmp(objCType,@encode(CATransform3D))==0 || strcmp(objCType,@encode(float))==0 || strcmp(objCType,@encode(double))==0) {
            if (strcmp(objCType,@encode(CGPoint))==0 || strcmp(objCType,@encode(CGSize))==0 || strcmp(objCType,@encode(CGRect))==0 || strcmp(objCType,@encode(CATransform3D))==0 || strcmp(objCType,@encode(float))==0 || strcmp(objCType,@encode(double))==0 ||
                strcmp(objCType,@encode(NSInteger))==0 || strcmp(objCType,@encode(NSUInteger))==0 || strcmp(objCType,@encode(long))==0 || strcmp(objCType,@encode(long long))==0 || strcmp(objCType,@encode(int))==0 || strcmp(objCType,@encode(short))==0 || strcmp(objCType,@encode(char))==0 || strcmp(objCType,@encode(unsigned long))==0 || strcmp(objCType,@encode(unsigned long long))==0 || strcmp(objCType,@encode(unsigned int))==0 || strcmp(objCType,@encode(unsigned short))==0 || strcmp(objCType,@encode(unsigned char))==0) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [self.seamlessPreviousLayer setValue:[self valueForKey:theKey] forKey:theKey];
                [CATransaction commit];
            }
        }
	}
	[self seamlessLayerSwizzleWillChangeValueForKey:theKey];
}

const CGFloat seamlessFloat(CGFloat old, CGFloat nu, double progress, BOOL isSeamless) {
    return (isSeamless) ? (1-progress) * (old-nu) : old+(progress*(nu-old));
}


-(void)seamlessLayerSwizzleAddAnimation:(CAAnimation*)theAnimation forKey:(NSString*)theKey { // I do this here because in animationForKey: and actionForKey: the fromValue is set to the presentationLayer value, but keyPath, toValue, and byValue are null. Key is known but conversions to keyPath are not, for example frameOrigin to layer.position.
    
    if ([theAnimation isKindOfClass:[CABasicAnimation class]]) {
        CABasicAnimation *theBasicAnimation = (CABasicAnimation*)theAnimation;
        
        BOOL isSeamlessClass = [theAnimation isKindOfClass:[SeamlessAnimation class]];
        BOOL isSeamless = (theBasicAnimation.seamlessNegativeDelta || [CATransaction seamlessNegativeDelta]);
        
        SeamlessTimingBlock theTimingBlock = theBasicAnimation.seamlessTimingBlock;
        if (theTimingBlock == nil) theTimingBlock = [CATransaction seamlessTimingBlock];
        if (isSeamless || theTimingBlock) {
            
            NSString *theKeyPath = theBasicAnimation.keyPath;
            if (theKeyPath == nil) theKeyPath = theKey; // At one point some appKit default animations had a keyPath of nil, is this still true?
            
            id theOldValue = nil;
            if (isSeamlessClass || isSeamless) {
                if (isSeamlessClass) theOldValue = [(SeamlessAnimation*)theAnimation oldValue];
                if (theOldValue == nil) theOldValue = [self.seamlessPreviousLayer valueForKeyPath:theKeyPath];
            } else theOldValue = theBasicAnimation.fromValue;
            
            if (theOldValue != nil && [theOldValue respondsToSelector:@selector(objCType)]) {
                const char *objCType = [theOldValue objCType];
                id theNewValue = [theBasicAnimation toValue];
                if (isSeamlessClass && [(SeamlessAnimation*)theAnimation nuValue] != nil) theNewValue = [(SeamlessAnimation*)theAnimation nuValue];
                if (theNewValue == nil) theNewValue = [self valueForKeyPath:theKeyPath];
                
                
                SeamlessKeyBehavior animationBehavior = [theBasicAnimation seamlessKeyBehavior];
                if (animationBehavior == seamlessKeyDefault) animationBehavior = [CATransaction seamlessKeyBehavior];
                NSString *seamlessKey = theKey;
                if (animationBehavior == seamlessKeyExact) {
                    seamlessKey = theKey; // duplicated code but prevents seamlessKeyDefault behavior
                } else if (animationBehavior == seamlessKeyIncrement) {
                    seamlessKey = [CALayer seamlessAnimationKey];
                } else if (animationBehavior == seamlessKeyIncrementKey) {
                    if (theKey == nil) seamlessKey = [CALayer seamlessAnimationKey];
                    else seamlessKey = [theKey stringByAppendingString:[CALayer seamlessAnimationKey]];
                } else if (animationBehavior == seamlessKeyIncrementKeyPath) {
                    seamlessKey = [theKeyPath stringByAppendingString:[CALayer seamlessAnimationKey]];
                } else if (isSeamless) {
                    seamlessKey = nil; // seamlessKeyDefault is nil if seamlessNegativeDelta
                } else {
                    seamlessKey = theKey; // seamlessKeyDefault
                }
                
                SeamlessEasedAnimation *theKeyframeAnimation = [SeamlessEasedAnimation animationWithKeyPath:theKeyPath];
                [theKeyframeAnimation setValue:theAnimation forKey:@"seamlessOriginalAnimation"];
                theKeyframeAnimation.duration = theAnimation.duration;
                if (theAnimation.delegate) theKeyframeAnimation.delegate = [SeamlessDelegate singleton];
                
                [theAnimation setValue:theKeyframeAnimation forKey:@"seamlessReplacedAnimation"];
                
                NSSet *undefinedKeys = [theBasicAnimation valueForKey:@"seamlessUndefinedKeys"];
                [theKeyframeAnimation setValue:undefinedKeys forKey:@"seamlessUndefinedKeys"];
                for (NSString* theKey in undefinedKeys) {
                    [theKeyframeAnimation setValue:[theBasicAnimation valueForKey:theKey] forKey:theKey];
                }
                
                CAMediaTimingFunction *perfectTimingFunction = [CAMediaTimingFunction functionWithControlPoints:0.5 :0.0 :0.5 :1.0f];
                if (!theTimingBlock) theKeyframeAnimation.timingFunction = perfectTimingFunction;
                theKeyframeAnimation.fillMode = theBasicAnimation.fillMode;
                theKeyframeAnimation.additive = theBasicAnimation.additive;
                if (isSeamless) {
                    theKeyframeAnimation.fillMode = kCAFillModeBackwards; // In case mediaTiming is off by a small amount. It can happen post 10.5 Leopard
                    theKeyframeAnimation.additive = YES;
                }
                theKeyframeAnimation.beginTime = theBasicAnimation.beginTime;
                theKeyframeAnimation.timeOffset = theBasicAnimation.timeOffset;
                
                NSUInteger steps = [theBasicAnimation seamlessSteps];
                if (!steps) steps = [CATransaction seamlessSteps];
                if (!theTimingBlock) steps = 2;
                else if (steps < 2) steps = kSeamlessSteps;
                
                NSArray *(^keyframeValues)(NSValue *(^theValueBlock)(double)) = ^(NSValue *(^theValueBlock)(double)) { // A block that takes a block as an argument.
                    NSMutableArray *theValues = @[].mutableCopy;
                    for (NSUInteger i=0; i<steps; i++) {
                        double progress = (1.0/(steps-1))*i;
                        if (theTimingBlock) progress = theTimingBlock(progress);
                        NSValue *theFrame = theValueBlock(progress);
                        [theValues addObject:theFrame];
                    }
                    return theValues;
                };
                
                
                if (strcmp(objCType,@encode(CATransform3D))==0) {
                    CATransform3D theOld = [theOldValue CATransform3DValue];
                    CATransform3D theNew = [theNewValue CATransform3DValue];
                    CATransform3D theFrom = (isSeamless) ? CATransform3DConcat(theOld,CATransform3DInvert(theNew)) : theOld;
                    CATransform3D theTo = (isSeamless) ? CATransform3DIdentity : theNew;
                    
                    __weak typeof(self) me = self;
                    theKeyframeAnimation.values = keyframeValues(^(double progress) {
                        CATransform3D theResult = [me seamlessBlendTransform:theFrom to:theTo progress:progress];
                        return [NSValue valueWithCATransform3D:theResult];
                    });
                    return [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:seamlessKey];
                    
                } else if (strcmp(objCType,@encode(CGPoint))==0) {
                    CGPoint oldPoint, newPoint;
#if TARGET_OS_IPHONE
                    oldPoint = [theOldValue CGPointValue];
                    newPoint = [theNewValue CGPointValue];
#else
                    oldPoint = [theOldValue pointValue];
                    newPoint = [theNewValue pointValue];
#endif
                    
                    theKeyframeAnimation.values = keyframeValues(^(double progress) {
                        CGFloat theX = seamlessFloat(oldPoint.x, newPoint.x, progress, isSeamless);
                        CGFloat theY = seamlessFloat(oldPoint.y, newPoint.y, progress, isSeamless);
#if TARGET_OS_IPHONE
                        return [NSValue valueWithCGPoint:CGPointMake(theX, theY)];
#else
                        return [NSValue valueWithPoint:NSMakePoint(theX, theY)];
#endif
                    });
                    return [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:seamlessKey];
                    
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
                        SeamlessEasedAnimation *theOriginAnimation = nil;
                        SeamlessEasedAnimation *theSizeAnimation = nil;
                        
                        theOriginAnimation = [SeamlessEasedAnimation animationWithKeyPath:[theKeyPath stringByAppendingString:@".origin"]];
                        theOriginAnimation.values = keyframeValues(^(double progress) {
                            CGFloat theX = seamlessFloat(oldRect.origin.x, newRect.origin.x, progress, isSeamless);
                            CGFloat theY = seamlessFloat(oldRect.origin.y, newRect.origin.y, progress, isSeamless);
#if TARGET_OS_IPHONE
                            return [NSValue valueWithCGPoint:CGPointMake(theX, theY)];
#else
                            return [NSValue valueWithPoint:NSMakePoint(theX, theY)];
#endif
                        });
                        theOriginAnimation.fillMode = kCAFillModeBackwards;
                        theOriginAnimation.additive = YES;
                        
                        theSizeAnimation = [SeamlessEasedAnimation animationWithKeyPath:[theKeyPath stringByAppendingString:@".size"]];
                        theSizeAnimation.values = keyframeValues(^(double progress) {
                            CGFloat theW = seamlessFloat(oldRect.size.width, newRect.size.width, progress, isSeamless);
                            CGFloat theH = seamlessFloat(oldRect.size.height, newRect.size.height, progress, isSeamless);
#if TARGET_OS_IPHONE
                            return [NSValue valueWithCGSize:CGSizeMake(theW, theH)];
#else
                            return [NSValue valueWithSize:NSMakeSize(theW, theH)];
#endif
                        });
                        theSizeAnimation.fillMode = kCAFillModeBackwards;
                        theSizeAnimation.additive = YES;
                        
                        
                        CAAnimationGroup *theGroupAnimation = [CAAnimationGroup animation];
                        if (!theTimingBlock) theGroupAnimation.timingFunction = perfectTimingFunction;
                        theGroupAnimation.fillMode = kCAFillModeBoth;
                        theGroupAnimation.animations = [NSArray arrayWithObjects:theOriginAnimation, theSizeAnimation, nil];
                        
                        [theGroupAnimation setValue:theAnimation forKey:@"seamlessOriginalAnimation"];
                        
                        [theGroupAnimation setValue:undefinedKeys forKey:@"seamlessUndefinedKeys"];
                        for (NSString* theKey in undefinedKeys) {
                            [theGroupAnimation setValue:[theBasicAnimation valueForKey:theKey] forKey:theKey];
                        }
                        
                        if (theAnimation.delegate) theGroupAnimation.delegate = [SeamlessDelegate singleton];
                        theGroupAnimation.duration = theAnimation.duration;
                        theGroupAnimation.beginTime = theBasicAnimation.beginTime;
                        theGroupAnimation.timeOffset = theBasicAnimation.timeOffset;
                        
                        [theAnimation setValue:theGroupAnimation forKey:@"seamlessReplacedAnimation"];
                        
                        return [self seamlessLayerSwizzleAddAnimation:theGroupAnimation forKey:seamlessKey];
                        
                    } else { // rect animation was not broken in 10.5 Leopard:
                        CGRect oldRect,newRect;
#if TARGET_OS_IPHONE
                        oldRect = [theOldValue CGRectValue];
                        newRect = [theNewValue CGRectValue];
#else
                        oldRect = [theOldValue rectValue];
                        newRect = [theNewValue rectValue];
#endif
                        theKeyframeAnimation.values = keyframeValues(^(double progress) {
                            CGFloat theX = seamlessFloat(oldRect.origin.x, newRect.origin.x, progress, isSeamless);
                            CGFloat theY = seamlessFloat(oldRect.origin.y, newRect.origin.y, progress, isSeamless);
                            CGFloat theW = seamlessFloat(oldRect.size.width, newRect.size.width, progress, isSeamless);
                            CGFloat theH = seamlessFloat(oldRect.size.height, newRect.size.height, progress, isSeamless);
#if TARGET_OS_IPHONE
                            return [NSValue valueWithCGRect:CGRectMake(theX, theY, theW, theH)];
#else
                            return [NSValue valueWithRect:NSMakeRect(theX, theY, theW, theH)];
#endif
                        });
                        return [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:seamlessKey];
                        
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
                    
                    theKeyframeAnimation.values = keyframeValues(^(double progress) {
                        CGFloat theW = seamlessFloat(oldSize.width, newSize.width, progress, isSeamless);
                        CGFloat theH = seamlessFloat(oldSize.height, newSize.height, progress, isSeamless);
#if TARGET_OS_IPHONE
                        return [NSValue valueWithCGSize:CGSizeMake(theW, theH)];
#else
                        return [NSValue valueWithSize:NSMakeSize(theW, theH)];
#endif
                    });
                    return [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:seamlessKey];
                    
                } else if (strcmp(objCType,@encode(float))==0 || strcmp(objCType,@encode(double))==0 ||
                           // animate ints as doubles just for the hell of it:
                           // this does not make sense for unsigned, now does it?
                           // I do this in case someone animates from @0 to @1 instead of @0.0 to @1.0
                           strcmp(objCType,@encode(NSInteger))==0 || strcmp(objCType,@encode(NSUInteger))==0 || strcmp(objCType,@encode(long))==0 || strcmp(objCType,@encode(long long))==0 || strcmp(objCType,@encode(int))==0 || strcmp(objCType,@encode(short))==0 || strcmp(objCType,@encode(char))==0 || strcmp(objCType,@encode(unsigned long))==0 || strcmp(objCType,@encode(unsigned long long))==0 || strcmp(objCType,@encode(unsigned int))==0 || strcmp(objCType,@encode(unsigned short))==0 || strcmp(objCType,@encode(unsigned char))==0) {
                    double old = [theOldValue doubleValue];
                    double nu = [theNewValue doubleValue];
                    
                    theKeyframeAnimation.values = keyframeValues(^(double progress) {
                        return [NSNumber numberWithDouble:(isSeamless) ? (1-progress) * (old-nu) : old+(progress*(nu-old))];
                    });
                    return [self seamlessLayerSwizzleAddAnimation:theKeyframeAnimation forKey:seamlessKey];
                } else {
                    //NSLog(@"unknown objCType:%@;",[[NSString alloc] initWithCString:objCType encoding:NSASCIIStringEncoding]);
                }
            }
        }
    }
    [theAnimation setValue:@YES forKey:@"seamlessNotSeamless"];
    [self seamlessLayerSwizzleAddAnimation:theAnimation forKey:theKey];
}

-(CATransform3D)seamlessBlendTransform:(CATransform3D)fromTransform to:(CATransform3D)toTransform progress:(double)progress {
    CATransform3D final = seamlessBlend(fromTransform,toTransform,progress);
    return final;
}

@end
