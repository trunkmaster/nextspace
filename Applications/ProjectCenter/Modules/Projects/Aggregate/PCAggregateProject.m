/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2004-2017 Free Software Foundation

   Authors: Serg Stoyan
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
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCMakefileFactory.h>

#import "PCAggregateProject.h"

@implementation PCAggregateProject

//----------------------------------------------------------------------------
// Init and free
//----------------------------------------------------------------------------

- (id)init
{
  if ((self = [super init]))
    {
/*      NSString *_file;
      Class    class = [self builderClass];

      _file = [[NSBundle bundleForClass:class] pathForResource:@"Info"
                                                        ofType:@"table"];
      infoDict = [NSMutableDictionary dictionaryWithContentsOfFile:_file];
      rootEntries = [infoDict objectForKey:@"BrowserRootEntries"];
      rootKeys = [[rootEntries allKeys] retain];
      rootCategories = [[rootEntries allValues] retain];*/

      rootKeys = [[NSArray arrayWithObjects:
	PCSubprojects,
	PCSupportingFiles,
	PCNonProject,
	nil] retain];

      rootCategories = [[NSArray arrayWithObjects:
	@"Subprojects",
	@"Supporting Files",
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

  if (projectAttributesView) [projectAttributesView release];
  
  [super dealloc];
}

//----------------------------------------------------------------------------
// --- PCProject overridings
//----------------------------------------------------------------------------

- (Class)builderClass
{
  return [PCAggregateProject class];
}

// ----------------------------------------------------------------------------
// --- ProjectType protocol
// ----------------------------------------------------------------------------

- (PCProject *)createProjectAt:(NSString *)path withOption:projOption
{
  PCFileManager *pcfm = [PCFileManager defaultManager];
  NSString      *_file;
  NSBundle      *projectBundle;

  NSAssert(path,@"No valid project path provided!");

  projectBundle = [NSBundle bundleForClass:[self class]];

  [pcfm createDirectoriesIfNeededAtPath:path];
  
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

  // GNUmakefile.postamble
  [[PCMakefileFactory sharedFactory] createPostambleForProject:self];

  // Save the project to disc
  [self writeMakefile];
  [self save];

  return self;
}

@end

@implementation PCAggregateProject (GeneratedFiles)

- (BOOL)writeMakefile
{
  PCMakefileFactory *mf = [PCMakefileFactory sharedFactory];
  NSString          *mfl = nil;
  NSData            *mfd = nil;

  // Save the GNUmakefile backup
  [super writeMakefile];

  // Save GNUmakefile.preamble
  [mf createPreambleForProject:self];

  // Create the new file
  [mf createMakefileForProject:self];

  // Head
  [self appendHead:mf];

  // Subprojects
  if ([[projectDict objectForKey:PCSubprojects] count] > 0)
    {
      [mf appendSubprojects:[projectDict objectForKey:PCSubprojects]];
    }

  // Tail
  [self appendTail:mf];

  // Write the new file to disc!
  mfl = [projectPath stringByAppendingPathComponent:@"GNUmakefile"];
  if ((mfd = [mf encodedMakefile])) 
    {
      if ([mfd writeToFile:mfl atomically:NO]) 
	{
	  return YES;
	}
    }

  return NO;
}

- (void)appendHead:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n#\n# Aggregate\n#\n"];
  [mff appendString:[NSString stringWithFormat:@"VERSION = %@\n",
    [projectDict objectForKey:PCRelease]]];
  [mff appendString:[NSString stringWithFormat:@"PACKAGE_NAME = %@\n",
    projectName]];
}

- (void)appendTail:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n\n#\n# Makefiles\n#\n"];
  [mff appendString:@"-include GNUmakefile.preamble\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/aggregate.make\n"];
  [mff appendString:@"-include GNUmakefile.postamble\n"];
}

@end

@implementation PCAggregateProject (Inspector)

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

