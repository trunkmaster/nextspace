/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2015 Free Software Foundation

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

#ifndef _PCFileCreator_h_
#define _PCFileCreator_h_

#import <AppKit/AppKit.h>

#define ProtocolFile	@"Objective-C Protocol"
#define ObjCClass	@"Objective-C Class"
#define ObjCHeader	@"Objective-C Header"
#define CFile		@"C File"
#define CHeader	        @"C Header"
#define ObjCppClass	@"Objective-C++ Class"
#define GSMarkupFile	@"GNUstep Markup"

@class PCProject;

@interface PCFileCreator : NSObject
{
  PCProject              *activeProject;
  NSMutableString        *file;

  // New File in Project panel
  IBOutlet NSPanel       *newFilePanel;
  IBOutlet NSImageView   *nfImage;
  IBOutlet NSPopUpButton *nfTypePB;
  IBOutlet NSTextView    *nfDescriptionTV;
  IBOutlet NSTextField   *nfNameField;
  IBOutlet NSButton      *nfCancelButton;
  IBOutlet NSButton      *nfCreateButton;
  IBOutlet NSButton      *nfAddHeaderButton;
}

+ (id)sharedCreator;

- (NSDictionary *)creatorDictionary;

- (void)newFileInProject:(PCProject *)aProject;

- (void)createFileOfType:(NSString *)fileType
		    path:(NSString *)path
		 project:(PCProject *)project;

// Return list of file paths for creation
- (NSDictionary *)filesToCreateForFileOfType:(NSString *)type
					path:(NSString *)path
			   withComplementary:(BOOL)complementary;
- (BOOL)createFiles:(NSDictionary *)fileList
	  inProject:(PCProject *)aProject;

- (void)replaceTagsInFileAtPath:(NSString *)newFile
                    withProject:(PCProject *)aProject;

@end

@interface PCFileCreator (UInterface)

- (void)showNewFilePanel;
- (void)closeNewFilePanel:(id)sender;
- (void)createFile:(id)sender;
- (void)newFilePopupChanged:(id)sender;
- (void)controlTextDidChange:(NSNotification *)aNotif;
- (BOOL)createFile;

@end

#endif
