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

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCFileCreator.h>
#import <ProjectCenter/PCMakefileFactory.h>

#import "PCBundleProject.h"

@implementation PCBundleProject

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
#ifdef DEVELOPMENT
  NSLog(@"PCBundleProject: dealloc");
#endif
  [rootCategories release];
  [rootKeys release];
  [rootEntries release];

  [projectAttributesView release];

  [super dealloc];
}

//----------------------------------------------------------------------------
// Project
//----------------------------------------------------------------------------

- (Class)builderClass
{
  return [PCBundleProject class];
}

// ----------------------------------------------------------------------------
// --- ProjectType protocol
// ----------------------------------------------------------------------------

- (PCProject *)createProjectAt:(NSString *)path withOption:projOption
{
  NSBundle      *projectBundle = nil;
  NSString      *_file = nil;
  NSString      *_2file = nil;
  PCFileCreator *pcfc = [PCFileCreator sharedCreator];

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
  [projectDict setObject:projectName forKey:PCPrincipalClass];
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

  // GNUmakefile.postamble
  [[PCMakefileFactory sharedFactory] createPostambleForProject:self];

  // Save the project to disc
  [self writeMakefile];
  [self save];

  return self;
}

@end

@implementation PCBundleProject (GeneratedFiles)

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

  [mff appendString:@"\n#\n# Bundle\n#\n"];
  [mff appendString:[NSString stringWithFormat:@"VERSION = %@\n",
  [projectDict objectForKey:PCRelease]]];
  [mff appendString:[NSString stringWithFormat:@"PACKAGE_NAME = %@\n",
    projectName]];
  [mff appendString:[NSString stringWithFormat:@"BUNDLE_NAME = %@\n",
    projectName]];
  [mff appendString:[NSString stringWithFormat:@"%@_PRINCIPAL_CLASS = %@\n",
    projectName, [projectDict objectForKey:PCPrincipalClass]]];
  [mff appendString:[NSString stringWithFormat:@"BUNDLE_EXTENSION = %@\n",
    [projectDict objectForKey:PCBundleExtension]]];

  /* FIXME %@_COPY_INTO_DIR needs to be properly reinstantiated
     as well as %@_STANDARD_INSTALL = no  */

  /* set the domain if it was specified */
  if (!(installDomain == nil) && ![installDomain isEqualToString:@""])
    {
      [mff appendString:
	     [NSString stringWithFormat:@"GNUSTEP_INSTALLATION_DOMAIN = %@\n", [installDomain uppercaseString]]];
    }
}

- (void)appendTail:(PCMakefileFactory *)mff
{
  [mff appendString:@"\n\n#\n# Makefiles\n#\n"];
  [mff appendString:@"-include GNUmakefile.preamble\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/aggregate.make\n"];
  [mff appendString:@"include $(GNUSTEP_MAKEFILES)/bundle.make\n"];
  [mff appendString:@"-include GNUmakefile.postamble\n"];
}

@end

@implementation PCBundleProject (Inspector)

- (NSView *)projectAttributesView
{
  if (projectAttributesView == nil)
    {
      if ([NSBundle loadNibNamed:@"Inspector" owner:self] == NO)
	{
	  NSLog(@"PCBundleProject: error loading Inspector NIB!");
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
  [bundleExtensionField 
    setStringValue:[projectDict objectForKey:PCBundleExtension]];
}

- (void)setPrincipalClass:(id)sender
{
  [self setProjectDictObject:[principalClassField stringValue]
                      forKey:PCPrincipalClass
		      notify:YES];
}

- (void)setBundleExtension:(id)sender
{
  [self setProjectDictObject:[bundleExtensionField stringValue]
                      forKey:PCBundleExtension
		      notify:YES];
}

@end

