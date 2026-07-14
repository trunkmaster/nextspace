/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2004-2014 Free Software Foundation

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

#import <ProjectCenter/PCLogController.h>
#import <ProjectCenter/PCAddFilesPanel.h>

static PCAddFilesPanel *addFilesPanel = nil;

@implementation PCAddFilesPanel

+ (PCAddFilesPanel *)addFilesPanel
{
  if (addFilesPanel == nil)
    {
      addFilesPanel = [[self alloc] init];
    }

  return addFilesPanel;
}

// --- "Add Files..." panel
- (id)init
{
  NSRect fr;

  self = [super init];

  fr = NSMakeRect(20,30,160,21);

  // File type popup
  fileTypePopup = [[NSPopUpButton alloc] initWithFrame:fr pullsDown:NO];
  [fileTypePopup setRefusesFirstResponder:YES];
  [fileTypePopup setAutoenablesItems:NO];
  [fileTypePopup setTarget:self];
  [fileTypePopup setAction:@selector(filesForAddPopupClicked:)];
  [fileTypePopup selectItemAtIndex:0];

  fileTypeAccessaryView = [[NSBox alloc] init];
  [fileTypeAccessaryView setTitle:@"File Types"];
  [fileTypeAccessaryView setTitlePosition:NSAtTop];
  [fileTypeAccessaryView setBorderType:NSGrooveBorder];
  [fileTypeAccessaryView addSubview:fileTypePopup];
  [fileTypeAccessaryView sizeToFit];
  [fileTypeAccessaryView setAutoresizingMask:NSViewMinXMargin 
    | NSViewMaxXMargin];

  // Panel
  [self setAllowsMultipleSelection:YES];

  return self;
}

- (void)setCategories:(NSArray *)categories
{
  [fileTypePopup removeAllItems];
  [fileTypePopup addItemsWithTitles:categories];
}

- (void)selectCategory:(NSString *)category
{
  [self setAccessoryView:fileTypeAccessaryView];
  [fileTypePopup selectItemWithTitle:category];
  [self filesForAddPopupClicked:self];
}

- (NSString *)selectedCategory
{
  return [fileTypePopup titleOfSelectedItem];
}

- (void)setFileTypes:(NSArray *)fileTypes
{
  NSString  *path = nil;

  [super setAllowedFileTypes: fileTypes];

  path = [_browser path];
  [self validateVisibleColumns];
  [_browser setPath:path];

  [self display];
}

- (void)filesForAddPopupClicked:(id)sender
{
  NSString  *category = [fileTypePopup titleOfSelectedItem];

  if ([[self delegate] respondsToSelector:@selector(categoryChangedTo:)])
    {
      [[self delegate] categoryChangedTo:category];
    }
}

@end
