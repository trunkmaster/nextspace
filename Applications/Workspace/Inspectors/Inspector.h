/*
   Inspector.h
   The workspace manager's inspector.

   Copyright (C) 2014 Sergii Stoian
   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/
/*
  Inspector bundle loaded by Workspace and dispayed with one 
  activate*Inspector: methods.
  Inspector is a parent class for built-in inspectors. That's why actual
  initialization performed in activateInspector: method. activateInspector:
  should only be called by show*Inspector methods.
*/

#import <AppKit/AppKit.h>

@class WMInspector;

@interface Inspector : NSObject
{
  id window;         // The Inspector window.
  id fileIconButton; // The Button that displays the file's icon.
  id fileNameField;  // The TextField that displays the file name.
  id dirNameField;   // The TextField that holds the current directory.
  id dirTitleField;  // The TextField that titles dirNameField.
  id okButton;       // The Inspector's OK button.
  id revertButton;   // The Inspector's Revert button.

@private
  NSBox *box;
  id    popUpButton;

  // Special NSTextField that displays "No ... Inspector" text
  id noInspectorBox;
  id noInspectorField;

  // Local cache of FileViewer selection
  NSString *filePath;
  NSArray  *fileSelection;
  BOOL     fileViewerSelectionChanged;

  // built-in inspectors
  Inspector             *attributesInspector;
  // FileContentsInspector *contentsInspector;
  Inspector             *toolsInspector;
  Inspector             *accessInspector;

  WMInspector           *currentInspector;

  // array of "bundle.registry contents"
  // + path=@"path to bundle" or path=@"BUILTIN"
  NSMutableArray        *inspectorsRegistry;
  // "path to bundle"="object instance"
  NSMutableDictionary   *contentsInspectors;
}

+ sharedInspector;
- (void)setInspectorPanel:(Inspector *)panel;

- (void)activateInspector:sender;
- (void)deactivateInspector:sender;

- (void)showAttributesInspector:sender;
- (void)showContentsInspector:sender;
- (void)showToolsInspector:sender;
- (void)showPermissionsInspector:sender;

- (void)ok:sender;
- okButton;
- (id)revert:(id)sender;
- revertButton;
- window;

- (unsigned)selectionCount;
// Wrapper around getSelectedPath:andFiles:
- selectionPathsInto:(char *)pathString separator:(char)character;
- (void)getSelectedPath:(NSString **)pathString andFiles:(NSArray **)fileArray;

- textDidChange:sender;
- (void)touch:sender;

@end
