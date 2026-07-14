/* GormShelfPref.m
 *  
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author: Gregory Casamento <greg_casamento@yahoo.com>
 * Date: February 2004
 *
 * Author: Enrico Sersale <enrico@imago.ro>
 * Date: August 2001
 *
 * This class is heavily based on work done by Enrico Sersale
 * on ShelfPref.m for GWorkspace.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormShelfPref.h"

#define BOX_W 197
#define NAME_OR_Y 5
#define NAME_W 16
#define NAME_MARGIN 6

#ifndef max
#define max(a,b) ((a) > (b) ? (a):(b))
#endif

#ifndef min
#define min(a,b) ((a) < (b) ? (a):(b))
#endif

static NSString *nibName = @"GormShelfPref";

@implementation ArrResizer

- (void)dealloc
{
  RELEASE (arrow);
  [super dealloc];
}

- (id)initForController:(id)acontroller 
           withPosition:(ArrowPosition)pos
{
  self = [super init];
  [self setFrame: NSMakeRect(0, 0, 16, 16)];	  
  position = pos;
  controller = acontroller;
  
  if (position == leftarrow) {
    ASSIGN (arrow, [NSImage imageNamed: @"LeftArr.tiff"]);
  } else {
    ASSIGN (arrow, [NSImage imageNamed: @"RightArr.tiff"]);
  }
  
  return self;
}

- (ArrowPosition)position
{
  return position;
}

- (void)mouseDown:(NSEvent *)e
{
  [controller startMouseEvent: e onResizer: self];
}

- (void)drawRect:(NSRect)rect
{
  [super drawRect: rect];
  [arrow compositeToPoint: NSZeroPoint operation: NSCompositeSourceOver];
}

@end


@implementation GormShelfPref

- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  TEST_RELEASE (prefbox);
  RELEASE (leftResizer);
  RELEASE (rightResizer);  
  RELEASE (fname);
  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if ((self = [super init]) != nil) 
    {    
      if ([NSBundle loadNibNamed: nibName owner: self] == NO) 
	{
	  NSLog(@"failed to load %@!", nibName);
	} 
      else 
	{ 
	  int orx;
	  
	  RETAIN (prefbox);
	  RELEASE (win);
	  
	  [imView setImageScaling: NSScaleProportionally];	  
	  
	  // set up the info...
	  [imView setImage: [NSImage imageNamed: @"GormObject.tiff"]]; 		
	  ASSIGN(fname, @"GormSampleObjectName");
	  cellsWidth = [self shelfCellsWidth];
	  
	  orx = (int)((BOX_W - cellsWidth) / 2);
	  
	  leftResizer = [[ArrResizer alloc] initForController: self 
					    withPosition: leftarrow];
	  [leftResizer setFrame: NSMakeRect(0, 0, NAME_W, NAME_W)];  
	  [(NSBox *)leftResBox setContentView: leftResizer]; 
	  [leftResBox setFrame: NSMakeRect(orx - NAME_W, NAME_OR_Y, NAME_W, NAME_W)];  
	  
	  rightResizer = [[ArrResizer alloc] initForController: self 
					     withPosition: rightarrow];
	  [rightResizer setFrame: NSMakeRect(0, 0, NAME_W, NAME_W)];
	  [(NSBox *)rightResBox setContentView: rightResizer]; 
	  [rightResBox setFrame: NSMakeRect(orx + cellsWidth, NAME_OR_Y, NAME_W, NAME_W)];  
	  
	  [nameField setFrame: NSMakeRect(orx, NAME_OR_Y, cellsWidth, NAME_W)];    
	  [nameField setStringValue: cutFileLabelText(fname, nameField, cellsWidth -NAME_MARGIN)];
	  
	  /* Internationalization */
	  [setButt setTitle: _(@"Default")];
	  [iconbox setTitle: _(@"Title Width")];
	}                              
    }
  
  return self;
}

- (NSView *)view
{
  return ((NSView *)prefbox);
}

- (void)selectionChanged:(NSNotification *)n
{
/*
  NSArray *selPaths = [gw selectedPaths];
  int count = [selPaths count];
  NSString *fpath = [selPaths objectAtIndex: 0];
  NSString *defApp;
  NSString *type;
  
  ASSIGN (fname, [fpath lastPathComponent]);
  [imView setImage: @"GormObject.tiff"];	
  
  cellsWidth = [self shelfCellsWidth];
  [self tile];
*/
}

- (int) shelfCellsWidth
{
  // return the current cell width;
  return [[NSUserDefaults standardUserDefaults] integerForKey: @"CellSizeWidth"];
}

- (void)tile
{
  int orx = (int)((BOX_W - cellsWidth) / 2);
  
  [nameField setFrame: NSMakeRect(orx, NAME_OR_Y, cellsWidth, NAME_W)];    
  [nameField setStringValue: cutFileLabelText(fname, nameField, cellsWidth -NAME_MARGIN)];  
  [leftResBox setFrame: NSMakeRect(orx - NAME_W, NAME_OR_Y, NAME_W, NAME_W)];  
  [rightResBox setFrame: NSMakeRect(orx + cellsWidth, NAME_OR_Y, NAME_W, NAME_W)];  
  
  [iconbox setNeedsDisplay: YES];
}

- (void)startMouseEvent:(NSEvent *)event onResizer:(ArrResizer *)resizer
{
  NSApplication	*app = [NSApplication sharedApplication];
  NSDate *farAway = [NSDate distantFuture];
  ArrowPosition pos = [resizer position];
  int orx = (int)[prefbox convertPoint: [event locationInWindow] fromView: nil].x;
  NSView *resbox1 = (pos == leftarrow) ? leftResBox : rightResBox;
  NSView *resbox2 = (pos == leftarrow) ? rightResBox : leftResBox;
  unsigned int eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask;
  NSEvent	*e;

  [prefbox lockFocus];
  [[NSRunLoop currentRunLoop] limitDateForMode: NSEventTrackingRunLoopMode];

  e = [app nextEventMatchingMask: eventMask
	   untilDate: farAway
	   inMode: NSEventTrackingRunLoopMode
	   dequeue: YES];

  while ([e type] != NSLeftMouseUp) 
    {
      int x = (int)[prefbox convertPoint: [e locationInWindow] fromView: nil].x;
      int diff = x - orx;
      int orx1 = (int)[resbox1 frame].origin.x;
      int orx2 = (int)[resbox2 frame].origin.x;
      
      if ((max(orx1 + diff, orx2 - diff) - min(orx1 + diff, orx2 - diff)) < 160
	  && (max(orx1 + diff, orx2 - diff) - min(orx1 + diff, orx2 - diff)) > 70) {      
	int fieldwdt = max(orx1 + diff, orx2 - diff) - min(orx1 + diff, orx2 - diff) - NAME_W;
	int nameforx = (int)((BOX_W - fieldwdt) / 2);
	
	[resbox1 setFrameOrigin: NSMakePoint(orx1 + diff, NAME_OR_Y)];
	[resbox2 setFrameOrigin: NSMakePoint(orx2 - diff, NAME_OR_Y)];
	
	[nameField setFrame: NSMakeRect(nameforx, NAME_OR_Y, fieldwdt, NAME_W)];    
	[nameField setStringValue: cutFileLabelText(fname, nameField, fieldwdt -NAME_MARGIN)];
	
	[iconbox setNeedsDisplay: YES];
	
	orx = x;
      }
      e = [app nextEventMatchingMask: eventMask
	       untilDate: farAway
	       inMode: NSEventTrackingRunLoopMode
	       dequeue: YES];
    }
  [prefbox unlockFocus];
  [self setNewWidth: (int)[nameField frame].size.width];
  [setButt setEnabled: YES];
}

- (void) _postNotification
{
  NSDebugLog(@"Notify the app that the size has changed....");
  [[NSNotificationCenter defaultCenter]
    postNotificationName: GormResizeCellNotification
    object: self];
}

- (void)setNewWidth:(int)w
{
  // set the new default...
  [[NSUserDefaults standardUserDefaults] setInteger: w forKey: @"CellSizeWidth"];
  [self _postNotification];
}

- (void)setDefaultWidth:(id)sender
{
  // set some default width...
  cellsWidth = 72; 
  [[NSUserDefaults standardUserDefaults] setInteger: cellsWidth forKey: @"CellSizeWidth"];
  [self tile];
  [setButt setEnabled: NO];  
  [self _postNotification];
}

@end
