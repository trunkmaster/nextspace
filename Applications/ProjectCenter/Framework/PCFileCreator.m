/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2015 Free Software Foundation

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
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCFileCreator.h>

#import <ProjectCenter/PCLogController.h>

static PCFileCreator *_creator = nil;
static NSDictionary  *dict = nil;

@implementation PCFileCreator

+ (id)sharedCreator
{
  if (_creator == nil)
    {
      NSDictionary *classDict;
      NSDictionary *headerDict;
      NSDictionary *ccDict;
      NSDictionary *chDict;
      NSDictionary *classPpDict;
      NSDictionary *protocolDict;
      NSDictionary *gsmarkupDict;
      NSString     *descr;
      NSString     *template;
      NSBundle     *bundle;

      _creator = [[[self class] alloc] init];
      bundle = [NSBundle bundleForClass:[self class]];

      // Setting up the dictionary needed for registration!

      // Objective C Class
      descr = @"Generic Objective-C class.\n\n"
		@"This is a plain subclass of NSObject which includes"
		@" only Foundation.h.";
      template = [bundle pathForResource:@"class" ofType:@"template"];
      classDict = [NSDictionary dictionaryWithObjectsAndKeys:
	PCClasses, @"ProjectKey",
	descr, @"TypeDescription",
	template,@"TemplateFile",
	nil];

      // Objective C Header
      descr = @"Generic Objective-C header.\n\n"
		@"This is a plain interface subclassing NSObject."
		@" The file includes Foundation.h";
      template = [bundle pathForResource:@"header" ofType:@"template"];
      headerDict =[NSDictionary dictionaryWithObjectsAndKeys:
        PCHeaders,@"ProjectKey",
        descr,@"TypeDescription",
	template,@"TemplateFile",
        nil];

      // C File
      descr = @"Generic ANSI-C implementation file.\n\n"
		@"This file contains no Objective-C dependency in any form.";
      template = [bundle pathForResource:@"cfile" ofType:@"template"];
      ccDict = [NSDictionary dictionaryWithObjectsAndKeys:
        PCOtherSources,@"ProjectKey",
        descr,@"TypeDescription",
	template,@"TemplateFile",
        nil];

      // C Header
      descr = @"Generic ANSI-C header.\n\n"
		@"This file contains no Objective-C dependency in any form.";
      template = [bundle pathForResource:@"cheader" ofType:@"template"];
      chDict = [NSDictionary dictionaryWithObjectsAndKeys:
        PCHeaders,@"ProjectKey",
        descr,@"TypeDescription",
	template,@"TemplateFile",
        nil];

      // Objective C Protocol
      descr = @"Generic Objective-C protocol.\n\n"
		@"This is common Objective-C protocol, comparable"
		@" i.e. to a Java interface.";
      template = [bundle pathForResource:@"protocol" ofType:@"template"];
      protocolDict = [NSDictionary dictionaryWithObjectsAndKeys:
        PCHeaders,@"ProjectKey",
        descr,@"TypeDescription",
	template,@"TemplateFile",
        nil];

      // Objective C++ Class
      descr = @"Generic Objective-C++ class.\n\n"
		@"This is a plain subclass of NSObject which includes"
		@" only Foundation.h. Extend it with c++";
      template = [bundle pathForResource:@"ocppclass" ofType:@"template"];
      classPpDict = [NSDictionary dictionaryWithObjectsAndKeys:
	PCClasses, @"ProjectKey",
	descr, @"TypeDescription",
	template,@"TemplateFile",
	nil];
      
      // GSMarkup
      descr = @"Generic GSMarkup File.\n\n"
		@"This is the interface description of GNUstep Renaissance.";
      template = [bundle pathForResource:@"gsmarkup" ofType:@"template"];
      gsmarkupDict =[NSDictionary dictionaryWithObjectsAndKeys:
        PCGSMarkupFiles,@"ProjectKey",
        descr,@"TypeDescription",
	template, @"TemplateFile",
        nil];


      dict = [[NSDictionary alloc] initWithObjectsAndKeys:
	ccDict, CFile,
        chDict, CHeader,
        protocolDict, ProtocolFile,
        headerDict, ObjCHeader,
        classDict, ObjCClass,
	classPpDict, ObjCppClass,	   
        gsmarkupDict, GSMarkupFile,
	nil];
    }

  return _creator;
}

- (id)init
{
  self = [super init];
  activeProject = nil;

  return self;
}

- (void)dealloc
{
  RELEASE(newFilePanel);
  RELEASE(dict);

  [super dealloc];
}

- (NSDictionary *)creatorDictionary
{
  return dict;
}

- (void)newFileInProject:(PCProject *)aProject
{
  // Set to nil after panel closing
  activeProject = aProject;
  [self showNewFilePanel];
}

- (void)createFileOfType:(NSString *)fileType
		    path:(NSString *)path
		 project:(PCProject *)project
{
  NSDictionary *newFiles;

  newFiles = [self filesToCreateForFileOfType:fileType 
					 path:path
			    withComplementary:YES];

  [self createFiles:newFiles inProject:project];
}

- (NSDictionary *)filesToCreateForFileOfType:(NSString *)type
					path:(NSString *)path
			   withComplementary:(BOOL)complementary
{
  NSMutableDictionary *files = nil;
  NSString            *newFile = nil;

  // A class and possibly a header
  files = [NSMutableDictionary dictionaryWithCapacity:2];

  // Remove file extension from "path"
  if (![[path pathExtension] isEqualToString: @""])
    {
      path = [path stringByDeletingPathExtension];
    }
  
  // Objective-C Class
  if ([type isEqualToString:ObjCClass]) 
    {
      newFile = [path stringByAppendingPathExtension:@"m"];
      [files setObject:[dict objectForKey:ObjCClass] forKey:newFile];
    }
  // Objective-C++ Class
  else if ([type isEqualToString:ObjCppClass]) 
    {
      newFile = [path stringByAppendingPathExtension:@"mm"];
      [files setObject:[dict objectForKey:ObjCppClass] forKey:newFile];
    }
  // C File
  else if ([type isEqualToString:CFile]) 
    {
      newFile = [path stringByAppendingPathExtension:@"c"];
      [files setObject:[dict objectForKey:CFile] forKey:newFile];
    }

  // C Header
  // When creating C file also create C Header file
  if ([type isEqualToString:CHeader] ||
      ([type isEqualToString:CFile] && complementary)) 
    {
      newFile = [path stringByAppendingPathExtension:@"h"];
      [files setObject:[dict objectForKey:CHeader] forKey:newFile];
    }
  // Objective-C Header
  // When creating Objective C Class file also create Objective C Header file
  else if ([type isEqualToString:ObjCHeader] ||
	   ([type isEqualToString:ObjCClass] && complementary))
    {
      newFile = [path stringByAppendingPathExtension:@"h"];
      [files setObject:[dict objectForKey:ObjCHeader] forKey:newFile];
    }
  // GSMarkup
  else if ([type isEqualToString:GSMarkupFile])
    {
      newFile = [path stringByAppendingPathExtension:@"gsmarkup"];
      [files setObject:[dict objectForKey:GSMarkupFile] forKey:newFile];
    }
  // Objective-C Protocol
  else if ([type isEqualToString:ProtocolFile]) 
    {
      newFile = [path stringByAppendingPathExtension:@"h"];
      [files setObject:[dict objectForKey:ProtocolFile] forKey:newFile];
    }

  return files;
}

- (BOOL)createFiles:(NSDictionary *)fileList
	  inProject:(PCProject *)aProject
{
  PCFileManager  *pcfm = [PCFileManager defaultManager];
  NSEnumerator   *enumerator = [[fileList allKeys] objectEnumerator];
  NSString       *template = nil;
  NSString       *newFile = nil;
  NSDictionary   *fileType = nil;
  NSString       *key = nil;

  while ((newFile = [enumerator nextObject])) 
    {
      fileType = [fileList objectForKey:newFile];
      key = [fileType objectForKey:@"ProjectKey"];
      template = [fileType objectForKey:@"TemplateFile"];

      if ([pcfm copyFile:template toFile:newFile])
        {
          [self replaceTagsInFileAtPath:newFile withProject:aProject];
          [aProject addFiles:[NSArray arrayWithObject:newFile]
                      forKey:key
                      notify:YES];
        }
    }

  // Notify the browser!
  [[NSNotificationCenter defaultCenter] 
    postNotificationName:@"ProjectDictDidChangeNotification"
                  object:self];

  return YES;
}

- (void)replaceTagsInFileAtPath:(NSString *)newFile
                    withProject:(PCProject *)aProject
{
  NSString *projectName = [aProject projectName];
  NSString *date = [[NSCalendarDate calendarDate] description];
  int      year = [[NSCalendarDate calendarDate] yearOfCommonEra];
  NSString *aFile = [newFile lastPathComponent];
  NSString *UCfn = [[aFile stringByDeletingPathExtension] uppercaseString];
  NSString *fn = [aFile stringByDeletingPathExtension];
  NSRange  subRange;

#ifdef WIN32 	 
  file = [[NSMutableString stringWithContentsOfFile: newFile 	 
					   encoding: NSUTF8StringEncoding 	 
					      error: NULL] retain]; 	 
#else
  file = [[NSMutableString stringWithContentsOfFile:newFile] retain];
#endif

  while ((subRange = [file rangeOfString:@"$FULLFILENAME$"]).length)
    {
      [file replaceCharactersInRange:subRange withString:aFile];
    }
    
  while ((subRange = [file rangeOfString:@"$FILENAME$"]).length)
    {
      [file replaceCharactersInRange:subRange withString:fn];
    }

  while ((subRange = [file rangeOfString:@"$UCFILENAME$"]).length)
    {
      [file replaceCharactersInRange:subRange withString:UCfn];
    }

  while ((subRange = [file rangeOfString:@"$USERNAME$"]).length)
    {
      [file replaceCharactersInRange:subRange withString:NSUserName()];
    }
    
  while ((subRange = [file rangeOfString:@"$FULLUSERNAME$"]).length)
    {
      [file replaceCharactersInRange:subRange withString:NSFullUserName()];
    }

  while ((subRange = [file rangeOfString:@"$PROJECTNAME$"]).length)
    {
      [file replaceCharactersInRange:subRange withString:projectName];
    }

  while ((subRange = [file rangeOfString:@"$DATE$"]).length)
    {
      [file replaceCharactersInRange:subRange withString:date];
    }
    
  while ((subRange = [file rangeOfString:@"$YEAR$"]).length)
    {
      [file replaceCharactersInRange:subRange 
	withString:[[NSNumber numberWithInt:year] stringValue]];
    }

#ifdef WIN32 	 
  [file writeToFile: newFile 	 
	 atomically: YES 	 
	   encoding: NSUTF8StringEncoding 	 
	      error: NULL]; 	 
#else
  [file writeToFile:newFile atomically:YES];
#endif

  [file release];
}

@end


@implementation PCFileCreator (UInterface)

// ============================================================================
// ==== "New File in Project" Panel
// ============================================================================
- (void)showNewFilePanel
{
  if (!newFilePanel)
    {
      if ([NSBundle loadNibNamed:@"NewFile" owner:self] == NO)
	{
	  PCLogError(self, @"error loading NewFile NIB!");
	  return;
	}
      [newFilePanel setFrameAutosaveName:@"NewFile"];
      if (![newFilePanel setFrameUsingName: @"NewFile"])
    	{
	  [newFilePanel center];
	}
      [nfImage setImage:[NSApp applicationIconImage]];
      [nfTypePB setRefusesFirstResponder:YES];
      [nfTypePB removeAllItems];
      [nfTypePB addItemsWithTitles:
	[[dict allKeys] 
	  sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)]];
      [nfTypePB selectItemAtIndex:0];
      [nfCancelButton setRefusesFirstResponder:YES];
      [nfCreateButton setRefusesFirstResponder:YES];
      [nfAddHeaderButton setRefusesFirstResponder:YES];
      [newFilePanel setDefaultButtonCell:[nfCreateButton cell]];
    }

  [self newFilePopupChanged:nfTypePB];

  [newFilePanel makeKeyAndOrderFront:self];
  [nfNameField setStringValue:@""];
  [newFilePanel makeFirstResponder:nfNameField];

  [newFilePanel setLevel:NSModalPanelWindowLevel];
  [NSApp runModalForWindow:newFilePanel];
}

- (void)closeNewFilePanel:(id)sender
{
  [newFilePanel orderOut:self];
  [NSApp stopModal];

  activeProject = nil;
}

- (void)createFile:(id)sender
{
  if ([self createFile])
    {
      [self closeNewFilePanel:self];
    }
  else
    {
      [newFilePanel makeKeyAndOrderFront:self];
    }
}

- (void)newFilePopupChanged:(id)sender
{
  NSString     *typeTitle = [sender titleOfSelectedItem];
  NSDictionary *fileType = [dict objectForKey:typeTitle];

  if (!fileType)
    {
      return;
    }

  [nfDescriptionTV setString:[fileType objectForKey:@"TypeDescription"]];
  [nfAddHeaderButton setState:NSOffState];
  if ([typeTitle isEqualToString:ObjCClass] || 
      [typeTitle isEqualToString:CFile])
    {
      [nfAddHeaderButton setEnabled:YES];
    }
  else
    {
      [nfAddHeaderButton setEnabled:NO];
    }
}

- (void)controlTextDidChange:(NSNotification *)aNotif
{
  if ([aNotif object] != nfNameField)
    {
      return;
    }

  // TODO: Add check for valid file names
  if ([[nfNameField stringValue] length] > 0)
    {
      [nfCreateButton setEnabled:YES];
    }
  else
    {
      [nfCreateButton setEnabled:NO];
    }
}

- (BOOL)createFile
{
  NSString      *fileName = [nfNameField stringValue];
  NSString      *fileType = [nfTypePB titleOfSelectedItem];
  NSString      *path = nil;
  NSString      *key = nil;
  NSDictionary  *newFiles = nil;
  NSEnumerator  *enumerator = nil;
  NSString      *filePath = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          complementary;

  path = [[activeProject projectPath] stringByAppendingPathComponent:fileName];
  // Create file
  if (path) 
    {
      // Get file list for creation
      complementary = [nfAddHeaderButton state]==NSOnState ? YES : NO;
      newFiles = [self filesToCreateForFileOfType:fileType 
			       		     path:path
				withComplementary:complementary];

      // Check if project already has files with such names
      enumerator = [[newFiles allKeys] objectEnumerator]; 
      while ((filePath = [enumerator nextObject])) 
	{
	  key = [[newFiles objectForKey:filePath] objectForKey:@"ProjectKey"];
	  fileName = [filePath lastPathComponent];
	  if (![activeProject doesAcceptFile:fileName forKey:key]) 
	    {
	      NSRunAlertPanel(@"New File in Project", 
			      @"Project %@ already has file %@ in %@",
			      @"OK", nil, nil, 
			      [activeProject projectName], fileName, key);
	      return NO;
	    }
	  if ([fm fileExistsAtPath:filePath])
	    {
	      int  ret;

	      ret = NSRunAlertPanel
		(@"New File in Project", 
		 @"Project directory %@ already has file %@.\n"
		 @"Do you want to overwrite it?",
		 @"Stop", @"Overwrite", nil, 
		 [filePath stringByDeletingLastPathComponent], 
		 fileName);

	      if (ret == NSAlertDefaultReturn) // Stop
		{
		  return NO;
		}
	      else // Overwrite. Remove destination of copy operation
		{
		  [fm removeFileAtPath:filePath handler:nil];
		}
	    }
	}

      // Create files
      return [self createFiles:newFiles inProject:activeProject];
    }

  return NO;
}

@end

