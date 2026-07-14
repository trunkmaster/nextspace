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

// TODO: Split into several files with categories
// TODO: Take care of Libraries(gnustep-gui, gnustep-base) 
//       and Non Project Files

#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCDefines.h>

#import <ProjectCenter/PCProjectWindow.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCProjectLoadedFiles.h>

#import <ProjectCenter/PCProjectInspector.h>
#import <ProjectCenter/PCProjectBuilder.h>
#import <ProjectCenter/PCProjectEditor.h>
#import <ProjectCenter/PCProjectLauncher.h>

#import <ProjectCenter/PCLogController.h>

#import <Protocols/CodeEditor.h>

#import "Modules/Preferences/Saving/PCSavingPrefs.h"
#import "Modules/Preferences/Misc/PCMiscPrefs.h"

// #import <AppKit/NSFileWrapper.h>
// #import <Foundation/NSData.h>

NSString 
*PCProjectDictDidChangeNotification = @"PCProjectDictDidChangeNotification";
NSString 
*PCProjectDictDidSaveNotification = @"PCProjectDictDidSaveNotification";
NSString 
*PCProjectBreakpointNotification = @"PCProjectBreakpointNotification";

@implementation PCProject

- (NSString *)description
{
  return [NSString stringWithFormat: @"%@: %@ (%@)", [self className], projectName, projectPath];
}

// ============================================================================
// ==== Init and free
// ============================================================================

- (id)init
{
  if ((self = [super init])) 
    {
      projectDict = [[NSMutableDictionary alloc] init];
      projectPath = [[NSString alloc] init];
      projectName = [[NSString alloc] init];
      buildOptions = [[NSMutableDictionary alloc] init];
      loadedSubprojects = [[NSMutableArray alloc] init];

      projectBuilder = nil;
      projectLauncher = nil;

      isSubproject = NO;
      activeSubproject = nil;
    }

  return self;
}

- (PCProject *)openWithWrapperAt:(NSString *)aPath
{
  BOOL isDir = NO;
  BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath: aPath 
						isDirectory: &isDir];
  if(isDir && exists)
    {
      projectFileWrapper = [[NSFileWrapper alloc] initWithPath: aPath];
      if(projectFileWrapper != nil)
	{
	  NSDictionary *wrappers = [projectFileWrapper fileWrappers];
	  NSData *data = [[wrappers objectForKey: @"PC.project"] regularFileContents];
	  NSData *userData = [[wrappers objectForKey: [NSUserName() stringByAppendingPathExtension: @"project"]]
			       regularFileContents];
	  NSMutableDictionary *dict = [[[[NSString alloc] initWithData: data
							  encoding: NSASCIIStringEncoding] 
					 propertyList] mutableCopy];
	  NSDictionary *udict = [[[NSString alloc] initWithData: userData
						   encoding: NSASCIIStringEncoding] 
				  propertyList];
	  
	  if (udict != nil)
	    [dict addEntriesFromDictionary: udict]; 
	  [udict release];
	  [self assignProjectDict:dict atPath: aPath];
	}
    }
  else
    {
      NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile: aPath];
      
      projectFileWrapper = [[NSFileWrapper alloc] 
			     initDirectoryWithFileWrappers: 
			       [NSMutableDictionary dictionaryWithCapacity: 3]];
      [projectFileWrapper addRegularFileWithContents:
			    [NSData dataWithBytes: [[dict description] cString]
				    length: [[dict description] length]]
			  preferredFilename: @"PC.project"];
      [self assignProjectDict: dict
	    atPath: aPath];
    }
  
  return self;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCProject %@: dealloc", projectName);
#endif
  
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(projectDict);
  RELEASE(projectName);
  RELEASE(projectPath);
  RELEASE(buildOptions);
  RELEASE(loadedSubprojects);

  // Initialized in -setProjectManager: of project and
  // in setSuperProject: of subproject
  RELEASE(projectWindow);
  RELEASE(projectBrowser);
  RELEASE(projectLoadedFiles);
  RELEASE(projectEditor);
  TEST_RELEASE(projectBuilder);
  TEST_RELEASE(projectLauncher);

  if (isSubproject == YES)
    {
      RELEASE(rootProject);
      RELEASE(superProject);
    }

  [super dealloc];
}

- (void)loadPreferences:(NSNotification *)aNotification
{
  id <PCPreferences> prefs = [projectManager prefController];

  rememberWindows = [prefs boolForKey:RememberWindows];
  keepBackup = [prefs boolForKey:KeepBackup];
}

// ============================================================================
// ==== Project handling
// ============================================================================

// --- Dictionary
- (BOOL)assignProjectDict:(NSDictionary *)pDict atPath:(NSString *)pPath
{
  NSString *tempPath = nil;

  NSAssert(pDict,@"No valid project dictionary!");

  PCLogStatus(self, @"assignProjectDict at %@", pPath);

  if (projectDict)
    {
      [projectDict release];
    }
  projectDict = [[NSMutableDictionary alloc] initWithDictionary:pDict];

  // Project path
  if ([[pPath lastPathComponent] isEqualToString:@"PC.project"] ||
      [[[pPath lastPathComponent] pathExtension] isEqualToString:@"pcproj"])
    {
      tempPath = [pPath stringByDeletingLastPathComponent];
      if ([[tempPath pathExtension] isEqualToString:@"pcproj"])
	{
	  tempPath = [tempPath stringByDeletingLastPathComponent];
	}
      [self setProjectPath:tempPath];
    }
  else
    {
      [self setProjectPath:pPath];
    }

  [self setProjectName:[projectDict objectForKey:PCProjectName]];
  [self writeMakefile];
  [self save];

  return YES;
}

- (BOOL)isValidDictionary:(NSDictionary *)aDict
{
  NSString     *_file;
  NSString     *key;
  Class        projClass = [self builderClass];
  NSDictionary *origin;
  NSArray      *keys;
  NSEnumerator *enumerator;

  _file = [[NSBundle bundleForClass:projClass] pathForResource:@"PC"
                                                        ofType:@"project"];

  origin = [NSMutableDictionary dictionaryWithContentsOfFile:_file];
  keys   = [origin allKeys];

  enumerator = [keys objectEnumerator];
  while ((key = [enumerator nextObject]))
    {
      if ([aDict objectForKey:key] == nil)
	{
	  PCLogInfo(self, @"invalid dict entry for key %@", key);
	  return NO;
	}
    }

  return YES;
}

- (void)validateProjectDict
{
  if ([self isValidDictionary:projectDict] == NO)
    {
      [self updateProjectDict];

      NSRunAlertPanel(@"Open Project!", 
		      @"The project file was converted from previous version!\n"
		      @"Please make sure that every project attribute contain"
		      @" valid values!", 
		      @"OK",nil,nil);
    }
}

- (void)setProjectDictObject:(id)object forKey:(NSString *)key notify:(BOOL)yn
{
  id                  currentObject = [projectDict objectForKey:key];
  NSMutableDictionary *notifObject = [NSMutableDictionary dictionary];

  if ([object isKindOfClass:[NSString class]]
      && [currentObject isEqualToString:object])
    {
      return;
    }

  [projectDict setObject:object forKey:key];

  // Send in notification project itself and project dictionary object key 
  // that was changed
  [notifObject setObject:self forKey:@"Project"];
  [notifObject setObject:key forKey:@"Attribute"];

  if (yn == YES)
    {
      [[NSNotificationCenter defaultCenter] 
	postNotificationName:PCProjectDictDidChangeNotification
                      object:notifObject];
    }
}

- (void)updateProjectDict
{
  Class        projClass = [self builderClass];
  NSString     *_file = nil;
  NSString     *key = nil;
  NSDictionary *origin = nil;
  NSArray      *keys = nil;
  NSEnumerator *enumerator = nil;

  _file = [[NSBundle bundleForClass:projClass] pathForResource:@"PC"
                                                        ofType:@"project"];

  origin = [NSMutableDictionary dictionaryWithContentsOfFile:_file];
  keys   = [origin allKeys];

  enumerator = [keys objectEnumerator];
  while ((key = [enumerator nextObject]))
    {
      if ([projectDict objectForKey:key] == nil)
	{
	  // Doesn't call setProjectDictObject:forKey for opimization
	  [projectDict setObject:[origin objectForKey:key] forKey:key];
	}
    }

  [self save];
}

- (NSDictionary *)projectDict
{
  return (NSDictionary *)projectDict;
}

// --- Name and path
- (NSString *)projectName
{
  return projectName;
}

- (void)setProjectName:(NSString *)aName
{
  if (projectName)
    {
      [projectName autorelease];
    }
  projectName = [aName copy];
//  [projectWindow setFileIconTitle:projectName];
}

- (NSString *)projectPath
{
    return projectPath;
}

- (void)setProjectPath:(NSString *)aPath
{
  if (projectPath)
    {
      [projectPath autorelease];
    }
  projectPath = [aPath copy];
}

// --- Saving
- (BOOL)isProjectChanged
{
  return [projectWindow isDocumentEdited];
}

// Saves backup file
- (BOOL)writeMakefile
{
  NSString *mf = [projectPath stringByAppendingPathComponent:@"GNUmakefile"];
  NSString *bu = [projectPath stringByAppendingPathComponent:@"GNUmakefile~"];
  NSFileManager *fm = [NSFileManager defaultManager];

  if ([fm isReadableFileAtPath:mf])
    {
      if ([fm isWritableFileAtPath:bu])
	{
	  [fm removeFileAtPath:bu handler:nil];
	}

      if (![fm copyPath:mf toPath:bu handler:nil])
	{
	  NSRunAlertPanel(@"Attention!",
			  @"Could not keep a backup of the GNUMakefile!",
			  @"OK",nil,nil);
	  return NO;
	}
    }

  return YES;
}

- (BOOL)saveProjectWindowsAndPanels
{
  NSMutableDictionary *windows = [NSMutableDictionary dictionary];
  NSString            *projectFile = nil;
  NSMutableDictionary *projectFileDict = nil;

  projectFile = [NSUserName() stringByAppendingPathExtension:@"project"];
  projectFileDict = [[NSMutableDictionary alloc] initWithCapacity:4];

  // Project Window
  [windows setObject:[projectWindow stringWithSavedFrame]
              forKey:@"ProjectWindow"];
  if ([projectWindow isToolbarVisible] == YES)
    {
      [windows setObject:@"YES"
	          forKey:@"ShowToolbar"];
    }
  else
    {
      [windows setObject:@"NO"
                  forKey:@"ShowToolbar"];
    }

  // ProjectBrowser
  [windows setObject:NSStringFromRect([[projectBrowser view] frame])
              forKey:@"ProjectBrowser"];

  // Write to file and exit if preferences wasn't set to save panels
  if (!rememberWindows)
    {
      [projectFileDict setObject:windows forKey:PCWindows];
      [projectFileDict writeToFile:projectFile atomically:YES];
      [projectFileDict release];
      return YES;
    }

  // Project Build
  if (projectBuilder && [[projectManager buildPanel] isVisible])
    {
      [windows setObject:[[projectManager buildPanel] stringWithSavedFrame]
	          forKey:@"ProjectBuild"];
    }
  else
    {
      [windows removeObjectForKey:@"ProjectBuild"];
    }

  // Project Launch
  if (projectLauncher && [[projectManager launchPanel] isVisible])
    {
      [windows setObject:[[projectManager launchPanel] stringWithSavedFrame]
                  forKey:@"ProjectLaunch"];
    }
  else
    {
      [windows removeObjectForKey:@"ProjectLaunch"];
    }

  // Loaded Files
  if (projectLoadedFiles && [[projectManager loadedFilesPanel] isVisible])
    {
      [windows 
	setObject:[[projectManager loadedFilesPanel] stringWithSavedFrame]
           forKey:@"LoadedFiles"];
    }
  else
    {
      [windows removeObjectForKey:@"LoadedFiles"];
    }

  // Set to project dict for case if project changed
  // Don't notify about projectDict changes
  [projectDict setObject:windows forKey:PCWindows];

  // Now save it directly to username.project file
  [projectFileDict setObject:windows forKey:PCWindows];

  [projectFileDict setObject: [[NSCalendarDate date] description]
	       forKey: PCLastEditing];

  // add the file and write the wrapper.
  [projectFileWrapper addRegularFileWithContents:
			[NSData dataWithBytes: [[projectFileDict description] cString]
				length: [[projectFileDict description] length]]
		      preferredFilename: projectFile];
  [projectFileWrapper writeToFile: wrapperPath 
		      atomically: YES 
		      updateFilenames: YES];
  
  // release
  [projectFileDict release];

  return YES;
}

- (BOOL)save
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSUInteger      spCount = [loadedSubprojects count];
  int            i;
  NSString *wrapperFile;
  NSString *file = @"PC.project";
  NSString *backup;
  NSMutableDictionary *dict = [projectDict mutableCopy];
  NSData *dictData = nil;

  // remove key..
  [dict removeObjectForKey: PCWindows];
  [dict removeObjectForKey: PCLastEditing];

  // initialize the wrappers..
  wrapperFile = [projectName stringByAppendingPathExtension: @"pcproj"];
  projectFileWrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers: 
						[NSMutableDictionary dictionaryWithCapacity: 3]];  
  wrapperPath = [projectPath stringByAppendingPathComponent: wrapperFile];
  backup = [wrapperPath stringByAppendingPathExtension:@"backup"];

  // load subprojects...
  for (i = 0; i < spCount; i++)
    {
      [[loadedSubprojects objectAtIndex:i] save];
    }

  // Remove backup file if exists
  if ([fm fileExistsAtPath:backup] && ![fm removeFileAtPath:backup handler:nil])
    {
      NSRunAlertPanel(@"Save Project",
		      @"Couldn't remove the old project backup file",
		      @"OK",nil,nil);
      [dict release];
      return NO;
    }

  // Save backup
  if ((keepBackup == YES) && [fm isReadableFileAtPath: wrapperPath]) 
    {
      if ([fm copyPath: wrapperPath 
	      toPath: backup 
	      handler:nil] == NO)
	{
	  NSRunAlertPanel(@"Save Project",
			  @"Couldn't save project backup file",
			  @"OK",nil,nil);
	  return NO;
	}
    }

  // Save project file
  dictData = [NSPropertyListSerialization dataFromPropertyList: dict
					  format: NSPropertyListOpenStepFormat
					  errorDescription: NULL];
  [projectFileWrapper addRegularFileWithContents: dictData
		      preferredFilename: file];
  if ([projectFileWrapper
	writeToFile:wrapperPath
	atomically:YES 
	updateFilenames: YES] == NO)
    {
      NSRunAlertPanel(@"Save Project",
		      @"Couldn't save project file",
		      @"OK",nil,nil,projectName);
      return NO;
    }

  [[NSNotificationCenter defaultCenter] 
    postNotificationName:PCProjectDictDidSaveNotification 
                  object:self];

  // Save GNUmakefile
  if ([self writeMakefile] == NO)
    {
      NSRunAlertPanel(@"Save Project",
		      @"Couldn't write GNUmakefile",
		      @"OK",nil,nil);
      return NO;
    }

  return YES;
}

- (BOOL)close:(id)sender
{
  PCLogInfo(self, @"Closing %@ project", projectName);
  
  // Save visible windows and panels positions to project dictionary
  if (isSubproject == NO)
    {
      [self saveProjectWindowsAndPanels];
      [projectBrowser setPath:@"/"];
      [projectManager setActiveProject:self];
    }
  
  // Project files (GNUmakefile, PC.project etc.)
  if (isSubproject == NO && [self isProjectChanged] == YES)
    {
      int ret;

      ret = NSRunAlertPanel(@"Close Project",
			    @"Project or subprojects are modified",
			    @"Save and Close",@"Don't save",@"Stop");
      switch (ret)
	{
	case NSAlertDefaultReturn:
	  if ([self save] == NO)
	    {
	      return NO;
	    }
	  break;
	  
	case NSAlertAlternateReturn:
	  break;

	case NSAlertOtherReturn:
	  return NO;
	  break;
	}
    }
    
  // Close subprojects
  while ([loadedSubprojects count])
    {
      [(PCProject *)[loadedSubprojects objectAtIndex:0] close:self];
      // We should release subproject here, because it retains us
      // and we never reach -dealloc in other case.
      [loadedSubprojects removeObjectAtIndex:0];
    }

  if (isSubproject == YES)
    {
      [projectManager closeProject:self];
      return YES;
    }

  // Editors
  // "Cancel" button on "Save Edited Files" panel selected
  if ([projectEditor closeAllEditors] == NO)
    {
      return NO;
    }

  // Project window
  if (sender != projectWindow)
    {
      [projectWindow close];
    }

  // Remove self from loaded projects
  [projectManager closeProject:self];

  return YES;
}

// ============================================================================
// ==== Accessory methods
// ============================================================================

- (PCProjectManager *)projectManager
{
  return projectManager;
}

- (void)setProjectManager:(PCProjectManager *)aManager
{
  projectManager = aManager;

  if (isSubproject)
    {
      return;
    }

  if (!projectBrowser)
    {
      projectBrowser = [[PCProjectBrowser alloc] initWithProject:self];
    }

  if (!projectLoadedFiles)
    {
      projectLoadedFiles = [[PCProjectLoadedFiles alloc] initWithProject:self];
    }

  if (!projectEditor)
    {
      projectEditor = [[PCProjectEditor alloc] init];
      [projectEditor setProject:self];
      [projectEditor setProjectManager:aManager];
    }

  if (!projectWindow)
    {
      projectWindow = [[PCProjectWindow alloc] initWithProject:self];
    }

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(loadPreferences:)
	   name:PCPreferencesDidChangeNotification
	 object:nil];
  [self loadPreferences:nil];
}

- (PCProjectWindow *)projectWindow
{
  return projectWindow;
}

- (PCProjectBrowser *)projectBrowser
{
  return projectBrowser;
}

- (PCProjectLoadedFiles *)projectLoadedFiles
{
  if (!projectLoadedFiles && !isSubproject)
    {
      projectLoadedFiles = [[PCProjectLoadedFiles alloc] initWithProject:self];
    }

  return projectLoadedFiles;
}

- (PCProjectBuilder *)projectBuilder
{
  if (!projectBuilder && !isSubproject)
    {
      projectBuilder = [[PCProjectBuilder alloc] initWithProject:self];
    }

  return projectBuilder;
}

- (PCProjectLauncher *)projectLauncher
{
  if (!projectLauncher && !isSubproject)
    {
      projectLauncher = [[PCProjectLauncher alloc] initWithProject:self];
    }

  return projectLauncher;
}

- (PCProjectEditor *)projectEditor
{
  return projectEditor;
}

// ============================================================================
// ==== Bundle methods
// ============================================================================

//--- Project Inspector's "Project Attributes"
- (NSView *)projectAttributesView
{
  return nil;
}

//--- Properties from Info.table
- (NSDictionary *)projectBundleInfoTable
{
  NSString *_file;
  Class    class = [self builderClass];

  _file = [[NSBundle bundleForClass:class] pathForResource:@"Info"
			     ofType:@"table"];
  return [NSMutableDictionary dictionaryWithContentsOfFile:_file];
}

- (NSString *)projectTypeName
{
  return [[self projectBundleInfoTable] objectForKey:@"Name"];
}

- (Class)builderClass
{
  return [[self projectBundleInfoTable] objectForKey:@"BuilderClassName"];
}

- (NSString *)projectDescription
{
  return [[self projectBundleInfoTable] objectForKey:@"Description"];
}

- (BOOL)isExecutable
{
  if ([[[self projectBundleInfoTable] 
      objectForKey:@"Executable"] isEqualToString:@"YES"])
    {
      return YES;
    }

  return NO;
}


- (NSArray *)buildTargets
{
  NSArray *buildTargets = [projectDict objectForKey:PCBuilderTargets];

  if (!buildTargets)
    {
      buildTargets = 
	[[self projectBundleInfoTable] objectForKey:@"BuildTargets"];
      [self setProjectDictObject:buildTargets
			  forKey:PCBuilderTargets
			  notify:NO];
    }

  return buildTargets;
}

- (NSArray *)sourceFileKeys
{
  return [[self projectBundleInfoTable] objectForKey:@"SourceFileKeys"];
}

- (NSArray *)resourceFileKeys
{
  return [[self projectBundleInfoTable] objectForKey:@"ResourceFileKeys"];
}

- (NSArray *)otherKeys
{
  return [[self projectBundleInfoTable] objectForKey:@"OtherFileKeys"];
}

- (NSArray *)allowableSubprojectTypes
{
  return [[self projectBundleInfoTable] 
    objectForKey:@"AllowableSubprojectTypes"];
}

- (NSArray *)localizableKeys
{
  return [[self projectBundleInfoTable] objectForKey:@"LocalizableCategories"];
}

//--- Public headers (for Library, Framework)
- (BOOL)canHavePublicHeaders
{
  if ([[[self projectBundleInfoTable] 
      objectForKey:@"CanHavePublicHeaders"] isEqualToString:@"YES"])
    {
      return YES;
    }

  return NO;
}

- (NSArray *)publicHeaders
{
  if ([self canHavePublicHeaders] == YES)
    {
      return [projectDict objectForKey:PCPublicHeaders];
    }
    
  return nil;
}

- (void)setHeaderFile:(NSString *)file public:(BOOL)yn
{
  NSMutableArray *publicHeaders = nil;

  if ((yn == YES && [[self publicHeaders] containsObject:file])
      || [self canHavePublicHeaders] == NO)
    {
      return;
    }

  publicHeaders = [[projectDict objectForKey:PCPublicHeaders] copy];

  if (yn)
    {
      [publicHeaders addObject:file];
    }
  else if ([publicHeaders count] > 0 && [publicHeaders containsObject:file])
    {
      [publicHeaders removeObject:file];
    }

  [self setProjectDictObject:publicHeaders 
		      forKey:PCPublicHeaders 
		      notify:YES];

  [publicHeaders release];
}

//--- Localization
- (NSArray *)localizedResources
{
  return [projectDict objectForKey:PCLocalizedResources];
}

- (NSString *)resourceDirForLanguage:(NSString *)language
{
  NSString *dir = nil;

  dir = [projectPath stringByAppendingPathComponent:language];
  dir = [dir stringByAppendingPathExtension:@"lproj"];

  return dir;
}

- (void)setResourceFile:(NSString *)file localizable:(BOOL)yn
{
  PCFileManager  *fileManager = [projectManager fileManager];
  NSArray        *userLanguages = nil;
  NSEnumerator   *enumerator = nil;
  NSString       *currentLanguage = nil;
  NSString       *resPath = nil;
  NSString       *resFilePath = nil;
  NSString       *langPath = nil;
  NSMutableArray *localizedResources = nil;

  if (yn == YES && [[self localizedResources] containsObject:file])
    {
      return;
    }
    
  resPath = [projectPath stringByAppendingPathComponent:@"Resources"];
  resFilePath = [resPath stringByAppendingPathComponent:file];
  localizedResources = [[self localizedResources] mutableCopy];

  userLanguages = [projectDict objectForKey:PCUserLanguages];
  enumerator = [userLanguages objectEnumerator];
  while ((currentLanguage = [enumerator nextObject]))
    {
      langPath = [self resourceDirForLanguage:currentLanguage];
      if (yn == YES)
	{
	  [fileManager copyFile:resFilePath intoDirectory:langPath];
	}
      else
	{
	  if ([currentLanguage isEqualToString:@"English"])
	    {
	      [fileManager copyFile:file 
		      fromDirectory:langPath
		      intoDirectory:resPath];
	    }
	  [fileManager removeFile:file 
		    fromDirectory:langPath
		removeDirsIfEmpty:YES];
	}
    }

  if (yn == YES)
    {
      [fileManager removeFileAtPath:resFilePath removeDirsIfEmpty:YES];
      [localizedResources addObject:file];
      [self setProjectDictObject:localizedResources
			  forKey:PCLocalizedResources
			  notify:YES];
    }
  else if ([localizedResources count] > 0 
	   && [localizedResources containsObject:file])
    {
      [localizedResources removeObject:file];
      [self setProjectDictObject:localizedResources
			  forKey:PCLocalizedResources
			  notify:YES];
    }

  [localizedResources release];
}
//---

// May files will be added to category?
- (BOOL)isEditableCategory:(NSString *)category
{
  NSString *key = [self keyForCategory:category];

  if ([key isEqualToString:PCSupportingFiles])
    {
      return NO;
    }

  return YES;
}

// May file will be edited in PC editor?
- (BOOL)isEditableFile:(NSString *)filePath
{
  NSString *key = [self keyForCategory:[projectBrowser nameOfSelectedCategory]];
  NSString *fileName = [filePath lastPathComponent];
  NSString *extension = [filePath pathExtension];

  if ([key isEqualToString:PCSupportingFiles]) 
    {
      if ([fileName isEqualToString:@"GNUmakefile"] ||
	  [extension isEqualToString:@"plist"])
	{
	  return NO;
	}
    }
    
  return YES;
}

- (NSArray *)fileTypesForCategoryKey:(NSString *)key 
{
  if ([key isEqualToString:PCClasses])
    {
      return [NSArray arrayWithObjects:@"m",@"mm",nil];
    }
  else if ([key isEqualToString:PCHeaders])
    {
      return [NSArray arrayWithObjects:@"h",nil];
    }
  else if ([key isEqualToString:PCOtherSources])
    {
      return [NSArray arrayWithObjects:@"c",@"C",@"m",nil];
    }
  else if ([key isEqualToString:PCInterfaces])
    {
      return [NSArray arrayWithObjects:@"gmodel",@"gorm", @"gsmarkup", @"nib", nil];
    }
  else if ([key isEqualToString:PCImages])
    {
      return [NSImage imageFileTypes];
    }
  else if ([key isEqualToString:PCSubprojects])
    {
      return [NSArray arrayWithObjects:@"subproj",nil];
    }
  else if ([key isEqualToString:PCLibraries])
    {
      return [NSArray arrayWithObjects:@"so",@"a",@"lib",@"dylib",nil];
    }

  return nil;
}

- (NSString *)categoryKeyForFileType:(NSString *)type
{
  NSEnumerator *keysEnum = [rootKeys objectEnumerator];
  NSString     *key = nil;

  while ((key = [keysEnum nextObject]))
    {
      if ([[self fileTypesForCategoryKey:key] containsObject:type])
	{
	  return key;
	}
    }

  return nil;
}

- (NSString *)dirForCategoryKey:(NSString *)key 
{
  if ([[self resourceFileKeys] containsObject:key])
    {
      return [projectPath stringByAppendingPathComponent:@"Resources"];
    }

  return projectPath;
}

- (NSString *)localizedDirForCategoryKey:(NSString *)key 
{
  NSString *language = nil;

  if ([[self resourceFileKeys] containsObject:key])
    {
      language = [projectDict objectForKey:PCLanguage];
      language = [language stringByAppendingPathExtension:@"lproj"];
      return [projectPath stringByAppendingPathComponent:language];
    }

  return projectPath;
}

- (NSString *)complementaryTypeForType:(NSString *)type
{
  if ([type isEqualToString:@"m"] || [type isEqualToString:@"c"])
    {
      return @"h";
    }
  else if ([type isEqualToString:@"h"])
    {
      return @"m";
    }

  return nil;
}

// ============================================================================
// ==== File Handling
// ============================================================================

- (NSString *)pathForFile:(NSString *)file forKey:(NSString *)key
{
  NSString *resPath = nil;

  if ([[self resourceFileKeys] containsObject:key])
    {
      if ([[projectDict objectForKey:PCLocalizedResources] containsObject:file])
	{
	  resPath = [self localizedDirForCategoryKey:key];
	  return [resPath stringByAppendingPathComponent:file];
	}
      else
	{
	  resPath = [self dirForCategoryKey:key];
	  return [resPath stringByAppendingPathComponent:file];
	}
    }
    
  return [projectPath stringByAppendingPathComponent:file];
}

- (NSString *)projectFileFromFile:(NSString *)file forKey:(NSString *)type
{
  NSString        *projectFile = nil;
  NSString        *_path = nil;
  NSMutableArray  *_pathComponents = nil;
  NSString        *_file = nil;
  NSArray         *subprojects = [projectDict objectForKey:PCSubprojects];
  NSRange         pathRange;
  NSString        *spDir = nil;

  _path = [file stringByDeletingLastPathComponent];
  _pathComponents = [[_path pathComponents] mutableCopy];
  _file = [file lastPathComponent];

  // Remove "lib" prefix from library name
  if ([type isEqualToString:PCLibraries])
    {
      _file = [_file stringByDeletingPathExtension];
      _file = [_file substringFromIndex:3];
    }

  pathRange = [_path rangeOfString:projectPath];

  // File is located in project's directory tree
  if (pathRange.length && ![type isEqualToString:PCLibraries])
    {
      unsigned i;

      for (i = 0; i < [subprojects count]; i++)
	{
	  spDir = [[subprojects objectAtIndex:i] 
	    stringByAppendingPathExtension:@"subproj"];
	  if ([_pathComponents containsObject:spDir])
	    {
	      break;
	    }
	  spDir = nil;
	}
    }

  if (spDir != nil)
    {
      while (![[_pathComponents objectAtIndex:0] isEqualToString:spDir])
	{
	  [_pathComponents removeObjectAtIndex:0];
	}
    }
  else
    {
      [_pathComponents removeAllObjects];
    }
  
  // Construct project file name
  if ([_pathComponents count])
    {
      projectFile = [NSString pathWithComponents:_pathComponents];
      projectFile = [projectFile stringByAppendingPathComponent:_file];
    }
  else
    {
      projectFile = [NSString stringWithString:_file];
    }

  RELEASE(_pathComponents);
    
  return projectFile;
}

- (BOOL)doesAcceptFile:(NSString *)file forKey:(NSString *)type
{
  NSString     *pFile = [self projectFileFromFile:file forKey:type];
  NSArray      *sourceKeys = [self sourceFileKeys];
  NSArray      *resourceKeys = [self resourceFileKeys];
  NSEnumerator *keyEnum = nil;
  NSString     *key = nil;
  NSArray      *projectFiles = nil;

  if ([sourceKeys containsObject:type])
    {
      keyEnum = [sourceKeys objectEnumerator];
    }
  else if ([resourceKeys containsObject:type])
    {
      keyEnum = [resourceKeys objectEnumerator];
    }
  else
    {
      return YES;
    }

  while ((key = [keyEnum nextObject]))
    {
      projectFiles = [projectDict objectForKey:key];
      if ([projectFiles containsObject:pFile])
	{
	  return NO;
	}
    }

  return YES;
}

- (BOOL)addAndCopyFiles:(NSArray *)files forKey:(NSString *)key
{
  NSEnumerator   *fileEnum = [files objectEnumerator];
  NSString       *file = nil;
  NSMutableArray *fileList = [[files mutableCopy] autorelease];
  NSString       *complementaryType = nil;
  NSString       *complementaryKey = nil;
  NSString       *complementaryDir = nil;
  NSMutableArray *complementaryFiles = [NSMutableArray array];
  PCFileManager  *fileManager = [projectManager fileManager];
  NSString       *directory = [self dirForCategoryKey:key];

  complementaryType = [self 
    complementaryTypeForType:[[files objectAtIndex:0] pathExtension]];
  if (complementaryType)
    {
      complementaryKey = [self categoryKeyForFileType:complementaryType];
      complementaryDir = [self dirForCategoryKey:complementaryKey];
    }
    
//  PCLogInfo(self, @"{%@} {addAndCopyFiles} %@", projectName, fileList);

  // Validate files
  while ((file = [fileEnum nextObject]))
    {
      if (![self doesAcceptFile:file forKey:key])
	{
	  [fileList removeObject:file];
	}
      else if (complementaryType != nil)
	{
	  NSString *compFile = nil;

	  compFile = [[file stringByDeletingPathExtension] 
	    stringByAppendingPathExtension:complementaryType];
	  if ([[NSFileManager defaultManager] fileExistsAtPath:compFile]
	      && [self doesAcceptFile:compFile forKey:complementaryKey])
	    {
	      [complementaryFiles addObject:compFile];
	    }
	}
    }

//  PCLogInfo(self, @"{addAndCopyFiles} %@", fileList);

  // Copy files
  if (![key isEqualToString:PCLibraries]) // Don't copy libraries
    {
      if (![fileManager copyFiles:fileList intoDirectory:directory])
	{
	  NSRunAlertPanel(@"Add File(s)",
			  @"Error adding files %@ to project %@!",
			  @"OK", nil, nil, fileList, projectName);
	  return NO;
	}

//      PCLogInfo(self, @"Complementary files: %@", complementaryFiles);
      // Complementaries
      if (![fileManager copyFiles:complementaryFiles 
	            intoDirectory:complementaryDir])
	{
	  NSRunAlertPanel(@"Add File(s)",
			  @"Error adding files %@ to project %@!",
			  @"OK", nil, nil, complementaryFiles, projectName);
	  return NO;
	}
    }

  if ([complementaryFiles count] > 0)
    {
      [self addFiles:complementaryFiles forKey:complementaryKey notify:NO];
    }
  // Add files to project
  [self addFiles:fileList forKey:key notify:YES];

  return YES;
}

- (void)addFiles:(NSArray *)files forKey:(NSString *)type notify:(BOOL)yn
{
  NSEnumerator   *enumerator = nil;
  NSString       *file = nil;
  NSString       *pFile = nil;
  NSArray        *types = [projectDict objectForKey:type];
  NSMutableArray *projectFiles = [NSMutableArray arrayWithArray:types];

  if ([type isEqualToString:PCLibraries])
    {
      NSMutableArray *searchLibs = [NSMutableArray arrayWithCapacity:1];
      NSString       *path = nil;

      path = [[files objectAtIndex:0] stringByDeletingLastPathComponent];
      [searchLibs setArray:[projectDict objectForKey:PCSearchLibs]];
      [searchLibs addObject:path];
      [self setProjectDictObject:searchLibs forKey:PCSearchLibs notify:yn];
    }

  enumerator = [files objectEnumerator];
  while ((file = [enumerator nextObject]))
    {
      pFile = [self projectFileFromFile:file forKey:type];
      [projectFiles addObject:pFile];
    }

  [self setProjectDictObject:projectFiles forKey:type notify:yn];
}

- (BOOL)removeFiles:(NSArray *)files forKey:(NSString *)key notify:(BOOL)yn
{
  NSEnumerator   *enumerator = nil;
  NSString       *filePath = nil;
  NSString       *file = nil;
  NSMutableArray *projectFiles = [[NSMutableArray alloc] initWithCapacity:1];
  NSArray        *localizedFiles = nil;

  // Check if file localizable. If yes, make it not localizable so file moved
  // to Resources dir.
  localizedFiles = [[self localizedResources] copy];
  enumerator = [files objectEnumerator];
  while ((file = [enumerator nextObject]))
    {
      if ([localizedFiles containsObject:file])
	{
	  [self setResourceFile:file localizable:NO];
	}
    }
  [localizedFiles release];

  // Remove files from project
//  projectFiles = [NSMutableArray arrayWithArray:[projectDict objectForKey:key]];
  [projectFiles setArray:[projectDict objectForKey:key]];
  NSLog(@"--- projectFiles: %@ forKey: %@", projectFiles, key);
  enumerator = [files objectEnumerator];
  while ((file = [enumerator nextObject]))
    {
      if ([key isEqualToString:PCSubprojects])
	{
	  NSLog(@"Removing subproject %@", file);
	  [self removeSubprojectWithName:file];
	}
      NSLog(@"Project %@ remove file %@", projectName, file);
      [projectFiles removeObject:file];

      // Close editor
      filePath = [projectPath stringByAppendingPathComponent:file];
      [projectEditor closeEditorForFile:filePath];
    }

  NSLog(@"projectFiles: %@", projectFiles);

  [self setProjectDictObject:projectFiles forKey:key notify:yn];

  [projectFiles release];

  return YES;
}

- (BOOL)renameFile:(NSString *)fromFile toFile:(NSString *)toFile
{
  NSFileManager       *fm = [NSFileManager defaultManager];
  NSString            *selectedCategory = nil;
  NSString            *selectedCategoryKey = nil;
  NSString            *fromPath = nil;
  NSString            *toPath = nil;
  NSMutableDictionary *_pDict = nil;
  NSString            *_file = nil;
  NSMutableArray      *_array = nil;
  BOOL                saveToFile = NO;
  int                 index = 0;
  id<CodeEditor>      _editor;
  NSString            *_editorPath = nil;
  NSMutableString     *_editorCategory = nil;
  
  selectedCategory = [projectBrowser nameOfSelectedCategory];
  selectedCategoryKey = [self keyForCategory:selectedCategory];

  fromPath = [[self dirForCategoryKey:selectedCategoryKey]
    stringByAppendingPathComponent:fromFile];
  toPath = [[self dirForCategoryKey:selectedCategoryKey]
    stringByAppendingPathComponent:toFile];

  if ([fm fileExistsAtPath:toPath])
    {
      switch (NSRunAlertPanel(@"Rename file",
       			      @"File \"%@\" already exist",
			      @"Overwrite file",@"Stop",nil, toFile))
	{
	case NSAlertDefaultReturn: // Overwrite
	  if ([fm removeFileAtPath:toPath handler:nil] == NO)
	    {
	      return NO;
	    }
	  break;
	case NSAlertAlternateReturn: // Stop rename
	  return NO;
	  break;

	}
    }

/*  PCLogInfo(self, @"{%@} move %@ to %@ category: %@", 
	    projectName, fromPath, toPath, selectedCategory);*/

  if ([[self localizedResources] containsObject:fromFile])
    {// Rename file in language dirs
      NSArray        *userLanguages;
      NSEnumerator   *enumerator;
      NSString       *lang;
      NSString       *langPath;
      NSMutableArray *localizedResources;

      localizedResources = 
	[NSMutableArray arrayWithArray:[self localizedResources]];
      userLanguages = [projectDict objectForKey:PCUserLanguages];
      enumerator = [userLanguages objectEnumerator];
      while ((lang = [enumerator nextObject]))
	{
	  langPath = [self resourceDirForLanguage:lang];
	  fromPath = [langPath stringByAppendingPathComponent:fromFile];
	  toPath = [langPath stringByAppendingPathComponent:toFile];
	  if ([fm movePath:fromPath toPath:toPath handler:nil] == NO)
	    {
	      return NO;
	    }
	}
      index = [localizedResources indexOfObject:fromFile];
      [localizedResources replaceObjectAtIndex:index withObject:toFile];
      [projectDict setObject:localizedResources
		      forKey:PCLocalizedResources];
    }
  else if ([fm movePath:fromPath toPath:toPath handler:nil] == NO)
    {
      return NO;
    }

  // TODO: Rewrite this when file operations history will be implemented
  if ([self isProjectChanged])
    {
      // Project already has changes
      saveToFile = YES;
    }

  // Make changes to projectDict
  _array = [projectDict objectForKey:selectedCategoryKey];
  index = [_array indexOfObject:fromFile];
  [_array replaceObjectAtIndex:index withObject:toFile];

  // Put only this change to project file, leaving 
  // other changes in memory(projectDict)
  if (saveToFile)
    {
      _file = [projectPath stringByAppendingPathComponent:@"PC.project"];
      _pDict = [NSMutableDictionary dictionaryWithContentsOfFile:_file];
      _array = [_pDict objectForKey:selectedCategoryKey];
      [_array removeObject:fromFile];
      [_array addObject:toFile];
      [_pDict setObject:_array forKey:selectedCategoryKey];
      [_pDict writeToFile:_file atomically:YES];
    }
  else
    {
      [self save];
    }

  // Handle editor(if any) information
  _editor = [projectEditor activeEditor];
  if (_editor)
    {
      NSRange range;

      _editorPath = [_editor path];
      _editorPath = [_editorPath stringByDeletingLastPathComponent];
      _editorPath = [_editorPath stringByAppendingPathComponent:toFile];
      [_editor setPath:_editorPath];

      _editorCategory = [[_editor categoryPath] mutableCopy];
      range = [_editorCategory rangeOfString:fromFile];
      if (range.location != NSNotFound)
	{
	  [_editorCategory replaceCharactersInRange:range withString:toFile];

	  [_editor setCategoryPath:_editorCategory];
	  [projectBrowser setPath:_editorCategory];
	}
      RELEASE(_editorCategory);
    }
  else
    {
      // Set browser path to new file name
      [projectBrowser reloadLastColumnAndSelectFile:toFile];

    }

  return YES;
}

// ============================================================================
// ==== Subprojects
// ============================================================================

- (NSArray *)loadedSubprojects
{
  return loadedSubprojects;
}

- (PCProject *)activeSubproject
{
  return activeSubproject;
}

- (BOOL)isSubproject
{
  return isSubproject;
}

- (void)setIsSubproject:(BOOL)yn
{
  isSubproject = yn;
}

- (PCProject *)superProject
{
  return superProject;
}

- (void)setSuperProject:(PCProject *)project
{
  if (superProject != nil)
    {
      return;
    }

  ASSIGN(superProject, project);

  // Assigning releases left part
  ASSIGN(projectBrowser,[project projectBrowser]);
  ASSIGN(projectLoadedFiles,[project projectLoadedFiles]);
  ASSIGN(projectEditor,[project projectEditor]);
  ASSIGN(projectWindow,[project projectWindow]);
}

- (PCProject *)subprojectWithName:(NSString *)name
{
  int       count = [loadedSubprojects count];
  int       i;
  PCProject *sp = nil;
  NSString  *spName = nil;
  NSString  *spPath = nil;

  // Subproject in project but not loaded
  if ([[projectDict objectForKey:PCSubprojects] containsObject:name])
    {
/*      PCLogInfo(self, @"{%@}Searching for loaded subproject: %@",
		projectName, name);*/
      // Search for subproject with name among loaded subprojects 
      for (i = 0; i < count; i++)
	{
	  sp = [loadedSubprojects objectAtIndex:i];
	  spName = [sp projectName];
	  if ([spName isEqualToString:name])
	    {
	      break;
	    }
	  sp = nil;
	}

      // Subproject not found in array, load it
      if (sp == nil)
	{
	  spPath = [projectPath stringByAppendingPathComponent:name];
	  spPath = [spPath stringByAppendingPathExtension:@"subproj"];

	  sp = [projectManager openProjectAt:spPath makeActive:NO];
	  if (sp)
	    {
	      [sp setIsSubproject:YES];
	      [sp setSuperProject:self];
	      [sp setProjectManager:projectManager];
	      [loadedSubprojects addObject:sp];
	    }
	}
    }
  
  return sp;
}

- (void)addSubproject:(PCProject *)aSubproject
{
  NSMutableArray *_subprojects;

  if (!aSubproject)
    {
      return;
    }

  _subprojects = [NSMutableArray 
    arrayWithArray:[projectDict objectForKey:PCSubprojects]];

  [_subprojects addObject:[aSubproject projectName]];
  [loadedSubprojects addObject:aSubproject];
  [self setProjectDictObject:_subprojects forKey:PCSubprojects notify:YES];
}

- (void)addSubprojectWithName:(NSString *)name
{
  NSMutableArray *_subprojects = nil;

  if (!name)
    {
      return;
    }

  _subprojects = [NSMutableArray 
    arrayWithArray:[projectDict objectForKey:PCSubprojects]];
  [_subprojects addObject:name];
  [self setProjectDictObject:_subprojects forKey:PCSubprojects notify:YES];
}

- (BOOL)removeSubprojectWithName:(NSString *)subprojectName
{
  NSString *extension = [subprojectName pathExtension];
  NSString *sName = subprojectName;
  
  if (extension && [extension isEqualToString:@"subproj"])
    {
      sName = [subprojectName stringByDeletingPathExtension];
    }

  return [self removeSubproject:[self subprojectWithName:sName]];
}

- (BOOL)removeSubproject:(PCProject *)aSubproject
{
  if ([loadedSubprojects containsObject:aSubproject])
    {
      [aSubproject close:self];
      [loadedSubprojects removeObject:aSubproject];
    }

  return YES;
}

@end

@implementation PCProject (ProjectBrowser)

// e.g. CLASS_FILES
- (NSArray *)rootKeys
{
  if (activeSubproject)
    {
      return [activeSubproject rootKeys];
    }

  return rootKeys;
}

// e.g. Classes
- (NSArray *)rootCategories
{
  if (activeSubproject)
    {
      return [activeSubproject rootCategories];
    }

  return rootCategories;
}

- (NSDictionary *)rootEntries
{
  if (activeSubproject)
    {
      return [activeSubproject rootEntries];
    }

  return rootEntries;
}

// Category - the name we see in project browser, e.g. "Classes"
// Key - the uppercase names located in PC.roject, e.g. "CLASS_FILES"
- (NSString *)keyForCategory:(NSString *)category
{
  int index = -1;

  if (activeSubproject)
    {
      return [activeSubproject keyForCategory:category];
    }

  if (![rootCategories containsObject:category])
    {
      return nil;
    }
    
  index = [rootCategories indexOfObject:category];
  return [rootKeys objectAtIndex:index];
}

- (NSString *)categoryForKey:(NSString *)key
{
  if (activeSubproject)
    {
      return [activeSubproject categoryForKey:key];
    }

  return [rootEntries objectForKey:key];
}

- (NSString *)rootCategoryForCategoryPath:(NSString *)categoryPath
{
  NSArray *pathComponents = nil;

  if ([categoryPath isEqualToString:@"/"] || [categoryPath isEqualToString:@""])
    {
      return nil;
    }
    
  pathComponents = [categoryPath componentsSeparatedByString:@"/"];

  return [pathComponents objectAtIndex:1];
}

- (NSString *)keyForRootCategoryInCategoryPath:(NSString *)categoryPath
{
  NSString *category = nil;
  NSString *key = nil;
  int      index = -1;

  if (categoryPath == nil 
      || [categoryPath isEqualToString:@""]
      || [categoryPath isEqualToString:@"/"])
    {
      return nil;
    }

  category = [self rootCategoryForCategoryPath:categoryPath];

  // Since keyForCategory subproject sensitive implement 
  // key searching here
  // TODO: revise all code in PCProject against subproject
  // sensitiveness
  // key = [self keyForCategory:category];
  if (![rootCategories containsObject:category])
    {
      return nil;
    }
    
  index = [rootCategories indexOfObject:category];
  key = [rootKeys objectAtIndex:index];

/*  PCLogInfo(self, @"{%@}(keyForRootCategoryInCategoryPath): %@ key:%@", 
	    projectName, categoryPath, key);*/

  return key;
}

// --- Requested by Project Browser

- (NSArray *)contentAtCategoryPath:(NSString *)categoryPath
{
  NSString *key = [self keyForRootCategoryInCategoryPath:categoryPath];
  NSArray  *pathArray = nil;
  NSString *listEntry = nil;

  pathArray = [categoryPath componentsSeparatedByString:@"/"];
  listEntry = [pathArray lastObject];

/*  PCLogInfo(self, @"{%@}{contentAtCategoryPath:} %@",
	    projectName, categoryPath);*/

  if ([categoryPath isEqualToString:@""] || [categoryPath isEqualToString:@"/"])
    {
      if ([projectManager activeProject] != self)
	{
	  [projectManager setActiveProject:self];
	}
      return rootCategories;
    }
  else if ([pathArray count] == 2)
    { // Click on /Category. [pathArray count] == 2 even in subprojects
      // because category path stripped from leading path components before 
      // going into subproject's code
//      NSLog(@"Click on Category");
      if ([projectManager activeProject] != self)
	{
	  [projectManager setActiveProject:self];
	}
      activeSubproject = nil;
      return [projectDict objectForKey:key];
    }
  else if ([key isEqualToString:PCSubprojects] && [pathArray count] > 2)
    { // Click on "/Subprojects/Name+"
      PCProject      *_subproject = nil;
      NSString       *spCategoryPath = nil;
      NSMutableArray *mCategoryPath = [NSMutableArray arrayWithArray:pathArray];

      _subproject = [self subprojectWithName:[pathArray objectAtIndex:2]];
      activeSubproject = _subproject;

      [mCategoryPath removeObjectAtIndex:1];
      [mCategoryPath removeObjectAtIndex:1];

      spCategoryPath = [mCategoryPath componentsJoinedByString:@"/"];

      return [_subproject contentAtCategoryPath:spCategoryPath];
    }
  else
    { // The file is selected, ask editor for browser items
      return [[projectEditor activeEditor] browserItemsForItem:listEntry];
    }
}

- (BOOL)hasChildrenAtCategoryPath:(NSString *)categoryPath
{
  NSString  *listEntry = nil;
  PCProject *activeProject = [projectManager activeProject];
  NSString  *category = [projectBrowser nameOfSelectedCategory];
  NSString  *categoryKey = [self keyForCategory:category];

  if (self != activeProject)
    {
      return [activeProject hasChildrenAtCategoryPath:categoryPath];
    }

  listEntry = [[categoryPath componentsSeparatedByString:@"/"] lastObject];
 
  // Categories
  if ([rootCategories containsObject:listEntry])
    {
      return YES;
    }
   
  // Subprojects
  if ([[projectDict objectForKey:PCSubprojects] containsObject:listEntry]
      && [category isEqualToString:@"Subprojects"])
    {
      return YES;
    }

  // Files. listEntry is file in category or contents of file
  if ([[projectDict objectForKey:categoryKey] containsObject:listEntry] ||
      [projectBrowser nameOfSelectedFile])
    {
      // TODO: Libraries
      if ([category isEqualToString:@"Libraries"])
	{
	  return NO;
	}

      if ([projectEditor editorProvidesBrowserItemsForItem:listEntry] == YES)
	{
	  return YES;
	}
    }
  
  return NO;
}

@end

