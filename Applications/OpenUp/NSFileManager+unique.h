/*
 File:       NSFileManager+unique.h
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include <AppKit/AppKit.h>

@interface NSFileManager(unique)
- (NSString *)createUniqueDirectoryAtPath:(NSString *)path withBaseFilename:(NSString *)baseName attributes:(NSDictionary *)attributes;
- (NSString *)createUniqueDirectoryAtPath:(NSString *)path withBaseFilename:(NSString *)baseName attributes:(NSDictionary *)attributes maximumRetries:(int)maximumRetries;

@end
