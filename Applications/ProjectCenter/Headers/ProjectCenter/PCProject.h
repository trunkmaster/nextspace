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

#ifndef _PCProject_h_
#define _PCProject_h_

#import <AppKit/AppKit.h>

@class PCProjectManager;
@class PCProjectWindow;
@class PCProjectBrowser;
@class PCProjectLoadedFiles;

@class PCProjectInspector;
@class PCProjectBuilder;
@class PCProjectLauncher;
@class PCProjectEditor;

extern NSString *PCProjectDictDidChangeNotification;
extern NSString *PCProjectDictDidSaveNotification;
extern NSString *PCProjectBreakpointNotification;

@interface PCProject : NSObject
{
  PCProjectManager     *projectManager; 
  PCProjectWindow      *projectWindow;
  PCProjectBrowser     *projectBrowser;
  PCProjectLoadedFiles *projectLoadedFiles;
  PCProjectEditor      *projectEditor;
  PCProjectBuilder     *projectBuilder;
  PCProjectLauncher    *projectLauncher;

  // Preferences
  BOOL                 rememberWindows;
  BOOL                 keepBackup;

  NSMutableDictionary  *projectDict;
  NSString             *projectName;
  NSString             *projectPath;

  NSArray              *rootKeys;       // e.g. CLASS_FILES
  NSArray              *rootCategories; // e.g. Classes
  NSDictionary         *rootEntries;    // Initialised by subclasses

  NSMutableDictionary  *buildOptions;

  PCProject            *activeSubproject;

  // Subproject
  NSMutableArray       *loadedSubprojects;
  BOOL                 isSubproject;
  PCProject            *rootProject;
  PCProject            *superProject;
  NSFileWrapper        *projectFileWrapper;
  NSString             *wrapperPath;
}

// ============================================================================
// ==== Init and free
// ============================================================================

- (id)init;
- (PCProject *)openWithWrapperAt:(NSString *)path;
- (void)dealloc;
- (void)loadPreferences:(NSNotification *)aNotification;

// ============================================================================
// ==== Project handling
// ============================================================================

- (BOOL)assignProjectDict:(NSDictionary *)pDict atPath:(NSString *)pPath;
//- (BOOL)assignProjectDict:(NSDictionary *)aDict;
- (BOOL)isValidDictionary:(NSDictionary *)aDict;
// Validates the project dictionary and inserts missing keys if needed. 
// It calls isValidDictionary to validate.
- (void)validateProjectDict;
- (void)setProjectDictObject:(id)object forKey:(NSString *)key notify:(BOOL)yn;
- (void)updateProjectDict;
- (NSDictionary *)projectDict;

- (NSString *)projectName;
- (void)setProjectName:(NSString *)aName;
- (NSString *)projectPath;
- (void)setProjectPath:(NSString *)aPath;

- (BOOL)isProjectChanged;
// Subclasses need to call this before their customised implementation!
- (BOOL)writeMakefile;
- (BOOL)saveProjectWindowsAndPanels;
- (BOOL)save;
- (BOOL)close:(id)sender;

// ============================================================================
// ==== Accessory methods
// ============================================================================

- (PCProjectManager *)projectManager;
- (void)setProjectManager:(PCProjectManager *)aManager;
- (PCProjectWindow *)projectWindow;
- (PCProjectBrowser *)projectBrowser;
- (PCProjectLoadedFiles *)projectLoadedFiles;
- (PCProjectBuilder *)projectBuilder;
- (PCProjectLauncher *)projectLauncher;
- (PCProjectEditor *)projectEditor;

// ===========================================================================
// ==== Can be overriden
// ===========================================================================

// Project Attributes Inspector
- (NSView *)projectAttributesView;

//--- Properties from Info.table
- (NSDictionary *)projectBundleInfoTable;
- (NSString *)projectTypeName;
- (Class)builderClass;
- (NSString *)projectDescription;
- (BOOL)isExecutable;
- (BOOL)canHavePublicHeaders;
- (NSArray *)publicHeaders;
- (void)setHeaderFile:(NSString *)file public:(BOOL)yn;
- (NSArray *)localizedResources;
- (NSString *)resourceDirForLanguage:(NSString *)language;
- (void)setResourceFile:(NSString *)file localizable:(BOOL)yn;

- (NSArray *)buildTargets;
// Files placed into /
- (NSArray *)sourceFileKeys;
// Files placed into /Resources or /Language.lproj
- (NSArray *)resourceFileKeys;
- (NSArray *)otherKeys;
- (NSArray *)allowableSubprojectTypes;
- (NSArray *)localizableKeys;

- (BOOL)isEditableCategory:(NSString *)category;
- (BOOL)isEditableFile:(NSString *)filePath;
- (NSArray *)fileTypesForCategoryKey:(NSString *)key;
- (NSString *)categoryKeyForFileType:(NSString *)type;
- (NSString *)dirForCategoryKey:(NSString *)key;
- (NSString *)complementaryTypeForType:(NSString *)type;

// ============================================================================
// ==== File Handling
// ============================================================================

// Returns file path taking into account localizable resources
- (NSString *)pathForFile:(NSString *)file forKey:(NSString *)key;

// Remove path from "file" and handle special cases like libraries
- (NSString *)projectFileFromFile:(NSString *)file forKey:(NSString *)type;

// Returns YES if type is a valid key and file is not contained in the 
// project already
- (BOOL)doesAcceptFile:(NSString *)file forKey:(NSString *)key;

- (BOOL)addAndCopyFiles:(NSArray *)files forKey:(NSString *)key;
- (void)addFiles:(NSArray *)files forKey:(NSString *)key notify:(BOOL)yn;
- (BOOL)removeFiles:(NSArray *)files forKey:(NSString *)key notify:(BOOL)yn;
- (BOOL)renameFile:(NSString *)fromFile toFile:(NSString *)toFile;

// ============================================================================
// ==== Subprojects
// ============================================================================

- (NSArray *)loadedSubprojects;
- (PCProject *)activeSubproject;

- (BOOL)isSubproject;
- (void)setIsSubproject:(BOOL)yn;
- (PCProject *)superProject;
- (void)setSuperProject:(PCProject *)project;

- (PCProject *)subprojectWithName:(NSString *)name;

- (void)addSubproject:(PCProject *)aSubproject;
- (void)addSubprojectWithName:(NSString *)name;
- (BOOL)removeSubproject:(PCProject *)aSubproject;
- (BOOL)removeSubprojectWithName:(NSString *)subprojectName;

@end

@interface PCProject (ProjectBrowser)

- (NSArray *)rootKeys;
- (NSArray *)rootCategories;
- (NSDictionary *)rootEntries;
- (NSString *)keyForCategory:(NSString *)category;
- (NSString *)categoryForKey:(NSString *)key;

- (NSArray *)contentAtCategoryPath:(NSString *)categoryPath;
- (BOOL)hasChildrenAtCategoryPath:(NSString *)keyPath;

- (NSString *)rootCategoryForCategoryPath:(NSString *)categoryPath;
//- (NSString *)categoryForCategoryPath:(NSString *)categoryPath;
- (NSString *)keyForRootCategoryInCategoryPath:(NSString *)categoryPath;
//- (NSString *)keyForCategoryPath:(NSString *)categoryPath;

@end

#endif

