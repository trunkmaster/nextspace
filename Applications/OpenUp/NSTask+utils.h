/*
 File:       NSTask+utils.h
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include <AppKit/AppKit.h>

@interface NSTask(utils)
+ (NSDictionary *)performTask:(NSString *)command
                  inDirectory:(NSString *)directory
                     withArgs:(NSArray *)values;


@end
