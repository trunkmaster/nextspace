/*
   The Sizer processing.

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

#import "Size.h"

static unsigned long long batchSize = 0;
static unsigned long filecount = 0;

@implementation Size

// Recursive calculation of the 'dir' contents
- (void)calculateBatchSizeInDirectory:(NSString *)dir
                        operationType:(OperationType)opType
                         communicator:(Communicator *)comm
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray       *dirContents = [fm directoryContentsAtPath:dir];
  NSString     *path = nil;
  NSDictionary *fattrs = nil;

  for (NSString *file in dirContents)
    {
      path = [dir stringByAppendingPathComponent:file];
      fattrs = [fm fileAttributesAtPath:path traverseLink:NO];

      [comm showProcessingFilename:[path lastPathComponent]
                      sourcePrefix:[path stringByDeletingLastPathComponent]
                      targetPrefix:nil
                     bytesAdvanced:0
                     operationType:SizingOp];

      if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory])
        {
          // Recursion
          [self calculateBatchSizeInDirectory:path
                                operationType:opType
                                 communicator:comm];
        }
      else
        {
          if (opType != DeleteOp)
            {
              batchSize += [fattrs fileSize];
            }
          filecount++;
        }
      filecount++;
      
      if (isStopped == YES)
        return;
    }
}

// Should update with printf:
//           number of files: "Q\tF\t%u\t+"   <----(Queued Files)
//                batch size: "Q\tS\t%llu\t+" <----(Queued Size)
// If field #4 contains '+' it is an update to the totals (sendIncrement:YES).
// Currently FileOperation.m gets this numbers if no other message types
// detected "F" "B"
- (void)calculateBatchSizeInDirectory:(NSString *)sourceDir
                                files:(NSArray *)filenames
                        operationType:(OperationType)opType
                        sendIncrement:(BOOL)isIncrement
                         communicator:(Communicator *)comm
{
  isStopped = NO;

  // if (opType == LinkOp || opType == MoveOp)
  if (opType == LinkOp)
    {
      if (isIncrement)
        {
          printf("Q\tF\t%lu\t+\n", [filenames count]);
        }
      else
        {
          printf("Q\tF\t%lu\n", [filenames count]);
        }
      fflush(stdout);
      return;
    }

  if (!filenames)
    { // Process all FS heirarchy starting from -Source directory
      [self calculateBatchSizeInDirectory:sourceDir
                            operationType:opType
                             communicator:comm];
    }
  else
    { // Process objects specified in -Files located in -Source
      NSFileManager *fm = [NSFileManager defaultManager];
      NSString      *path = nil;
      NSDictionary  *fattrs = nil;

      for (NSString *file in filenames)
        {
          path = [sourceDir stringByAppendingPathComponent:file];
          fattrs = [fm fileAttributesAtPath:path traverseLink:NO];

          [comm showProcessingFilename:[file lastPathComponent]
                          sourcePrefix:sourceDir
                          targetPrefix:nil
                         bytesAdvanced:0
                         operationType:SizingOp];

          if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory])
            { // recursive
              [self calculateBatchSizeInDirectory:path
                                    operationType:opType
                                     communicator:comm];
            }
          else
            {
              if (opType != DeleteOp)
                {
                  batchSize += [fattrs fileSize];
                }
              filecount++;
            }
          if (isStopped == YES)
            return;
        }
    }

  if (isIncrement)
    {
      printf("Q\tF\t%lu\t+\n", filecount);
      printf("Q\tS\t%llu\t+\n", batchSize);
    }
  else
    {
      printf("Q\tF\t%lu\n", filecount);
      printf("Q\tS\t%llu\n", batchSize);
    }
  fflush(stdout);
}

@end
