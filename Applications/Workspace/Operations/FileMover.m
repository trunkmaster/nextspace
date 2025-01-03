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

#import "Operations/FileMover.h"
#import "Processes/FileMoverUI.h"

static inline void ReportGarbage(NSString *garbage)
{
  NSDebugLLog(@"FileMover", @"Got garbage \"%@\" from FileMover subprocess. Ignoring...", garbage);
}

//=============================================================================
// FileMover tool error processing
//=============================================================================

@interface FileMover (Private)

- (void)reportReadError;
- (void)reportWriteError;
- (void)reportDeleteError;
- (void)reportMoveError;
- (void)reportSymlink;
- (void)reportAttributesUnchangeable;
- (void)reportFileExists;
- (void)reportUnknownFile;
- (void)reportSymlinkTargetNotExist;

@end

@implementation FileMover (Private)

- (void)reportReadError
{
  problem = ReadError;

  ASSIGN(problemDesc,
         ([NSString stringWithFormat:_(@"%@/%@ is not readable"), currSourceDir, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file to proceed with operation."));
  ASSIGN(solutions, [NSArray arrayWithObject:_(@"Skip")]);

  // 1. Upon receiving notification:
  //    a. Processes selects operation (setView:->showOperation:) and
  //       shows panel.
  //  or
  //    b. ProcessManager loads Processes and selects operaion and shows
  //       panel via setView:BGOperation->showOperation:BGOperation.
  // 2. showOperation: calls [[BGOperation userInterface] processView].
  // 3. [[BGOperation userInterface] processView]: loads OperationAlert.gorm
  //    and initializes it (awakeFromNib).
  // 3. 'Processes' calls updateProcessView which fills fields and labels of
  //    alert view.
  [self setState:OperationAlert];
}

- (void)reportWriteError
{
  problem = WriteError;

  ASSIGN(problemDesc, ([NSString stringWithFormat:_(@"%@/%@ is not writable"), target, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file to proceed with operation."));
  ASSIGN(solutions, [NSArray arrayWithObject:_(@"Skip")]);

  [self setState:OperationAlert];
}

- (void)reportDeleteError
{
  problem = DeleteError;

  ASSIGN(problemDesc,
         ([NSString stringWithFormat:_(@"%@/%@ is not deletable"), currSourceDir, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file to proceed with operation."));
  ASSIGN(solutions, [NSArray arrayWithObject:_(@"Skip")]);

  [self setState:OperationAlert];
}

- (void)reportMoveError
{
  problem = MoveError;

  ASSIGN(problemDesc,
         ([NSString stringWithFormat:_(@"%@/%@ is not moveable"), currSourceDir, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file to proceed with operation."));
  ASSIGN(solutions, [NSArray arrayWithObject:_(@"Skip")]);

  [self setState:OperationAlert];
}

- (void)reportSymlink
{
  problem = SymlinkEncountered;

  ASSIGN(problemDesc,
         ([NSString stringWithFormat:_(@"%@/%@ is a symbolic link"), currSourceDir, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can create new link, skip this link, "
                                @"copy the original, or stop the entire opertaion"));
  ASSIGN(solutions, (@[ _(@"Copy"), _(@"Skip"), _(@"New Link") ]));

  [self setState:OperationAlert];
}

- (void)reportAttributesUnchangeable
{
  problem = AttributesUnchangeable;

  ASSIGN(problemDesc, ([NSString stringWithFormat:_(@"Attributes of %@/%@ is not changeable"),
                                                  target, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file to proceed with operation."));
  ASSIGN(solutions, @[ _(@"Skip") ]);

  [self setState:OperationAlert];
}

- (void)reportFileExists
{
  problem = FileExists;

  ASSIGN(problemDesc, ([NSString stringWithFormat:_(@"%@/%@ already exists"), target, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file to proceed with operation"
                                @" or ovewrite existig file with the new one"));
  ASSIGN(solutions, (@[ _(@"Overwrite"), _(@"Skip") ]));

  [self setState:OperationAlert];
}

- (void)reportUnknownFile
{
  problem = UnknownFile;

  ASSIGN(problemDesc, ([NSString stringWithFormat:_(@"File %@/%@ doesn't exist or not unsupported"),
                                                  currSourceDir, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file, or stop the entire operation"));
  ASSIGN(solutions, [NSArray arrayWithObject:_(@"Skip")]);

  [self setState:OperationAlert];
}

- (void)reportSymlinkTargetNotExist
{
  problem = SymlinkTargetNotExist;

  ASSIGN(problemDesc,
         ([NSString stringWithFormat:_(@"Symlink %@/%@ points to file wich doesn't exist"),
                                     currSourceDir, currFile]));
  ASSIGN(problemSolutionDesc, _(@"You can skip this file, make new link, "
                                @"or stop the entire operation"));
  ASSIGN(solutions, (@[ _(@"Skip"), _(@"New Link") ]));

  [self setState:OperationAlert];
}

@end

@implementation FileMover (Alert)

- (void)postSolution:(int)solution applyToSubsequent:(BOOL)subseq
{
  if (solution == -1)  // Stop
  {
    [[writePipe fileHandleForWriting] writeData:[@"t\n" dataUsingEncoding:NSASCIIStringEncoding]];

    [[writePipe fileHandleForWriting] synchronizeFile];

    problem = NoProblem;

    [self setState:OperationStopping];
    return;
  }

  switch (problem) {
    case ReadError:
    case WriteError:
    case MoveError:
    case DeleteError:
    case UnknownFile:
      // Skip file
      if (subseq) {
        [[writePipe fileHandleForWriting]
            writeData:[@"S\n" dataUsingEncoding:NSASCIIStringEncoding]];
      } else {
        [[writePipe fileHandleForWriting]
            writeData:[@"s\n" dataUsingEncoding:NSASCIIStringEncoding]];
      }
      break;
    case SymlinkEncountered:
      // TODO: There should be 2 actions:
      // Copy - "copy the original" now it's equal to Follow
      // New Link - "make new link" now it's equal to Copy and Relink
      switch (solution) {
        case 0:  // "Copy" - copy the original
          if (subseq) {
            [[writePipe fileHandleForWriting]
                writeData:[@"C\n" dataUsingEncoding:NSASCIIStringEncoding]];
          } else {
            [[writePipe fileHandleForWriting]
                writeData:[@"c\n" dataUsingEncoding:NSASCIIStringEncoding]];
          }
          break;
        case 1:  // Skip
          if (subseq) {
            [[writePipe fileHandleForWriting]
                writeData:[@"S\n" dataUsingEncoding:NSASCIIStringEncoding]];
          } else {
            [[writePipe fileHandleForWriting]
                writeData:[@"s\n" dataUsingEncoding:NSASCIIStringEncoding]];
          }
          break;
        case 2:  // "New Link"
          if (subseq) {
            [[writePipe fileHandleForWriting]
                writeData:[@"N\n" dataUsingEncoding:NSASCIIStringEncoding]];
          } else {
            [[writePipe fileHandleForWriting]
                writeData:[@"n\n" dataUsingEncoding:NSASCIIStringEncoding]];
          }
          break;
      }
      break;
    case SymlinkTargetNotExist:
      switch (solution) {
        case 0:  // Skip
          if (subseq) {
            NSDebugLLog(@"FileMover", @"SymlinkTargetNotExist: SKIP");
            [[writePipe fileHandleForWriting]
                writeData:[@"S\n" dataUsingEncoding:NSASCIIStringEncoding]];
          } else {
            NSDebugLLog(@"FileMover", @"SymlinkTargetNotExist: skip");
            [[writePipe fileHandleForWriting]
                writeData:[@"s\n" dataUsingEncoding:NSASCIIStringEncoding]];
          }
          break;
        case 1:  // "New Link" - copy link file
          if (subseq) {
            NSDebugLLog(@"FileMover", @"SymlinkTargetNotExist: NEWLINK");
            [[writePipe fileHandleForWriting]
                writeData:[@"N\n" dataUsingEncoding:NSASCIIStringEncoding]];
          } else {
            NSDebugLLog(@"FileMover", @"SymlinkTargetNotExist: newlink");
            [[writePipe fileHandleForWriting]
                writeData:[@"n\n" dataUsingEncoding:NSASCIIStringEncoding]];
          }
          break;
      }
      break;
    case AttributesUnchangeable:  // Ignore
      if (subseq) {
        [[writePipe fileHandleForWriting]
            writeData:[@"I\n" dataUsingEncoding:NSASCIIStringEncoding]];
      } else {
        [[writePipe fileHandleForWriting]
            writeData:[@"i\n" dataUsingEncoding:NSASCIIStringEncoding]];
      }
      break;
    case FileExists:
      switch (solution) {
        case 0:  // Overwrite
          if (subseq) {
            [[writePipe fileHandleForWriting]
                writeData:[@"O\n" dataUsingEncoding:NSASCIIStringEncoding]];
          } else {
            [[writePipe fileHandleForWriting]
                writeData:[@"o\n" dataUsingEncoding:NSASCIIStringEncoding]];
          }
          break;
        case 1:  // Skip
          if (subseq) {
            [[writePipe fileHandleForWriting]
                writeData:[@"S\n" dataUsingEncoding:NSASCIIStringEncoding]];
          } else

          {
            [[writePipe fileHandleForWriting]
                writeData:[@"s\n" dataUsingEncoding:NSASCIIStringEncoding]];
          }
          break;
      }
      break;
    case NoProblem:
      [NSException raise:NSInternalInconsistencyException
                  format:@"Posted a problem solution when "
                         @"the file operation thought that there "
                         @"was none"];
      break;
  }

  [[writePipe fileHandleForWriting] synchronizeFile];

  problem = NoProblem;

  [self setState:OperationRunning];
}

@end

//=============================================================================
// Main part of class
//=============================================================================

@implementation FileMover

- (id)initWithOperationType:(OperationType)opType
                  sourceDir:(NSString *)sourceDir
                  targetDir:(NSString *)targetDir
                      files:(NSArray *)fileList
                    manager:(ProcessManager *)delegate
{
  [super initWithOperationType:opType
                     sourceDir:sourceDir
                     targetDir:targetDir
                         files:fileList
                       manager:delegate];

  problem = NoProblem;

  numberOfFiles = 0;
  totalBatchSize = 0;
  isSizing = NO;

  inputLock = [NSLock new];

  [self startSizer];

  [self setState:OperationRunning];

  return self;
}

- (void)startSizer
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

  isSizing = YES;

  sizerTask = [NSTask new];
  [sizerTask setLaunchPath:[[NSBundle mainBundle] pathForResource:@"Sizer" ofType:@"tool"]];
  [sizerTask setArguments:@[
    @"-Operation", [self typeString], @"-Source", source, @"-Destination", target, @"-Files",
    [files description]
  ]];

  readPipe = [NSPipe new];
  writePipe = [NSPipe new];
  [sizerTask setStandardInput:writePipe];
  [sizerTask setStandardOutput:readPipe];

  [nc addObserver:self
         selector:@selector(sizerTaskTerminated)
             name:NSTaskDidTerminateNotification
           object:sizerTask];
  [nc addObserver:self
         selector:@selector(readInput:)
             name:NSFileHandleDataAvailableNotification
           object:[readPipe fileHandleForReading]];

  [[readPipe fileHandleForReading] waitForDataInBackgroundAndNotify];

  [sizerTask launch];
}

- (void)startFileMover
{
  NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
  NSString *fileMoverPath = [[NSBundle mainBundle] pathForResource:@"FileMover" ofType:@"tool"];
  // Restore runtime ivars to default state
  ASSIGN(currSourceDir, source);
  ASSIGN(currTargetDir, target);
  ASSIGN(currFile, [files objectAtIndex:0]);

  fileMoverTask = [NSTask new];
  [fileMoverTask setLaunchPath:fileMoverPath];
  [fileMoverTask setArguments:@[
    @"-Operation", [self typeString], @"-Source", source, @"-Destination", target
  ]];
  // Transfer '-Files' argument as environment variable to omit parameter
  // length limit
  if (files) {
    NSProcessInfo *procInfo = [NSProcessInfo processInfo];
    NSMutableDictionary *env = [[procInfo environment] mutableCopy];
    [env setObject:files forKey:@"Files"];
    [fileMoverTask setEnvironment:env];
    [env release];
  }

  readPipe = [NSPipe new];
  writePipe = [NSPipe new];
  [fileMoverTask setStandardInput:writePipe];
  [fileMoverTask setStandardOutput:readPipe];

  [nc addObserver:self
         selector:@selector(taskTerminated)
             name:NSTaskDidTerminateNotification
           object:fileMoverTask];
  [nc addObserver:self
         selector:@selector(readInput:)
             name:NSFileHandleDataAvailableNotification
           object:[readPipe fileHandleForReading]];

  [[readPipe fileHandleForReading] waitForDataInBackgroundAndNotify];

  [fileMoverTask launch];
}

- (BGProcess *)userInterface
{
  if (processUI == nil) {
    processUI = [[FileMoverUI alloc] initWithOperation:self];
  }

  return processUI;
}

- (void)dealloc
{
  NSDebugLLog(@"FileMover", @"FileMover: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  TEST_RELEASE(problemDesc);
  TEST_RELEASE(solutions);

  [super dealloc];
}

//
//--- Action and state -------------------------------------------------------
//

// Suspend/Resume button
- (void)pause:(id)sender
{
  NSTask *task = (isSizing ? sizerTask : fileMoverTask);

  if (!isSuspended) {
    if ([task suspend]) {
      isSuspended = YES;
      [self setState:OperationPaused];
    }
  } else {
    if ([task resume]) {
      isSuspended = NO;
      [self setState:OperationRunning];
    }
  }
}

- (void)stop:(id)sender
{
  NSTask *task = (isSizing ? sizerTask : fileMoverTask);

  if (isSuspended) {
    [self pause:nil];
  }

  if (state == OperationAlert) {
    [self postSolution:-1 applyToSubsequent:YES];
  } else {
    [self setState:OperationStopping];
    [task interrupt];
  }
}

//
//--- Accessory methods ------------------------------------------------------
//

- (BOOL)isProgressSupported
{
  return YES;
}

- (float)progressValue
{
  if (totalBatchSize == 0) {
    return (float)numberOfFilesDone / numberOfFiles;
  } else {
    return (float)doneBatchSize / totalBatchSize;
  }
}

//
//--- NSTask management ------------------------------------------------------
//
- (void)readInput:(NSNotification *)notif
{
  NSTask *task = (isSizing ? sizerTask : fileMoverTask);
  NSString *input;
  NSMutableArray *lines;
  NSEnumerator *e;
  NSString *line;
  NSData *data = nil;

  // NSDebugLLog(@"FileMover", @"==== [FileOperation readInput]");

  // === LOCK
  while (inputLock && [inputLock tryLock] == NO) {
    NSDebugLLog(@"FileMover", @"[FileMover readInput] LOCK FAILED! Waiting...");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }
  // ===

  NS_DURING
  {
    if (task != nil && ![task isRunning] && notif == nil) {
      // Grab data left in input from '-terminate'd NSTask
      NSDebugLLog(@"FileMover", @"==== [FileMover readInput] last read");
      data = [[readPipe fileHandleForReading] readDataToEndOfFile];
    } else {
      data = [[readPipe fileHandleForReading] availableData];
    }
  }
  NS_HANDLER
  {
    NSDebugLLog(@"FileMover", @"==== [FileMover readInput] EXCEPTION");
    [inputLock unlock];
    return;
  }
  NS_ENDHANDLER

  // NSUTF8StringEncoding is important in case of non ASCII file names
  input = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];

  if (input == nil) {
    NSDebugLLog(@"FileMover", @"==== [FileMover readInput] NIL");
    [inputLock unlock];
    [[readPipe fileHandleForReading] waitForDataInBackgroundAndNotify];
    return;
  }

  //  lines = [input componentsSeparatedByString:@"\n"];
  lines = [NSMutableArray arrayWithArray:[input componentsSeparatedByString:@"\n"]];

  // Assemble remembered truncated line with newly received
  // input's first line
  if (truncatedLine != nil && [truncatedLine length] > 0) {
    truncatedLine = [truncatedLine stringByAppendingString:[lines objectAtIndex:0]];
    [lines replaceObjectAtIndex:0 withObject:[truncatedLine copy]];
    // NSDebugLLog(@"FileMover", @"LINE ASSEMBLED: %@", truncatedLine);
    ASSIGN(truncatedLine, @"");
  }

  // Check if input is truncated. It means that last line is not fully
  // transmitted from FileOperation tool.
  if (input != nil && [input length] > 1 && [input characterAtIndex:[input length] - 1] != '\n') {
    ASSIGN(truncatedLine, [lines objectAtIndex:[lines count] - 1]);
    // NSDebugLLog(@"FileMover", @"GOT TRUNCATED LINE: %@", truncatedLine);
  }

  // NSDebugLLog(@"FileMover", @"%@", input);

  e = [lines objectEnumerator];
  while ((line = [e nextObject]) != nil) {
    NSArray *args = nil;
    char msgType = ' ';

    // skip over empty lines
    if ([line length] < 1) {
      // NSDebugLLog(@"FileMover", @"skipping empty line");
      // ReportGarbage(line);
      continue;
    }

    args = [line componentsSeparatedByString:@"\t"];
    msgType = [[args objectAtIndex:0] characterAtIndex:0];
    // NSDebugLLog(@"FileMover", @"ARGS: %@", args);

    switch (msgType) {
      case '0':
        if ([args count] < 2) {
          NSDebugLLog(@"FileMover", @"0: not enought args: %@", args);
          continue;
        }
        ASSIGN(message, [args objectAtIndex:1]);
        ASSIGN(currFile, @"");
        ASSIGN(currSourceDir, @"");
        ASSIGN(currTargetDir, @"");
        numberOfFilesDone = 0.0;
        doneBatchSize = 0.0;

        [self updateProcessView:NO];
        break;
      case '1':
        if ([args count] < 2) {
          NSDebugLLog(@"FileMover", @"0: not enought args: %@", args);
          continue;
        }
        ASSIGN(message, [args objectAtIndex:1]);
        ASSIGN(currFile, @"");
        ASSIGN(currSourceDir, @"");
        ASSIGN(currTargetDir, @"");
        numberOfFilesDone = 0.0;
        doneBatchSize = 0.0;

        [self updateProcessView:NO];
        break;
        // F\t<message>\t<currFile>\t<source dir>\t<target dir>
      case 'F': {
        // NSDebugLLog(@"FileMover", @"%@", input);
        if ([args count] < 5) {
          NSDebugLLog(@"FileMover", @"F: not enought args: %@", args);
          continue;
        }
        ASSIGN(message, [args objectAtIndex:1]);
        ASSIGN(currFile, [args objectAtIndex:2]);
        ASSIGN(currSourceDir, [args objectAtIndex:3]);
        ASSIGN(currTargetDir, [args objectAtIndex:4]);

        if (numberOfFiles > 0) {
          numberOfFilesDone++;
          // NSDebugLLog(@"FileMover", @"numberOfFilesDone: %llu (%llu)", numberOfFilesDone,
          //             numberOfFiles);
        }
        if (!isSizing && [currFile isEqualToString:@""]) {
          [self setState:OperationCompleted];
        }
        [self updateProcessView:NO];
      } break;
      case 'B': {
        unsigned long long advance;
        NSString *arg;

        if ([args count] < 2) {
          NSDebugLLog(@"FileMover", @"B: not enought args: %@", args);
          continue;
        }

        arg = [args objectAtIndex:1];
        if (sscanf([arg cString], "%llu", &advance) != 1) {
          ReportGarbage(line);
          break;
        }
        doneBatchSize += advance;

        // NSDebugLLog(@"FileMover", @"doneBatchSize: %llu (%llu)", doneBatchSize, totalBatchSize);
        [self updateProcessView:NO];
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
            }
            continue;
          }
        }
        break;
      case 'R':
        [self reportReadError];
        break;
      case 'W':
        [self reportWriteError];
        break;
      case 'M':
        [self reportMoveError];
        break;
      case 'S':
        [self reportSymlink];
        break;
      case 'D':
        [self reportDeleteError];
        break;
      case 'A':
        [self reportAttributesUnchangeable];
        break;
      case 'E':
        [self reportFileExists];
        break;
      case 'U':
        [self reportUnknownFile];
        break;
      case 'T':
        [self reportSymlinkTargetNotExist];
        break;
      default:
        ReportGarbage(line);
        break;
    }
  }

  if (task != nil && [task isRunning]) {
    [[readPipe fileHandleForReading] waitForDataInBackgroundAndNotify];
  }

  // NSDebugLLog(@"FileMover", @"==== [FileOperation readInput] END");

  // === UNLOCK
  [inputLock unlock];
}

- (void)destroyOperation
{
  // Notify ProcessManager
  [[NSNotificationCenter defaultCenter] postNotificationName:WMOperationWillDestroyNotification
                                                      object:self];
}

- (void)sizerTaskTerminated
{
  NSDebugLLog(@"FileMover", @"FileMover: Sizer task terminated");

  if (state != OperationStopped) {
    [self readInput:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    isSizing = NO;
    [self startFileMover];
  } else {
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(destroyOperation)
                                   userInfo:nil
                                    repeats:NO];
  }
}

- (void)taskTerminated
{
  NSDebugLLog(@"FileMover", @"FileMover: FileMover task terminated");

  if (state != OperationStopping) {
    [self readInput:nil];
    [self setState:OperationCompleted];
  } else {
    [self setState:OperationStopped];
  }

  [NSTimer scheduledTimerWithTimeInterval:1.0
                                   target:self
                                 selector:@selector(destroyOperation)
                                 userInfo:nil
                                  repeats:NO];
}

@end
