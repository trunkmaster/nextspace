/*
   GormImageViewAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author:  Laurent Julliard <laurent@julliard-online.org>
   Date: Nov 2001
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

/*
  July 2005 : Split inspector classes into separate files.
  Always use ok: revert: methods
  Clean up
  Author : Fabien Vallon <fabien@sonappart.net>
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GormCore/GormCore.h>

#include "GormImageViewAttributesInspector.h"

/* This macro makes sure that the string contains a value, even if @"" */
#define VSTR(str) ({id _str = (id)str; (_str) ? (id)_str : (id)(@"");})

@implementation GormImageViewAttributesInspector

- (id) init
{
  if ([super init] == nil)
      return nil;

  if ([NSBundle loadNibNamed: @"GormNSImageViewInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormImageViewInspector");
      return nil;
    }

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id)sender
{
  /* icon name */
  if (sender == iconField)
    {
      NSString *name = [sender stringValue];
      NSImage *image;

      if (name == nil || [name isEqual: @""])
	{
	  [object setImage: nil];
	  return;
	}

      image = [NSImage imageNamed: name];
      if (image == nil)
	{
	  image = [[NSImage alloc] init]; // [[NSImage alloc] initByReferencingFile: name];
	  if (image)
	    {
	      [image setName: name];
	      [image setArchiveByName: YES];
	    }
	  else
	    {
	      // NSBeep();
	    }
	}
      // else
	{
	  [object setImage: image ];
	}
    }
  /* border */
  else  if (sender == borderMatrix)
    {
      [object setImageFrameStyle: [[sender selectedCell] tag]];
    }
  /* alignment */
  else if (sender == alignmentMatrix)
    {
      [object setImageAlignment: [[sender selectedCell] tag]];
    }
  /* scaling */
  else if (sender == scalingMatrix)
    {
      [object setImageScaling: [[sender selectedCell] tag]];
    }
  /* editable */
  else if (sender == editableSwitch)
    {
      [object setEditable: ([sender state] == NSOnState)];
    }

  [super ok:sender];
}

/* Sync from object ( ImageView ) changes to the inspector   */
-(void) revert:(id) sender
{
  if ( object == nil)
    return;

  if ( [ [[object image] name] isEqualToString: @"Sunday_seurat.tiff"] )
    [object setImage: nil];
  
  [iconField setStringValue: VSTR([[object image] name])];
  [borderMatrix selectCellWithTag: [object imageFrameStyle]];
  [alignmentMatrix selectCellWithTag: [object imageAlignment]];
  [scalingMatrix selectCellWithTag: [object imageScaling]];
  [editableSwitch setState: [object isEditable]];

  [super revert:sender];
}

/* delegate method for changing the ImageView Name */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  // [self ok:[aNotification object]];
}

@end
