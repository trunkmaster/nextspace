/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2022 Free Software Foundation

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
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCFileCreator.h>
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCAddFilesPanel.h>

#import <Protocols/Preferences.h>
#import <ProjectCenter/PCLogController.h>

@implementation PCFileManager

// ===========================================================================
// ==== Class methods
// ===========================================================================

static PCFileManager *_mgr = nil;

+ (PCFileManager *)defaultManager
{
  if (_mgr == nil)
    {
      _mgr = [[self alloc] init];
    }

  return _mgr;
}

// ===========================================================================
// ==== Init and free
// ===========================================================================

- (id)initWithProjectManager:(PCProjectManager *)aProjectManager
{
  if ((self = [super init])) 
    {
      projectManager = aProjectManager;
    }
  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog (@"PCFileManager: dealloc");
#endif

  if (addFilesPanel)
    {
      RELEASE(addFilesPanel);
    }
  
  [super dealloc];
}

// ===========================================================================
// ==== NSFileManager delegate methods
// ===========================================================================
- (BOOL)     fileManager:(NSFileManager *)manager 
 shouldProceedAfterError:(NSDictionary *)errorDict
{
  NSLog(@"FM error is: %@", [errorDict objectForKey:@"Error"]);

  return YES;
}

// ===========================================================================
// ==== File handling
// ===========================================================================
- (BOOL)createDirectoriesIfNeededAtPath:(NSString *)path
{
  NSString       *_path = [NSString stringWithString:path];
  NSString       *_oldPath = nil;
  NSMutableArray *pathArray = [NSMutableArray array];
  NSFileManager  *fm = [NSFileManager defaultManager];
  BOOL           isDir;
  int            i;

  /* We stop when we find a file, or when we can't remove any path
   * component any more.  Else, you may end up in an infinite loop if
   * _path = @"".
   */
  isDir = NO;
  while (_path != nil  
	 &&  ![_path isEqualToString: _oldPath]
	 &&  ![fm fileExistsAtPath:_path isDirectory:&isDir])
    {
      [pathArray addObject:[_path lastPathComponent]];
      _oldPath = _path;
      _path = [_path stringByDeletingLastPathComponent];
    }

  if (!isDir)
    {
      return NO;
    }

  if ([_path length] != [path length])
    {
      for (i = [pathArray count]-1; i >= 0; i--)
	{
	  _path = 
	    [_path stringByAppendingPathComponent:[pathArray objectAtIndex:i]];
	  if ([fm createDirectoryAtPath:_path attributes:nil] == NO)
	    {
	      return NO;
	    }
	}
    }

  return YES;
}

- (BOOL)copyFile:(NSString *)file toFile:(NSString *)toFile
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString      *directoryPath = nil;

  if (!file)
    {
      return NO;
    }

  if (![fm fileExistsAtPath:toFile]) 
    {
      directoryPath = [toFile stringByDeletingLastPathComponent];
      if ([self createDirectoriesIfNeededAtPath:directoryPath] == NO)
	{
	  NSRunAlertPanel(@"Copy File",
			  @"Couldn't create directories at path %@",
			  @"Ok",nil,nil, directoryPath);
	  return NO;
	}

      if ([fm copyPath:file toPath:toFile handler:self] == NO)
	{
	  NSRunAlertPanel(@"Copy File",
			  @"Couldn't copy file %@ to %@",
			  @"Ok",nil,nil, file, toFile);
	  return NO;
	}
    }

  return YES;
}

- (BOOL)copyFile:(NSString *)file intoDirectory:(NSString *)directory
{
  NSString *path = nil;

  if (!file)
    {
      return NO;
    }
    
  path = [directory stringByAppendingPathComponent:[file lastPathComponent]];

  if (![self copyFile:file toFile:path])
    { // No need to open aler panel here
      return NO;
    }

  return YES;
}

- (BOOL)copyFile:(NSString *)file 
   fromDirectory:(NSString *)fromDir
   intoDirectory:(NSString *)toDir
{
  NSString *path = nil;

  if (!file || !fromDir || !toDir)
    {
      return NO;
    }
    
  path = [fromDir stringByAppendingPathComponent:[file lastPathComponent]];

  if (![self copyFile:path intoDirectory:toDir])
    {
      return NO;
    }

  return YES;
}

- (BOOL)copyFiles:(NSArray *)files intoDirectory:(NSString *)directory
{
  NSEnumerator *enumerator = nil;
  NSString     *file = nil;

  if (!files)
    {
      return NO;
    }

  enumerator = [files objectEnumerator];
  while ((file = [enumerator nextObject]))
    {
      if ([self copyFile:file intoDirectory:directory] == NO)
	{
	  return NO;
	}
    }

  return YES;
}

- (BOOL)removeDirectoriesIfEmptyAtPath:(NSString *)path
{
  NSFileManager *fm = [NSFileManager defaultManager];

  while ([[fm directoryContentsAtPath:path] count] == 0)
    {
      if ([fm removeFileAtPath:path handler:nil] == NO)
	{
	  NSRunAlertPanel(@"Remove Directory",
			  @"Couldn't remove empty directory at path %@",
			  @"Ok",nil,nil, path);
	  return NO;
	}
      path = [path stringByDeletingLastPathComponent];
    }

  return YES;
}

- (BOOL)removeFile:(NSString *)file
     fromDirectory:(NSString *)directory
 removeDirsIfEmpty:(BOOL)removeDirs
{
  NSString      *path = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  
  if (!file)
    {
      return NO;
    }

  path = [directory stringByAppendingPathComponent:file];
  if (![fm removeFileAtPath:path handler:nil])
    {
      NSRunAlertPanel(@"Remove File",
		      @"Couldn't remove file at path %@",
		      @"Ok",nil,nil, path);
      return NO;
    }

  if (removeDirs)
    {
      [self removeDirectoriesIfEmptyAtPath:directory];
    }

  return YES;
}

- (BOOL)removeFileAtPath:(NSString *)file removeDirsIfEmpty:(BOOL)removeDirs
{
  return [self removeFile:[file lastPathComponent]
	    fromDirectory:[file stringByDeletingLastPathComponent]
	removeDirsIfEmpty:removeDirs];
}

- (BOOL)removeFiles:(NSArray *)files
      fromDirectory:(NSString *)directory
  removeDirsIfEmpty:(BOOL)removeDirs
{
  NSEnumerator *filesEnum = nil;
  NSString     *file = nil;

  if (!files)
    {
      return NO;
    }

  filesEnum = [files objectEnumerator];
  while ((file = [filesEnum nextObject]))
    {
      if ([self removeFile:file 
	     fromDirectory:directory 
	 removeDirsIfEmpty:removeDirs] == NO)
	{
	  return NO;
	}
    }

  return YES;
}

- (BOOL)moveFile:(NSString *)file intoDirectory:(NSString *)directory
{
  if ([self copyFile:file intoDirectory:directory] == YES)
    {
      [self removeFileAtPath:file removeDirsIfEmpty:YES];
    }
  else
    {
      NSRunAlertPanel(@"Move File",
		      @"Couldn't move file %@ to %@",
		      @"Ok",nil,nil, file, directory);
      return NO;
    }

  return YES;
}

// ===========================================================================
// ==== Find Executable
// Tries to find the first matching executable tool fromt he given, nil-terminated
// list. Returns the full path for it.
// ===========================================================================
- (NSString*) findExecutableToolFrom: (NSArray*)candidates
{
  NSFileManager	*manager;
  NSEnumerator	*pathEnumerator;
  NSString	*directory;

  manager = [NSFileManager defaultManager];
  pathEnumerator = [NSSearchPathForDirectoriesInDomains(NSDeveloperDirectory, NSAllDomainsMask, YES) objectEnumerator];

  while (nil != (directory = [pathEnumerator nextObject]))
    {
      NSEnumerator *candidateEnumerator = [candidates objectEnumerator];
      NSString     *candidate;

      while (nil != (candidate = [candidateEnumerator nextObject]))
        {
          NSString *path = [directory stringByAppendingPathComponent: candidate];
          
          if ([manager isExecutableFileAtPath: path])
	    {
	      return path;
            }
        }
    }
  return nil;
}


@end

@implementation PCFileManager (UInterface)

// ===========================================================================
// ==== Panels
// ===========================================================================

- (id)_panelForOperation:(int)op
		   title:(NSString *)title
		 accView:(NSView *)accessoryView
{
  id <PCPreferences> prefs = [projectManager prefController];
  NSString           *lastOpenDir;
  id                 panel;

  operation = op;

  switch (op)
    {
    case PCOpenFileOperation: 
      panel = [NSOpenPanel openPanel];
      [panel setCanChooseFiles:YES];
      [panel setCanChooseDirectories:NO];
      lastOpenDir = [prefs stringForKey:@"FileOpenLastDirectory"];
      break;
    case PCSaveFileOperation: 
      panel = [NSSavePanel savePanel];
      lastOpenDir = [prefs stringForKey:@"FileSaveLastDirectory"];
      break;
    case PCOpenProjectOperation: 
      panel = [NSOpenPanel openPanel];
      [panel setAllowsMultipleSelection:NO];
      [panel setCanChooseFiles:YES];
      [panel setCanChooseDirectories:YES];
      lastOpenDir = [prefs stringForKey:@"ProjectOpenLastDirectory"];
      break;
    case PCOpenDirectoryOperation: 
      panel = [NSOpenPanel openPanel];
      [panel setCanChooseFiles:NO];
      [panel setCanChooseDirectories:YES];
      lastOpenDir = [prefs stringForKey:@"FileOpenLastDirectory"];
      break;
    case PCAddFileOperation: 
      if (addFilesPanel == nil)
	{
	  addFilesPanel = [PCAddFilesPanel addFilesPanel];
	  [addFilesPanel setTreatsFilePackagesAsDirectories: YES]; 
	}
      panel = addFilesPanel;
      lastOpenDir = [prefs stringForKey:@"FileAddLastDirectory"];
      if (lastOpenDir == nil)
	{
	  PCProject *pr = [projectManager activeProject];
	  NSString *prPathRoot = [pr projectPath];
	  lastOpenDir = prPathRoot;
	}
      break;
    default:
      return nil;
      break;
    }

  if (!lastOpenDir)
    {
      lastOpenDir = NSHomeDirectory();
    }
  [panel setDirectory:lastOpenDir];
  [panel setDelegate:self];

  if (title != nil)
    {
      [panel setTitle:title];
    }
  if (accessoryView != nil)
    {
      [panel setAccessoryView:accessoryView];
    }


  return panel;
}

- (void)_saveLastDirectoryForPanel:(id)panel
{
  id <PCPreferences> prefs = [projectManager prefController];
  NSString           *key = nil;

  switch (operation)
    {
    case PCOpenFileOperation: 
      key = @"FileOpenLastDirectory";
      break;
    case PCSaveFileOperation: 
      key = @"FileSaveLastDirectory";
      break;
    case PCOpenProjectOperation: 
      key = @"ProjectOpenLastDirectory";
      break;
    case PCAddFileOperation: 
      key = @"FileAddLastDirectory";
      break;
    default:
      break;
    }

  if (key != nil)
    {
      [prefs setString:[panel directory] forKey:key notify:NO];
    }
}

- (NSMutableArray *)filesOfTypes:(NSArray *)types
		       operation:(int)op
			multiple:(BOOL)yn
			   title:(NSString *)title
			 accView:(NSView *)accessoryView
{
  id             panel;
  NSMutableArray *fileList = [[NSMutableArray alloc] init];
  int            result = -10;

  panel = [self _panelForOperation:op title:title accView:accessoryView];
  if (types != nil)
    {
      [panel setAllowedFileTypes:types];
    }

  if ((op == PCOpenFileOperation) || 
      (op == PCOpenProjectOperation) || 
      (op == PCOpenDirectoryOperation))
    {
      if ((result = [panel runModalForTypes:types]) == NSOKButton) 
	{
	  [fileList addObjectsFromArray:[panel filenames]];
	}
    }
  else if (op == PCSaveFileOperation)
    {
      if ((result = [panel runModal]) == NSOKButton) 
	{
	  [fileList addObject:[panel filename]];
	}
    }
  else if (op == PCAddFileOperation)
    {
      PCProject *project = [projectManager activeProject];
      NSString  *selectedCategory = nil;

      [panel setCategories:[project rootCategories]];
      selectedCategory = [[project projectBrowser] nameOfSelectedCategory];
      [panel selectCategory:selectedCategory];

      if ((result = [panel runModalForTypes:types]) == NSOKButton) 
	{
	  [fileList addObjectsFromArray:[panel filenames]];
	}
    }

  if (result == NSOKButton)
    {
      [self _saveLastDirectoryForPanel:panel];
      return [fileList autorelease];
    }

  return nil;
}

// ============================================================================
// ==== PCAddFilesPanel delegate
// ============================================================================

- (void)categoryChangedTo:(NSString *)category
{
  PCProject        *project = [projectManager activeProject];
  NSArray          *fileTypes = nil;
  PCProjectBrowser *browser = [project projectBrowser];
  NSString         *path = [browser path];

  [addFilesPanel setTitle:[NSString stringWithFormat:@"Add %@",category]];

  fileTypes = [project 
    fileTypesForCategoryKey:[project keyForCategory:category]];
  [addFilesPanel setFileTypes:fileTypes];

  // Set project browser path
  path = [path stringByDeletingLastPathComponent];
  path = [path stringByAppendingPathComponent:category];
  [browser setPath:path];
}

// ============================================================================
// ==== NSOpenPanel and NSSavePanel delegate
// ============================================================================

// If file name already in project -- don't show it! 
- (BOOL)panel:(id)sender shouldShowFilename:(NSString *)filename
{
  NSFileManager *fileManager = [NSFileManager defaultManager];
  BOOL          isDir;
  PCProject     *project = nil;
  NSArray       *fileTypes = nil;
  NSString      *category = nil;
  NSString      *categoryKey = nil;

  [fileManager fileExistsAtPath:filename isDirectory:&isDir];
  
  if ([[filename pathExtension] isEqualToString:@"gorm"])
    {
      isDir = NO;
    }
    
  if (sender == addFilesPanel && !isDir)
    {
      project = [projectManager activeProject];
      category = [addFilesPanel selectedCategory];
      categoryKey = [project keyForCategory:category];
      fileTypes = [project fileTypesForCategoryKey:categoryKey];
      // Wrong file extension
      if (fileTypes 
	  && ![fileTypes containsObject:[filename pathExtension]])
	{
	  return NO;
	}
      // File is already in project
      if (![project doesAcceptFile:filename forKey:categoryKey])
	{
	  return NO;
	}
    }

  return YES;
}

// Test if we should accept file name selected or entered
- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename
{
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          isDir;
  NSEnumerator  *e = nil;
  NSArray       *tempList = nil;
  NSString      *tempExtension = nil;

  if (operation == PCOpenProjectOperation)
    {
      if ([fm fileExistsAtPath:filename isDirectory:&isDir] && isDir)
	{
	  e = [[sender allowedFileTypes] objectEnumerator]; 
	  while ((tempExtension = [e nextObject]) != nil)
	    {
	      tempList = [self filesWithExtension:tempExtension
				  	   atPath:filename 
				      includeDirs:YES];
	      if ([tempList count] > 0)
		{
		  return YES;
		}
	    }

	  return NO;
	}
    }

  return YES;
}

@end

@implementation PCFileManager (Misc)

/**
 * Returns YES if the file identified by `filename' is a text file,
 * otherwise returns NO.
 *
 * The test is one by reading the first 512 bytes of the file
 * and checking whether at least 90% of the data are printable
 * ASCII characters.
 *
 * Author Saso Kiselkov
 */
- (BOOL)isTextFile:(NSString *)filename
{
  NSFileHandle *fh;
  NSData       *data;
  NSUInteger i, printable = 0;
  NSString *content;
  NSCharacterSet *alpha = [NSCharacterSet alphanumericCharacterSet];
  NSCharacterSet *spaces = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSCharacterSet *marks = [NSCharacterSet punctuationCharacterSet];

  fh = [NSFileHandle fileHandleForReadingAtPath:filename];
  if (fh == nil)
    {
      return NO;
    }

  data = [fh readDataOfLength:512];
  if ([data length] == 0)
    {
      return YES;
    }

  content = [NSString stringWithContentsOfFile: filename];
  for (i = 0; i < [content length]; i++)
    {
      if ([alpha characterIsMember: [content characterAtIndex: i]] ||
	  [spaces characterIsMember: [content characterAtIndex: i]] ||
	  [marks characterIsMember: [content characterAtIndex: i]])
	{
	  printable++;
	}
    }

  return (((double) printable / i) > 0.9);
}

- (NSArray *)filesWithExtension:(NSString *)extension
	     		 atPath:(NSString *)dirPath
     		    includeDirs:(BOOL)incDirs
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *filesList = [[NSMutableArray alloc] init];
  NSEnumerator   *e = nil;
  NSString       *temp = nil;
  BOOL           isDir;

  e = [[fm directoryContentsAtPath:dirPath] objectEnumerator];
  while ((temp = [e nextObject]) != nil)
    {
      if ([fm fileExistsAtPath:temp isDirectory:&isDir] && isDir && !incDirs)
	{
	  continue;
	}

      if ([[temp pathExtension] isEqual:extension])
	{
	  [filesList addObject:[dirPath stringByAppendingPathComponent:temp]];
	}
    }

  return [filesList autorelease];
}

@end
