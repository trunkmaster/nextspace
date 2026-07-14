/* 
   GormTextViewAttributesInspector.m

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

#include <AppKit/AppKit.h>

// #warning GNUstep bug ?
#include <GormCore/GormCore.h>

#include "GormTextViewAttributesInspector.h"


@implementation GormTextViewAttributesInspector

- (id) init
{
  if ([super init] == nil)
    return nil;
    
  if ([NSBundle loadNibNamed: @"GormNSTextViewInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormTextViewInspector");
      return nil;
    }

  return self;
}

- (void) setObject: (id)anObject
{
  [super setObject: anObject];
  [self revert:anObject];
}

/* Commit changes that the user makes in the Attributes Inspector */
- (void) ok: (id) sender
{
  BOOL isScrollView;
  id scrollView;

  scrollView = [[object superview] superview];
  isScrollView = [scrollView isKindOfClass: [NSScrollView class]];

  if (sender == backgroundColorWell)
    {
      [object setBackgroundColor: [sender color]];
    }
  else if (sender == textColorWell)
    {
      [object setTextColor: [sender color]];
    }
  else if ( (sender == borderMatrix) && isScrollView)
    {
      [scrollView setBorderType: [[sender selectedCell] tag]];
      [scrollView setNeedsDisplay: YES];
    }
  /* options */
  else if ( sender == selectableButton ) 
    {
      [object setSelectable: [selectableButton state]];
    }
  else if ( sender == editableButton ) 
    {
      [object setEditable: [editableButton state]];
    }
  else if ( sender == multipleFontsButton )
    {
      [object setRichText:[multipleFontsButton state]];
    }
  else if ( sender == graphicsButton ) 
    {
      [object setImportsGraphics:[graphicsButton state]];
    }
  else if ( sender == undoButton )
    {
      [object setAllowsUndo:[undoButton state]];
    }
  else if ( sender == findPanelButton )
    {
      [object setUsesFindPanel:[findPanelButton state]];
    }
  
  [super ok:sender];
}

/* Sync from object ( NSTextView ) changes to the inspector   */
-(void) revert:(id) sender
{
  BOOL isScrollView;
  id scrollView;

  if (object == nil)
    return;

  scrollView = [[object superview] superview];
  isScrollView = [scrollView isKindOfClass: [NSScrollView class]];

  [backgroundColorWell setColorWithoutAction: [object backgroundColor]];
  [textColorWell setColorWithoutAction: [object textColor]];

  if (isScrollView) 
    [borderMatrix selectCellWithTag: [scrollView borderType]];

  /* options*/
  [selectableButton setState: [object isSelectable]];
  [editableButton setState: [object isEditable]];
  [multipleFontsButton setState: [object isRichText]];
  [graphicsButton setState: [object importsGraphics]];
  [undoButton setState: [object allowsUndo]];
  [findPanelButton setState: [object usesFindPanel]];

  [super revert:sender];
}

@end
