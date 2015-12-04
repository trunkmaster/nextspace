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

#import <Foundation/Foundation.h>

extern BOOL isStopped;
extern void StopOperation();
extern BOOL makeCleanupOnStop;

typedef enum {
  SizingOp,
  CopyOp,
  DuplicateOp,
  MoveOp,
  LinkOp,
  DeleteOp
} OperationType;

typedef enum {
  ReadError,
  WriteError,
  DeleteError,
  MoveError,
  SymlinkEncountered,
  SymlinkTargetNotExist,
  AttributesUnchangeable,
  FileExists,
  UnknownFile
} ProblemType;

typedef enum {
  NOT_SET,
  SkipFile,
  NewLink,
  CopyOriginal,
  IgnoreProblem,
  OverwriteFile
} ProblemSolution;

// Communication messages:
// "F\t<message>\t<filename>\t<source dir>\t<target dir>"
// "B\t<size>\n" - file size progress
// "B\t<file count>\t<size>\n"
// --- Alerts
// "R<message>\n" - Read error
// "W<message>\n" - Wrtite error
// "D<message>\n" - Delete error
// "M<message>\n" - Move error
// "S<message>\n" - Symlink encountered
//     Cc - Copy the orignial 
//     Nn - New Link
//     Ss - Skip
// "T<message>\n" - symlink's Taget doesn't exist
// "A<message>\n" - Attributes is unchangeable
// "E<message>\n" - target file already Exists
// "U<message>\n" - target file type is Unknown

@interface Communicator : NSObject
{
  ProblemSolution defaultReadErrorAction;
  ProblemSolution defaultWriteErrorAction;
  ProblemSolution defaultMoveErrorAction;
  ProblemSolution defaultDeleteErrorAction;
  ProblemSolution defaultSymlinkAction;
  ProblemSolution defaultSymlinkTargetAction;
  ProblemSolution defaultAttrsAction;
  ProblemSolution defaultFileExistsAction;
  ProblemSolution defaultUnknownFileAction;

  OperationType lastOpType;
  
  NSString *sentFilename;
  NSString *currentFilename;
  NSString *currentSourcePrefix;
  NSString *currentTargetPrefix;

  unsigned long long fileProgress;
}

+ (id)shared;

- (void)showProcessingFilename:(NSString *)filename
                  sourcePrefix:(NSString *)sourcePrefix
                  targetPrefix:(NSString *)targetPrefix
                 bytesAdvanced:(unsigned long long)progress
                 operationType:(OperationType)opType;

- (void)finishOperation:(NSString *)opName
                stopped:(BOOL)isStopped;
  
- (ProblemSolution)howToHandleProblem:(ProblemType)p;

- (ProblemSolution)howToHandleProblem:(ProblemType)p
                             argument:(NSString *)message;

@end
