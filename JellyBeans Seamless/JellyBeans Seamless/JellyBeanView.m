//
//  JellyBeanView.m
//  JellyBeans
//
//  Created by Kevin Doughty on 8/11/12.
//  Copyright (c) 2012 Kevin Doughty. All rights reserved.
//

#import "JellyBeanView.h"
#import <QuartzCore/QuartzCore.h>
#import <Seamless/Seamless.h>

@interface JellyBeanView ()
@property (retain) NSEnumerator *layerEnumerator;
@property (retain) NSArray *runLoopModes;
@property (assign) CGFloat previousWidth;
@property (assign) NSUInteger layerIndex;
@end

@implementation JellyBeanView
@synthesize layerCount, runLoopModes, itemDimension, previousWidth, layerIndex;

-(void) awakeFromNib {
    
    layerCount = 0; // accessor does stuff
    
    self.layerIndex = NSNotFound;
    self.itemDimension = 20.0;
    self.animationDuration = 1.0;
    self.layerEnumerator = nil;
    self.runLoopModes = [NSArray arrayWithObjects:@"NSDefaultRunLoopMode",@"NSEventTrackingRunLoopMode",nil];
    
    self.layer = [CALayer layer];
    self.wantsLayer = YES;
    self.layer.delegate = self;
    
    srandomdev();
    CGFloat red = (random() % 256) / 256.0;
	CGFloat green =  (random() % 256) / 256.0;
	CGFloat blue =  (random() % 256) / 256.0;
	CGColorRef backgroundColorRef = CGColorCreateGenericRGB(red,green,blue,0.5);
	self.layer.backgroundColor = backgroundColorRef;
	CGColorRelease(backgroundColorRef);
    
    self.layerCount = 500; // accessor does stuff
}


-(BOOL) isFlipped {
    return YES;
}

-(void)setItemDimension:(CGFloat)theItemDimension {
    if (theItemDimension < 5.0) theItemDimension = 5.0;
    itemDimension = theItemDimension;
    [self setNeedsLayout:YES];
}
-(void)setLayerCount:(NSUInteger)theCount {
	if (self.wantsLayer) {
        [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(layoutPass) object:nil];
        self.layerEnumerator = nil;
        
        [CATransaction begin];
		[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        
        NSUInteger theIndex = layerCount;
        NSArray *theSublayers = self.layer.sublayers;
        while (theIndex > theCount) {
            theIndex--;
            [[theSublayers objectAtIndex:theIndex] removeFromSuperlayer];
        }
        while (theIndex < theCount) {
            theIndex++;
            [self createLayer];
        }
        [CATransaction commit];
        
        [self setNeedsLayout:YES];
    }
    layerCount = theCount;
}

-(void) createLayer {
    CGFloat theDiameter = self.itemDimension;
    
    CALayer *theLayer = [CALayer layer];
    theLayer.bounds = CGRectMake(0,0,theDiameter, theDiameter);
    theLayer.cornerRadius = theDiameter/2.0;
    theLayer.anchorPoint = CGPointZero;
    
    CGFloat red = (random() % 256) / 256.0;
	CGFloat green =  (random() % 256) / 256.0;
	CGFloat blue =  (random() % 256) / 256.0;
	CGColorRef backgroundColorRef = CGColorCreateGenericRGB(red,green,blue,0.5);
	theLayer.backgroundColor = backgroundColorRef;
	CGColorRelease(backgroundColorRef);
    /*
    CGColorRef borderColorRef = CGColorCreateGenericRGB(1.0-red,1.0-green,1.0-blue,0.5);
	theLayer.borderColor = borderColorRef;
	CGColorRelease(borderColorRef);
    theLayer.borderWidth = 2.0;
    */
    [self.layer addSublayer:theLayer];
}


-(void) layoutSublayersOfLayer:(CALayer*)theContainerLayer {
	
    if (!self.wantsLayer) return;
    
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(layoutPass) object:nil];
	/*
    NSArray *theSublayers = self.layer.sublayers;
    NSArray *notLaidOut = [self.layerEnumerator allObjects];
    NSMutableArray *alreadyLaidOut = [[NSMutableArray alloc] initWithArray:theSublayers];
    [alreadyLaidOut removeObjectsInArray:notLaidOut];
    NSMutableArray *sortedArray = [[NSMutableArray alloc] initWithArray:notLaidOut];
    [sortedArray addObjectsFromArray:alreadyLaidOut];
    self.layerEnumerator = [sortedArray objectEnumerator];
    */
    
   
    NSArray *theSublayers = theContainerLayer.sublayers;
    NSUInteger theCount = theSublayers.count;
    if (self.layerIndex >= theCount) self.layerIndex = 0;
    NSInteger theDirection = 0;
    if (self.previousWidth < self.bounds.size.width) theDirection = 1;
    else theDirection = -1;
    NSMutableArray *theArray = [NSMutableArray arrayWithCapacity:theCount];
    
    NSInteger theIndex = self.layerIndex;
    if (theDirection > 0) theIndex++;
    
    NSRange theFirstRange = NSMakeRange(theIndex,theCount-theIndex);
    NSRange theSecondRange = NSMakeRange(0, theIndex);
    if (theFirstRange.length) [theArray addObjectsFromArray:[theSublayers subarrayWithRange:theFirstRange]];
    if (theSecondRange.length) [theArray addObjectsFromArray:[theSublayers subarrayWithRange:theSecondRange]];
    
    if (theDirection > 0) self.layerEnumerator = [theArray objectEnumerator];
    else self.layerEnumerator = [theArray reverseObjectEnumerator];
    
    
    
    self.previousWidth = self.bounds.size.width;
    
    
    [self performSelector:@selector(layoutPass) withObject:nil afterDelay:0 inModes:runLoopModes];
}

-(void) layoutPass {
	CALayer *theLayer = [self.layerEnumerator nextObject];
	if (theLayer == nil) self.layerIndex = NSNotFound;
    else {
        self.layerIndex = [self.layer.sublayers indexOfObject:theLayer];
        [CATransaction setAnimationDuration:self.animationDuration];
        [CATransaction setSeamlessTimingBlock:^ (double progress) {
            double omega = 20.0;
            double zeta = 0.75;
            progress = 1 - cosf( progress * M_PI / 2 );
            double beta = sqrt(1.0 - zeta * zeta);
            progress = 1.0 / beta * expf(-zeta * omega * progress) * sinf(beta * omega * progress + atanf(beta / zeta));
            return 1-progress;
        }];
        theLayer.position = [self gridPointForLayer:theLayer];
        theLayer.bounds = CGRectMake(0,0,self.itemDimension,self.itemDimension);
        theLayer.cornerRadius = self.itemDimension/2.0;
        [self performSelector:@selector(layoutPass) withObject:nil afterDelay:0 inModes:runLoopModes];
	}
}

-(CGPoint) gridPointForLayer:(CALayer*)theLayer {
	NSUInteger theIndex = [self.layer.sublayers indexOfObject:theLayer];
	CGFloat theItemDimension = roundf(self.itemDimension);
	if (theItemDimension < 1.0) theItemDimension = 1.0;
	NSUInteger countPerRow = self.bounds.size.width / theItemDimension;
	if (!countPerRow) countPerRow = 1;
	CGFloat x = (itemDimension * theLayer.anchorPoint.x) + ((CGFloat)(theIndex % countPerRow) * (theItemDimension));
	CGFloat y = (itemDimension * theLayer.anchorPoint.y) + (floor((CGFloat)theIndex / (CGFloat)countPerRow) * theItemDimension);
	return CGPointMake(x,y);
}

-(void)setNilValueForKey:(NSString*)theKey { // gotta love number formatters
    if ([theKey isEqualToString:@"layerCount"] || [theKey isEqualToString:@"animationDuration"] || [theKey isEqualToString:@"itemDimension"]) {
        [self setValue:@0 forKey:theKey];
    } else [super setNilValueForKey:theKey];
}
@end
