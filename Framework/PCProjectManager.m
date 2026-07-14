/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2021 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan
	    Riccardo Mottola

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

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCLogController.h>

#import <ProjectCenter/PCBundleManager.h>
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCFileCreator.h>
#import <ProjectCenter/PCEditorManager.h>
#import <ProjectCenter/PCProjectManager.h>

#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectWindow.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCProjectInspector.h>
#import <ProjectCenter/PCProjectEditor.h>
#import <ProjectCenter/PCProjectBuilderPanel.h>
#import <ProjectCenter/PCProjectLauncherPanel.h>
#import <ProjectCenter/PCProjectLoadedFilesPanel.h>

#import "Protocols/ProjectType.h"
#import "Protocols/CodeEditor.h"

#import "Modules/Preferences/Saving/PCSavingPrefs.h"
#import "Modules/Preferences/Misc/PCMiscPrefs.h"

NSString *PCActiveProjectDidChangeNotification = @"PCActiveProjectDidChange";

@implementation PCProjectManager

// ============================================================================
// ==== Intialization & deallocation
// ============================================================================

- (id)init
{
  if ((self = [super init]))
    {
      buildPanel = nil;
      launchPanel = nil;
      loadedFilesPanel = nil;
      findPanel = nil;

      // Prepare bundles
      bundleManager = [[PCBundleManager alloc] init];
      projectTypes = [self loadProjectTypesInfo];
      
      loadedProjects = [[NSMutableDictionary alloc] init];
      
      [[NSNotificationCenter defaultCenter] 
	addObserver:self 
	   selector:@selector(resetSaveTimer:)
	       name:PCSavePeriodDidChangeNotification
	     object:nil];

      fileManager = [[PCFileManager alloc] initWithProjectManager:self];
    }

  return self;
}

- (BOOL)close
{
  if ([self closeAllProjects] == NO)
    {
      return NO;
    }

  if ((editorManager != nil) && ([editorManager closeAllEditors] == NO))
    {
      return NO;
    }

  return YES;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCProjectManager: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if ([saveTimer isValid])
    {
      [saveTimer invalidate];
    }

  RELEASE(loadedProjects);
  RELEASE(fileManager);

  RELEASE(bundleManager);
  RELEASE(projectTypes);
  RELEASE(projectTypeAccessaryView);
  RELEASE(fileTypeAccessaryView);

  TEST_RELEASE(editorManager);

  TEST_RELEASE(projectInspector);
  TEST_RELEASE(loadedFilesPanel);
  TEST_RELEASE(buildPanel);
  TEST_RELEASE(launchPanel);

  [super dealloc];
}

- (void)setDelegate:(id)aDelegate 
{
  delegate = aDelegate;
}

- (id)delegate
{
  return delegate;
}

- (void)setPrefController:(id)aController
{
  prefController = aController;
}

- (id <PCPreferences>)prefController
{
  return prefController;
}

- (void)createProjectTypeAccessaryView
{
  NSRect fr = NSMakeRect(20,30,160,20);

  if (projectTypeAccessaryView != nil)
    {
      return;
    }

  // For "Open Project" and "New Project" panels
  projectTypePopup = [[NSPopUpButton alloc] initWithFrame:fr pullsDown:NO];
  [projectTypePopup setRefusesFirstResponder:YES];
  [projectTypePopup setAutoenablesItems:NO];
  [projectTypePopup addItemsWithTitles:
    [[projectTypes allKeys] 
    sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
  [projectTypePopup sizeToFit];
  [projectTypeAccessaryView sizeToFit];
  [projectTypePopup selectItemAtIndex:0];

  projectTypeAccessaryView = [[NSBox alloc] init];
  [projectTypeAccessaryView setTitle:@"Project Types"];
  [projectTypeAccessaryView setTitlePosition:NSAtTop];
  [projectTypeAccessaryView setBorderType:NSGrooveBorder];
  [projectTypeAccessaryView addSubview:projectTypePopup];
  [projectTypeAccessaryView sizeToFit];
  [projectTypeAccessaryView setAutoresizingMask:NSViewMinXMargin 
                                                | NSViewMaxXMargin];
  RELEASE(projectTypePopup);
}

- (NSMutableDictionary *)loadProjectTypesInfo
{
  NSDictionary *bundlesInfo;
  NSEnumerator *enumerator;
  NSArray      *bundlePaths;
  NSString     *key;
  NSDictionary *infoTable;
  
  if (projectTypes == nil)
    {
      projectTypes = [[NSMutableDictionary alloc] init];
      bundlesInfo = [bundleManager infoForBundlesType:@"project"];

      bundlePaths = [bundlesInfo allKeys];
      enumerator = [bundlePaths objectEnumerator];

      while ((key = [enumerator nextObject]))
	{
	  infoTable = [bundlesInfo objectForKey:key];
	  [projectTypes setObject:[infoTable objectForKey:@"PrincipalClassName"]
	                   forKey:[infoTable objectForKey:@"Name"]];
	}
    }

  return projectTypes;
}

// ============================================================================
// ==== Timer handling
// ============================================================================

- (BOOL)startSaveTimer
{
  NSTimeInterval interval;

  interval = [[prefController stringForKey:AutoSavePeriod] intValue];

  if (interval > 0 && saveTimer == nil)
    {
      saveTimer = [NSTimer 
	scheduledTimerWithTimeInterval:interval
	                        target:self
	                      selector:@selector(saveAllProjects)
	                      userInfo:nil
	                       repeats:YES];
      return YES;
    }
  return NO;
}

- (BOOL)resetSaveTimer:(NSNotification *)notif
{
  [self stopSaveTimer];

  return [self startSaveTimer];
}

- (BOOL)stopSaveTimer
{
  if (saveTimer && [saveTimer isValid])
    {
      [saveTimer invalidate];
      saveTimer = nil;

      return YES;
    }
  return NO;
}

// ============================================================================
// ==== Accessory methods
// ============================================================================

- (PCBundleManager *)bundleManager
{
  return bundleManager;
}

- (PCFileManager *)fileManager
{
  return fileManager;
}

- (PCEditorManager *)editorManager
{
  if (!editorManager)
    {
      // For non project editors
      editorManager = [[PCEditorManager alloc] init];
      [editorManager setProjectManager:self];
    }

  return editorManager;
}

- (PCProjectInspector *)projectInspector
{
  if (!projectInspector)
    {
      projectInspector = 
	[[PCProjectInspector alloc] initWithProjectManager:self];
    }

  return projectInspector;
}

- (NSPanel *)inspectorPanel
{
  return [[self projectInspector] panel];
}

- (void)showProjectInspector:(id)sender
{
  [[[self projectInspector] panel] makeKeyAndOrderFront:self];
}

- (NSPanel *)loadedFilesPanel
{
  if (!loadedFilesPanel && [prefController boolForKey:UseTearOffWindows])
    {
      loadedFilesPanel = 
	[[PCProjectLoadedFilesPanel alloc] initWithProjectManager:self];
    }

  return loadedFilesPanel;
}

- (void)showProjectLoadedFiles:(id)sender
{
  if ([prefController boolForKey:UseTearOffWindows])
    {
      [[self loadedFilesPanel] orderFront:nil];
    }
}

- (NSPanel *)buildPanel
{
  if (!buildPanel && [prefController boolForKey:UseTearOffWindows])
    {
      buildPanel = [[PCProjectBuilderPanel alloc] initWithProjectManager:self];
    }

  return buildPanel;
}

- (NSPanel *)launchPanel
{
  if (!launchPanel && [prefController boolForKey:UseTearOffWindows])
    {
      launchPanel = [[PCProjectLauncherPanel alloc] initWithProjectManager:self];
    }

  return launchPanel;
}

- (NSPanel *)projectFinderPanel
{
  return findPanel;
}

// ============================================================================
// ==== Project management
// ============================================================================

- (NSMutableDictionary *)loadedProjects
{
  return loadedProjects;
}

- (PCProject *)activeProject
{
  return activeProject;
}

- (PCProject *)rootActiveProject
{
  PCProject *rootProject = nil;

  if (!activeProject)
    {
      return nil;
    }
  
  rootProject = activeProject;
  while ([rootProject isSubproject] == YES)
    {
      rootProject = [rootProject superProject];
    }

  return rootProject;
}

- (void)setActiveProject:(PCProject *)aProject
{
  if (aProject != activeProject)
    {
      activeProject = aProject;

      [[NSNotificationCenter defaultCenter]
	postNotificationName:PCActiveProjectDidChangeNotification
		      object:activeProject];
    }
}

- (void)saveAllProjectsIfNeeded
{
//  PCLogInfo(self, @"saveAllProjectsIfNeeded");

  // If this method was called not by NSTimer, check if we should save projects
  if ([prefController boolForKey:SaveOnQuit])
    {
      [self saveAllProjects];
    }
}

- (BOOL)saveAllProjects
{
  NSEnumerator *enumerator = [loadedProjects keyEnumerator];
  NSString     *key;
  PCProject    *project;

  while ((key = [enumerator nextObject]))
    {
      project = [loadedProjects objectForKey:key];

      if ([project save] == NO)
	{
	  return NO;
	}
    }

  return YES;
}

// ============================================================================
// ==== Project actions
// ============================================================================


- (PCProject *)convertLegacyProject:(NSMutableDictionary *)pDict
                             atPath:(NSString *)aPath
{
  NSString               *pPath = nil;
  NSString               *projectClassName = nil;
  NSString               *projectTypeName = nil;
  NSString               *_projectPath = nil;
  NSFileManager          *fm = [NSFileManager defaultManager];
  NSString               *_resPath = nil;
  NSArray                *_fromDirArray = nil;
  NSString               *_fromDirPath = nil;
  NSString               *_file = nil;
  NSString               *_2file = nil;
  NSString               *_resFile = nil;
  unsigned               i = 0;
  PCProject              *project = nil;
  NSMutableArray         *otherResArray = nil;
  NSString               *plistFile = nil;

  projectClassName = [pDict objectForKey:PCProjectBuilderClass];
  if (projectClassName == nil)
    {
      // Project created by 0.4 release or later
      return nil;
    }

  PCLogInfo(self, @"Converting legacy project");

  // Gorm project type doesn't exists anymore
  if ([projectClassName isEqualToString:@"PCGormProj"] ||
      [projectClassName isEqualToString:@"PCAppProj"])
    {
      projectTypeName = @"Application";
      projectClassName = [projectTypes objectForKey:projectTypeName];
    }

  // Handling directory layout
  _projectPath = [aPath stringByDeletingLastPathComponent];
  _resPath = [_projectPath stringByAppendingPathComponent:@"Resources"];
  [fm createDirectoryAtPath:_resPath attributes:nil];

  // Documents
  _fromDirPath = [_projectPath stringByAppendingPathComponent:@"Documentation"];
  _fromDirArray = [pDict objectForKey:PCDocuFiles];
  for (i = 0; i < [_fromDirArray count]; i++)
    {
      _resFile = [_fromDirArray objectAtIndex:i];
      _file = [_fromDirPath stringByAppendingPathComponent:_resFile];
      _2file = [_resPath stringByAppendingPathComponent:_resFile];
      [fm movePath:_file toPath:_2file handler:nil];
    }
  [fm removeFileAtPath:_fromDirPath handler:nil];

  // Images
  _fromDirPath = [_projectPath stringByAppendingPathComponent:@"Images"];
  _fromDirArray = [pDict objectForKey:PCImages];
  for (i = 0; i < [_fromDirArray count]; i++)
    {
      _resFile = [_fromDirArray objectAtIndex:i];
      _file = [_fromDirPath stringByAppendingPathComponent:_resFile];
      _2file = [_resPath stringByAppendingPathComponent:_resFile];
      [fm movePath:_file toPath:_2file handler:nil];
    }
  [fm removeFileAtPath:_fromDirPath handler:nil];
  
  // Interfaces
  _fromDirArray = [pDict objectForKey:PCInterfaces];
  for (i = 0; i < [_fromDirArray count]; i++)
    {
      _resFile = [_fromDirArray objectAtIndex:i];
      _file = [_projectPath stringByAppendingPathComponent:_resFile];
      _2file = [_resPath stringByAppendingPathComponent:_resFile];
      [fm movePath:_file toPath:_2file handler:nil];
    }

  // Other resources
  otherResArray = [NSMutableArray 
    arrayWithArray:[pDict objectForKey:PCOtherResources]];
  plistFile = [NSString stringWithFormat:@"%@Info.plist",
               [pDict objectForKey:PCProjectName]];
  for (i = 0; i < [otherResArray count]; i++)
    {
      _resFile = [otherResArray objectAtIndex:i];
      _file = [_projectPath stringByAppendingPathComponent:_resFile];
      if ([_resFile isEqualToString:plistFile])
	{
	  _2file = 
	    [_resPath stringByAppendingPathComponent:@"Info-gnustep.plist"];
	  [otherResArray replaceObjectAtIndex:i 
	                           withObject:@"Info-gnustep.plist"];
	  [pDict setObject:otherResArray forKey:PCOtherResources];
	}
      else
	{
	  _2file = [_resPath stringByAppendingPathComponent:_resFile];
	}
      [fm movePath:_file toPath:_2file handler:nil];
    }

  /* remove non meaningful keys */
  [pDict removeObjectForKey: PCWindows];
  [pDict removeObjectForKey: PCLastEditing];

  // GNUmakefiles will be generated in [PCProject initWithProjectDictionary:]

  // Remove obsolete records from project dictionary and write to PC.project
  pPath = [[aPath stringByDeletingLastPathComponent]
    stringByAppendingPathComponent:@"PC.project"];

  project = [bundleManager objectForClassName:projectClassName
				   bundleType:@"project"
				     protocol:@protocol(ProjectType)];

  projectTypeName = [project projectTypeName];
  [pDict setObject:projectTypeName forKey:PCProjectType];
  [pDict removeObjectForKey:PCProjectBuilderClass];
  [pDict removeObjectForKey:PCPrincipalClass];

  if ([pDict writeToFile:pPath atomically:YES] == YES)
    {
//      [[NSFileManager defaultManager] removeFileAtPath:aPath handler:nil];
    }

  return project;
}

// aPath is path to a project file PC.project or project bundle *.pcproj.
// Also it can be project directory where one of the above resides.
- (PCProject *)openProjectAt:(NSString *)aPath makeActive: (BOOL)flag
{
  NSString     *projectPath = nil;
  NSString     *projectFileType = nil;
  PCProject    *project = nil;
  NSString     *projectPathToSave;

  // Check project path for invalid characters
  if ([aPath rangeOfString: @" "].location != NSNotFound ||
      [aPath rangeOfString: @"\t"].location != NSNotFound ||
      [aPath rangeOfString: @"\r"].location != NSNotFound ||
      [aPath rangeOfString: @"\n"].location != NSNotFound)
    {
      if (NSRunAlertPanel 
	  (@"Open Project",
	   @"Project path contains whitespaces.\n"
	   @"GNUstep's build environment currently "
	   @"can't handle that reliably.\n"
	   @"Do you want to open a project anyway?\n",
	   @"Open", @"Don't open", nil) != NSAlertDefaultReturn)
	{
	  return nil;
	}
    }

  projectFileType = [[aPath lastPathComponent] pathExtension];
  if ([projectFileType isEqualToString:@"pcproj"] || 
      [projectFileType isEqualToString:@"project"])
    {
      projectPath = [aPath stringByDeletingLastPathComponent];
    }
  else
    {
      projectPath = aPath;
    }

  if ((project = [loadedProjects objectForKey:projectPath])== nil)
    {  
      NSMutableDictionary *projectFile = nil;
      NSString            *projectTypeName = nil;
      NSString            *projectClassName = nil;
      BOOL                isDir = NO;
      BOOL                exists = NO;
      NSArray             *tempList;
 
      exists = [[NSFileManager defaultManager] fileExistsAtPath:aPath 
						    isDirectory:&isDir];
      if (!exists)
	{
	  return nil;
	}

      projectPathToSave = projectPath;
      if (isDir)
	{
	  if ([projectFileType isEqualToString:@"pcproj"] == NO)
	    {
	      tempList = [fileManager filesWithExtension:@"pcproj"
						  atPath:aPath
					     includeDirs:YES];
	      if ([tempList count] > 0)
		{
		  aPath = [tempList objectAtIndex:0];
		}
	    }
	  else
	    {
	      projectPathToSave = aPath;
	    }
	  aPath = [aPath stringByAppendingPathComponent:@"PC.project"];
	  projectFile = [NSMutableDictionary dictionaryWithContentsOfFile:aPath];
	}
      else if ([projectFileType isEqualToString:@"project"])
	{
	  projectFile = [NSMutableDictionary dictionaryWithContentsOfFile:aPath];
	}
      else
	{ //TODO: Remove support of 0.3.x projects
	  projectFile = [NSMutableDictionary dictionaryWithContentsOfFile:aPath];
	  if (projectFile != nil)
	    {
	      // For compatibility with 0.3.x projects
	      project = [self convertLegacyProject:projectFile atPath:aPath];
	    }
	}

      if (projectFile == nil)
	  return nil;

      if (project)
	{// Project was converted and created PC*Project with alloc&init
	  aPath = [[aPath stringByDeletingLastPathComponent]
		    stringByAppendingPathComponent:@"PC.project"];
	}
      else
	{// No conversion were taken
	  projectTypeName = [projectFile objectForKey:PCProjectType];
	  projectClassName = [projectTypes objectForKey:projectTypeName];
	  if (projectClassName == nil)
	    {
	      NSRunAlertPanel(@"Open Project",
			      @"Project type '%@' is not supported!\n"
			      @"Report the bug, please!",
			      @"OK", nil, nil, projectTypeName); 
	      return nil;
	    }
	}
      
      project = [bundleManager objectForClassName:projectClassName
				       bundleType:@"project"
			  		 protocol:@protocol(ProjectType)];
      
      if (!project || ![project openWithWrapperAt:aPath]) 
	{
	  NSRunAlertPanel(@"Open Project",
			  @"Unable to open project '%@'.\nReport bug, please!",
			  @"OK",nil,nil,aPath); 
	  return nil;
	}
      
      PCLogStatus(self, @"Project %@ loaded as %@", 
		  [project projectName], [project projectTypeName]);
      
      // Started only if there's not save timer yet
      [self startSaveTimer];
      [project validateProjectDict];
      
      [loadedProjects setObject:project forKey:[project projectPath]];
      [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL: [NSURL fileURLWithPath:projectPathToSave]];
      PCLogStatus(self, @"Saved opened Document as %@", projectPathToSave);

      if (flag)
	{
          NSDictionary *wap = nil;
	  [project setProjectManager:self];
	  
	  // Windows and panels
	  wap = [projectFile objectForKey:PCWindows];
	  if ([[wap allKeys] containsObject:@"ProjectBuild"])
	    {
	      [[project projectWindow] showProjectBuild:self];
	    }
	  if ([[wap allKeys] containsObject:@"ProjectLaunch"])
	    {
	      [[project projectWindow] showProjectLaunch:self];
	    }
	  if ([[wap allKeys] containsObject:@"LoadedFiles"])
	    {
	      [[project projectWindow] showProjectLoadedFiles:self];
	    }
	}
    }
  else
    {
      PCLogStatus(self, @"Project %@ already Open", [project projectName]);
    }

  if (flag)
    {
      [self setActiveProject: project];
      [[project projectWindow] makeKeyAndOrderFront:self];
    }
  
  return project;
}

- (void)openProject
{
  NSArray       *fileTypes = nil;
  NSArray       *files = nil;
  NSString      *filePath = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          isDir;
  NSArray       *tempList = nil;

  fileTypes = [NSArray arrayWithObjects:@"pcproj",@"project",nil];
  files = [fileManager filesOfTypes:fileTypes
			  operation:PCOpenProjectOperation
			   multiple:NO
			      title:@"Open Project"
			    accView:nil];

  filePath = [files objectAtIndex:0];

  [fm fileExistsAtPath:filePath isDirectory:&isDir];
  if (isDir)
    {
      if (![[filePath pathExtension] isEqualToString:@"pcproj"])
	{
	  tempList = [fileManager filesWithExtension:@"pcproj" 
					      atPath:filePath
					 includeDirs:YES];
	  if ([tempList count] > 0)
	    {
	      filePath = [tempList objectAtIndex:0];
	    }
	}
      filePath = [filePath stringByAppendingPathComponent:@"PC.project"];
    }

  NSLog(@"PCPM: openProject: %@", filePath);

  if (filePath != nil)
    {
      [self openProjectAt:filePath makeActive:YES];
    }
}

- (PCProject *)createProjectOfType:(NSString *)projectType 
                              path:(NSString *)aPath
{
  NSString               *className = [projectTypes objectForKey:projectType];
  PCProject<ProjectType> *projectCreator;
  PCProject              *project = nil;
  NSString               *subType = nil;
 
  if ((project = [loadedProjects objectForKey: [aPath stringByDeletingLastPathComponent]]) != nil)
    {
      [[project projectWindow] makeKeyAndOrderFront:self];
      return project;
    }

  if ([projectType isEqualToString:@"Application"])
    subType = PCProjectInterfaceGorm;
 
  projectCreator = [bundleManager objectForClassName:className 
					  bundleType:@"project"
					    protocol:@protocol(ProjectType)];
//  NSLog(@"%@ CLASS: %@", className, projectCreator);
  if (!projectCreator)
    {
      NSRunAlertPanel(@"New Project",
		      @"Could not create project directory %@.\n"
		      @"No project creator. Report the bug, please!",
		      @"OK", nil, nil, aPath); 
      return nil;
    }

  // Create project directory
  if (![[PCFileManager defaultManager] createDirectoriesIfNeededAtPath:aPath])
    {
      NSRunAlertPanel(@"New Project",
		      @"Could not create project directory %@.\n"
		      @"Check permissions of the directory where you"
		      @" want to create a project",
		      @"OK", nil, nil, aPath); 
      return nil;
    }

  // Create project
  if (!(project = [projectCreator createProjectAt:aPath withOption:subType])) 
    {
      NSRunAlertPanel(@"New Project",
		      @"Project %@ could not be created.\nReport bug, please!",
		      @"OK",nil,nil,[project projectName]); 
      return nil;
    }

  [project setProjectManager:self];
  [self startSaveTimer];

  return project;
}

- (void)newProject: (id)sender
{
  NSArray   *files, *types = nil;
  NSString  *filePath;
  NSString  *projectType;
  PCProject *project;
  NSString  *projectPath;

  [self createProjectTypeAccessaryView];
  
  files = [fileManager filesOfTypes:types
			  operation:PCSaveFileOperation
			   multiple:NO
			      title:@"New Project"
			    accView:projectTypeAccessaryView];
  filePath = [files objectAtIndex:0];

#ifdef WIN32
  filePath = [filePath stringByDeletingPathExtension];
#endif

  if (filePath != nil) 
    {
      if ([filePath rangeOfString: @" "].location != NSNotFound ||
	  [filePath rangeOfString: @"\t"].location != NSNotFound ||
	  [filePath rangeOfString: @"\r"].location != NSNotFound ||
	  [filePath rangeOfString: @"\n"].location != NSNotFound)
	{
	  if (NSRunAlertPanel 
	      (@"New Project",
	       @"Are you sure you want to create a project with whitespace in it's path?\n"
	       @"GNUstep's build environment currently can't handle that reliably.",
	       @"OK", @"Cancel", nil) != NSAlertDefaultReturn)
	    {
	      return;
	    }
	}
      
      projectType = [projectTypePopup titleOfSelectedItem];

      if (!(project = [self createProjectOfType:projectType path:filePath]))
	{
	  // No need to open alert panel. Alert panel was already opened
	  // in createProjectOfType:path: method.
	  return;
	}

      projectPath = [project projectPath];
      [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:[NSURL fileURLWithPath:projectPath]];
      [loadedProjects setObject:project forKey:projectPath];
      [self setActiveProject:project];
      [[project projectWindow] orderFront:self];
    }
}

- (BOOL)saveProject
{
  PCProject *rootProject = [self rootActiveProject];

  if (!rootProject)
    {
      return NO;
    }
    
//  PCLogInfo(self, @"save root project: %@", [rootProject projectName]);

  // Save PC.project and the makefiles!
  if ([rootProject save] == NO)
    {
      NSRunAlertPanel(@"Save Project",
		      @"Couldn't save project %@!", 
		      @"OK", nil, nil, [rootProject projectName]);
      return NO;
    }

  return YES;
}

- (BOOL)addProjectFiles
{
  PCProject      *project = [self rootActiveProject];
  NSString       *category = [[project projectBrowser] nameOfSelectedCategory];
  NSString       *categoryKey = [activeProject keyForCategory:category];
  NSMutableArray *files = nil;
  NSString       *file = nil;
  NSString       *projectFile = nil;
  NSArray        *fileTypes = [project fileTypesForCategoryKey:categoryKey];

  files = [fileManager filesOfTypes:fileTypes
			  operation:PCAddFileOperation
			   multiple:NO
			      title:nil
			    accView:nil];

/*  PCLogInfo(self, @"[addProjectFiles] %@ to category: %@ of project %@",
	    files, categoryKey, [activeProject projectName]);*/

  // Category may be changed
  category = [[project projectBrowser] nameOfSelectedCategory];
  categoryKey = [activeProject keyForCategory:category];
  
  // No files was selected 
  if (!files)
    {
      return NO;
    }

  file = [[files objectAtIndex:0] lastPathComponent];
  projectFile = [activeProject projectFileFromFile:[files objectAtIndex:0] 
                                            forKey:categoryKey];

  if (![projectFile isEqualToString:file])
    {
      [activeProject addFiles:files forKey:categoryKey notify:YES];
    }
  else
    {
      // Copy and add files
      [activeProject addAndCopyFiles:files forKey:categoryKey];
    }

  return YES;
}

- (BOOL)saveProjectFiles
{
  return [[activeProject projectEditor] saveAllFiles];
}

- (BOOL)removeProjectFiles
{
  PCProject      *project = [self rootActiveProject];
  NSArray        *files = [[project projectBrowser] selectedFiles];
  NSString       *category = [[project projectBrowser] nameOfSelectedCategory];
  NSString       *categoryKey = [project keyForCategory:category];
  NSString       *directory = [activeProject dirForCategoryKey:categoryKey];
  NSString       *removeString = nil;
  NSMutableArray *subprojs = [NSMutableArray array];
  unsigned       i;

  NSLog(@"Root active project '%@' category '%@'", 
	[project projectName], category);

  // Determining target project
  if ([categoryKey isEqualToString:PCSubprojects])
    {
      if ([activeProject isSubproject])
	{
	  project = [activeProject superProject];
	  [self setActiveProject:project];
	}
      removeString = @"Remove subprojects...";
      directory = [project dirForCategoryKey:categoryKey];
    }
  else
    {
      removeString = @"Remove files...";
      project = activeProject;
    }

/*  PCLogInfo(self, @"%@: %@ from %@", removeString, files, directory);
  PCLogInfo(self, @"[removeProjectFiles]:%@ KEY:%@", 
	    [activeProject projectName], categoryKey);*/

  if (files)
    {
      int ret;

      if ([categoryKey isEqualToString:PCLibraries])
	{
	  ret = NSRunAlertPanel(@"Remove File",
				@"Remove libraries from Project?",
				@"Remove",
				@"Cancel",
				nil);
	}
      else
	{
	  ret = NSRunAlertPanel(@"Remove File",
				removeString,
				@"...from Project and Disk",
				@"...from Project only",
				@"Cancel");
	}

      if (ret == NSAlertDefaultReturn || ret == NSAlertAlternateReturn)
	{
	  BOOL flag = (ret == NSAlertDefaultReturn) ? YES : NO;

	  // Remove from projectDict
	  // If files localizable make them not localizable
	  ret = [project removeFiles:files forKey:categoryKey notify:YES];

	  // Remove files from disk
	  if (flag && ret && ![categoryKey isEqualToString:PCLibraries])
	    {
	      if ([categoryKey isEqualToString:PCSubprojects])
		{
		  for (i = 0; i < [files count]; i++)
		    {
		      [subprojs addObject:
			[[files objectAtIndex:i] 
			stringByAppendingPathExtension:@"subproj"]];
		    }
		  files = subprojs;
		}
    	      ret = [fileManager removeFiles:files 
		               fromDirectory:directory
			   removeDirsIfEmpty:YES];
	    }

	  if (!ret)
	    {
	      NSRunAlertPanel(@"Remove File",
			      @"Error removing files from project %@!",
			      @"OK", nil, nil, [activeProject projectName]);
	      return NO;
	    }
	  else if (flag) 
	    {
	      // Save project because we've removed file(s) from disk
	      // TODO: Maybe fix it later? (add pending removal of files)
	      [activeProject save];
	    }
	}
      else
	{
	  return NO;
	}
    } // files

  return YES;
}

- (void)closeProject:(PCProject *)aProject
{
  PCProject *currentProject = nil;

  currentProject = [loadedProjects objectForKey: [aProject projectPath]];
  if (!currentProject)
    {
      return;
    }

  // Remove it from the loaded projects!
  [loadedProjects removeObjectForKey: [aProject projectPath]];

  if ([loadedProjects count] == 0)
    {
      if (projectInspector)
	{
	  [projectInspector close];
	}
      if (loadedFilesPanel && [loadedFilesPanel isVisible])
	{
	  [loadedFilesPanel close];
	}
      if (buildPanel && [buildPanel isVisible])
	{
	  [buildPanel close];
	}
      if (launchPanel && [launchPanel isVisible])
	{
	  [launchPanel close];
	}
      [self setActiveProject:nil];
      [self stopSaveTimer];
    }
  else if (currentProject == [self activeProject])
    {
      [self setActiveProject:[[loadedProjects allValues] lastObject]];
    }

  RELEASE(currentProject);
}

- (void)closeProject
{
  if ([prefController boolForKey:SaveOnQuit])
    {
      [activeProject save];
    }

  [activeProject close:self];
}

- (BOOL)closeAllProjects
{
  PCProject      *project = nil;
  NSEnumerator   *enumerator = [[loadedProjects allValues] objectEnumerator];

//  PCLogInfo(self, @"loaded %i projects", [loadedProjects count]);

  while ((project = [enumerator nextObject]) != nil)
    {
      if ([prefController boolForKey:SaveOnQuit])
	{
	  [project save];
	}
      if ([project close:self] == NO)
	{
	  return NO;
	}
    }
   
  return YES;
}

// ============================================================================
// ==== File actions
// ============================================================================

- (void)openFileAtPath:(NSString *)filePath
	      windowed:(BOOL)windowed
{
  editorManager = [self editorManager];

  if (filePath != nil)
    {
      [editorManager openEditorForFile:filePath 
			      editable:YES
			      windowed:windowed];
      [editorManager orderFrontEditorForFile:filePath];
    }
}

- (void)openFileAtPath:(NSString *)filePath
{
  [self openFileAtPath: filePath windowed: YES];
}


- (void)openFile
{
  NSArray  *files = nil;
  NSString *filePath = nil;

  files = [fileManager filesOfTypes:nil
			  operation:PCOpenFileOperation
			   multiple:NO
			      title:@"Open File"
			    accView:nil];
  filePath = [files objectAtIndex:0];
  if (filePath)
    {
      [self openFileAtPath:filePath];
    }
}

- (void)newFile
{
  [[PCFileCreator sharedCreator] newFileInProject:activeProject];
}

- (BOOL)saveFile
{
  if (activeProject) 
    {
      return [[[activeProject projectEditor] activeEditor] saveFile];
    }
  else if (editorManager)
    {
      return [[editorManager activeEditor] saveFile];
    }

  return NO;
}

- (BOOL)saveFileAs
{
  NSArray  *files = nil;
  NSString *filePath = nil;

  files = [fileManager filesOfTypes:nil
			  operation:PCSaveFileOperation
			   multiple:NO
			      title:@"Save File As..."
			    accView:nil];
  filePath = [files objectAtIndex:0];

  if (filePath != nil && ![[activeProject projectEditor] saveFileAs:filePath]) 
    {
      NSRunAlertPanel(@"Save File As", 
		      @"Unable to save file as\n%@!",
		      @"OK", nil, nil, filePath);
      return NO;
    }
  else
    {
      // TODO: implement 'Save File As' functionality wrt project and
      // non-project files
/*      PCProject *project = [projectManager activeProject];
      NSString  *categoryPath =  nil;

      categoryPath = [NSString stringWithString:@"/"];
      categoryPath = [categoryPath stringByAppendingPathComponent:
			      [[project rootEntries] objectForKey:PCNonProject]];

      [projectManager closeFile];
      [project addFiles:[NSArray arrayWithObject:newFilePath]
		 forKey:PCNonProject
		 notify:YES];
      [[activeProject projectEditor] openEditorForFile:newFilePath
	      				  categoryPath:categoryPath
	      				      editable:YES
	      				      windowed:NO];*/
    }

  return YES;
}

- (BOOL)saveFileTo
{
  NSArray  *files = nil;
  NSString *filePath = nil;

  files = [fileManager filesOfTypes:nil
			  operation:PCSaveFileOperation
			   multiple:NO
			      title:@"Save File To..."
			    accView:nil];
  filePath = [files objectAtIndex:0];

  if (filePath != nil && ![[activeProject projectEditor] saveFileTo:filePath]) 
    {
      NSRunAlertPanel(@"Save File To", 
		      @"Unable to save file to\n%@!",
		      @"OK", nil, nil, filePath);
      return NO;
    }

  return YES;
}

- (BOOL)revertFileToSaved
{
  return [[activeProject projectEditor] revertFileToSaved];
}

- (BOOL)renameFile
{
  [self showProjectInspector:self];
  [projectInspector selectSectionWithTitle:@"File Attributes"];
  [projectInspector beginFileRename];

  return YES;
}

- (void)closeFile
{
  return [[activeProject projectEditor] closeActiveEditor:self];
}

@end

@implementation PCProjectManager (Subprojects)

- (BOOL)openNewSubprojectPanel
{
//  PCLogInfo(self, @"newSubproject");

  if (!nsPanel)
    {
      if ([NSBundle loadNibNamed:@"NewSubproject" owner:self] == NO)
	{
	  NSRunAlertPanel(@"New Subproject",
			  @"Internal error!"
			  @" Install ProjectCenter again, please.",
			  @"OK", nil, nil);
	  return NO;
	}

      [nsPanel setFrameAutosaveName:@"NewSubproject"];
      if (![nsPanel setFrameUsingName: @"NewSubproject"])
    	{
	  [nsPanel center];
	}

      [nsImage setImage:[NSApp applicationIconImage]];
      [nsTypePB removeAllItems];
      [nsTypePB addItemsWithTitles:
	[[activeProject allowableSubprojectTypes] 
	sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
      [nsTypePB setRefusesFirstResponder:YES];
      [nsTypePB selectItemAtIndex:0];
      [nsCancelButton setRefusesFirstResponder:YES];
      [nsCreateButton setRefusesFirstResponder:YES];
    }
  [projectNameField setStringValue:[activeProject projectName]];
  [nsPanel makeKeyAndOrderFront:nil];
  [nsNameField setStringValue:@""];
  [nsPanel makeFirstResponder:nsNameField];

  [nsPanel setLevel:NSModalPanelWindowLevel];
  [NSApp runModalForWindow:nsPanel];

  return YES;
}

- (void)closeNewSubprojectPanel:(id)sender
{
  [nsPanel orderOut:self];
  [NSApp stopModal];
}

- (void)createSubproject:(id)sender
{
  PCProject *subproject = nil;
  NSString  *spName = [nsNameField stringValue];
  NSString  *spPath = nil;
  NSString  *spType = [nsTypePB titleOfSelectedItem];

  // Check if subproject with entered name already exists.
  if (![activeProject doesAcceptFile:spName forKey:PCSubprojects])
    {
      NSRunAlertPanel(@"New Subproject",
		      @"Subproject with name %@ already exists in project %@",
		      @"OK", nil, nil, spName, [activeProject projectName]);
      return;
    }

  [self closeNewSubprojectPanel:self];

  if (![[spName pathExtension] isEqualToString:@"subproj"])
    {
      spName = [[nsNameField stringValue] 
	stringByAppendingPathExtension:@"subproj"];
    }

  spPath = [[activeProject projectPath] stringByAppendingPathComponent:spName];

  PCLogStatus(self, @"creating subproject with type %@ at path %@",
	      spType, spPath);

  // Create subproject
  subproject = [self createSubprojectOfType:spType path:spPath];

  //  PCLogInfo(self, @"{createSubproject} add to %@", [activeProject projectName]);
  [activeProject addSubproject:subproject];

  return;
}

- (PCProject *)createSubprojectOfType:(NSString *)projectType 
                                 path:(NSString *)aPath
{
  NSString               *className = [projectTypes objectForKey:projectType];
  PCProject<ProjectType> *projectCreator;
  PCProject              *subproject = nil;
  NSString               *subType = nil;

  if ([projectType isEqualToString:@"Application"])
    subType = PCProjectInterfaceGorm;

  projectCreator = [bundleManager objectForClassName:className 
					  bundleType:@"project"
					    protocol:@protocol(ProjectType)];
  if (!(subproject = [projectCreator createProjectAt:aPath withOption:subType])) 
    {
      NSRunAlertPanel(@"New Subproject",
		      @"Internal error!"
		      @" Install ProjectCenter again, please.",
		      @"OK", nil, nil);
      return nil;
    }
  [subproject setIsSubproject:YES];
  [subproject setSuperProject:activeProject];
  [subproject setProjectManager:self];

  return subproject;
}

- (void)controlTextDidChange:(NSNotification *)aNotif
{
  NSString *tfString = nil;
  NSArray  *subprojectList = nil;

  if ([aNotif object] != nsNameField)
    {
      return;
    }
    
  // Check for valid subproject names
  tfString = [nsNameField stringValue];
  subprojectList = [[activeProject projectDict] objectForKey:PCSubprojects];
  if (![subprojectList containsObject:tfString])
    {
      [nsCreateButton setEnabled:YES];
    }
  else
    {
      [nsCreateButton setEnabled:NO];
    }
}

- (BOOL)addSubproject
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *files = nil;
  NSString       *pcProject = nil;
  NSString       *spDir = nil;
  NSDictionary   *spDict = nil;
  NSString       *spName = nil;
  unsigned       i;

  files = [fileManager filesOfTypes:[NSArray arrayWithObjects:@"subproj",nil]
			  operation:PCAddFileOperation
			   multiple:NO
			      title:@"Add Subproject"
			    accView:nil];

  // Validate if it real projects
  for (i = 0; i < [files count]; i++)
    {
      spDir = [files objectAtIndex:i];
      pcProject = [spDir stringByAppendingPathComponent:@"PC.project"];
      if (![[spDir pathExtension] isEqualToString:@"subproj"]
	  || ![fm fileExistsAtPath:pcProject])
	{
	  [files removeObjectAtIndex:i];
	}
    }
  
//  PCLogInfo(self, @"{addSubproject} %@", files);

  if (![fileManager copyFiles:files
                intoDirectory:[activeProject projectPath]])
    {
      return NO;
    }

  for (i = 0; i < [files count]; i++)
    {
      spDir = [files objectAtIndex:i];
      pcProject = [spDir stringByAppendingPathComponent:@"PC.project"];
      spDict = [NSDictionary dictionaryWithContentsOfFile:pcProject];
      spName = [spDict objectForKey:PCProjectName];
      
//      PCLogInfo(self, @"{addSubproject} dir: %@ file: %@", spDir, pcProject);
	
      [activeProject addSubprojectWithName:spName];
    }

  return YES;
}

@end

