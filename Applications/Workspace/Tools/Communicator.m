/*
   The FileOperation tool's communication facilities.

   Copyright (C) 2006-2014 Sergii Stoian
   Copyright (C) 2005 Saso Kiselkov

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <stdio.h>
#include <unistd.h>

#import "Communicator.h"

BOOL makeCleanupOnStop;

@implementation Communicator

static Communicator *shared = nil;

+ (id)shared
{
  if (shared == nil)
    {
      shared = [self new];
    }

  return shared;
}

- (id)init
{
  [super init];

  defaultReadErrorAction = NOT_SET;
  defaultWriteErrorAction = NOT_SET;
  defaultDeleteErrorAction = NOT_SET;
  defaultMoveErrorAction = NOT_SET;
  defaultSymlinkAction = NOT_SET;
  defaultAttrsAction = NOT_SET;
  defaultFileExistsAction = NOT_SET;
  defaultUnknownFileAction = NOT_SET;

  makeCleanupOnStop = YES;
  
  return self;
}

// filename - name of file which displayed in operation status field
//            e.g. "Copying filename"
// sourcePrefix - path of source dir minus 'filename'
// targetPrefix - full path of taget dir minus 'filename',
//              @"" for Delete and Duplicate operations
// bytesAdvanced - increment of processed data size (used for progress view)
// operationType - operation to construct message
- (void)showProcessingFilename:(NSString *)filename
                  sourcePrefix:(NSString *)sourcePrefix
                  targetPrefix:(NSString *)targetPrefix
                 bytesAdvanced:(unsigned long long)progress
                 operationType:(OperationType)opType
{
  NSString *opMessage = nil;

  ASSIGN(currentFilename, ((filename != nil) ? filename : @""));
  ASSIGN(currentSourcePrefix, ((sourcePrefix != nil) ? sourcePrefix : @""));
  ASSIGN(currentTargetPrefix, ((targetPrefix != nil) ? targetPrefix : @""));
  // currentSourcePrefix = (sourcePrefix != nil) ? sourcePrefix : @"";
  // currentTargetPrefix = (targetPrefix != nil) ? targetPrefix : @"";

  fileProgress += progress;

  // Construct message
  if (filename != nil && ![filename isEqualToString:@""])
    {
      switch (opType)
        {
        case SizingOp:
          opMessage = [NSString stringWithFormat:@"Computing size of %@",
                                filename];
          break;
        case CopyOp:
          opMessage = [NSString stringWithFormat:@"Copying %@", filename];
          break;
        case DuplicateOp:
          opMessage = [NSString stringWithFormat:@"Duplicating %@", filename];
          break;
        case MoveOp:
          opMessage = [NSString stringWithFormat:@"Moving %@", filename];
          break;
        case LinkOp:
          opMessage = [NSString stringWithFormat:@"Linking %@", filename];
          break;
        case DeleteOp:
          opMessage = [NSString stringWithFormat:@"Destroying %@", filename];
          break;
        default:
          opMessage = @"";
          break;
        }
      // Send output
      if (![sentFilename isEqual:currentFilename] || lastOpType != opType)
        {
          ASSIGN(sentFilename, currentFilename);
          lastOpType = opType;
          // F\t<message>\t<filename>\t<source dir>\t<target dir>
          printf("F\t%s\t%s\t%s\t%s\n",
                 [opMessage cString],
                 [currentFilename cString],
                 [currentSourcePrefix cString],
                 [currentTargetPrefix cString]);
        }
    }

  if (fileProgress != 0)
    {
      printf("B\t%llu\n", fileProgress);
      fileProgress = 0;
    }
  
  fflush(stdout);
}

- (void)finishOperation:(NSString *)opName
                stopped:(BOOL)isStopped
{
  if (isStopped)
    {
      printf("1\t%s\n",
             [[NSString stringWithFormat:@"%@ Operation Stopped", opName] cString]);
    }
  else
    {
      printf("0\t%s\n",
             [[NSString stringWithFormat:@"%@ Operation Completed", opName] cString]);
    }
  fflush(stdout);
}

- (ProblemSolution)howToHandleProblem:(ProblemType)probl
{
  return [self howToHandleProblem:probl argument:nil];
}

- (ProblemSolution)howToHandleProblem:(ProblemType)p
		  	     argument:(NSString *)message
{
  char answer;

  makeCleanupOnStop = NO;
  
  switch (p)
    {
    case ReadError:
      if (defaultReadErrorAction != NOT_SET)
	{
	  return defaultReadErrorAction;
	}

      printf("R%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 's' && answer != 'S' && answer != 't');

      switch (answer)
	{
	case 'S':
	  defaultReadErrorAction = SkipFile;
	case 's':
	  return SkipFile;
	  break;
	case 't':
          StopOperation();
	  break;
	}
      break;
    case WriteError:
      if (defaultWriteErrorAction != NOT_SET)
	{
	  return defaultWriteErrorAction;
	}

      printf("W%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 's' && answer != 'S' && answer != 't');

      switch (answer)
	{
	case 'S':
	  defaultWriteErrorAction = SkipFile;
	case 's':
	  return SkipFile;

	case 't':
          StopOperation();
          break;
	}
      break;
    case DeleteError:
      if (defaultDeleteErrorAction != NOT_SET)
	{
	  return defaultDeleteErrorAction;
	}

      printf("D%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 's' && answer != 'S' && answer != 't');

      switch (answer)
	{
	case 'S':
	  defaultDeleteErrorAction = SkipFile;
	case 's':
	  return SkipFile;

	case 't':
          StopOperation();
          break;
	}
      break;
    case MoveError:
      if (defaultMoveErrorAction != NOT_SET)
	{
	  return defaultMoveErrorAction;
	}

      printf("M%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 's' && answer != 'S' && answer != 't');

      switch (answer)
	{
	case 'S':
	  defaultMoveErrorAction = SkipFile;
	case 's':
	  return SkipFile;

	case 't':
          StopOperation();
          break;
	}
      break;
    case SymlinkEncountered:
      if (defaultSymlinkAction != NOT_SET)
	{
	  return defaultSymlinkAction;
	}

      // Cc - Copy the orignial 
      // Nn - New Link
      // Ss - Skip
      printf("S%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 's' && answer != 'S' &&
	     answer != 'n' && answer != 'N' &&
	     answer != 'c' && answer != 'C' &&
	     answer != 't');

      switch (answer)
	{
	case 'S':
	  defaultSymlinkAction = SkipFile;
	case 's':
	  return SkipFile;

	case 'N':
	  defaultSymlinkAction = NewLink;
	case 'n':
	  return NewLink;

	case 'C':
	  defaultSymlinkAction = CopyOriginal;
	case 'c':
	  return CopyOriginal;

	case 't':
          StopOperation();
          break;
	}
      break;
    case SymlinkTargetNotExist:
      if (defaultSymlinkTargetAction != NOT_SET)
	{
	  return defaultSymlinkTargetAction;
	}
      
      printf("T%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      // Nn - New Link
      // Ss - Skip
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 's' && answer != 'S' &&
	     answer != 'n' && answer != 'N' &&
	     answer != 't');

      switch (answer)
	{
	case 'S':
          NSLog(@"Communicator: SymlinkTargetNotExist: SKIP");
	  defaultSymlinkTargetAction = SkipFile;
	case 's':
          NSLog(@"Communicator: SymlinkTargetNotExist: skip");
	  return SkipFile;
          
	case 'N':
          NSLog(@"Communicator: SymlinkTargetNotExist: SKIP");
	  defaultSymlinkTargetAction = NewLink;
	case 'n':
	  return NewLink;
          
	case 't':
          StopOperation();
          break;
	}
      break;
    case AttributesUnchangeable:
      if (defaultAttrsAction != NOT_SET)
	{
	  return defaultAttrsAction;
	}
      printf("A%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 'i' && answer != 'I' && answer != 't');

      switch (answer)
	{
	case 'I':
	  defaultAttrsAction = IgnoreProblem;
	case 'i':
	  return IgnoreProblem;
	case 't':
          StopOperation();
          break;
	}
      break;
    case FileExists:
      if (defaultFileExistsAction != NOT_SET)
	{
	  return defaultFileExistsAction;
	}

      printf("E%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 's' && answer != 'S' &&
	     answer != 'o' && answer != 'O' &&
	     answer != 't');

      switch (answer)
	{
	case 'S':
	  defaultFileExistsAction = SkipFile;
	case 's':
	  return SkipFile;

	case 'O':
	  defaultFileExistsAction = OverwriteFile;
	case 'o':
	  return OverwriteFile;

	case 't':
          StopOperation();
          break;
	}
      break;
    case UnknownFile:
      if (defaultUnknownFileAction != NOT_SET)
	{
	  return defaultUnknownFileAction;
	}

      printf("U%s\n", message != nil ? [message cString] : "");
      fflush(stdout);
      do
	{
	  answer = fgetc(stdin);
	}
      while (answer != 'S' && answer != 's' && answer != 't');

      switch (answer)
	{
	case 'S':
	  defaultUnknownFileAction = SkipFile;
	case 's':
	  return SkipFile;
          
	case 't':
          StopOperation();
          break;
	}
      break;
    }

  return -1;
}

@end
