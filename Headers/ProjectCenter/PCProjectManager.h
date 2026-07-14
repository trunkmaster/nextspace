/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2004 Free Software Foundation

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

#ifndef _PCProjectManager_h_
#define _PCProjectManager_h_

#import <AppKit/AppKit.h>

#import <Protocols/Preferences.h>

@class PCBundleManager;
@class PCFileManager;
@class PCEditorManager;
@class PCProject;
@class PCProjectInspector;
@class PCProjectBuilder;
@class PCProjectLauncher;
@class PCProjectLoadedFiles;
@class PCProjectFinder;

@class NewSubprojectController;

extern NSString *PCActiveProjectDidChangeNotification;

@interface PCProjectManager : NSObject
{
  id                  delegate;
  id <PCPreferences>  prefController;

  PCBundleManager     *bundleManager;
  NSMutableDictionary *projectTypes;

  PCFileManager       *fileManager;
  PCEditorManager     *editorManager;
  PCProjectInspector  *projectInspector;
  
  NSPanel             *buildPanel;
  NSPanel             *launchPanel;
  NSPanel             *loadedFilesPanel;
  NSPanel             *findPanel;
  
  NSMutableDictionary *loadedProjects;
  PCProject           *activeProject;
  
  NSTimer             *saveTimer;

  NSBox	              *projectTypeAccessaryView;
  id                  projectTypePopup;

  NSBox	              *fileTypeAccessaryView;
  id                  fileTypePopup;

  IBOutlet NSPanel       *nsPanel;
  IBOutlet NSImageView   *nsImage;
  IBOutlet NSTextField   *nsTitle;
  IBOutlet NSTextField   *projectNameField;
  IBOutlet NSTextField   *nsNameField;
  IBOutlet NSPopUpButton *nsTypePB;
  IBOutlet NSButton      *nsCancelButton;
  IBOutlet NSButton      *nsCreateButton;

  @private
    BOOL _needsReleasing;
}

// ============================================================================
// ==== Intialization & deallocation
// ============================================================================
- (id)init;
- (BOOL)close;
- (void)dealloc;
- (void)setDelegate:(id)aDelegate;
- (id)delegate;
- (void)setPrefController:(id)aController;
- (id <PCPreferences>)prefController;

- (void)createProjectTypeAccessaryView;
- (NSMutableDictionary *)loadProjectTypesInfo;

// ============================================================================
// ==== Timer handling
// ============================================================================
- (BOOL)startSaveTimer;
- (BOOL)resetSaveTimer:(NSNotification *)notif;
- (BOOL)stopSaveTimer;

// ============================================================================
// ==== Accessory methods
// ============================================================================
- (PCBundleManager *)bundleManager;
- (PCFileManager *)fileManager;
- (PCEditorManager *)editorManager;
- (PCProjectInspector *)projectInspector;
- (NSPanel *)inspectorPanel;
- (void)showProjectInspector:(id)sender;
- (NSPanel *)loadedFilesPanel;
- (void)showProjectLoadedFiles:(id)sender;
- (NSPanel *)buildPanel;
- (NSPanel *)launchPanel;
- (NSPanel *)projectFinderPanel;

// ============================================================================
// ==== Project management
// ============================================================================

// Returns all currently loaded projects. They are stored with their absolute
// paths as keys.
- (NSMutableDictionary *)loadedProjects;
- (PCProject *)activeProject;
- (PCProject *)rootActiveProject;
- (void)setActiveProject:(PCProject *)aProject;

// ============================================================================
// ==== Project actions
// ============================================================================

- (PCProject *)convertLegacyProject:(NSMutableDictionary *)pDict
                             atPath:(NSString *)aPath;
- (PCProject *)openProjectAt:(NSString *)aPath makeActive: (BOOL)flag;
- (void)openProject;
- (PCProject *)createProjectOfType:(NSString *)projectType 
                              path:(NSString *)aPath;
- (void)newProject: (id)sender;
- (BOOL)saveProject;

// Calls saveAllProjects if the preferences are setup accordingly.
- (void)saveAllProjectsIfNeeded;

// Saves all projects if needed.
- (BOOL)saveAllProjects;
- (BOOL)addProjectFiles;
- (BOOL)saveProjectFiles;
- (BOOL)removeProjectFiles;

- (void)closeProject:(PCProject *)aProject;
- (void)closeProject;
- (BOOL)closeAllProjects;

// ============================================================================
// ==== File actions
// ============================================================================

// Also called by PCAppController
- (void)openFileAtPath:(NSString *)filePath;
- (void)openFileAtPath:(NSString *)filePath windowed: (BOOL)windowed;
- (void)openFile;
- (void)newFile;
- (BOOL)saveFile;
- (BOOL)saveFileAs;
- (BOOL)saveFileTo;
- (BOOL)revertFileToSaved;
- (BOOL)renameFile;
- (void)closeFile;

@end

@interface NSObject (PCProjectManagerDelegates)

- (void)projectManager:(id)sender willCloseProject:(PCProject *)aProject;
- (void)projectManager:(id)sender didCloseProject:(PCProject *)aProject;
- (void)projectManager:(id)sender didOpenProject:(PCProject *)aProject;
- (BOOL)projectManager:(id)sender shouldOpenProject:(PCProject *)aProject;

@end

@interface NewSubprojectController : NSWindowController
{
  id image;
  id nameTextField;
  id typePopup;
  id createButton;
  id cancelButton;
}

@end

@interface PCProjectManager (Subprojects)

- (BOOL)openNewSubprojectPanel;
- (void)closeNewSubprojectPanel:(id)sender;

- (void)createSubproject:(id)sender;
- (PCProject *)createSubprojectOfType:(NSString *)projectType 
                                 path:(NSString *)aPath;
- (BOOL)addSubproject;
@end

#endif
