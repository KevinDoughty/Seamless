/*
 Copyright (c) 2014, Kevin Doughty
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

typedef double(^SeamlessTimingBlock)(double);

typedef enum SeamlessKeyBehavior : NSUInteger { // In addAnimation:forKey: nil or unique keys are critical to allow multiple additive animations running at the same time. Unique keys are required if you want to recall and copy animations, useful for inserting new layers animating in sync with existing layers that have running animations.
    seamlessKeyDefault, // If seamlessNegativeDelta == YES default is to use a nil key, otherwise use Core Animation default behavior of using the exact key as passed.
    seamlessKeyExact, // Use the exact key as passed to addAnimation:forKey: (Useful if you have your own scheme for creating unique keys, for recalling them, most likely to copy animations)
    seamlessKeyNil, // Use a nil key regardless of what was passed in addAnimation:forKey:
    seamlessKeyIncrement, // Deprecated. Just a number. Key passed in addAnimation:forKey: is ignored.
    seamlessKeyIncrementKey, // The key plus a number appended. If the key passed in addAnimation:forKey: is nil you get just a number.
    seamlessKeyIncrementKeyPath // The key path plus a number appended.
} SeamlessKeyBehavior;
