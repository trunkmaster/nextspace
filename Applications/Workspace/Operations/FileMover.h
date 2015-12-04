/*
   FileMover.h
   A FileMover.tool wrapper.

   Copyright (C) 2015 Sergii Stoian
   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <Foundation/Foundation.h>

#import "Operations/BGOperation.h"

@interface FileMover : BGOperation
{
  unsigned long long numberOfFiles;
  unsigned long long numberOfFilesDone;

  unsigned long long totalBatchSize;
  unsigned long long doneBatchSize;

  // NSTask and operation management
  BOOL     isSuspended;
  BOOL     isSizing;
  NSTask   *sizerTask;
  NSTask   *fileMoverTask;
  NSPipe   *readPipe;
  NSPipe   *writePipe;
  
  NSLock   *inputLock;
  NSString *truncatedLine;
}

- (void)startSizer;
- (void)startFileMover;

// Suspend/Resume button
- (void)pause:(id)sender;

@end

@interface FileMover (Alert)

// passing -1 in `solutionProblem' means 'stop operation'
- (void)postSolution:(int)solutionIndex
   applyToSubsequent:(BOOL)subseq;

@end
