/*
 File:       NSTask+utils.m
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include "NSTask+utils.h"

@implementation NSTask (utils)

+ (NSDictionary *)performTask:(NSString *)command
                  inDirectory:(NSString *)directory
                     withArgs:(NSArray *)values
{
  NSTask *pipeTask;
  NSPipe *readPipe;
  NSFileHandle *readHandle;
  NSData *inData = nil;
  NSMutableData *outData;
  NSMutableDictionary *outputDict;

  outputDict = [NSMutableDictionary dictionary];
  [outputDict setObject:command forKey:@"LaunchPath"];
  [outputDict setObject:directory forKey:@"CurrentDirectoryPath"];
  [outputDict setObject:values forKey:@"LaunchArguments"];

  pipeTask = [[NSTask alloc] init];
  readPipe = [NSPipe pipe];
  readHandle = [readPipe fileHandleForReading];
  outData = (id)[NSMutableData data];
  [pipeTask setCurrentDirectoryPath:directory];

  [pipeTask setStandardError:readPipe];
  [pipeTask setLaunchPath:command];
  [pipeTask setArguments:values];
  [pipeTask launch];

  // if we are sure that the pipe is running, then we'll cycle
  // while the pipe reads any available data from stderr.  This
  // will only read stuff if the file that we're attempting to
  // decompress is corrupted, or the commandline app that we've
  // launched is horribly verbose (perhaps an argument causes an
  // app to be verbose?)
  if ([pipeTask isRunning]) {
    while ((inData = [readHandle availableData]) && [inData length]) {
      [outData appendData:inData];
    }
  }

  [pipeTask waitUntilExit];

  [outputDict setObject:[[[NSString alloc] initWithData:outData
                                               encoding:NSASCIIStringEncoding] autorelease]
                 forKey:@"StandardError"];
  [outputDict setObject:[NSNumber numberWithInt:[pipeTask terminationStatus]]
                 forKey:@"TerminationStatus"];

  [pipeTask release];

  return outputDict;
}

@end
