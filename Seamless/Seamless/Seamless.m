//
//  Seamless.m
//  Seamless
//
//  Created by Kevin Doughty on 3/8/13.
//  Copyright (c) 2013 Kevin Doughty. All rights reserved.
//

#import <objc/objc-runtime.h>

void SeamlessSwizzle(Class c, SEL orig, SEL new) {
    Method origMethod = class_getInstanceMethod(c, orig);
    Method newMethod = class_getInstanceMethod(c, new);
    if (class_addMethod(c, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
        class_replaceMethod(c, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
    else method_exchangeImplementations(origMethod, newMethod);
}
