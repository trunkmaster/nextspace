/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2015 Sergii Stoian
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
#import <stdio.h>

#import "Size.h"

BOOL isStopped;

void PrintHelp(void)
{
  printf("Usage: Sizer.tool <options>\n\n"
         "Options:\n"
         "  -Operation Copy|Move|Link|Delete \n"
         "  -Source directory \n"
         "  -Files (Source, Filename, Array) \n");
}

void SignalHandler(int sig)
{
  // if (sig == SIGTERM)
  //   fprintf(stderr, "FileOperation.tool: received TERMINATE signal\n");
  if (sig == SIGINT) {
    NSLog(@"Sizer.tool: received INTERRUPT signal");
    StopOperation();
  }
}

void StopOperation() { isStopped = YES; }

int main(int argc, const char **argv)
{
  NSString *op;
  NSString *source;
  NSArray *files;
  NSUserDefaults *df;
  BOOL argsOK = YES;
  OperationType opType;
  Size *sizer;
  Communicator *comm;

  CREATE_AUTORELEASE_POOL(pool);

  // Signals
  signal(SIGINT, SignalHandler);
  // signal(SIGTERM, SignalHandler);

  df = [NSUserDefaults standardUserDefaults];
  op = [df objectForKey:@"Operation"];
  source = [df objectForKey:@"Source"];
  files = [df objectForKey:@"Files"];

  // check args
  if (source == nil || ![source isKindOfClass:[NSString class]]) {
    NSLog(@"Sizer.tool: incorrect source path (-Source)!");
    argsOK = NO;
  }
  if (files == nil || ![files isKindOfClass:[NSArray class]]) {
    files = nil;
  }

  if (argsOK == NO) {
    PrintHelp();
    return 1;
  }

  isStopped = NO;

  if ([op isEqualToString:@"Copy"]) {
    opType = CopyOp;
  } else if ([op isEqualToString:@"Move"]) {
    opType = MoveOp;
  } else if ([op isEqualToString:@"Link"]) {
    opType = LinkOp;
  } else if ([op isEqualToString:@"Duplicate"]) {
    opType = DuplicateOp;
  } else if ([op isEqualToString:@"Delete"]) {
    opType = DeleteOp;
  } else {
    opType = CopyOp;
  }

  comm = [[Communicator alloc] init];
  sizer = [[Size alloc] init];
  [sizer calculateBatchSizeInDirectory:source
                                 files:files
                         operationType:opType
                         sendIncrement:NO
                          communicator:comm];

  [comm finishOperation:op stopped:isStopped];

  [comm release];
  [sizer release];

  DESTROY(pool);

  return 0;
}
