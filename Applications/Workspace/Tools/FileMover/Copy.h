/*
   The FileOperation tool's copying functions.

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
#import "../Communicator.h"

BOOL CopyOperation(NSString *sourceDir,
                   NSArray *files,
                   NSString *destDir,
                   OperationType opType);

BOOL CopyFile(NSString *filename,
              NSString *sourcePrefix,
              NSString *targetPrefix,
              BOOL traverseLink,
              OperationType opType);

void DuplicateOperation(NSString *sourceDir, NSArray *files);

BOOL DuplicateSymbolicLink(NSString *sourceFile,
                           NSString *targetFile,
                           NSDictionary *fattrs);
  
BOOL DuplicateFile(NSString *filename,
                   NSString *sourcePrefix,
                   BOOL     traverseLink);
