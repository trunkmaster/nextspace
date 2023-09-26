/*
 File:       NSString+utils.m
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include "NSString+utils.h"

@implementation NSString (utils)

- stringByReplacing:(NSString *)value with:(NSString *)newValue
{
  NSRange remainingRange;
  NSMutableString *newString;
  BOOL done;
  int newValueLength = [newValue length];

  newString = [self mutableCopy];

  remainingRange = NSMakeRange(0, [newString length]);

  done = NO;

  while (!done) {
    NSRange foundSourceRange;

    foundSourceRange = [newString rangeOfString:value options:NSLiteralSearch range:remainingRange];

    if (foundSourceRange.length > 0) {
      [newString replaceCharactersInRange:foundSourceRange withString:newValue];
      remainingRange.location = foundSourceRange.location + newValueLength;
      remainingRange.length = [newString length] - remainingRange.location;
    } else
      done = YES;
  }

  return newString;
}

- stringByReplacingValuesInArray:(NSArray *)values withValuesInArray:(NSArray *)newValues
{
  int i;
  NSString *tempString = self;

  for (i = 0; i < [values count]; i++) {
    NSString *newValue;

    newValue = [tempString stringByReplacing:[values objectAtIndex:i]
                                        with:[newValues objectAtIndex:i]];
    tempString = newValue;
  }
  return tempString;
}

- stringByDeletingSuffix:(NSString *)suffix
{
  if ([[self substringFromIndex:([self length] - [suffix length])] isEqual:suffix])
    return [self substringToIndex:([self length] - [suffix length])];
  return nil;
}

- stringWithShellCharactersQuoted
{
  NSString *tempStr;
  tempStr = [self stringByReplacing:@"\"" with:@"\\\""];
  return [NSString stringWithFormat:@"\"%@\"", tempStr];
}

- (BOOL)stringContainsValueFromArray:(NSArray *)theValues
{
  NSEnumerator *overItems;
  id eachItem;

  overItems = [theValues objectEnumerator];
  while ((eachItem = [overItems nextObject])) {
    NSRange foundSourceRange;

    foundSourceRange = [self rangeOfString:eachItem options:NSLiteralSearch];
    if (foundSourceRange.length != 0)
      return YES;
  }
  return NO;
}
@end
