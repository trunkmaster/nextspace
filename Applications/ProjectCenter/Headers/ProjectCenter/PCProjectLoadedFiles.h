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

#ifndef _PCProjectLoadedFiles_h_
#define _PCProjectLoadedFiles_h_

#import <AppKit/AppKit.h>

@class PCProject;

typedef enum _PHSortType
{
  PHSortByTime,
  PHSortByName
} PHSortType;

@interface PCProjectLoadedFiles : NSObject
{
  PCProject      *project;
  NSTableView    *filesList;
  NSTableColumn  *filesColumn;
  NSScrollView   *filesScroll;
  NSMutableArray *editedFiles;

  PHSortType     sortType;
}

- (id)initWithProject:(PCProject *)aProj;
- (void)dealloc;
- (NSView *)componentView;
- (NSArray *)editedFilesRep;

- (void)setSortType:(PHSortType)type;
- (void)setSortByTime;
- (void)setSortByName;
- (void)selectNextFile;
- (void)selectPreviousFile;

- (void)click:(id)sender;
- (void)doubleClick:(id)sender;

@end

@interface PCProjectLoadedFiles (HistoryTableDelegate)

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;

- (id)            tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
                        row:(NSInteger)rowIndex;

- (void)tableView:(NSTableView *)aTableView
   setObjectValue:anObject
   forTableColumn:(NSTableColumn *)aTableColumn
              row:(NSInteger)rowIndex;

@end

#endif 

