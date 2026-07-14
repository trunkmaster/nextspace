/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2014 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#ifndef _PCFileManager_h_
#define _PCFileManager_h_

//#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class PCProject;
@class PCProjectManager;
@class PCAddFilesPanel;

enum {
    PCOpenFileOperation,
    PCSaveFileOperation,
    PCAddFileOperation,
    PCOpenProjectOperation,
    PCOpenDirectoryOperation
};

@interface PCFileManager : NSObject
{
  PCProjectManager       *projectManager;
  id                     delegate;        // PCProjectManager

  // New File in Project panel
  IBOutlet NSPanel       *newFilePanel;
  IBOutlet NSImageView   *nfImage;
  IBOutlet NSPopUpButton *nfTypePB;
  IBOutlet NSTextView    *nfDescriptionTV;
  IBOutlet NSTextField   *nfNameField;
  IBOutlet NSButton      *nfCancleButton;
  IBOutlet NSButton      *nfCreateButton;

  PCAddFilesPanel        *addFilesPanel;

  int                    operation;
}

//==============================================================================
// ==== Class methods
//==============================================================================

+ (PCFileManager *)defaultManager;

//==============================================================================
// ==== Init and free
//==============================================================================

- (id)initWithProjectManager:(PCProjectManager *)aProjectManager;
- (void)dealloc;

// ===========================================================================
// ==== File stuff
// ===========================================================================

// Checks if directories in path exists and creates if not.
- (BOOL)createDirectoriesIfNeededAtPath:(NSString *)path;

// Create directories in toFile path if needed
- (BOOL)copyFile:(NSString *)file toFile:(NSString *)toFile;

// Calls copyFile:toFile:
- (BOOL)copyFile:(NSString *)file intoDirectory:(NSString *)directory;

// Calls copyFile:intoDirectory in cycle
- (BOOL)copyFiles:(NSArray *)files intoDirectory:(NSString *)directory;

// Calls copyFile:intoDirectory:
- (BOOL)copyFile:(NSString *)file 
   fromDirectory:(NSString *)fromDir
   intoDirectory:(NSString *)toDir;
   
// If directory is empty remove it recursively
- (BOOL)removeDirectoriesIfEmptyAtPath:(NSString *)path;

// Remove 'file' located in 'directory'
- (BOOL)removeFile:(NSString *)file
     fromDirectory:(NSString *)directory
 removeDirsIfEmpty:(BOOL)removeDirs;

// Remove file with full path 'file'
- (BOOL)removeFileAtPath:(NSString *)file removeDirsIfEmpty:(BOOL)removeDirs;

// Remove array of files from directory
- (BOOL)removeFiles:(NSArray *)files
      fromDirectory:(NSString *)directory
  removeDirsIfEmpty:(BOOL)removeDirs;

- (BOOL)moveFile:(NSString *)file intoDirectory:(NSString *)directory;

// find an executable from list and return full path
- (NSString*) findExecutableToolFrom: (NSArray*)candidates;

@end

@interface PCFileManager (UInterface)

// Shows panel and return selected files if any
- (NSMutableArray *)filesOfTypes:(NSArray *)types
		       operation:(int)op
			multiple:(BOOL)yn
			   title:(NSString *)title
			 accView:(NSView *)accessoryView;

@end

@interface PCFileManager (Misc)

- (BOOL)isTextFile:(NSString *)filename;

// Return list of files and directories absolute paths that has 
// specified 'extension' at directory 'dirPath'. If 'incDirs'
// has value YES also include directories in this list.
- (NSArray *)filesWithExtension:(NSString *)extension
	     		 atPath:(NSString *)dirPath
     		    includeDirs:(BOOL)incDirs;

@end
#endif
