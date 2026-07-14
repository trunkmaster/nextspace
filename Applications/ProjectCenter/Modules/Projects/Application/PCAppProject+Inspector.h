/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2021 Free Software Foundation

   Author: Serg Stoyan <stoyan@on.com.ua>
           Riccardo Mottola <rm@gnu.org>

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

#ifndef _PCAppProject_Inspector_h_
#define _PCAppProject_Inspector_h_

#import "PCAppProject.h"

@interface PCAppProject (Inspector)

// ----------------------------------------------------------------------------
// --- User Interface
// ----------------------------------------------------------------------------
- (NSView *)projectAttributesView;

// ----------------------------------------------------------------------------
// --- Actions
// ----------------------------------------------------------------------------
- (IBAction)setAppType:(id)sender;
- (IBAction)setAppClass:(id)sender;
- (IBAction)setBundleIdentifier:(id)sender;

- (void)clearAppIcon:(id)sender;
- (BOOL)setAppIconWithFileAtPath:(NSString *)path;

- (void)clearHelpFile:(id)sender;
- (IBAction)setHelpFile:(id)sender;

- (void)clearMainNib:(id)sender;
- (BOOL)setMainNibWithFileAtPath:(NSString *)path;

- (IBAction)setDocBasedApp:(id)sender;
- (IBAction)addDocType: (id)sender;
- (IBAction)removeDocType: (id)sender;

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)            tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
                        row:(NSInteger)rowIndex;
- (void) tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
               row:(NSInteger)rowIndex;
	       
- (void)fillFieldsForRow:(NSInteger)rowIndex;

// ----------------------------------------------------------------------------
// --- Notifications
// ----------------------------------------------------------------------------
- (void)updateInspectorValues:(NSNotification *)aNotif;
- (void)tfGetFocus:(NSNotification *)aNotif;

@end

@interface PCAppProject (FileNameIconDelegate)

- (BOOL)canPerformDraggingOf:(NSArray *)paths;
- (BOOL)prepareForDraggingOf:(NSArray *)paths;
- (BOOL)performDraggingOf:(NSArray *)paths;

@end

#endif
