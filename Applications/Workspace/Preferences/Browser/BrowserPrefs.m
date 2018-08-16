/*
   Browser preferences.

   Copyright (C) 2005 Saso Kiselkov
   Copyright (C) 2005 Sergii Stoian

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPXSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "BrowserPrefs.h"
#import <NXFoundation/NXDefaults.h>

static inline NSRect IncrementedRect(NSRect r)
{
  r.origin.x--;
  r.origin.y--;
  r.size.width += 2;
  r.size.height += 2;

  return r;
}

@interface BrowserPrefs (Private)

- (void)setupArrows;

@end

@implementation BrowserPrefs (Private)

- (void)setupArrows
{
  NSRect     aFrame;
  NSRect     bFrame = [browser frame];
  NSSize     s = [[rightArr superview] frame].size;
  float      width;
  NXDefaults *df = [NXDefaults userDefaults];

  if ([df objectForKey:BrowserViewerColumnWidth])
    {
      [button setEnabled:YES];
      width = [df floatForKey:BrowserViewerColumnWidth];
    }
  else
    {
      width = 180;
    }

  bFrame.size.width = width;
  [browser setFrame:bFrame];

  aFrame = [rightArr frame];
  aFrame.origin.x = bFrame.origin.x + bFrame.size.width;
  [rightArr setFrame:aFrame];

  [box2 setNeedsDisplay:YES];
}

@end

@implementation BrowserPrefs

- (void)dealloc
{
  NSDebugLLog(@"BrowserPrefs", @"BrowserPrefs: dealloc");

//  [[NSNotificationCenter defaultCenter] removeObserver: self];

  TEST_RELEASE(box);

  [super dealloc];
}

- (void)awakeFromNib
{
  NSRect frame;
  NSRect shortLabelFrame;
  NSRect box2Frame;

  // get the box and destroy the bogus window
  [box retain];
  [box removeFromSuperview];
  DESTROY(bogusWindow);

  // configure the arrows
  box2Frame = [[box2 contentView] frame];

  [self setupArrows];

/*  [[NSNotificationCenter defaultCenter]
    addObserver: self
       selector: @selector(changedSelection:)
	   name: @"FileViewerDidChangeSelectionNotification"
	 object: nil];*/
}

- (NSString *)moduleName
{
  return _(@"Browser");
}

- (NSView *)view
{
  if (box == nil)
    {
      [NSBundle loadNibNamed:@"BrowserPrefs" owner:self];
    }

  return box;
}

// --- NXSizer delegate

- (BOOL) arrowView:(NXSizer *)sender
 shouldMoveByDelta:(float)delta
{
  NSView     *superview = [sender superview];
  NSSize     s = [superview frame].size;
  NSRect     bFrame = [browser frame];
  NSRect     aFrame = [rightArr frame];
  NSUInteger newWidth;

//  NSLog(@"[BrowserPrefs] arrowView moved by delta: %f", delta);

  newWidth = (aFrame.origin.x + delta) - bFrame.origin.x;

  if (newWidth <= BROWSER_MIN_COLUMN_WIDTH ||
      newWidth >= BROWSER_MAX_COLUMN_WIDTH)
    {
      return NO;
    }

  bFrame.size.width = newWidth;
  [browser setFrame:bFrame];
  aFrame.origin.x = aFrame.origin.x + delta;
  [superview setNeedsDisplay:YES];

  if (newWidth == BROWSER_COLUMN_WIDTH)
    {
      [button setEnabled:NO];
    }
  else
    {
      [button setEnabled:YES];
    }

  return YES;
}

- (void)arrowViewStoppedMoving:(NXSizer *)sender
{
  NSLog(@"[BrowserPrefs] browser column width changed to: %f",
	[rightArr frame].origin.x - [browser frame].origin.x);

  [[NXDefaults userDefaults]
    setFloat:([rightArr frame].origin.x - [browser frame].origin.x)
      forKey:BrowserViewerColumnWidth];

  [[NSNotificationCenter defaultCenter]
    postNotificationName:BrowserViewerColumnWidthDidChangeNotification
		  object:self];
}

// --- Button

- (void)revert:sender
{
  if ([sender isEqualTo:button] == NO)
    return;
  
  [sender setEnabled:NO];
  [[NXDefaults userDefaults] removeObjectForKey:BrowserViewerColumnWidth];
  [[NSNotificationCenter defaultCenter]
    postNotificationName:BrowserViewerColumnWidthDidChangeNotification
        	  object:self];

  [self setupArrows];
}

@end
