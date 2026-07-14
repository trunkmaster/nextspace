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
#import <ProjectCenter/PCEditorManager.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectEditor.h>
#import <ProjectCenter/PCLogController.h>
#import <ProjectCenter/PCSaveModified.h>

#import <Protocols/CodeEditor.h>

#import "Modules/Preferences/Misc/PCMiscPrefs.h"

NSString *PCEditorDidChangeFileNameNotification = 
          @"PCEditorDidChangeFileNameNotification";

NSString *PCEditorWillOpenNotification = @"PCEditorWillOpenNotification";
NSString *PCEditorDidOpenNotification = @"PCEditorDidOpenNotification";
NSString *PCEditorWillCloseNotification = @"PCEditorWillCloseNotification";
NSString *PCEditorDidCloseNotification = @"PCEditorDidCloseNotification";

NSString *PCEditorWillChangeNotification = @"PCEditorWillChangeNotification";
NSString *PCEditorDidChangeNotification = @"PCEditorDidChangeNotification";
NSString *PCEditorWillSaveNotification = @"PCEditorWillSaveNotification";
NSString *PCEditorDidSaveNotification = @"PCEditorDidSaveNotification";
NSString *PCEditorWillRevertNotification = @"PCEditorWillRevertNotification";
NSString *PCEditorDidRevertNotification = @"PCEditorDidRevertNotification";

NSString *PCEditorDidBecomeActiveNotification = 
          @"PCEditorDidBecomeActiveNotification";
NSString *PCEditorDidResignActiveNotification = 
          @"PCEditorDidResignActiveNotification";

@implementation PCEditorManager
// ===========================================================================
// ==== Initialisation
// ===========================================================================

- (id)init
{
  if ((self = [super init]))
    {
      PCLogStatus(self, @"[init]");
      _editorsDict = [[NSMutableDictionary alloc] init];

      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidOpen:)
	       name:PCEditorDidOpenNotification
	     object:nil];

      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidClose:)
	       name:PCEditorDidCloseNotification
	     object:nil];
	     
      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidBecomeActive:)
	       name:PCEditorDidBecomeActiveNotification
	     object:nil];
	     
      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidResignActive:)
	       name:PCEditorDidResignActiveNotification
	     object:nil];

      [[NSNotificationCenter defaultCenter]
	addObserver:self 
	   selector:@selector(editorDidChangeFileName:)
	       name:PCEditorDidChangeFileNameNotification
	     object:nil];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCEditorManager: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(editorName);
  RELEASE(_editorsDict);

  [super dealloc];
}

- (PCProjectManager *)projectManager
{
  return _projectManager;
}

- (void)setProjectManager:(PCProjectManager *)aProjectManager
{
  _projectManager = aProjectManager;

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(loadPreferences:)
	   name:PCPreferencesDidChangeNotification
	 object:nil];
  [self loadPreferences:nil];
}

- (void)loadPreferences:(NSNotification *)aNotification
{
  id <PCPreferences> prefs = [_projectManager prefController];

  ASSIGN(editorName, [prefs stringForKey:Editor]);
}

// ===========================================================================
// ==== Editor handling
// ===========================================================================

- (id<CodeEditor>)editorForFile:(NSString *)filePath
{
  return [_editorsDict objectForKey:filePath];
}

- (id<CodeEditor>)openEditorForFile:(NSString *)filePath
			   editable:(BOOL)editable
			   windowed:(BOOL)windowed
{
  NSFileManager   *fm = [NSFileManager defaultManager];
  BOOL            isDir;
  PCBundleManager *bundleManager = [_projectManager bundleManager];
  NSString        *fileName = [filePath lastPathComponent];
  id<CodeEditor>  editor;
  id<CodeParser>  parser;
  BOOL exists = [fm fileExistsAtPath:filePath isDirectory:&isDir];

  // Determine if file does not exist or file is directory
  if (!exists)
    {
      NSRunAlertPanel(@"Open Editor",
		      @"Couldn't open editor for file '%@'.\n"
		      @"File doesn't exist.",
		      @"Close", nil, nil, filePath);
      return nil;
    }

  // Determine if file is text file
  if(isDir == NO)
    {
      if (![[PCFileManager defaultManager] isTextFile:filePath] && !isDir)
	{
	  // TODO: Do not open alert panel for now. Internal editor
	  // for non text files must not be opened. Review PCProjectBrowser.
	  /*      NSRunAlertPanel(@"Open Editor",
		  @"Couldn't open editor for file '%@'.\n"
		  @"File is not plain text.",
		  @"Close", nil, nil, filePath);*/
          PCLogInfo(self, @"Not a text file %@", filePath);
	  return nil;
	}
    }
  else
    {
      NSString *app;

      /* we don't have in-window editors for any bundles right now */
      if (!windowed)
        return nil;
      
      /* Check for bundles and if possible let them be opened by Workspace but only if windowed */
      app = [[NSWorkspace sharedWorkspace] getBestAppInRole:@"Editor" forExtension:[fileName pathExtension]];
      if (windowed && app != nil)
        {
          if ([[NSWorkspace sharedWorkspace] openFile: filePath])
            return nil;
        }
    }

//  NSLog(@"EditorManager 1: %@", _editorsDict);
  editor = [_editorsDict objectForKey: filePath];
  if (editor == nil)
    {
      // Editor
      editor = [bundleManager objectForBundleWithName:editorName
			      type:@"editor"
			      protocol:@protocol(CodeEditor)];
      if (editor == nil)
	{
	  editor = [bundleManager 
		     objectForBundleWithName:@"ProjectCenter"
		     type:@"editor"
		     protocol:@protocol(CodeEditor)];
	}

      /* if we have a valid editor, we try to set a parser */
      if (editor)
        {
          // Parser
          parser = [bundleManager objectForBundleType:@"parser"
                                             protocol:@protocol(CodeParser)
                                             fileName:fileName];
          if(parser != nil)
            {
              [editor setParser:parser];
            }
          [editor openFileAtPath:filePath 
                   editorManager:self 
                        editable:editable];
          [_editorsDict setObject:editor forKey:filePath];
          RELEASE(editor);
        }
      else
        {
          //
          // If we don't have an editor, we fall back to opening the
          // file with the editor designated by the system.
          //
          [[NSWorkspace sharedWorkspace] openFile: filePath];
        }
    }
  
  if(editor != nil)
    {
      [editor setWindowed:windowed];
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
  [editor show];
}

- (id<CodeEditor>)activeEditor
{
  return _activeEditor;
}

- (void)setActiveEditor:(id<CodeEditor>)anEditor
{
  if (anEditor != _activeEditor)
    {
      _activeEditor = anEditor;
    }
}

- (NSArray *)allEditors
{
  return [_editorsDict allValues];
}

- (void)closeActiveEditor:(id)sender
{
  if (!_activeEditor)
    {
      return;
    }

  [_activeEditor close:sender];
}

- (void)closeEditorForFile:(NSString *)file
{
  id<CodeEditor> editor;

  if ([_editorsDict count] > 0 && (editor = [_editorsDict objectForKey:file]))
    {
      [editor close:self];
    }
}

- (NSArray *)modifiedFiles
{
  NSEnumerator   *enumerator = [_editorsDict keyEnumerator];
  NSString       *key = nil;
  id<CodeEditor> editor;
  NSMutableArray *modifiedFiles = [[NSMutableArray alloc] init];

  while ((key = [enumerator nextObject]))
    {
      editor = [_editorsDict objectForKey:key];
      if ([editor isEdited])
	{
	  [modifiedFiles addObject:key];
	}
    }

  return AUTORELEASE((NSArray *)modifiedFiles);
}

- (BOOL)hasModifiedFiles
{
  if ([[self modifiedFiles] count])
    {
      return YES;
    }

  return NO;
}

- (BOOL)reviewUnsaved:(NSArray *)modifiedFiles
{
  NSEnumerator   *enumerator = [modifiedFiles objectEnumerator];
  NSString       *filePath;
  id<CodeEditor> editor;

  while ((filePath = [enumerator nextObject]))
    {
      editor = [_editorsDict objectForKey:filePath];

      [self orderFrontEditorForFile:filePath];

      if ([editor close:self] == NO)
	{ // Operation should be aborted
	  return NO;
	}
    }

  return YES;
}

- (BOOL)closeAllEditors
{
  NSArray *modifiedFiles = [self modifiedFiles];

  if ([modifiedFiles count])
    {
      if (!PCRunSaveModifiedFilesPanel(self, 
				       @"Save and Close",
				       @"Close Anyway",
				       @"Cancel"))
	{
	  return NO;
	}
    }

  [_editorsDict removeAllObjects];

  return YES;
}

// ===========================================================================
// ==== File handling
// ===========================================================================

- (BOOL)saveAllFiles
{
  NSEnumerator   *enumerator = [_editorsDict keyEnumerator];
  id<CodeEditor> editor;
  NSString       *key;
  BOOL           ret = YES;

  while ((key = [enumerator nextObject]))
    {
      editor = [_editorsDict objectForKey:key];

      if ([editor saveFileIfNeeded] == NO)
	{
	  ret = NSRunAlertPanel(@"Save Files",
				@"Couldn't save file '%@'.\n"
				@"Operation stopped.",
				@"Ok",nil,nil);
	  return NO;
	}
    }

  return ret;
}

- (BOOL)saveFile
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      return [editor saveFileIfNeeded];
    }

  return NO;
}

- (BOOL)saveFileAs:(NSString *)file
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      BOOL res;
      BOOL iw = [editor isWindowed];
      
      res = [editor saveFileTo:file];
      [editor closeFile:self save:NO];

      [self openEditorForFile:file 
		     editable:YES
		     windowed:iw];

      return res;
    }

  return NO;
}

- (BOOL)saveFileTo:(NSString *)file
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      return [editor saveFileTo:file];
    }

  return NO;
}

- (BOOL)revertFileToSaved
{
  id<CodeEditor> editor = [self activeEditor];

  if (editor != nil)
    {
      return [editor revertFileToSaved];
    }

  return NO;
}

// ===========================================================================
// ==== Notifications
// ===========================================================================

- (void)editorDidOpen:(NSNotification *)aNotif
{
  id editor = [aNotif object];

  [self setActiveEditor:editor];
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

  if (![_editorsDict count])
    {
      [self setActiveEditor:nil];
    }
}

- (void)editorDidBecomeActive:(NSNotification *)aNotif
{
  id<CodeEditor> editor = [aNotif object];

  if (![[_editorsDict allValues] containsObject:editor])
    {
      return;
    }

  [self setActiveEditor:editor];
}

- (void)editorDidResignActive:(NSNotification *)aNotif
{
  // Clearing activeEditor blocks the ability to get some information from
  // loaded and visible but not active editor
/*  PCEditor *editor = [aNotif object];
  
  if ([editor projectEditor] != self)
    {
      return;
    }

  [self setActiveEditor:nil];*/
}

- (void)editorDidChangeFileName:(NSNotification *)aNotif
{
  NSDictionary   *_editorDict = [aNotif object];
  id<CodeEditor> _editor = [_editorDict objectForKey:@"Editor"];
  NSString       *_oldFileName = nil;
  NSString       *_newFileName = nil;

  if (![[_editorsDict allValues] containsObject:_editor])
    {
      return;
    }
    
  _oldFileName = [_editorDict objectForKey:@"OldFile"];
  _newFileName = [_editorDict objectForKey:@"NewFile"];
  
  [_editorsDict removeObjectForKey:_oldFileName];
  [_editorsDict setObject:_editor forKey:_newFileName];
}

- (void)gotoFile: (NSString *)fileName atLine: (NSUInteger)line
{
  PCProject      *project = [_projectManager rootActiveProject];
  PCProjectEditor *pe = [project projectEditor];

  id<CodeEditor> editor = [pe openEditorForFilePath: fileName windowed: NO];
  
  // [self orderFrontEditorForFile:fileName];
  [editor scrollToLineNumber: line];
}

@end

