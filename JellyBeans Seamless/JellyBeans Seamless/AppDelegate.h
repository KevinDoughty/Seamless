//
//  AppDelegate.h
//  JellyBeans Seamless
//
//  Created by Kevin Doughty on 3/8/13.
//  Copyright (c) 2013 Kevin Doughty. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <Cocoa/Cocoa.h>
@class JellyBeanView;
@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet JellyBeanView *viewOne;
@property (assign) IBOutlet JellyBeanView *viewTwo;
@end