/*
   The FileOperation tool's deletion functions.

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

#import "Delete.h"
#import "../Communicator.h"

void DeleteOperation(NSString * dir, NSArray * files)
{
  Deleter       *d = [Deleter new];
  NSEnumerator  *e;
  NSString      *filename;
  NSFileManager *fm = [NSFileManager defaultManager];
  Communicator  *comm = [Communicator shared];

  e = [files objectEnumerator];
  while (((filename = [e nextObject]) != nil) && !isStopped)
    {
      [comm showProcessingFilename:filename
                      sourcePrefix:dir
                      targetPrefix:nil
                     bytesAdvanced:0
                     operationType:DeleteOp];
      
      [fm removeFileAtPath:[dir stringByAppendingPathComponent:filename]
                   handler:d];
    }
  
  DESTROY(d);
}

@implementation Deleter

- (BOOL)      fileManager:(NSFileManager*)fileManager
  shouldProceedAfterError:(NSDictionary*)errorDictionary
{
  [[Communicator shared] howToHandleProblem:DeleteError];

  return YES;
}

- (void)fileManager:(NSFileManager*)fileManager
    willProcessPath:(NSString*)path
{
  [[Communicator shared] 
    showProcessingFilename:[path lastPathComponent]
	      sourcePrefix:[path stringByDeletingLastPathComponent]
	      targetPrefix:nil
	     bytesAdvanced:0
             operationType:DeleteOp];
}

@end
