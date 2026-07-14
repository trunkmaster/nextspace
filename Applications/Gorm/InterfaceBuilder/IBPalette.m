/* IBPalette.m
 *
 * Copyright (C) 2003 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2003
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2.1 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "IBPalette.h"

NSString	*IBCellPboardType = @"IBCellPboardType";
NSString	*IBMenuPboardType = @"IBMenuPboardType";
NSString	*IBMenuCellPboardType = @"IBMenuCellPboardType";
NSString	*IBObjectPboardType = @"IBObjectPboardType";
NSString	*IBViewPboardType = @"IBViewPboardType";
NSString	*IBWindowPboardType = @"IBWindowPboardType";
NSString	*IBFormatterPboardType = @"IBFormatterPboardType";

// Gorm specific paste board types..
NSString        *GormImagePboardType = @"GormImagePboardType";
NSString        *GormSoundPboardType = @"GormSoundPboardType";
NSString        *GormLinkPboardType = @"GormLinkPboardType";

@implementation	IBPalette

static NSMapTable	*viewToObject = 0;
static NSMapTable	*viewToType = 0;

+ (void) initialize
{
  if (self == [IBPalette class])
    {
      viewToObject = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSObjectMapValueCallBacks, 20);
      viewToType = NSCreateMapTable(NSNonOwnedPointerMapKeyCallBacks,
	NSObjectMapValueCallBacks, 20);
    }
}

+ (id) objectForView: (NSView*)aView
{
  id	obj = (id)NSMapGet(viewToObject, (void*)aView);

  if (obj == nil)
    {
      obj = aView;
    }
  return obj;
}

+ (NSString*) typeForView: (NSView*)aView
{
  NSString	*type = (NSString*)NSMapGet(viewToType, (void*)aView);

  if (type == nil)
    {
      type = IBViewPboardType;
    }
  return type;
}

- (void) associateObject: (id)anObject
		    type: (NSString*)aType
		    with: (NSView*)aView
{
  NSMapInsert(viewToType, (void*)aView, (id)aType);
  NSMapInsert(viewToObject, (void*)aView, (id)anObject);
}

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(icon);
  RELEASE(paletteDocument);
  [super dealloc];
}

- (void) finishInstantiate
{
}

- (id) init
{
  NSBundle	*bundle;
  NSDictionary	*paletteInfo;
  NSString	*fileName;
  
  bundle = [NSBundle bundleForClass: [self class]]; 

  // load the palette dictionary...
  fileName = [bundle pathForResource: @"palette" ofType: @"table"];
  paletteInfo = [[NSString stringWithContentsOfFile: fileName]
		  propertyList];

  // load the image...
  fileName = [paletteInfo objectForKey: @"Icon"];
  fileName = [bundle pathForImageResource: fileName];
  if (fileName == nil)
    {
      NSRunAlertPanel(NULL, 
		      [NSString stringWithFormat: @"Palette could not load image %@.", 
				fileName],
		      @"OK", NULL, NULL);
      AUTORELEASE(self);
      return nil;
    }
  icon = [[NSImage alloc] initWithContentsOfFile: fileName];

  // load the nibfile...
  fileName = [paletteInfo objectForKey: @"NibFile"];
  if (fileName != nil && [fileName isEqual: @""] == NO)
    {
      NSDictionary *context = [NSDictionary dictionaryWithObjectsAndKeys: self, @"NSOwner",nil];
      if ([bundle loadNibFile: fileName
		  externalNameTable: context
		  withZone: NSDefaultMallocZone()] == NO)
	{
	  NSRunAlertPanel(NULL, 
			  [NSString stringWithFormat: @"Palette could not load nib/gorm %@.", 
				    fileName],
			  @"OK", NULL, NULL);
	  AUTORELEASE(self);
	  return nil;
	}
    }

  return self;
}

- (NSImage*) paletteIcon
{
  return icon;
}

- (NSWindow*) originalWindow
{
  return originalWindow;
}

- (id<IBDocuments>) paletteDocument
{
  return paletteDocument;
}
@end
