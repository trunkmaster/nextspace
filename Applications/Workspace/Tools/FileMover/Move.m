/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2006-2014 Sergii Stoian
// Copyright (C) 2005 Saso Kiselkov
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

#import <NXSystem/NXFileSystem.h>

#import <string.h>
#import <errno.h>

#import "Move.h"
#import "Copy.h"
#import "Delete.h"
#import "../Communicator.h"

void CleanUpAfterMove(NSString *sourceDir, NSArray *files, NSString *destDir)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator  *e = [files objectEnumerator];
  NSString      *file;

  while ((file = [e nextObject]) != nil)
    {
      NSString *src;
      NSString *dest;

      src = [sourceDir stringByAppendingPathComponent:file];
      dest = [destDir stringByAppendingPathComponent:file];

      rename([src cString], [dest cString]);
    }
}

void MoveOperation(NSString *sourceDir, NSArray  *files, NSString *destDir)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator  *e = [files objectEnumerator];
  NSString      *file;
  Communicator  *comm = [Communicator shared];

  while (((file = [e nextObject]) != nil) && !isStopped)
    {
      NSString *src, *dest;
      NSString *smp, *dmp;

      src = [sourceDir stringByAppendingPathComponent:file];
      dest = [destDir stringByAppendingPathComponent:file];

      [comm showProcessingFilename:file
		      sourcePrefix:sourceDir
		      targetPrefix:destDir
		     bytesAdvanced:0
                     operationType:MoveOp];

      if ([fm fileExistsAtPath:dest])
	{
	  if ([comm howToHandleProblem:FileExists argument:dest] == SkipFile)
	    {
	      continue;
	    }
	  else if ([fm removeFileAtPath:dest handler:nil] == NO)
	    {
	      [comm howToHandleProblem:DeleteError argument:dest];
	      continue;
	    }
	}

      smp = [NXFileSystem fileSystemMountPointAtPath:sourceDir];
      dmp = [NXFileSystem fileSystemMountPointAtPath:destDir];
      if ([smp isEqualToString:dmp])
        {
          if (rename([src cString], [dest cString]) < 0)
            {
              [comm howToHandleProblem:MoveError
                              argument:[NSString stringWithCString:
                                                   strerror(errno)]];
            }
        }
      else
        {
          // Copy then Delete
          if (CopyOperation(sourceDir, [NSArray arrayWithObject:file],
                            destDir, MoveOp) == YES)
            {
              NSLog(@"Move: Copy operation successfull");
              DeleteOperation(sourceDir, [NSArray arrayWithObject:file]);
            }
        }
    }

  // We received SIGTERM signal or 'Stop' command
  // Remove created duplicates and exit
  if (isStopped)
    {
      if (makeCleanupOnStop)
        {
          CleanUpAfterMove(destDir, files, sourceDir);
        }
    }
}
