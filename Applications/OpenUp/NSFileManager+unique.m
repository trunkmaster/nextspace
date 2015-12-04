/*
 File:       NSFileManager+unique.m
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include "NSFileManager+unique.h"

@implementation NSFileManager(unique)

- (NSString *)createUniqueDirectoryAtPath:(NSString *)path
                         withBaseFilename:(NSString *)baseName
                               attributes:(NSDictionary *)attributes
                           maximumRetries:(int)maximumRetries;
{
    // We'll need to attempt to create a uniquely named directory based on the baseComponent.
    // which should be in the form of "SomeName%@"
    //
    // We should specify how many times we'll allow this to try to avoid getting caught in a loop.

    int each_try=0;
    BOOL keep_trying=YES;

    if (![[NSFileManager defaultManager] isWritableFileAtPath:path])
        return nil;

    while (keep_trying)
      {
        NSString *filename;
        NSString *attemptPath;

        filename=[NSString stringWithFormat:baseName,[NSNumber numberWithInt:each_try]];
        attemptPath=[NSString pathWithComponents:[NSArray arrayWithObjects:path,filename,nil]];
        if ([[NSFileManager defaultManager] createDirectoryAtPath:attemptPath attributes:attributes])
            return attemptPath;
        each_try++;
        keep_trying = (each_try < maximumRetries);
      }
    return nil;
}

- (NSString *)createUniqueDirectoryAtPath:(NSString *)path
                         withBaseFilename:(NSString *)baseName
                               attributes:(NSDictionary *)attributes;
{
    return [self createUniqueDirectoryAtPath:path
                            withBaseFilename:baseName
                                  attributes:attributes
                              maximumRetries:500];
}

@end
