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

#import <Foundation/Foundation.h>

#import "Operations/BGOperation.h"

@interface FileMover : BGOperation
{
  unsigned long long numberOfFiles;
  unsigned long long numberOfFilesDone;

  unsigned long long totalBatchSize;
  unsigned long long doneBatchSize;

  // NSTask and operation management
  BOOL isSuspended;
  BOOL isSizing;
  NSTask *sizerTask;
  NSTask *fileMoverTask;
  NSPipe *readPipe;
  NSPipe *writePipe;

  NSLock *inputLock;
  NSString *truncatedLine;
}

- (void)startSizer;
- (void)startFileMover;

// Suspend/Resume button
- (void)pause:(id)sender;

@end

@interface FileMover (Alert)

// passing -1 in `solutionProblem' means 'stop operation'
- (void)postSolution:(int)solutionIndex applyToSubsequent:(BOOL)subseq;

@end
