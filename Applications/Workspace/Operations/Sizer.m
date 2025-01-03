/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <SystemKit/OSEDefaults.h>

#import "Operations/Sizer.h"
#import "Processes/BGProcess.h"

NSString *WMSizerGotNumbersNotification = @"WMSizerGotNumbersNotification";

static inline void ReportGarbage(NSString *garbage)
{
  NSDebugLLog(@"Sizer", @"Got garbage \"%@\" from Sizer.tool. Ignoring...", garbage);
}

//=============================================================================
// Main part of class
//=============================================================================

@implementation Sizer

- (id)initWithOperationType:(OperationType)opType
                  sourceDir:(NSString *)sourceDir
                  targetDir:(NSString *)targetDir
                      files:(NSArray *)fileList
                    manager:(ProcessManager *)delegate
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  self = [super initWithOperationType:opType
                            sourceDir:sourceDir
                            targetDir:targetDir
                                files:fileList
                              manager:delegate];

  numberOfFiles = 0;
  totalBatchSize = 0;

  inputLock = [NSLock new];

  // Create task for tool
  task = [NSTask new];
  [task setLaunchPath:[[NSBundle mainBundle] pathForResource:@"Sizer" ofType:@"tool"]];
  [task setArguments:@[
    @"-Operation", [self typeString], @"-Source", currSourceDir, @"-Destination", currTargetDir,
    @"-Files", [fileList description]
  ]];

  readPipe = [NSPipe new];
  writePipe = [NSPipe new];
  [task setStandardInput:writePipe];
  [task setStandardOutput:readPipe];

  [nc addObserver:self
         selector:@selector(taskTerminated)
             name:NSTaskDidTerminateNotification
           object:task];
  [nc addObserver:self
         selector:@selector(readInput:)
             name:NSFileHandleDataAvailableNotification
           object:[readPipe fileHandleForReading]];

  [[readPipe fileHandleForReading] waitForDataInBackgroundAndNotify];

  [task launch];

  [self setState:OperationRunning];

  return self;
}

- (void)dealloc
{
  NSDebugLLog(@"Sizer", @"Sizer: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

//
//--- Accessories ------------------------------------------------------------
//
- (NSString *)titleString
{
  if ([files count] > 1) {
    return [NSString stringWithFormat:@"%@/*", source];
  } else {
    NSString *format;

    if ([source length] > 1)
      format = @"%@/%@";
    else
      format = @"%@%@";

    return [NSString stringWithFormat:format, source, [files objectAtIndex:0]];
  }
}

//
//--- Action and state -------------------------------------------------------
//
- (void)stop:(id)sender
{
  [task interrupt];
  [self setState:OperationStopped];
}

- (void)reportNumbers
{
  if (state == OperationStopped) {
    [[NSNotificationCenter defaultCenter] postNotificationName:WMSizerGotNumbersNotification
                                                        object:self
                                                      userInfo:nil];
  } else {
    NSNumber *fileCount, *batchSize;
    NSDictionary *userInfo;

    fileCount = [NSNumber numberWithUnsignedLongLong:numberOfFiles];
    batchSize = [NSNumber numberWithUnsignedLongLong:totalBatchSize];
    userInfo = @{@"FileCount" : fileCount, @"Size" : batchSize};

    [[NSNotificationCenter defaultCenter] postNotificationName:WMSizerGotNumbersNotification
                                                        object:self
                                                      userInfo:userInfo];
  }
}

//
//--- NSTask management ------------------------------------------------------
//
- (void)readInput:(NSNotification *)notif
{
  NSString *input;
  NSMutableArray *lines;
  NSEnumerator *e;
  NSString *line;
  NSData *data = nil;

  // NSDebugLLog(@"Sizer", @"==== [FileOperation readInput]");

  // === LOCK
  while (inputLock && [inputLock tryLock] == NO) {
    NSDebugLLog(@"Sizer", @"[Sizer readInput] LOCK FAILED! Waiting...");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }
  // ===

  NS_DURING
  {
    if (task != nil && ![task isRunning] && notif == nil) {
      // Grab data left in input from '-terminate'd NSTask
      NSDebugLLog(@"Sizer", @"==== [Sizer readInput] last read");
      data = [[readPipe fileHandleForReading] readDataToEndOfFile];
    } else {
      data = [[readPipe fileHandleForReading] availableData];
    }
  }
  NS_HANDLER
  {
    NSDebugLLog(@"Sizer", @"==== [Sizer readInput] EXCEPTION");
    [inputLock unlock];
    return;
  }
  NS_ENDHANDLER

  // NSUTF8StringEncoding is important in case of non ASCII file names
  input = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

  if (input == nil) {
    NSDebugLLog(@"Sizer", @"==== [Sizer readInput] NIL");
    // [inputLock unlock];
    // [[readPipe fileHandleForReading] waitForDataInBackgroundAndNotify];
    return;
  }

  lines = [NSMutableArray arrayWithArray:[input componentsSeparatedByString:@"\n"]];

  // Assemble remembered truncated line with newly received
  // input's first line
  if (truncatedLine != nil && [truncatedLine length] > 0) {
    truncatedLine = [truncatedLine stringByAppendingString:[lines objectAtIndex:0]];
    [lines replaceObjectAtIndex:0 withObject:[truncatedLine copy]];
    // NSDebugLLog(@"Sizer", @"LINE ASSEMBLED: %@", truncatedLine);
    ASSIGN(truncatedLine, @"");
  }

  // Check if input is truncated. It means that last line is not fully
  // transmitted from FileOperation tool.
  if (input != nil && [input length] > 1 && [input characterAtIndex:[input length] - 1] != '\n') {
    ASSIGN(truncatedLine, [lines objectAtIndex:[lines count] - 1]);
    // NSDebugLLog(@"Sizer", @"GOT TRUNCATED LINE: %@", truncatedLine);
  }

  // NSDebugLLog(@"Sizer", @"%@", input);

  e = [lines objectEnumerator];
  while ((line = [e nextObject]) != nil) {
    NSArray *args = nil;
    char msgType = ' ';

    // skip over empty lines
    if ([line length] < 1) {
      // NSDebugLLog(@"Sizer", @"skipping empty line");
      // ReportGarbage(line);
      continue;
    }

    args = [line componentsSeparatedByString:@"\t"];
    msgType = [[args objectAtIndex:0] characterAtIndex:0];
    // NSDebugLLog(@"Sizer", @"ARGS: %@", args);

    switch (msgType) {
      case '0':
        if ([args count] < 2) {
          NSDebugLLog(@"Sizer", @"0: not enought args: %@", args);
          continue;
        }
        [self setState:OperationCompleted];
        if (processUI) {
          [processUI updateWithMessage:[args objectAtIndex:1]
                                  file:@""
                                source:@""
                                target:@""
                              progress:0.0];
        }
        break;
      case '1':
        if ([args count] < 2) {
          NSDebugLLog(@"Sizer", @"0: not enought args: %@", args);
          continue;
        }
        [self setState:OperationStopped];
        if (processUI) {
          [processUI updateWithMessage:[args objectAtIndex:1]
                                  file:@""
                                source:@""
                                target:@""
                              progress:0.0];
        }
        break;
        // F\t<message>\t<currFile>\t<source dir>
      case 'F': {
        if ([args count] < 4) {
          NSDebugLLog(@"Sizer", @"F: not enought args: %@", args);
          continue;
        }
        ASSIGN(message, [args objectAtIndex:1]);
        ASSIGN(currFile, [args objectAtIndex:2]);
        ASSIGN(currSourceDir, [args objectAtIndex:3]);

        if (processUI) {
          [processUI updateWithMessage:message
                                  file:currFile
                                source:currSourceDir
                                target:nil
                              progress:0.0];
        }
      } break;
      case 'Q':
        // Catch and update file count and batch size.
        // Number of files: "Q\tF\t%u\t+"   <----(Queued Files)
        //      Batch size: "Q\tS\t%llu\t+" <----(Queued Size)
        // If field #4 contains '+' it is an update to the totals.
        {
          char qType = ' ';
          BOOL isIncrement = NO;
          NSString *digits;
          unsigned long long files_count;
          unsigned long long batch_size;

          if ([args count] < 3)
            continue;

          qType = [[args objectAtIndex:1] characterAtIndex:0];
          digits = [args objectAtIndex:2];
          if ([args count] > 3 && [[args objectAtIndex:3] characterAtIndex:0] == '+') {
            isIncrement = YES;
          }

          if (qType == 'F')  // Queued file count
          {
            if (sscanf([digits cString], "%llu", &files_count) != 1) {
              ReportGarbage(line);
              continue;
            }

            if (isIncrement) {
              numberOfFiles += files_count;
            } else {
              numberOfFiles = files_count;
              if (totalBatchSize > 0) {
                [self reportNumbers];
              }
            }
            continue;
          } else if (qType == 'S')  // Queued batch file size
          {
            if (sscanf([digits cString], "%llu", &batch_size) != 1) {
              ReportGarbage(line);
              continue;
            }

            if (isIncrement) {
              totalBatchSize += batch_size;
            } else {
              totalBatchSize = batch_size;
              if (numberOfFiles > 0) {
                [self reportNumbers];
              }
            }
            continue;
          }
        }
        break;
      default:
        ReportGarbage(line);
        break;
    }
  }

  if (task != nil && [task isRunning]) {
    [[readPipe fileHandleForReading] waitForDataInBackgroundAndNotify];
  }

  // NSDebugLLog(@"Sizer", @"==== [Sizer readInput] END");

  // === UNLOCK
  [inputLock unlock];
}

- (void)destroyOperation
{
  [[NSNotificationCenter defaultCenter] postNotificationName:WMOperationWillDestroyNotification
                                                      object:self];
}

- (void)taskTerminated
{
  NSDebugLLog(@"Sizer", @"Sizer: taskTerminated");

  if (state != OperationStopped) {
    [self readInput:nil];
    [self setState:OperationCompleted];
  } else {
    [self reportNumbers];
  }

  [NSTimer scheduledTimerWithTimeInterval:1.0
                                   target:self
                                 selector:@selector(destroyOperation)
                                 userInfo:nil
                                  repeats:NO];
}

@end
