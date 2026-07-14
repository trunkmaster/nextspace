/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2005-2023 Free Software Foundation

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
#import <ProjectCenter/PCMakefileFactory.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCFileCreator.h>

#import "PCFrameworkProject.h"

@implementation PCFrameworkProject

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
  return [PCFrameworkProject class];
}

// ----------------------------------------------------------------------------
// --- ProjectType protocol
// ----------------------------------------------------------------------------

- (PCProject *)createProjectAt:(NSString *)path withOption:projOption
{
//  PCFileManager *pcfm = [PCFileManager defaultManager];
  PCFileCreator *pcfc = [PCFileCreator sharedCreator];
  NSBundle      *projectBundle = nil;
  NSString      *_file = nil;
  NSString      *_2file = nil;
//  NSString      *_resourcePath;

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
//  _resourcePath = [path stringByAppendingPathComponent:@"Resources"];

  // Save the project to disc
  [self writeMakefile];
  [self save];

  return self;
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

@implementation PCFrameworkProject (GeneratedFiles)

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
  [mf appendClasses:[projectDict objectForKey:PCClasses]];
  [mf appendOtherSources:[projectDict objectForKey:PCOtherSources]];

  // AutoGSDoc
  [self appendGSDoc:mf];
  
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
  [mff appendString:@"\n#\n# Framework\n#\n"];
  [mff appendString:[NSString stringWithFormat:@"VERSION = %@\n",
    [projectDict objectForKey:PCRelease]]];
  [mff appendString:
	 [NSString stringWithFormat:@"PACKAGE_NAME = %@\n", projectName]];
  [mff appendString:[NSString stringWithFormat:@"FRAMEWORK_NAME = %@\n",
    projectName]];
  [mff appendString:[NSString 
    stringWithFormat:@"%@_CURRENT_VERSION_NAME = %@\n",
    projectName, [projectDict objectForKey:PCRelease]]];
  [mff appendString:[NSString 
    stringWithFormat:@"%@_DEPLOY_WITH_CURRENT_VERSION = yes\n", projectName]];
}

- (void)appendPublicHeaders:(PCMakefileFactory *)mff
{
  NSArray *array = [projectDict objectForKey:PCPublicHeaders];

  if (array == nil || [array count] == 0)
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

- (void)appendGSDoc:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n#\n# AutoGSDoc\n#\n"];
  [mff appendString: [NSString stringWithFormat:@"DOCUMENT_NAME = %@\n\n", projectName]];
  [mff appendString: [NSString stringWithFormat:@"%@_AGSDOC_FILES = %@.gsdoc \\\n", 
			       projectName, projectName]];
  [mff appendString: [NSString stringWithFormat:@"\t$(%@_HEADER_FILES) \\\n", 
                              projectName]];
  [mff appendString: [NSString stringWithFormat:@"\t$(%@_OBJC_FILES) \\\n", 
                              projectName]];
  [mff appendString: [NSString stringWithFormat:@"\n\n%@_AGSDOC_FLAGS += -MakeFrames YES\n", projectName]];
}


- (void)appendTail:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n\n#\n# Makefiles\n#\n"];
  [mff appendString:@"-include GNUmakefile.preamble\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/aggregate.make\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/framework.make\n"];
  [mff appendString:@"-include GNUmakefile.postamble\n"];

  [mff appendString:@"\n\n#Only build documentation if doc=yes was passed on the command line\n#\n"];
  [mff appendString:@"ifeq ($(doc),yes)\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/documentation.make\n"];
  [mff appendString:@"endif\n"];
}

@end

@implementation PCFrameworkProject (Inspector)

- (NSView *)projectAttributesView
{
  if (projectAttributesView == nil)
    {
      if ([NSBundle loadNibNamed:@"Inspector" owner:self] == NO)
	{
	  NSLog(@"PCFrameworkProject: error loading Inspector NIB!");
	  return nil;
	}
      [projectAttributesView retain];
      [self updateInspectorValues:nil];
    }

  return projectAttributesView;
}

- (void)updateInspectorValues:(NSNotification *)aNotif 
{
  [principalClassField 
    setStringValue:[projectDict objectForKey:PCPrincipalClass]];
}

- (void)setPrincipalClass:(id)sender
{
  [self setProjectDictObject:[principalClassField stringValue]
                      forKey:PCPrincipalClass
		      notify:YES];
}


@end

