/*
   The FileMover tool's main function.

   Copyright (C) 2005 Saso Kiselkov
   Copyright (C) 2015 Sergii Stoian

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

#import "../Communicator.h"
#import "Copy.h"
#import "Move.h"
#import "Link.h"
#import "Delete.h"

BOOL isStopped;

void PrintHelp(void)
{
  printf("Usage: FileOperation <options>\n\n"
         "Options:"
         "  -Operation Copy|Move|Link|Delete \n"
         "  -Source directory \n"
         "  -Files (Source, Filename, Array) \n"
         "  -Destination directory \n");
}

void SignalHandler(int sig)
{
  // if (sig == SIGTERM)
  //   fprintf(stderr, "FileOperation.tool: received TERMINATE signal\n");
  if (sig == SIGINT)
    {
      fprintf(stderr, "FileMover.tool: received INTERRUPT signal\n");
      StopOperation();
    }
}

void StopOperation()
{
  isStopped = YES;
}

int main(int argc, const char **argv)
{
  NSString       *op;
  NSString       *source;
  NSString       *dest;
  NSArray        *files;
  NSUserDefaults *df;
  BOOL           argsOK = YES;

  CREATE_AUTORELEASE_POOL(pool);

  // Signals
  signal(SIGINT, SignalHandler);
  //signal(SIGTERM, SignalHandler);

  // Get args
  df = [NSUserDefaults standardUserDefaults];
  op = [df objectForKey:@"Operation"];
  source = [df objectForKey:@"Source"];
  dest = [df objectForKey:@"Destination"];
  // files = [df objectForKey:@"Files"];
  files = [[[[NSProcessInfo processInfo] environment] objectForKey:@"Files"]
            propertyList];

  // NSLog(@"FileMover.tool: files: %@", files);
  // NSLog(@"FileMover.tool: files count: %lu", [files count]);

  // Check args
  if (op == nil || ![op isKindOfClass:[NSString class]])
    {
      printf("FileMover.tool: unknown operation type (-Operation)!\n");
      argsOK = NO;
    }
  else if (source == nil || ![source isKindOfClass:[NSString class]])
    {
      printf("FileMover.tool: incorrect source path (-Source)!\n");
      argsOK = NO;
    }
  else if (![op isEqualToString:@"Delete"] &&
           ![op isEqualToString:@"Duplicate"])
    {
      if (dest == nil || ![dest isKindOfClass:[NSString class]])
        {
          printf("FileMover.tool: incorrect destination path (-Destination)!\n");
          argsOK = NO;
        }
      else if (files == nil || ![files isKindOfClass:[NSArray class]])
        {
          printf("FileMover.tool: incorect file list (-Files)!\n");
          argsOK = NO;
        }
    }
  
  if (argsOK == NO)
    {
      PrintHelp();
      return 1;
    }

  isStopped = NO;

  if ([op isEqualToString:@"Copy"])
    {
      CopyOperation(source, files, dest, CopyOp);
    }
  else if ([op isEqualToString:@"Move"])
    {
      MoveOperation(source, files, dest);
    }
  else if ([op isEqualToString:@"Link"])
    {
      LinkOperation(source, files, dest);
    }
  else if ([op isEqualToString:@"Duplicate"])
    {
      DuplicateOperation(source, files); // located in Copy.m
    }
  else if ([op isEqualToString:@"Delete"])
    {
      DeleteOperation(source, files);
    }
  else
    {
      printf("FileMover.tool: unknown operation type!\n");
      PrintHelp();
      return 1;
    }

  [[Communicator shared] finishOperation:op stopped:isStopped];
  
  // NSLog(@"time: %f sec", [[NSDate date] timeIntervalSinceDate:start]);
  DESTROY(pool);

  return 0;
}
