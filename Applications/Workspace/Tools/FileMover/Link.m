/*
   The FileOperation tool's linking functions.

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

#import "Link.h"
#import "../Communicator.h"

void CleanUpAfterLink(NSArray *files, NSString *dir)
{
  NSEnumerator  *e;
  NSString      *filename;
  NSFileManager *fm = [NSFileManager defaultManager];
  
  e = [files objectEnumerator];
  while ((filename = [e nextObject]) != nil)
    {
      [fm removeFileAtPath:[dir stringByAppendingPathComponent:filename]
                   handler:nil];
    }
}

void LinkOperation(NSString *sourceDir, NSArray *files, NSString *destDir)
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator  *e = [files objectEnumerator];
  NSString      *file;
  Communicator  *comm = [Communicator shared];

  while (((file = [e nextObject]) != nil) && !isStopped)
    {
      NSString *sourceFile = [sourceDir stringByAppendingPathComponent:file];
      NSString *destFile = [destDir stringByAppendingPathComponent:file];

      [comm showProcessingFilename:file
		      sourcePrefix:sourceDir
		      targetPrefix:destDir
		     bytesAdvanced:0
                     operationType:LinkOp];

      if ([fm fileExistsAtPath:destFile])
	{
	  ProblemSolution s = [comm howToHandleProblem:FileExists];

	  if (s == SkipFile)
	    {
	      continue;
	    }
	  else if (![fm removeFileAtPath:destFile
				 handler:nil])
	    {
      	      [comm howToHandleProblem: WriteError];
	      continue;
  	    }
    	}

      if (![fm createSymbolicLinkAtPath:destFile
			    pathContent:sourceFile])
	{
   	  [comm howToHandleProblem:WriteError];
	  continue;
  	}
    }
  
  // We received SIGTERM signal or 'Stop' command
  // Remove created duplicates and exit
  if (isStopped)
    {
      if (makeCleanupOnStop)
        {
          CleanUpAfterLink(files, destDir);
        }
    }
}
