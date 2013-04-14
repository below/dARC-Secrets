//
//  dARC_SecretsTests.m
//  dARC-SecretsTests
//
//  Created by Alexander v. Below on 14.04.13.
//  Copyright (c) 2013 Alexander v. Below. All rights reserved.
//

#import "dARC_SecretsTests.h"
#import "DerivedClass.h"

@implementation dARC_SecretsTests

- (void)testErrorExample
{
    BaseClass * testClass = [DerivedClass new];
    
    if ([testClass performTest]) {
        NSLog (@"The number is even");
    }
    else {
        NSLog(@"The number is odd");
    }
    
}

@end
