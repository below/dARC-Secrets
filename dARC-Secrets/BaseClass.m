//
//  BaseClass.m
//  FootShooter
//
//  Created by Alexander v. Below on 10.04.13.
//  Copyright (c) 2013 Alexander v. Below. All rights reserved.
//

#import "BaseClass.h"
#import "DerivedClass.h"

@implementation BaseClass
- (BOOL) performTest {
    if ([self doFoo]) {
        return YES;
    }
    else {
        return NO;
    }
}

- (id) doFoo {
    NSAssert(false, @"Abstract implementation");
    return nil;
}
@end
