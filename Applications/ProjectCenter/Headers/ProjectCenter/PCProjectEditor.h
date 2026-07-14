/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2002-2004 Free Software Foundation

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

#ifndef _PCProjectEditor_h_
#define _PCProjectEditor_h_

#import <Foundation/Foundation.h>

#import <Protocols/CodeEditor.h>
#import <Protocols/CodeParser.h>

#import <ProjectCenter/PCEditorManager.h>

@class PCProject;

@class NSBox;
@class NSView;
@class NSScrollView;

@interface PCProjectEditor : PCEditorManager
{
  PCProject           *_project;
  NSBox               *_componentView;
  NSScrollView        *_scrollView;

/*  NSDictionary        *_editorBundlesInfo;
  NSDictionary        *_parserBundlesInfo;
  NSMutableDictionary *_editorsDict;
  id<CodeEditor>      _activeEditor;*/
}

// ===========================================================================
// ==== Initialisation
// ===========================================================================

- (id)init;
- (void)dealloc;
- (NSView *)componentView;
- (PCProject *)project;
- (void)setProject:(PCProject *)aProject;

// ===========================================================================
// ==== Project and Editor handling
// ===========================================================================

- (BOOL)editorProvidesBrowserItemsForItem:(NSString *)item;

- (id<CodeEditor>)openEditorForFilePath:(NSString *)categoryPath
                               windowed:(BOOL)windowed;

- (id<CodeEditor>)openEditorForCategoryPath:(NSString *)categoryPath
                                   windowed:(BOOL)windowed;

- (void)orderFrontEditorForFile:(NSString *)path;

// ===========================================================================
// ==== File handling
// ===========================================================================

- (BOOL)saveFileAs:(NSString *)file;

// ===========================================================================
// ==== Delegate
// ===========================================================================

- (void)editorDidClose:(NSNotification *)aNotif;
- (void)editorDidBecomeActive:(NSNotification *)aNotif;

@end

#endif 

