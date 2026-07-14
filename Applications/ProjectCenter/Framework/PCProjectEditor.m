/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2002-2015 Free Software Foundation

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
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCBundleManager.h>

#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectWindow.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCProjectEditor.h>

#import <ProjectCenter/PCLogController.h>

@interface PCProjectEditor (CreateUI)

- (void) _createComponentView;

@end

@implementation PCProjectEditor (CreateUI)

- (void) _createComponentView
{
  NSRect     frame;
  NSTextView *textView;

  frame = NSMakeRect(0,0,562,248);
  _componentView = [[NSBox alloc] initWithFrame:frame];
  [_componentView setTitlePosition:NSNoTitle];
  [_componentView setBorderType:NSNoBorder];
  [_componentView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
  [_componentView setContentViewMargins:NSMakeSize(0.0,0.0)];

  frame = NSMakeRect (0, 0, 562, 40);
  _scrollView = [[NSScrollView alloc] initWithFrame:frame];
  [_scrollView setHasHorizontalScroller:NO];
  [_scrollView setHasVerticalScroller:YES];
  [_scrollView setBorderType:NSBezelBorder];
  [_scrollView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];

  // This is a placeholder!
  frame = [[_scrollView contentView] frame];
  textView =   [[NSTextView alloc] initWithFrame:frame];
  [textView setMinSize:NSMakeSize (0, 0)];
  [textView setMaxSize:NSMakeSize(1e7, 1e7)];
  [textView setRichText:NO];
  [textView setEditable:NO];
  [textView setSelectable:YES];
  [textView setVerticallyResizable:YES];
  [textView setHorizontallyResizable:NO];
  [textView setAutoresizingMask:(NSViewWidthSizable|NSViewHeightSizable)];
  [[textView textContainer] setWidthTracksTextView:YES];
  [_scrollView setDocumentView:textView];
  RELEASE(textView);

  frame.size = NSMakeSize([_scrollView contentSize].width,1e7);
  [[textView textContainer] setContainerSize:frame.size];

  [_componentView setContentView:_scrollView];
//  RELEASE(_scrollView);

  [_componentView sizeToFit];
}

@end

@implementation PCProjectEditor
// ===========================================================================
// ==== Initialisation
// ===========================================================================

- (id)init
{
  if ((self = [super init]))
    {
      PCLogStatus(self, @"[init]");
      _componentView = nil;
    }

  return self;
}

- (void)dealloc
{
#ifdef DEVELOPMENT
#endif
  NSLog (@"PCProjectEditor: dealloc");

//  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if (_componentView)
    {
      RELEASE(_scrollView);
      RELEASE(_componentView);
    }

//  RELEASE(_editorsDict);

  [super dealloc];
}

- (NSView *)componentView
{
  if (_componentView == nil)
    {
      [self _createComponentView];
    }

  return _componentView;
}

- (PCProject *)project
{
  return _project;
}

- (void)setProject:(PCProject *)aProject
{
  _project = aProject;
}

// ===========================================================================
// ==== Project and Editor handling
// ===========================================================================

// TODO: Should it be editor or parser?
- (BOOL)editorProvidesBrowserItemsForItem:(NSString *)item
{
  NSString        *file = [[_project projectBrowser] nameOfSelectedFile];
  PCBundleManager *bundleManager = [[_project projectManager] bundleManager];
  NSDictionary    *infoTable = nil;

  // File selected and editor should already be loaded
  if (file != nil)
    {
      if ([[item substringToIndex:1] isEqualToString:@"@"])
	{
	  return YES;
	}
    }

  // Category selected
  infoTable = [bundleManager infoForBundleType:@"editor" 
				       keyName:@"FileTypes"
				   keyContains:[item pathExtension]];

  if ([[infoTable objectForKey:@"ProvidesBrowserItems"] isEqualToString:@"YES"])
    {
      return YES;
    }
  
  return NO;
}

- (id<CodeEditor>) openEditorForFilePath: (NSString *)filePath
				windowed: (BOOL)windowed
{
  PCProject      *activeProject = [[_project projectManager] activeProject];
  NSString       *fileName = [filePath lastPathComponent];
  BOOL           editable = YES;
  id<CodeEditor> editor = nil;
  NSFileManager  *mgr = [NSFileManager defaultManager];
  
  NSLog(@"PCPE: fileName: %@, filePath: %@, project: %@", 
	fileName, filePath, [activeProject projectName]);

  if (![mgr fileExistsAtPath: filePath])
    {
      return nil;
    }

  // Determine if file should be opened for read only
  if (![_project isEditableFile:fileName])
    {
      editable = NO;
    }

  // Set the 'editor' var either by requesting already opened
  // editor or by creating the new one.
  editor = [self openEditorForFile:filePath 
			  editable:editable 
			  windowed:windowed];
  if (!editor)
    {
      NSLog(@"We don't have editor for file: %@", fileName);
      [self setActiveEditor: nil];
      return nil;
    }

  // Category path was changed by user's clicking inside browser.
  // That's why new category path must be transfered to editor.
  NSString *categoryPath = [NSString stringWithFormat: @"/Classes/%@/", fileName];
  [editor setCategoryPath:categoryPath];
  [self orderFrontEditorForFile:filePath];

  // Reload last column because editor has just been loaded
  [[_project projectBrowser] reloadLastColumnAndNotify:NO]; 
  [editor fileStructureItemSelected:fileName];

  return editor;
}

// Called by PCProjectBrowser
// categoryPath:
// 1. "/Classes/Class.m/- init"
// 2. "/Subprojects/Project/Classes/Class.m/- init"
// 3. "/Library/gnustep-gui"
- (id<CodeEditor>)openEditorForCategoryPath:(NSString *)categoryPath
    				   windowed:(BOOL)windowed
{
  NSArray        *pathArray = [categoryPath pathComponents];
  NSString       *pathLastObject = [pathArray lastObject];
  PCProject      *activeProject = [[_project projectManager] activeProject];
  NSString       *category = [[_project projectBrowser] nameOfSelectedCategory];
  NSString       *categoryKey = [activeProject keyForCategory:category];
  NSString       *fileName = nil;
  NSString       *filePath = nil;
  BOOL           editable = YES;
  id<CodeEditor> editor;

  fileName = [[[[_project projectBrowser] pathFromSelectedCategory] 
    pathComponents] objectAtIndex:2];
  filePath = [activeProject pathForFile:fileName forKey:categoryKey];

/*  NSLog(@"PCPE: fileName: %@ filePath: %@ project: %@", 
	fileName, filePath, [activeProject projectName]);*/

  // Determine if file should be opened for read only
  if (![_project isEditableFile:fileName])
    {
      editable = NO;
    }

//  NSLog(@"fileName: %@ > %@", fileName, listEntry);

  // Set the 'editor' var either by requesting already opened
  // editor or by creating the new one.
  editor = [self openEditorForFile:filePath 
			  editable:editable 
			  windowed:windowed];
  if (!editor)
    {
      NSLog(@"We don't have editor for file: %@", fileName);
      [self setActiveEditor: nil];
      return nil;
    }

  // Category path was changed by user's clicking inside browser.
  // That's why new category path must be transfered to editor.
  [editor setCategoryPath:categoryPath];
  [self orderFrontEditorForFile:filePath];

  pathLastObject = [pathArray lastObject];
/*  NSLog(@"pathArray: c: %i %@", [pathArray count], pathArray);
  NSLog(@"pathArray: lastObject %@", [pathArray lastObject]);
  NSLog(@"lastObject[1]: %@", 
  [pathLastObject substringWithRange:NSMakeRange(0,1)]);*/

  if ([pathLastObject isEqualToString:@"/"])
    {
      pathLastObject = [pathArray objectAtIndex:[pathArray count]-2];

      if ([pathLastObject isEqualToString:fileName]) // file selected
	{ // Reload last column because editor has just been loaded
	  [[_project projectBrowser] reloadLastColumnAndNotify:NO]; 
	}
      else
	{
	  [editor fileStructureItemSelected:pathLastObject];
	}
    }
  else // TODO: rethink
    {
      [editor fileStructureItemSelected:pathLastObject];
    }

  return editor;
}

- (void)orderFrontEditorForFile:(NSString *)path
{
  id<CodeEditor> editor = [_editorsDict objectForKey:path];

  if (!editor)
    {
      return;
    }

  if ([editor isWindowed])
    {
      [editor show];
    }
  else
    {
      [_componentView setContentView:[editor componentView]];
      [[_project projectWindow] setCustomContentView:_componentView];
      [[_project projectWindow] makeFirstResponder:[editor editorView]];
      [[_project projectWindow] makeKeyAndOrderFront:self];

      NSLog(@"PCPE: categoryPath - %@", [editor categoryPath]);
      [[_project projectBrowser] setPath:[editor categoryPath]];
    }
}

// ===========================================================================
// ==== File handling
// ===========================================================================

- (BOOL)saveFileAs:(NSString *)file
{
  id<CodeEditor> editor = [self activeEditor];
  NSString       *categoryPath = nil;
  BOOL           res;

  if (editor != nil)
    {
      categoryPath = [editor categoryPath];
      res = [super saveFileAs:file];
      [editor setCategoryPath:categoryPath];

      return res;
    }

  return NO;
}

// ===========================================================================
// ==== Notifications
// ===========================================================================

- (void)editorDidOpen:(NSNotification *)aNotif
{
/*  PCEditor         *editor = [aNotif object];
  PCProjectBrowser *browser = [_project projectBrowser];
  NSString         *path = [browser path];
  
  // Active editor is set after PCEditorDidBecomeActiveNotification will be
  // sent, but we should do it here for loading list of classes into browser.
  [self setActiveEditor:editor];
  [browser reloadLastColumnAndNotify:NO];
  [browser setPath:path];*/
  NSLog(@"PCProjectEditor editorDidOpen!");
}

- (void)editorDidClose:(NSNotification *)aNotif
{
  id editor = [aNotif object];

  // It is not our editor
  if (![[_editorsDict allValues] containsObject:editor])
    {
      return;
    }
  
  [_editorsDict removeObjectForKey:[editor path]];

  if ([_editorsDict count])
    {
      NSString       *lastEditorKey = [[_editorsDict allKeys] lastObject];
      id<CodeEditor> lastEditor = [_editorsDict objectForKey:lastEditorKey];

      [_componentView setContentView:[lastEditor componentView]];
      [[_project projectWindow] makeFirstResponder:[lastEditor editorView]];
    }
  else
    {
      PCProjectBrowser *browser = [_project projectBrowser];
      
      [_componentView setContentView:_scrollView];
      [[_project projectWindow] makeFirstResponder:_scrollView];

      [browser setPath:[browser pathToSelectedCategory]];
      [self setActiveEditor:nil];
    }
}

- (void)editorDidBecomeActive:(NSNotification *)aNotif
{
  id<CodeEditor> editor = [aNotif object];
  NSString       *categoryPath = [editor categoryPath];

  if (![[_editorsDict allValues] containsObject:editor])
    {
      return;
    }

  [self setActiveEditor:editor];

  if (categoryPath)
    {
      [[_project projectBrowser] setPath:categoryPath];
    }
}

@end

