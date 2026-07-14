/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2017 Free Software Foundation

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
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCFileCreator.h>

#import "PCToolProject.h"

@implementation PCToolProject

//----------------------------------------------------------------------------
// Init and free
//----------------------------------------------------------------------------

- (id)init
{
  if ((self = [super init]))
    {
      rootKeys = [[NSArray arrayWithObjects:
	PCClasses,
	PCHeaders,
	PCOtherSources,
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
	@"Images",
	@"Other Resources",
	@"Subprojects",
	@"Documentation",
	@"Supporting Files",
	@"Libraries",
	@"Non Project Files",
	nil] retain];

      rootEntries = [[NSDictionary 
	dictionaryWithObjects:rootCategories forKeys:rootKeys] retain];
    
    }

  return self;
}

- (void)assignInfoDict:(NSMutableDictionary *)dict
{
  infoDict = [dict mutableCopy];
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
{
  [rootCategories release];
  [rootKeys release];
  [rootEntries release];
  
  [super dealloc];
}

- (Class)builderClass
{
  return [PCToolProject class];
}

// ----------------------------------------------------------------------------
// --- ProjectType protocol
// ----------------------------------------------------------------------------

- (PCProject *)createProjectAt:(NSString *)path withOption:(NSString *)option
{
  PCFileManager  *pcfm = [PCFileManager defaultManager];
  PCFileCreator  *pcfc = [PCFileCreator sharedCreator];
  NSBundle       *projectBundle = nil;
  NSString       *_file = nil;
  NSString       *_2file = nil;
  NSString       *_resourcePath;
  NSMutableArray *_array = nil;

  NSAssert(path,@"No valid project path provided!");

  projectBundle = [NSBundle bundleForClass:[self class]];

  _file = [projectBundle pathForResource:@"PC" ofType:@"project"];
  [projectDict initWithContentsOfFile:_file];

  // Customise the project
  [self setProjectPath:path];
  [self setProjectName:[path lastPathComponent]];
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
  _file = [projectBundle pathForResource:@"main" ofType:@"m"];
  _2file = [path stringByAppendingPathComponent:@"main.m"];
  [pcfm copyFile:_file toFile:_2file];
  [pcfc replaceTagsInFileAtPath:_2file withProject:self];

  // GNUmakefile.postamble
  [[PCMakefileFactory sharedFactory] createPostambleForProject:self];

  _resourcePath = [path stringByAppendingPathComponent:@"Resources"];
  [pcfm createDirectoriesIfNeededAtPath:_resourcePath];

  // Info-gnutstep.plist
  _file = [projectBundle pathForResource:@"Info" ofType:@"gnustep"];
  infoDict = [[NSMutableDictionary alloc] initWithContentsOfFile:_file];
  [infoDict setObject:projectName forKey:@"ToolName"];

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

//----------------------------------------------------------------------------
// --- PCProject overridings
//----------------------------------------------------------------------------

- (PCProject *)openWithWrapperAt:(NSString *)path
{
  [super openWithWrapperAt: path];
  [self loadInfoFile];
  return self;
}

@end

@implementation PCToolProject (GeneratedFiles)

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

  [self writeInfoEntry:@"ToolName" forKey:PCProjectName];
  [self writeInfoEntry:@"ToolDescription" forKey:PCDescription];
  [self writeInfoEntry:@"ToolIcon" forKey:PCToolIcon];
  [self writeInfoEntry:@"ToolRelease" forKey:PCRelease];
  [self writeInfoEntry:@"FullVersionID" forKey:PCRelease];
  [self writeInfoEntry:@"Authors" forKey:PCAuthors];
  [self writeInfoEntry:@"URL" forKey:PCURL];
  [self writeInfoEntry:@"Copyright" forKey:PCCopyright];
  [self writeInfoEntry:@"CopyrightDescription" forKey:PCCopyrightDescription];

  infoFile = [NSString stringWithFormat:@"%@Info.plist",projectName];
  infoFile = [projectPath stringByAppendingPathComponent:infoFile];
  
  return [infoDict writeToFile:infoFile atomically:YES];
}

- (BOOL)writeMakefile
{
  PCMakefileFactory *mf = [PCMakefileFactory sharedFactory];
  NSUInteger        i,count;
  NSString          *mfl = nil;
  NSData            *mfd = nil;
  NSString          *key = nil;
  NSMutableArray    *resources = nil;
  NSArray           *localizedResources = nil;

  // Info-gnustep.plist
  [self writeInfoFile];

  // Save the GNUmakefile backup
  [super writeMakefile];

  // Save GNUmakefile.preamble
  [mf createPreambleForProject:self];

  // Create the new file
  [mf createMakefileForProject:self];

  // Head
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

  [mff appendString:@"\n#\n# Tool\n#\n"];
  [mff appendString:[NSString stringWithFormat:@"VERSION = %@\n",
    [projectDict objectForKey:PCRelease]]];
  [mff appendString:[NSString stringWithFormat:@"PACKAGE_NAME = %@\n",
    projectName]];
  [mff appendString:[NSString stringWithFormat:@"TOOL_NAME = %@\n",
    projectName]];
  [mff appendString:[NSString stringWithFormat:@"%@_TOOL_ICON = %@\n",
    projectName, [projectDict objectForKey:PCToolIcon]]];

  /* FIXME %@_COPY_INTO_DIR needs to be properly reinstantiated
     as well as %@_STANDARD_INSTALL = no  */

  /* set the domain if it was specified */
  if (!(installDomain == nil) && ![installDomain isEqualToString:@""])
    {
      [mff appendString:
	     [NSString stringWithFormat:@"GNUSTEP_INSTALLATION_DOMAIN = %@\n",[installDomain uppercaseString]]];
    }
}

- (void)appendTail:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n\n#\n# Makefiles\n#\n"];
  [mff appendString:@"-include GNUmakefile.preamble\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/aggregate.make\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/tool.make\n"];
  [mff appendString:@"-include GNUmakefile.postamble\n"];
}

@end

@implementation PCToolProject (Inspector)

- (NSView *)projectAttributesView
{
  if (projectAttributesView == nil)
    {
      if ([NSBundle loadNibNamed:@"Inspector" owner:self] == NO)
	{
	  NSLog(@"PCLibraryProject: error loading Inspector NIB!");
	  return nil;
	}
      [projectAttributesView retain];
      [self updateInspectorValues:nil];
    }

  return projectAttributesView;
}

- (void)updateInspectorValues:(NSNotification *)aNotif 
{
}

@end

