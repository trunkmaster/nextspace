/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2004 Free Software Foundation

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

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCProjectEditor.h>
#import <ProjectCenter/PCFileNameField.h>

#import <ProjectCenter/PCLogController.h>

#import "Modules/Preferences/Misc/PCMiscPrefs.h"

NSString *PCBrowserDidSetPathNotification = @"PCBrowserDidSetPathNotification";

@implementation PCProjectBrowser

// ============================================================================
// ==== Intialization & deallocation
// ============================================================================

- (id)initWithProject:(PCProject *)aProject
{
  if ((self = [super init]))
    {
      project = aProject;

      browser = [[NSBrowser alloc] initWithFrame:NSMakeRect(-10,-10,256,128)];
      [browser setRefusesFirstResponder:YES];
//      [browser setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
      [browser setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable];
      [browser setTitled:NO];
      [browser setMaxVisibleColumns:4];
      [browser setSeparatesColumns:NO];
      [browser setAllowsMultipleSelection:YES];
      [browser setDelegate:self];
      [browser setTarget:self];
      [browser setAction:@selector(click:)];
      [browser setDoubleAction:@selector(doubleClick:)];
      [browser setRefusesFirstResponder:YES];
      [browser loadColumnZero];

      [[NSNotificationCenter defaultCenter] 
	addObserver:self 
	   selector:@selector(projectDictDidChange:)
	       name:PCProjectDictDidChangeNotification 
	     object:nil];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog (@"PCProjectBrowser: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(browser);

  [super dealloc];
}

// ============================================================================
// ==== Accessory methods
// ============================================================================

- (NSView *)view
{
  return browser;
}

// Returns nil if multiple files or category selected
- (NSString *)nameOfSelectedFile
{
  NSString       *name = [[browser path] lastPathComponent];
  NSString       *category = [self nameOfSelectedCategory];
  NSMutableArray *pathArray;
  NSEnumerator   *enumerator;
  NSString       *pathItem;

//  NSLog(@"---> Selected: %@: category: %@", name, category);

  if ([[browser selectedCells] count] != 1 ||
      !category || 
      [name isEqualToString:category])
    {
      return nil;
    }

  pathArray = [[[browser path] pathComponents] mutableCopy];
  enumerator = [pathArray objectEnumerator];
  while ((pathItem = [enumerator nextObject]))
    {
      if ([pathItem isEqualToString:category])
	{
	  name = [enumerator nextObject];
	  break;
	}
    }
  RELEASE(pathArray);
    
  return name;
}

// Returns nil if multiple files selected
- (NSString *)pathToSelectedFile
{
  NSString *name = [self nameOfSelectedFile];
  NSString *path = [browser path];

  if (!name)
    {
      path = nil;
    }

  return path;
}

// Returns 'nil' if selected:
// - root project (browser path is @"/")
// - multiple categories
// - name of subproject
// Should not call any of the nameOf... or pathTo... methods to prevent
// cyclic recursion.
- (NSString *)nameOfSelectedCategory
{
  NSArray   *pathArray = [[browser path] componentsSeparatedByString:@"/"];
  NSString  *lastPathElement = [[browser path] lastPathComponent];
  PCProject *activeProject = [[project projectManager] activeProject];
  NSArray   *rootCategories = [activeProject rootCategories];
  NSString  *name = nil;
  int       i;

  // Name of subproject selected: Change active project to superproject
  // to check category against superproject's catgory list.
  // But: path '/Subproject/Foo' and '/Subprojects/Foo/Subprojects' will
  // return the same category 'Subprojects' and active project will be 'Foo'
  // in both cases
//      ![[self nameOfSelectedFile] isEqualToString:lastPathElement])
/*  if ([lastPathElement isEqualToString:[activeProject projectName]])
    {
      activeProject = [activeProject superProject];
      rootCategories = [activeProject rootCategories];
    }*/

  // Multiple categories selected
  if (([rootCategories containsObject:lastPathElement]
	  && [[browser selectedCells] count] > 1))
    {
      return nil;
    }

  for (i = [pathArray count] - 1; i >= 0; i--)
    {
      if ([rootCategories containsObject:[pathArray objectAtIndex:i]])
	{
	  name = [pathArray objectAtIndex:i];
	  break;
	}
    }

  // Subproject's name selected
  if ([name isEqualToString:@"Subprojects"] &&
      [lastPathElement isEqualToString:[activeProject projectName]])
    {
      return nil;
    }
  
  return name;
}

// Returns nil of multiple categories selected
- (NSString *)pathToSelectedCategory
{
  NSString       *path = nil;
  NSString       *selectedCategory = [self nameOfSelectedCategory];
  NSMutableArray *bPathArray = nil;
  int            i;
 
  if (selectedCategory)
    {
      bPathArray = [NSMutableArray arrayWithArray:[[browser path]
	componentsSeparatedByString:@"/"]];
      i = [bPathArray count] - 1;
      while (![[bPathArray objectAtIndex:i] isEqualToString:selectedCategory])
	{
	  [bPathArray removeObjectAtIndex:i];
	  i = [bPathArray count] - 1;
	}
      path = [bPathArray componentsJoinedByString:@"/"];
    }
  
  return path;
}

// Returns nil of multiple categories selected
- (NSString *)pathFromSelectedCategory
{
  NSString       *selectedCategory = [self nameOfSelectedCategory];
  NSMutableArray *bPathArray;
  NSString       *path = nil;
 
  if (selectedCategory)
    {
      bPathArray = 
	[[[browser path] componentsSeparatedByString:@"/"] mutableCopy];
      while (![[bPathArray objectAtIndex:1] isEqualToString:selectedCategory])
	{
	  [bPathArray removeObjectAtIndex:1];
	}
      path = [bPathArray componentsJoinedByString:@"/"];
      RELEASE(bPathArray);
    }
  
  return path;
}

- (NSString *)nameOfSelectedRootCategory
{
  NSString *categoryPath = [self pathToSelectedCategory];
  NSArray  *pathComponents;

  if ([categoryPath isEqualToString:@"/"] || [categoryPath isEqualToString:@""])
    {
      return nil;
    }
    
  pathComponents = [categoryPath componentsSeparatedByString:@"/"];

  return [pathComponents objectAtIndex:1];
}

- (NSArray *)selectedFiles
{
  NSArray        *cells = [browser selectedCells];
  NSMutableArray *files = [[NSMutableArray alloc] initWithCapacity: 1];
  int            i;
  int            count = [cells count];
  PCProject      *activeProject = [[project projectManager] activeProject];

  // Return nil if categories selected
  if ([cells count] == 0
      || [[activeProject rootCategories] 
      containsObject:[[cells objectAtIndex:0] stringValue]])
    {
      return nil;
    }

  for (i = 0; i < count; i++)
    {
      [files addObject: [[cells objectAtIndex: i] stringValue]];
    }
    
  return AUTORELEASE((NSArray *)files);
}

- (NSString *)path
{
  return [browser path];
}

- (BOOL)setPath:(NSString *)path
{
  BOOL res;

  if ([[browser path] isEqualToString: path])
    {
      return YES;
    }

//  PCLogInfo(self, @"[setPath]: %@", path);

  res = [browser setPath:path];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCBrowserDidSetPathNotification
                  object:self];

  return res;
}

- (void)reloadLastColumnAndNotify:(BOOL)yn
{
  NSInteger column = [browser lastColumn];
  NSString  *category = [self nameOfSelectedCategory];
  NSInteger selectedColumn = [browser selectedColumn];
  NSMatrix  *colMatrix = [browser matrixInColumn:selectedColumn];
  NSInteger rowCount = 0, colCount = 0, spCount = 0;
  PCProject *activeProject = [[project projectManager] activeProject];
  NSString  *selCellTitle = [[browser selectedCell] stringValue];

  if ([category isEqualToString:@"Subprojects"]
      && ![selCellTitle isEqualToString:@"Subprojects"])
    { // /Subprojects/Name selected
      if ([selCellTitle isEqualToString:[activeProject projectName]])
	{
	  activeProject = [activeProject superProject];
	}
      [colMatrix getNumberOfRows:&rowCount columns:&colCount];
      spCount = [[[activeProject projectDict] 
	objectForKey:PCSubprojects] count];
    }

  if ([category isEqualToString:@"Subprojects"] && rowCount != spCount
      && ![[[browser selectedCell] stringValue] isEqualToString:@"Subprojects"])
    {
      column = selectedColumn;
    }
  
  [browser reloadColumn:column];

  if (yn)
    {
      [[NSNotificationCenter defaultCenter]
	postNotificationName:PCBrowserDidSetPathNotification
                      object:self];
    }
}

- (void)reloadLastColumnAndSelectFile:(NSString *)file
{
  PCProject *p = [[project projectManager] activeProject];
  NSString  *catKey = [p keyForCategory:[self nameOfSelectedCategory]];
  NSArray   *array = [[p projectDict] objectForKey:catKey];
  NSString  *path = [self path];
  NSString  *tmp;

  // Determine last column with files (removing classes and methods from path)
  tmp = [[path lastPathComponent] substringWithRange:NSMakeRange(0,1)];
  while ([tmp isEqualToString:@"@"]     // classes
	 || [tmp isEqualToString:@"+"]  // factory methods
	 || [tmp isEqualToString:@"-"]) // instance methods
    {
      path = [path stringByDeletingLastPathComponent];
      tmp = [[path lastPathComponent] substringWithRange:NSMakeRange(0,1)];
    }

  NSLog(@"PCBrowser set path: %@", path);
  [self setPath:[path stringByDeletingLastPathComponent]];
  [self reloadLastColumnAndNotify:NO];

  [browser selectRow:[array indexOfObject:file] inColumn:[browser lastColumn]];

  // Notify
  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCBrowserDidSetPathNotification
                  object:self];
}

// ============================================================================
// ==== Actions
// ============================================================================

- (void)click:(id)sender
{
  NSString  *category;
  PCProject *activeProject;
  NSString  *browserPath;
  NSString  *filePath;
  NSString  *fileName;

  if (sender != browser)
    {
      return;
    }

  category = [self nameOfSelectedCategory];
  activeProject = [[project projectManager] activeProject];
  browserPath = [self path];
  filePath = [self pathToSelectedFile];
  fileName = [self nameOfSelectedFile];

  NSLog(@"[click] category: %@ forProject: %@ fileName: %@", 
	category, [activeProject projectName], fileName);

//  ![fileName isEqualToString:[activeProject projectName]] &&
  if (filePath &&
      [filePath isEqualToString:browserPath] && 
      category &&
      ![category isEqualToString:@"Libraries"]
      )
    {
      NSLog(@"[click] category: %@ filePath: %@", category, filePath);
      [[activeProject projectEditor] openEditorForCategoryPath:browserPath
					    	      windowed:NO];
    }

  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCBrowserDidSetPathNotification 
                  object:self];
}

- (void)doubleClick:(id)sender
{
  NSString    *category = [self nameOfSelectedCategory];
  id          selectedCell;
  NSString    *fileName;
  PCProject   *activeProject;
  NSString    *key;
  NSString    *filePath;
  id <PCPreferences> prefs = [[project projectManager] prefController];
  NSWorkspace *workspace;
  NSString    *appName, *type;
  
  if ((sender != browser) || [category isEqualToString:@"Libraries"])
    {
      return;
    }

  selectedCell = [sender selectedCell];
  fileName = [[sender selectedCell] stringValue];
  activeProject = [[project projectManager] activeProject];
  key = [activeProject keyForCategory:category];
  filePath = [activeProject pathForFile:fileName forKey:key];

  if ([self nameOfSelectedFile] != nil) 
    {
      BOOL foundFile = NO;
      BOOL foundApp = NO;
      // PCLogInfo(self, @"{doubleClick} filePath: %@", filePath);*/

      workspace = [NSWorkspace sharedWorkspace];
      foundFile = [workspace getInfoForFile:filePath 
			    application:&appName 
				   type:&type];
      foundApp = foundFile && appName;
      // NSLog (@"Open file: %@ with app: %@", filePath, appName);

      // If 'Editor' role was set in .GNUstepExtPrefs application
      // name will be returned according that setting. Otherwise
      // 'ProjectCenter.app' will be returned accoring to NSTypes
      // from Info-gnustep.plist file of PC.
      if(foundApp == NO || [appName isEqualToString:@"ProjectCenter.app"])
	{
	  appName = [prefs stringForKey:Editor];

	  if (![appName isEqualToString:@"ProjectCenter"])
	    {
	      [workspace openFile:filePath 
		  withApplication:appName];
	    }
	  else
	    {
	      [[activeProject projectEditor] 
		openEditorForCategoryPath:[self path]
				 windowed:YES];
	    }
	}
      else
	{
	  [workspace openFile:filePath];
	}
    }
  else 
    {
      if ([[selectedCell title] isEqualToString:@"Subprojects"]) 
	{
	  [[project projectManager] addSubproject];
	}
      else 
	{
	  [[project projectManager] addProjectFiles];
	}
    }
}

// ============================================================================
// ==== Notifications
// ============================================================================

- (void)projectDictDidChange:(NSNotification *)aNotif
{
  NSDictionary *notifObject = [aNotif object];
  PCProject    *changedProject = [notifObject objectForKey:@"Project"];
  NSString     *changedAttribute = [notifObject objectForKey:@"Attribute"];

  if (!browser)
    {
      return;
    }

  if (changedProject != project 
      && changedProject != [project activeSubproject]
      && [changedProject superProject] != [project activeSubproject])
    {
      return;
    }
    
//  NSLog(@"PCPB: projectDictDidChange in %@ (%@)",
//	[changedProject projectName], [project projectName]);

  // If project dictionary changed after files adding/removal, 
  // refresh file list
  if ([[changedProject rootKeys] containsObject:changedAttribute])
    {
      [self reloadLastColumnAndNotify:YES];
    }
}

@end

@implementation PCProjectBrowser (ProjectBrowserDelegate)

- (void)     browser:(NSBrowser *)sender
 createRowsForColumn:(NSInteger)column
	    inMatrix:(NSMatrix *)matrix
{
  NSString   *pathToCol;
  NSArray    *files;
  NSUInteger i = 0;
  NSUInteger count = 0;

  if (sender != browser || !matrix || ![matrix isKindOfClass:[NSMatrix class]])
    {
      return;
    }

  pathToCol = [sender pathToColumn:column];
  files = [project contentAtCategoryPath:pathToCol];
  if (files)
    {
      count = [files count];
    }

  for (i = 0; i < count; ++i) 
    {
      NSMutableString *categoryPath = nil;
      id              cell;
      
      categoryPath = [NSMutableString stringWithString:pathToCol];
      
      [matrix insertRow:i];

      cell = [matrix cellAtRow:i column:0];
      [cell setStringValue:[files objectAtIndex:i]];

      if (![categoryPath isEqualToString:@"/"])
	{
	  [categoryPath appendString:@"/"];
	}
      [categoryPath appendString:[files objectAtIndex:i]];

      [cell setLeaf:![project hasChildrenAtCategoryPath:categoryPath]];
      [cell setRefusesFirstResponder:YES];
    }
}

@end

@implementation PCProjectBrowser (FileNameIconDelegate)

// If file was opened in editor: 
// 1. Determine editor
// 2. Ask editor for icon
- (NSImage *)_editorIconImageForFile:(NSString *)fileName
{
  PCProjectEditor *projectEditor = [project projectEditor];
  id<CodeEditor>  editor = nil;
  NSString        *categoryName = [self nameOfSelectedCategory];
  NSString        *categoryKey = [project keyForCategory:categoryName];
  NSString        *filePath;

  filePath = [project pathForFile:fileName forKey:categoryKey];
  editor = [projectEditor editorForFile:filePath];
  if (editor != nil)
    {
      return [editor fileIcon];
    }

  return nil;
}

- (NSImage *)fileNameIconImage
{
  NSString  *categoryName = nil;
  NSString  *fileName = nil;
  NSString  *iconName = nil;
  NSImage   *icon = nil;
  PCProject *activeProject = [[project projectManager] activeProject];

  fileName = [self nameOfSelectedFile];
  if (fileName)
    {
      if ((icon = [self _editorIconImageForFile:fileName]))
	{
	  return icon;
	}
    }
  else
    {
      categoryName = [self nameOfSelectedCategory];
    }

/*  PCLogError(self,@"{setFileIcon} file %@ category %@", 
	    fileName, categoryName);*/
  
  if ([[self selectedFiles] count] > 1)
    {
      iconName = [[NSString alloc] initWithString:@"MultiFiles"];
    }
  // Nothing or subproject name selected
  else if ((!categoryName && !fileName) ||
	   [fileName isEqualToString:[activeProject projectName]]) 
    {
      iconName = [[NSString alloc] initWithString:@"FileProject"];
    }
  else if ([categoryName isEqualToString: @"Classes"])
    {
      iconName = [[NSString alloc] initWithString:@"classSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Headers"])
    {
      iconName = [[NSString alloc] initWithString:@"headerSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Other Sources"])
    {
      iconName = [[NSString alloc] initWithString:@"genericSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Interfaces"])
    {
      iconName = [[NSString alloc] initWithString:@"nibSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Images"])
    {
      iconName = [[NSString alloc] initWithString:@"iconSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Other Resources"])
    {
      iconName = [[NSString alloc] initWithString:@"otherSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Subprojects"])
    {
      iconName = [[NSString alloc] initWithString:@"subprojectSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Documentation"])
    {
      iconName = [[NSString alloc] initWithString:@"helpSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Supporting Files"])
    {
      iconName = [[NSString alloc] initWithString:@"genericSuitcase"];
    }
  else if ([categoryName isEqualToString: @"Libraries"])
    {
      iconName = [[NSString alloc] initWithString:@"librarySuitcase"];
    }
  else if ([categoryName isEqualToString: @"Non Project Files"])
    {
      iconName = [[NSString alloc] initWithString:@"projectSuitcase"];
    }
    
  if (iconName != nil)
    {
      icon = IMAGE(iconName);
      RELEASE(iconName);
    }
  else
    {
      icon = [[NSWorkspace sharedWorkspace] iconForFile:fileName];
    }

  return icon;
}

- (NSString *)fileNameIconTitle
{
  NSString *categoryName = [self nameOfSelectedCategory];
  NSString *fileName = [self nameOfSelectedFile];
  int      filesCount = [[self selectedFiles] count];

  if (filesCount > 1)
    {
      return [NSString stringWithFormat:@"%i files", filesCount];
    }
  else if (fileName)
    {
      return fileName;
    }
  else if (categoryName)
    {
      return categoryName;
    }

  return PCFileNameFieldNoFiles;
}

- (NSString *)fileNameIconPath
{
  NSString *fileName = [self nameOfSelectedFile];
  NSString *category = [self nameOfSelectedCategory];

  return [project pathForFile:fileName 
		       forKey:[project keyForCategory:category]];
}

- (BOOL)canPerformDraggingOf:(NSArray *)paths
{
  NSString     *category = [self nameOfSelectedCategory];
  NSString     *categoryKey = [project keyForCategory:category];
  NSArray      *fileTypes = [project fileTypesForCategoryKey:categoryKey];
  NSEnumerator *e = [paths objectEnumerator];
  NSString     *s;

  NSLog(@"PCBrowser: canPerformDraggingOf -> %@", category);

  if (!category || ([self nameOfSelectedFile] != nil))
    {
      return NO;
    }

  if (![project isEditableCategory:category])
    {
      return NO;
    }

  // Check if we can accept files of such types
  while ((s = [e nextObject]))
    {
      if (![fileTypes containsObject:[s pathExtension]])
	{
	  return NO;
	}
    }

  return YES;
}

- (BOOL)prepareForDraggingOf:(NSArray *)paths
{
  return YES;
}

- (BOOL)performDraggingOf:(NSArray *)paths
{
  NSString     *category = [self nameOfSelectedCategory];
  NSString     *categoryKey = [project keyForCategory:category];
  NSEnumerator *pathsEnum = [paths objectEnumerator];
  NSString     *file = nil;

  while ((file = [[pathsEnum nextObject] lastPathComponent]))
    {
      if (![project doesAcceptFile:file forKey:categoryKey])
	{
	  return NO;
	}
    }

  return [project addAndCopyFiles:paths forKey:categoryKey];
}

@end
