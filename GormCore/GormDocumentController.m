/* GormDocumentController.m
 *
 * This class is a subclass of the NSDocumentController
 *
 * Copyright (C) 2006 Free Software Foundation, Inc.
 *
 * Author:      Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:        2006
 *
 * This file is part of GNUstep.
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
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <GormCore/GormDocument.h>
#include <GormCore/GormDocumentController.h>

#include "GormPrivate.h"

@implementation GormDocumentController

- (id) currentDocument
{
  NSArray  *documents = [self documents];
  unsigned i = [documents count];
  id result = nil;

  if (i > 0)
    {
      while (i-- > 0)
	{
	  id doc = [documents objectAtIndex: i];
 	  if ([doc isActive] == YES)
	    {
	      result = doc;
	      break;
	    }
	}
    }

  return result;
}

- (void) buildDocumentForType: (GormDocumentType)documentType
{
  GormDocument *doc = nil;

  NSDebugLog(@"In gorm document controller...");
  doc = (GormDocument *)[[self documents] lastObject]; // get the latest document...

  switch (documentType)
    {
    case GormApplication:
      {
	NSMenu	 *aMenu;
	NSWindow *aWindow;
	NSRect	 frame = [[NSScreen mainScreen] frame];
	unsigned style = NSTitledWindowMask | NSClosableWindowMask
	  | NSResizableWindowMask | NSMiniaturizableWindowMask;
	
	if ([NSMenu respondsToSelector: @selector(allocSubstitute)])
	  {
	    aMenu = [[NSMenu allocSubstitute] init];
	  }
	else
	  {
	    aMenu = [[NSMenu alloc] init];
	  }
	
	if ([NSWindow respondsToSelector: @selector(allocSubstitute)])
	  {
	    aWindow = [[NSWindow allocSubstitute]
			initWithContentRect: NSMakeRect(0,0,600, 400)
			styleMask: style
			backing: NSBackingStoreBuffered
			defer: NO];
	  }
	else
	  {
	    aWindow = [[NSWindow alloc]
			initWithContentRect: NSMakeRect(0,0,600, 400)
			styleMask: style
			backing: NSBackingStoreBuffered
			defer: NO];
	  }
	[aWindow setFrameTopLeftPoint:
		   NSMakePoint(230, frame.size.height-100)];
	[aWindow setTitle: _(@"My Window")]; 
	[doc setName: @"My Window" forObject: aWindow];
	[doc attachObject: aWindow toParent: nil];
	[doc setObject: aWindow isVisibleAtLaunch: YES];
	
	[aMenu setTitle: _(@"Main Menu")];
	[aMenu addItemWithTitle: _(@"Hide") 
	       action: @selector(hide:)
	       keyEquivalent: @"h"];	
	[aMenu addItemWithTitle: _(@"Quit") 
	       action: @selector(terminate:)
	       keyEquivalent: @"q"];
	
	// the first menu attached becomes the main menu.
	[doc attachObject: aMenu toParent: nil]; 
      }
      break;
    case GormInspector:
      {
	NSPanel	 *aWindow;
	NSRect	 frame = [[NSScreen mainScreen] frame];
	unsigned style = NSTitledWindowMask | NSClosableWindowMask;
	
	if ([NSPanel respondsToSelector: @selector(allocSubstitute)])
	  {
	    aWindow = [[NSPanel allocSubstitute] 
			initWithContentRect: NSMakeRect(0,0, IVW, IVH)
			styleMask: style
			backing: NSBackingStoreBuffered
			defer: NO];
	  }
	else
	  {
	    aWindow = [[NSPanel alloc] 
			initWithContentRect: NSMakeRect(0,0, IVW, IVH)
			styleMask: style
			backing: NSBackingStoreBuffered
			defer: NO];
	  }
	
	[aWindow setFrameTopLeftPoint:
		   NSMakePoint(230, frame.size.height-100)];
	[aWindow setTitle: _(@"Inspector Window")];
	[doc setName: @"InspectorWin" forObject: aWindow];
	[doc attachObject: aWindow toParent: nil];
      }
      break;
    case GormPalette:
      {
	NSPanel	 *aWindow;
	NSRect	 frame = [[NSScreen mainScreen] frame];
	unsigned style = NSTitledWindowMask | NSClosableWindowMask;
	
	if ([NSPanel respondsToSelector: @selector(allocSubstitute)])
	  {
	    aWindow = [[NSPanel allocSubstitute] 
			initWithContentRect: NSMakeRect(0,0,272,160)
			styleMask: style
			backing: NSBackingStoreBuffered
			defer: NO];
	  }
	else
	  {
	    aWindow = [[NSPanel alloc] 
			initWithContentRect: NSMakeRect(0,0,272,160)
			styleMask: style
			backing: NSBackingStoreBuffered
			defer: NO];
	  }

	[aWindow setFrameTopLeftPoint:
		   NSMakePoint(230, frame.size.height-100)];
	[aWindow setTitle: _(@"Palette Window")];
	[doc setName: @"PaletteWin" forObject: aWindow];
	[doc attachObject: aWindow toParent: nil];
      }
      break;
    case GormEmpty:
      {
	// nothing to do...
      }
      break;
    default:
      {
	NSLog(@"Unknown document type...");
      }
    }

  // set the filetype and touch the document.
  [doc setFileType: @"GSGormFileType"];
}

- (void) newDocument: (id)sender
{
  GormDocumentType documentType = GormApplication;

  if([sender respondsToSelector: @selector(tag)])
    {
      documentType = (GormDocumentType)[sender tag];
    }

  [super newDocument: sender];
  [self buildDocumentForType: documentType];
}

- (id) openDocumentWithContentsOfURL:(NSURL *)url
{
  return  [self openDocumentWithContentsOfURL:url display:YES];
}
@end
