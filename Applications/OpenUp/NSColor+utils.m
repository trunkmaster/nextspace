/*
 File:       NSColor+utils.m
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include "NSColor+utils.h"

@implementation NSColor (utils)

+ (NSColor *)tanTextBackgroundColor
{
  return [NSColor colorWithDeviceRed:(221.0 / 255.0)
                               green:(187.0 / 255.0)
                                blue:(136.0 / 255.0)
                               alpha:1.0];
}

@end
