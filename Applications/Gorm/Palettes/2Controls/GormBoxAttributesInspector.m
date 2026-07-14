/*
  GormBoxAttributesInspector.m

   Copyright (C) 2001-2005 Free Software Foundation, Inc.

   Author: Adam Fedor <fedor@gnu.org>
           Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   Author: Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2003, 2004, 2005  

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

#include "GormBoxAttributesInspector.h"

/* This macro makes sure that the string contains a value, even if @"" */
#define VSTR(str) ({id _str = (id)str; (_str) ? (id)_str : (id)(@"");})


/*
  IBObjectAdditions category
*/
@implementation	NSBox (IBObjectAdditions)
- (NSString*) inspectorClassName
{
  return @"GormBoxAttributesInspector";
}
@end


@implementation GormBoxAttributesInspector

- (id) init
{
  if ([super init] == nil)
      return nil;

  if ([NSBundle loadNibNamed: @"GormNSBoxInspector" owner: self] == NO)
    {
      NSLog(@"Could not load GormBoxInspector");
      return nil;
    }

  return self;
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  /* Position */
  if (sender == positionMatrix)
    {
      [object setTitlePosition: [[sender selectedCell] tag]];
    }
  /* border type */
  else if (sender == borderMatrix)
    {
      [object setBorderType: [[sender selectedCell] tag]];
    }
  /* title */
  else if (sender == titleForm)
    {
      [object setTitle: [[sender cellAtIndex: 0] stringValue]];
    }
  /* content view margins */
  else if (sender == horizontalSlider)
    {
      [object setContentViewMargins:
	NSMakeSize((float)[sender intValue], (float)[verticalSlider intValue])];
    }
  else if (sender == verticalSlider)
    {
      [object setContentViewMargins:
	NSMakeSize((float)[horizontalSlider intValue], (float)[sender intValue])];
    }
  /* title cell : background color, only useful for older NSBox instances */
  else if(sender == colorWell)
    {
      NSTextFieldCell *titleCell = (NSTextFieldCell *)[object titleCell];
      if([titleCell isKindOfClass: [NSTextFieldCell class]])
	{
	  [titleCell setBackgroundColor: [colorWell color]];
	  [object display];
	}
    }
  /* only useful for older NSBox instances */
  else if(sender == backgroundSwitch)
    {
      NSTextFieldCell *titleCell = (NSTextFieldCell *)[object titleCell];
      if([titleCell isKindOfClass: [NSTextFieldCell class]])
	{
	  BOOL state = ([backgroundSwitch state] == NSOnState)?YES:NO;
	  [titleCell setDrawsBackground: state];
	}
    }

  [super ok:sender];
}

/* Sync from object ( NSBox ) changes to the inspector   */
- (void) revert: (id) sender
{
  NSTextFieldCell *titleCell;
    
  if ( object == nil ) 
    return;

  /* Position */
  [positionMatrix selectCellWithTag: [object titlePosition]];
  /* Border Type */
  [borderMatrix selectCellWithTag: [object borderType]];
  /* title */
  [[titleForm cellAtIndex: 0] setStringValue: VSTR([object title])];
  /* content view margins */
  [horizontalSlider setIntValue: (int)[object contentViewMargins].width];
  [verticalSlider setIntValue: (int)[object contentViewMargins].height];

  /* title cell: background color */
  titleCell = (NSTextFieldCell *)[object titleCell];

  if([titleCell isKindOfClass: [NSTextFieldCell class]])
    {
      [colorWell setColorWithoutAction: [titleCell backgroundColor]];
      [backgroundSwitch setState: ([titleCell drawsBackground]?
				   NSOnState:NSOffState)];
    }

  [super revert:sender];
}


/* delegate method for titleForm */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  [self ok:[aNotification object]];
}

@end
