/*
 Copyright (c) 2014, Kevin Doughty
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "SeamlessDelegate.h"
#import <QuartzCore/QuartzCore.h>

@implementation SeamlessDelegate
+(instancetype)singleton {
    static dispatch_once_t pred;
    static SeamlessDelegate *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[SeamlessDelegate alloc] init];
    });
    return shared;
}
- (void)animationDidStart:(CAAnimation *)theAnimation {
    CAAnimation *theOriginal = [theAnimation valueForKey:@"seamlessOriginalAnimation"];
    if ([theOriginal.delegate respondsToSelector:@selector(animationDidStart:)]) {
        [theOriginal.delegate animationDidStart:theOriginal];
    }
}
-(void)animationDidStop:(CAAnimation*)theAnimation finished:(BOOL)theFinished {
    CAAnimation *theOriginal = [theAnimation valueForKey:@"seamlessOriginalAnimation"];
    if ([theOriginal.delegate respondsToSelector:@selector(animationDidStop:finished:)]) {
        [theOriginal.delegate animationDidStop:theOriginal finished:theFinished];
    }
    //[theAnimation setValue:nil forKey:@"seamlessOriginalAnimation"];
}
@end
