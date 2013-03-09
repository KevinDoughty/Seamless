//
//  AppDelegate.m
//  JellyBeans Seamless
//
//  Created by Kevin Doughty on 3/8/13.
//  Copyright (c) 2013 Kevin Doughty. All rights reserved.
//

#import "AppDelegate.h"
#import "JellyBeanView.h"
@implementation AppDelegate

@synthesize window, viewOne, viewTwo;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.viewOne.animationDuration = 5.0;
    self.viewTwo.animationDuration = 0.5;
}

@end
