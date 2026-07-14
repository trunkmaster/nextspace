/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2013 Free Software Foundation

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

#import <ProjectCenter/PCMakefileFactory.h>
#import <ProjectCenter/PCFileCreator.h>
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCProjectBrowser.h>

#import "PCLibProject.h"

@implementation PCLibProject

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

- (void)dealloc
{
  [rootCategories release];
  [rootKeys release];
  [rootEntries release];

  [super dealloc];
}

//----------------------------------------------------------------------------
// --- PCProject overridings
//----------------------------------------------------------------------------

- (Class)builderClass
{
  return [PCLibProject class];
}

// ----------------------------------------------------------------------------
// --- ProjectType protocol
// ----------------------------------------------------------------------------

- (PCProject *)createProjectAt:(NSString *)path
{
  PCFileManager *pcfm = [PCFileManager defaultManager];
  PCFileCreator *pcfc = [PCFileCreator sharedCreator];
  NSBundle      *projectBundle = nil;
  NSString      *_file = nil;
  NSString      *_2file = nil;
  NSString      *_resourcePath = nil;

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

  // $PROJECTNAME$.m
  _file = [NSString stringWithFormat:@"%@", projectName];
  _2file = [NSString stringWithFormat:@"%@.m", projectName];
  [pcfc createFileOfType:ObjCClass 
                    path:[path stringByAppendingPathComponent:_file]
                 project:self];
  [projectDict setObject:[NSArray arrayWithObjects:_2file,nil]
                  forKey:PCClasses];

  // $PROJECTNAME$.h already created by creating $PROJECTNAME$.m
  _file = [NSString stringWithFormat:@"%@.h", projectName];
  [projectDict setObject:[NSArray arrayWithObjects:_file,nil]
                  forKey:PCHeaders];
  [projectDict setObject:[NSArray arrayWithObjects:_file,nil]
                  forKey:PCPublicHeaders];

  // GNUmakefile.postamble
  [[PCMakefileFactory sharedFactory] createPostambleForProject:self];

  // Resources
  _resourcePath = [path stringByAppendingPathComponent:@"Resources"];

  _file = [projectBundle pathForResource:@"Version" ofType:@""];
  _2file = [_resourcePath stringByAppendingPathComponent:@"Version"];
  [pcfm copyFile:_file toFile:_2file];

  // Save the project to disc
  [self writeMakefile];
  [self save];

  return self;
}

- (PCProject *)createProjectAt:(NSString *)path withOption:(NSString *)option
{
  // FIXME: Just to implement the protocol
  return [self createProjectAt:path];
}

// ----------------------------------------------------------------------------
// --- File Handling
// ----------------------------------------------------------------------------

- (void)addFiles:(NSArray *)files forKey:(NSString *)type notify:(BOOL)yn
{
  if ([type isEqualToString:PCHeaders])
    {
      [super addFiles:files forKey:PCPublicHeaders notify:NO];
    }

  [super addFiles:files forKey:type notify:YES];
}

- (BOOL)renameFile:(NSString *)fromFile toFile:(NSString *)toFile
{
  NSString *category = [projectBrowser nameOfSelectedCategory];
  BOOL     success = NO;
  BOOL     isPublicHeader = YES;

  isPublicHeader = 
    [[projectDict objectForKey:PCPublicHeaders] containsObject:fromFile];

  success = [super renameFile:fromFile toFile:toFile];

  if (success && [category isEqualToString:[super categoryForKey:PCHeaders]])
    {
      if (isPublicHeader == NO)
	{
	  [self setHeaderFile:toFile public:NO];
	}
    }

  return success;
}

@end

@implementation PCLibProject (GeneratedFiles)

- (BOOL)writeMakefile
{
  PCMakefileFactory *mf = [PCMakefileFactory sharedFactory];
  NSUInteger        i,count; 
  NSString          *mfl = nil;
  NSData            *mfd = nil;
  NSString          *key = nil;
  NSMutableArray    *resources = nil;
  NSArray           *localizedResources = nil;

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
  [self appendPublicHeaders:mf];
  [mf appendClasses:[projectDict objectForKey:PCClasses]
          forTarget:[NSString stringWithFormat:@"%@",projectName]];
  [mf appendOtherSources:[projectDict objectForKey:PCOtherSources]
          forTarget:[NSString stringWithFormat:@"%@",projectName]];

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
  [mff appendString:@"\n#\n# Library\n#\n"];
  [mff appendString:[NSString stringWithFormat:@"VERSION = %@\n",
    [projectDict objectForKey:PCRelease]]];
  [mff appendString:[NSString stringWithFormat:@"PACKAGE_NAME = %@\n",
    projectName]];
  [mff appendString:[NSString stringWithFormat:@"LIBRARY_VAR = %@\n",
    [projectName uppercaseString]]];
  [mff appendString:[NSString stringWithFormat:@"LIBRARY_NAME = %@\n",
    projectName]];
  [mff appendString:[NSString stringWithFormat:@"%@_HEADER_FILES_DIR = %@\n",
    projectName,@"."]];
  [mff appendString:[NSString stringWithFormat:
    @"%@_HEADER_FILES_INSTALL_DIR = /%@\n", projectName, projectName]];
}

- (void)appendPublicHeaders:(PCMakefileFactory *)mff
{
  NSArray *array = [projectDict objectForKey:PCPublicHeaders];

  if ([array count] == 0)
    {
      return;
    }

  [mff appendString:@"\n\n#\n# Public headers (will be installed)\n#\n"];

  [mff appendString:[NSString stringWithFormat:@"%@_HEADER_FILES = ", 
                     projectName]];

  if (array && [array count])
    {
      NSString     *tmp;
      NSEnumerator *enumerator = [array objectEnumerator];

      while ((tmp = [enumerator nextObject])) 
	{
	  [mff appendString:[NSString stringWithFormat:@"\\\n%@ ",tmp]];
	}
    }
}

- (void)appendTail:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n\n#\n# Makefiles\n#\n"];
  [mff appendString:@"-include GNUmakefile.preamble\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/aggregate.make\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/library.make\n"];
  [mff appendString:@"-include GNUmakefile.postamble\n"];
}

@end

@implementation PCLibProject (Inspector)

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

