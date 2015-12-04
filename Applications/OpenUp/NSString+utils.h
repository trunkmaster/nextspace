/*
 File:       NSString+utils.h
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include <Foundation/Foundation.h>

@interface NSString (utils)
- stringByReplacing:(NSString *)value with:(NSString *)newValue;
- stringByReplacingValuesInArray:(NSArray *)values withValuesInArray:(NSArray *)newValues;
- stringByDeletingSuffix:(NSString *)suffix;
- stringWithShellCharactersQuoted;
- (BOOL)stringContainsValueFromArray:(NSArray *)theValues;
@end
