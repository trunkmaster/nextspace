/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2022 Free Software Foundation

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

#import <ProjectCenter/PCMakefileFactory.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCFileCreator.h>

#import "PCAppProject.h"
#import "PCAppProject+Inspector.h"

@implementation PCAppProject

// ----------------------------------------------------------------------------
// --- Init and free
// ----------------------------------------------------------------------------

- (id)init
{
  if ((self = [super init]))
    {
      rootKeys = [[NSArray arrayWithObjects: 
	PCClasses,
        PCHeaders,
        PCOtherSources,
        PCInterfaces,
        PCImages,
        PCOtherResources,
        PCSubprojects,
        PCDocuFiles,
        PCSupportingFiles,
        PCLibraries,
        PCNonProject,
        nil] retain];

      rootCategories = [[NSArray arrayWithObjects: 
  	@"Classes",
    	@"Headers",
      	@"Other Sources",
	@"Interfaces",
	@"Images",
	@"Other Resources",
	@"Subprojects",
	@"Documentation",
//      @"Context Help",
	@"Supporting Files",
//      @"Frameworks",
	@"Libraries",
	@"Non Project Files",
	nil] retain];
      
      rootEntries = [[NSDictionary 
	dictionaryWithObjects:rootCategories forKeys:rootKeys] retain];
    }

  return self;
}

- (void)loadInfoFile
{
  PCFileManager  *pcfm = [PCFileManager defaultManager];
  NSMutableArray *otherRes = nil;
  NSString       *oldFile = @"Info-gnustep.plist";
  NSString       *oldFilePath = nil;
  NSString       *infoFile = nil;
  NSString       *infoFilePath = nil;

  infoFile = [NSString stringWithFormat:@"%@Info.plist",projectName];
  infoFilePath = [projectPath stringByAppendingPathComponent:infoFile];

  // Old project with info file Info-gnustep.plist located in Resources 
  // directory. Move it to parent directory and replace it in PCOtherResources.
  otherRes = [[projectDict objectForKey:PCOtherResources] mutableCopy];
  if ([otherRes containsObject:oldFile])
    {
      oldFilePath = [self dirForCategoryKey:PCOtherResources];
      oldFilePath = [oldFilePath stringByAppendingPathComponent:oldFile];
      
      [pcfm copyFile:oldFilePath toFile:infoFilePath];
      [pcfm removeFileAtPath:oldFilePath removeDirsIfEmpty:YES];

      [otherRes removeObject:oldFile];
      [otherRes addObject:infoFile];
      [self setProjectDictObject:otherRes forKey:PCSupportingFiles notify:NO];
      RELEASE(otherRes);
    }

  if ([[NSFileManager defaultManager] fileExistsAtPath:infoFilePath])
    {
      infoDict = 
	[[NSMutableDictionary alloc] initWithContentsOfFile:infoFilePath];
    }
  else
    {
      infoDict = [[NSMutableDictionary alloc] init];
    }
}

- (void)dealloc
{ // TODO: Never called. Should be fixed.
#ifdef DEBUG
  NSLog (@"PCAppProject: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(infoDict);
  RELEASE(projectAttributesView);

  RELEASE(rootCategories);
  RELEASE(rootKeys);
  RELEASE(rootEntries);

  [super dealloc];
}

// ----------------------------------------------------------------------------
// --- ProjectType protocol
// ----------------------------------------------------------------------------

- (PCProject *)createProjectAt:(NSString *)path withOption:(NSString *)projOption
{
  PCFileManager  *pcfm = [PCFileManager defaultManager];
  PCFileCreator  *pcfc = [PCFileCreator sharedCreator];
  NSString       *_file = nil;
  NSString       *_2file = nil;
  NSString       *_resourcePath = nil;
  NSBundle       *projBundle = [NSBundle bundleForClass:[self class]];
  NSString       *mainNibFile = nil;
  NSMutableArray *_array = nil;
  NSString       *helpFile = nil;

  NSAssert(path,@"No valid project path provided!");

  // PC.project
  _file = [projBundle pathForResource:@"PC" ofType:@"project"];
  [projectDict initWithContentsOfFile:_file];

  // Customise the project
  [self setProjectPath:path];
  [self setProjectName: [path lastPathComponent]];

  if ([[projectName pathExtension] isEqualToString:@"subproj"])
    {
      projectName = [projectName stringByDeletingPathExtension];
    }

  [projectDict setObject:projectName forKey:PCProjectName];
  [projectDict setObject:[[NSCalendarDate date] description]
		  forKey:PCCreationDate];
  [projectDict setObject:NSFullUserName() forKey:PCProjectCreator];
  [projectDict setObject:NSFullUserName() forKey:PCProjectMaintainer];
  [projectDict setObject:[NSUserDefaults userLanguages] forKey:PCUserLanguages];

  // Copy the project files to the provided path
  _file = [projBundle pathForResource:@"main" ofType:@"m"];
  _2file = [path stringByAppendingPathComponent:
		     [NSString stringWithFormat:@"%@_main.m", projectName]];
  [pcfm copyFile:_file toFile:_2file];
  [pcfc replaceTagsInFileAtPath:_2file withProject:self];
  [projectDict 
    setObject:[NSArray arrayWithObjects:[_2file lastPathComponent],nil]
       forKey:PCOtherSources];

  _file = [projBundle pathForResource:@"AppController" ofType:@"m"];
  _2file = [path stringByAppendingPathComponent:@"AppController.m"];
  [pcfm copyFile:_file toFile:_2file];
  [pcfc replaceTagsInFileAtPath:_2file withProject:self];

  _file = [projBundle pathForResource:@"AppController" ofType:@"h"];
  _2file = [path stringByAppendingPathComponent:@"AppController.h"];
  [pcfm copyFile:_file toFile:_2file];
  [pcfc replaceTagsInFileAtPath:_2file withProject:self];

  // GNUmakefile.postamble
  [[PCMakefileFactory sharedFactory] createPostambleForProject:self];

  // Resources
  // By default resources located at Resources subdir.
  // If any resource marked as "Localizable" in Inspector it's moved
  // into English.lproj and copied into all available .lproj subdirs.
  _resourcePath = [path stringByAppendingPathComponent:@"Resources"];

  if ([projOption isEqualToString: PCProjectInterfaceGorm])
    {
      // Main NIB (Gorm)
      _file = [projBundle pathForResource:@"Main" ofType:@"gorm"];
      mainNibFile = [NSString stringWithFormat:@"%@.gorm", projectName];
      mainNibFile = [_resourcePath stringByAppendingPathComponent:mainNibFile];
      [pcfm copyFile:_file toFile:mainNibFile];
        
      [projectDict setObject:[mainNibFile lastPathComponent]
                      forKey:PCMainInterfaceFile];
      [projectDict setObject:[NSArray arrayWithObjects:[mainNibFile lastPathComponent], nil] 
                      forKey:PCInterfaces];
    }
  else if ([projOption isEqualToString: PCProjectInterfaceRenaissance])
    {
      // Renaissance
      _file = [projBundle pathForResource:@"Main" ofType:@"gsmarkup"];
      _2file = [_resourcePath stringByAppendingPathComponent:@"Main.gsmarkup"];
      [pcfm copyFile:_file toFile:_2file];
      _file = [projBundle pathForResource:@"MainMenu-GNUstep" ofType:@"gsmarkup"];
      _2file = [_resourcePath 
                 stringByAppendingPathComponent:@"MainMenu-GNUstep.gsmarkup"];
      [pcfm copyFile:_file toFile:_2file];
      _file = [projBundle pathForResource:@"MainMenu-OSX" ofType:@"gsmarkup"];
      _2file = [_resourcePath 
                 stringByAppendingPathComponent:@"MainMenu-OSX.gsmarkup"];
      [pcfm copyFile:_file toFile:_2file];

      [projectDict setObject:[NSArray arrayWithObjects:@"Main.gsmarkup", @"MainMenu-GNUstep.gsmarkup", @"MainMenu-OSX.gsmarkup", nil]
                      forKey:PCInterfaces];
    }

  // Info-gnustep.plist
  _file = [projBundle pathForResource:@"Info" ofType:@"gnustep"];
  infoDict = [[NSMutableDictionary alloc] initWithContentsOfFile:_file];
  [infoDict setObject:projectName forKey:@"ApplicationName"];
  [infoDict setObject:projectName forKey:@"NSExecutable"];
  if (mainNibFile)
    [infoDict setObject:[mainNibFile lastPathComponent] 
                 forKey:@"NSMainNibFile"];
  [infoDict setObject:[projectDict objectForKey:PCPrincipalClass]
    forKey:@"NSPrincipalClass"];
  
  // most probably empty
  if ([projectDict objectForKey:PCBundleIdentifier])
    [infoDict setObject:[projectDict objectForKey:PCBundleIdentifier] forKey:@"CFBundleIdentifier"];

  // Help file if present
  helpFile = [projectDict objectForKey:@"GSHelpContentsFile"];
  if (helpFile)
    [infoDict setObject:helpFile forKey:@"GSHelpContentsFile"];

  // Write to ProjectNameInfo.plist
  _file = [NSString stringWithFormat:@"%@Info.plist",projectName];
  _2file = [projectPath stringByAppendingPathComponent:_file];
  [infoDict writeToFile:_2file atomically:YES];

  // Add Info-gnustep.plist into SUPPORTING_FILES
  _array = [[projectDict objectForKey:PCSupportingFiles] mutableCopy];
  [_array addObject:_file];
  [projectDict setObject:_array forKey:PCSupportingFiles];
  RELEASE(_array);

  // Save the project to disc
  [self writeMakefile];
  [self save];

  return self;
}

// ----------------------------------------------------------------------------
// --- PCProject overridings
// ----------------------------------------------------------------------------

- (PCProject *)openWithWrapperAt:(NSString *)path
{
  [super openWithWrapperAt: path];
  [self loadInfoFile];
  return self;
}


- (Class)builderClass
{
  return [PCAppProject class];
}

// ----------------------------------------------------------------------------
// --- File Handling
// ----------------------------------------------------------------------------

- (BOOL)removeFiles:(NSArray *)files forKey:(NSString *)key notify:(BOOL)yn
{
  NSMutableArray *filesToRemove = [[files mutableCopy] autorelease];
  NSString       *mainNibFile = [projectDict objectForKey:PCMainInterfaceFile];
  NSString       *appIcon = [projectDict objectForKey:PCAppIcon];

  if (!files || !key)
    {
      return NO;
    }

  // Check for main NIB file
  if ([key isEqualToString:PCInterfaces] && [files containsObject:mainNibFile])
    {
      int ret;
      ret = NSRunAlertPanel(@"Remove",
			    @"You've selected to remove main interface file.\nDo you still want to remove it?",
			    @"Remove", @"Leave", nil);
			    
      if (ret == NSAlertAlternateReturn) // Leave
	{
	  [filesToRemove removeObject:mainNibFile];
	}
      else
	{
	  [self clearMainNib:self];
	}
    }
  // Check for application icon files
  else if ([key isEqualToString:PCImages] && [files containsObject:appIcon])
    {
      int ret;
      ret = NSRunAlertPanel(@"Remove",
			    @"You've selected to remove application icon file.\nDo you still want to remove it?",
			    @"Remove", @"Leave", nil);
			    
      if (ret == NSAlertAlternateReturn) // Leave
	{
	  [filesToRemove removeObject:appIcon];
	}
      else
	{
	  [self clearAppIcon:self];
	}
    }

  return [super removeFiles:filesToRemove forKey:key notify:yn];
}

- (BOOL)renameFile:(NSString *)fromFile toFile:(NSString *)toFile
{
  NSString *mainNibFile = [projectDict objectForKey:PCMainInterfaceFile];
  NSString *appIcon = [projectDict objectForKey:PCAppIcon];
  NSString *categoryKey = nil;
  NSString *ff = [fromFile copy];
  NSString *tf = [toFile copy];
  BOOL     success = NO;

  categoryKey = [self 
    keyForCategory:[projectBrowser nameOfSelectedRootCategory]];
  // Check for main NIB file
  if ([categoryKey isEqualToString:PCInterfaces] 
      && [fromFile isEqualToString:mainNibFile])
    {
      [self clearMainNib:self];
      if ([super renameFile:ff toFile:tf] == YES)
	{
	  [self setMainNibWithFileAtPath:
	    [[self dirForCategoryKey:categoryKey] 
	      stringByAppendingPathComponent:tf]];
	  success = YES;
	}
    }
  // Check for application icon files
  else if ([categoryKey isEqualToString:PCImages] 
	   && [fromFile isEqualToString:appIcon])
    {
      [self clearAppIcon:self];
      if ([super renameFile:ff toFile:tf] == YES)
	{
	  [self setAppIconWithFileAtPath:
	    [[self dirForCategoryKey:categoryKey] 
	      stringByAppendingPathComponent:tf]];
	  success = YES;
	}
    }
  else if ([super renameFile:ff toFile:tf] == YES)
    {
      success = YES;
    }
    
  [ff release];
  [tf release];

  return success;
}

@end

@implementation PCAppProject (GeneratedFiles)

- (void)writeInfoEntry:(NSString *)name forKey:(NSString *)key
{
  id entry = [projectDict objectForKey:key];

  if (entry == nil)
    {
      return;
    }

  if ([entry isKindOfClass:[NSString class]] && [entry isEqualToString:@""])
    {
      [infoDict removeObjectForKey:name];
      return;
    }

  if ([entry isKindOfClass:[NSArray class]] && [entry count] <= 0)
    {
      [infoDict removeObjectForKey:name];
      return;
    }

  [infoDict setObject:entry forKey:name];
}

- (BOOL)writeInfoFile
{
  NSString *infoFile = nil;

  [self writeInfoEntry:@"ApplicationDescription" forKey:PCDescription];
  [self writeInfoEntry:@"ApplicationIcon" forKey:PCAppIcon];
  [self writeInfoEntry:@"ApplicationName" forKey:PCProjectName];
  [self writeInfoEntry:@"ApplicationRelease" forKey:PCRelease];
  [self writeInfoEntry:@"CFBundleIdentifier" forKey:PCBundleIdentifier];
  [self writeInfoEntry:@"Authors" forKey:PCAuthors];
  [self writeInfoEntry:@"Copyright" forKey:PCCopyright];
  [self writeInfoEntry:@"CopyrightDescription" forKey:PCCopyrightDescription];
  [self writeInfoEntry:@"FullVersionID" forKey:PCRelease];
  [self writeInfoEntry:@"NSExecutable" forKey:PCProjectName];
  [self writeInfoEntry:@"NSIcon" forKey:PCAppIcon];
  if ([[projectDict objectForKey:PCAppType] isEqualToString:@"GORM"])
    {
      [self writeInfoEntry:@"NSMainNibFile" forKey:PCMainInterfaceFile];
      [infoDict removeObjectForKey:@"GSMainMarkupFile"];
    }
  else
    {
      [self writeInfoEntry:@"GSMainMarkupFile" forKey:PCMainInterfaceFile];
      [infoDict removeObjectForKey:@"NSMainNibFile"];
    }
  [self writeInfoEntry:@"NSPrincipalClass" forKey:PCPrincipalClass];
  [self writeInfoEntry:@"GSHelpContentsFile" forKey:PCHelpFile];
  [infoDict setObject:@"Application" forKey:@"NSRole"];
  [self writeInfoEntry:@"NSTypes" forKey:PCDocumentTypes];
  [self writeInfoEntry:@"URL" forKey:PCURL];

  infoFile = [NSString stringWithFormat:@"%@Info.plist",projectName];
  infoFile = [projectPath stringByAppendingPathComponent:infoFile];

  return [infoDict writeToFile:infoFile atomically:YES];
}

// Overriding
- (BOOL)writeMakefile
{
  PCMakefileFactory *mf = [PCMakefileFactory sharedFactory];
  NSUInteger        i,count; 
  NSString          *mfl = nil;
  NSData            *mfd = nil;
  NSString          *key = nil;
  NSMutableArray    *resources = nil;
  NSArray           *localizedResources = nil;

  // Save Info-gnustep.plist
  [self writeInfoFile];

  // Save the GNUmakefile backup
  [super writeMakefile];

  // Save GNUmakefile.preamble
  [mf createPreambleForProject:self];

  // Create the new file
  [mf createMakefileForProject:self];

  // Head (Application)
  [self appendHead:mf];

  // Libraries depend upon
  [mf appendLibraries:[projectDict objectForKey:PCLibraries]];

  // Subprojects
  if ([[projectDict objectForKey:PCSubprojects] count] > 0)
    {
      [mf appendSubprojects:[projectDict objectForKey:PCSubprojects]];
    }

  // Resources
  count = [[self resourceFileKeys] count];
  resources = [[NSMutableArray alloc] initWithCapacity:1];
  // Gather all resource files into one array
  for (i = 0; i < count; i++)
    {
      key = [[self resourceFileKeys] objectAtIndex:i];
      
      [resources addObjectsFromArray:[projectDict objectForKey:key]];
    }
  // Remove localized resource files from gathered array
  localizedResources = [projectDict objectForKey:PCLocalizedResources];
  for (i = [resources count]; i > 0; i--)
    {
      if ([localizedResources containsObject:[resources objectAtIndex:i-1]])
	{
	  [resources removeObjectAtIndex:i-1];
	}
    }
  [mf appendResources:resources inDir:@"Resources"];
  [resources release];

  // Localization
  [mf appendLocalizedResources:localizedResources
		  forLanguages:[projectDict objectForKey:PCUserLanguages]];

  // Sources
  [mf appendHeaders:[projectDict objectForKey:PCHeaders]];
  [mf appendClasses:[projectDict objectForKey:PCClasses]];
  [mf appendOtherSources:[projectDict objectForKey:PCOtherSources]];

  // Tail
  [self appendTail:mf];

  // Write the new file to disc!
  mfl = [projectPath stringByAppendingPathComponent:@"GNUmakefile"];
  if ((mfd = [mf encodedMakefile])) 
    {
      if ([mfd writeToFile:mfl atomically:YES]) 
	{
	  return YES;
	}
    }

  return NO;
}

- (void)appendHead:(PCMakefileFactory *)mff
{
  NSString *installDomain = [projectDict objectForKey:PCInstallDomain];

  [mff appendString:@"\n#\n# Application\n#\n"];
  [mff appendString:[NSString stringWithFormat:@"VERSION = %@\n",
			      [projectDict objectForKey:PCRelease]]];
  [mff appendString:
	 [NSString stringWithFormat:@"PACKAGE_NAME = %@\n", projectName]];
  [mff appendString:
	 [NSString stringWithFormat:@"APP_NAME = %@\n", projectName]];
    
  [mff appendString:[NSString stringWithFormat:@"%@_APPLICATION_ICON = %@\n",
			      projectName, [projectDict objectForKey:PCAppIcon]]];

  /* FIXME %@_COPY_INTO_DIR needs to be properly reinstantiated
     as well as %@_STANDARD_INSTALL = no  */

  /* set the domain if it was specified */
  if (!(installDomain == nil) && ![installDomain isEqualToString:@""])
    {
      [mff appendString:
	     [NSString stringWithFormat:@"GNUSTEP_INSTALLATION_DOMAIN = %@\n",
[installDomain uppercaseString]]];
    }
}

- (void)appendTail:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n\n#\n# Makefiles\n#\n"];
  [mff appendString:@"-include GNUmakefile.preamble\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/aggregate.make\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/application.make\n"];
  [mff appendString:@"-include GNUmakefile.postamble\n"];
}

@end
