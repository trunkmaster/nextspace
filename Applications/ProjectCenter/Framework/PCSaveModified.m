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

#import <ProjectCenter/PCEditorManager.h>

#import <ProjectCenter/PCSaveModified.h>

BOOL PCRunSaveModifiedFilesPanel(PCEditorManager *manager,
				 NSString *defaultText,
				 NSString *alternateText,
				 NSString *otherText)
{
  PCSaveModified *saveModifiedPanel;
  BOOL           result;

  if (!(saveModifiedPanel = [[PCSaveModified alloc] init]))
    {
      return NO;
    }

  result = [saveModifiedPanel saveFilesWithEditorManager:manager
				       defaultButtonText:defaultText
				     alternateButtonText:alternateText
					 otherButtonText:otherText];
  RELEASE(saveModifiedPanel);

  return result;
}


@implementation PCSaveModified

- (BOOL)saveFilesWithEditorManager:(PCEditorManager *)manager
		 defaultButtonText:(NSString *)defaultText
	       alternateButtonText:(NSString *)alternateText
		   otherButtonText:(NSString *)otherText
{
  if ([NSBundle loadNibNamed:@"SaveModified" owner:self] == NO)
    {
      NSLog(@"Error loading SaveModified NIB file!");
      return NO;
    }

  editorManager = manager;

  // Table
  [filesList setCornerView:nil];
  [filesList setHeaderView:nil];
  [filesList setDataSource:self];
  [filesList setTarget:self];
  [filesList selectAll:self];
  [filesList reloadData];

  // Buttons
  [defaultButton setTitle:defaultText];
  [alternateButton setTitle:alternateText];
  [otherButton setTitle:otherText];

  [panel makeKeyAndOrderFront:self];

  [NSApp runModalForWindow:panel];

  if (clickedButton == defaultButton)
    {
      [self saveSelectedFiles];
      return YES;
    }
  else if (clickedButton == alternateButton)
    {
      return YES;
    }
  else if (clickedButton == otherButton)
    {
      return NO;
    }

  return YES;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog(@"PCSaveModified: dealloc");
#endif
  RELEASE(panel);

  [super dealloc];
}

- (BOOL)saveSelectedFiles
{
  NSArray      *modifiedFiles = [editorManager modifiedFiles];
  NSIndexSet   *selectedRows = [filesList selectedRowIndexes];
  NSArray      *filesToSave = [modifiedFiles objectsAtIndexes:selectedRows];
  NSEnumerator *enumerator = [filesToSave objectEnumerator];
  NSString     *filePath = nil;

  NSLog(@"SaveModified|filesToSave: %@", filesToSave);

  while ((filePath = [enumerator nextObject]))
    {
      [[editorManager editorForFile:filePath] saveFileIfNeeded];
    }

  return YES;
}

- (void)buttonClicked:(id)sender
{
  clickedButton = sender;
  [NSApp stopModal];
  [panel close];
}

// ============================================================================
// ==== TableView delegate
// ============================================================================
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if (aTableView != filesList)
    {
      return 0;
    }
  
  return [[editorManager modifiedFiles] count];
}

- (id)            tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
                        row:(NSInteger)rowIndex
{
  if (aTableView != filesList)
    {
      return nil;
    }

  return [[[editorManager modifiedFiles] objectAtIndex:rowIndex] lastPathComponent];
}

@end

