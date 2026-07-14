/* inspectors - Various inspectors for control elements

   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Adam Fedor <fedor@gnu.org>
            Laurent Julliard <laurent@julliard-online.org>
   Date: Aug 2001
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2003, 2005
   
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

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include "GormButtonAttributesInspector.h"

/* This macro makes sure that the string contains a value, even if @"" */
#define VSTR(str) ({NSString *_str = (NSString *)str; ((NSString *)_str) ? (NSString *)_str : (NSString *)@"";})

const unichar up[]={NSUpArrowFunctionKey};
const unichar dn[]={NSDownArrowFunctionKey};
const unichar lt[]={NSLeftArrowFunctionKey};
const unichar rt[]={NSRightArrowFunctionKey};

NSString *upString = nil;
NSString *dnString = nil;
NSString *ltString = nil;
NSString *rtString = nil;


// trivial cell subclass.
@interface GormButtonCellAttributesInspector : GormButtonAttributesInspector
@end

@implementation GormButtonCellAttributesInspector
@end

@implementation GormButtonAttributesInspector

- (id) init
{
  if ([super init] == nil)
      return nil;

  if ([NSBundle loadNibNamed: @"GormNSButtonInspector" owner: self] == NO)
    {
      NSLog(@"Could not load GormButtonInspector");
      return nil;
    }
 
  // initialize the strings.
  upString = RETAIN([NSString stringWithCharacters: up length: 1]);
  dnString = RETAIN([NSString stringWithCharacters: dn length: 1]);
  ltString = RETAIN([NSString stringWithCharacters: lt length: 1]);
  rtString = RETAIN([NSString stringWithCharacters: rt length: 1]);

  return self;
}

- (void) dealloc
{
  RELEASE(upString);
  RELEASE(dnString);
  RELEASE(ltString);
  RELEASE(rtString);
  [super dealloc];
}

/* The button type isn't stored in the button, so reverse-engineer it */
- (NSButtonType) buttonTypeForObject: (id)button
{
  NSButtonCell *cell;
  NSButtonType type;
  int highlight, stateby;

  /* We could be passed the button or the cell */
  cell = ([button isKindOfClass: [NSButton class]]) ? [button cell] : button;

  highlight = [cell highlightsBy];
  stateby = [cell showsStateBy];
  NSDebugLog(@"highlight = %d, stateby = %d",
    (int)[cell highlightsBy],(int)[cell showsStateBy]);
  
  type = NSMomentaryPushInButton;
  if (highlight == NSChangeBackgroundCellMask)
    {
      if (stateby == NSNoCellMask)
	type = NSMomentaryLightButton;
      else 
	type = NSOnOffButton;
    }
  else if (highlight == (NSPushInCellMask | NSChangeGrayCellMask))
    {
      if (stateby == NSNoCellMask)
	type = NSMomentaryPushInButton;
      else
	type = NSPushOnPushOffButton;
    }
  else if (highlight == (NSPushInCellMask | NSContentsCellMask))
    {
      type = NSToggleButton;
    }
  else if (highlight == NSContentsCellMask)
    {
      if (stateby == NSNoCellMask)
	type = NSMomentaryChangeButton;
      else
	type = NSToggleButton; /* Really switch or radio. What should it be? */
    }
  else
    {
      NSDebugLog(@"Ack! no button type");
    }

  return type;
}

- (void) ok: (id) sender
{
  id obj = object;
  if ([object respondsToSelector: @selector(prototype)])
    {
      obj = [object prototype];
    }
  
  if (sender == alignMatrix)
    {
      [(NSButton *)obj setAlignment: (NSTextAlignment)[[sender selectedCell] tag]];
    }
  else if (sender == iconMatrix)
    {
      [(NSButton *)obj setImagePosition: 
		     (NSCellImagePosition)[[sender selectedCell] tag]];
    }
  else if (sender == keyForm)
    {
      // if the user does his own thing, select the default...
      [keyEquiv selectItemAtIndex: 0];
      [obj setKeyEquivalent: [[sender cellAtIndex: 0] stringValue]];
    }
  else if (sender == keyEquiv)
    {
      unsigned int tag = [[keyEquiv selectedItem] tag];
      switch(tag)
	{
	case 0: // none
	  {
	    [obj setKeyEquivalent: nil];
	  }
	  break;
	case 1: // return
	  {
	    [obj setKeyEquivalent: @"\r"];
            [[keyForm cellAtIndex: 0] setStringValue: @"\\r"];
	  }
	  break;
	case 2: // delete 
	  {
	    [obj setKeyEquivalent: @"\b"];
            [[keyForm cellAtIndex: 0] setStringValue: @"\\b"];
	  }
	  break;
	case 3: // escape
	  {
	    [obj setKeyEquivalent: @"\E"];
            [[keyForm cellAtIndex: 0] setStringValue: @"\\E"];
	  }
	  break;
	case 4: // tab
	  {
	    [obj setKeyEquivalent: @"\t"];
            [[keyForm cellAtIndex: 0] setStringValue: @"\\t"];
	  }
	  break;
	case 5: // up
	  {
	    [obj setKeyEquivalent: upString];
	  }
	  break;
	case 6: // down
	  {
	    [obj setKeyEquivalent: dnString];
	  }
	  break;
	case 7: // left
	  {
	    [obj setKeyEquivalent: ltString];
	  }
	  break;
	case 8: // right
	  {
	    [obj setKeyEquivalent: rtString];
	  }
	  break;
	default: // should never happen..
	  {
	    [obj setKeyEquivalent: nil];
	    NSLog(@"This shouldn't happen.");
	  }
	  break;
	}
    }
  else if (sender == optionMatrix)
    {
      BOOL flag;

      flag = ([[sender cellAtRow: 0 column: 0] state] == NSOnState) ? YES : NO;
      [obj setBordered: flag];
      flag = ([[sender cellAtRow: 1 column: 0] state] == NSOnState) ? YES : NO;
      [obj setContinuous: flag];
      flag = ([[sender cellAtRow: 2 column: 0] state] == NSOnState) ? YES : NO;
      [obj setEnabled: flag];

      [obj setState: [[sender cellAtRow: 3 column: 0] state]];
      flag = ([[sender cellAtRow: 4 column: 0] state] == NSOnState) ? YES : NO;
      [obj setTransparent: flag];
    }
  else if (sender == tagForm)
    {
      [(NSButton *)obj setTag: [[sender cellAtIndex: 0] intValue]];
    }
  else if (sender == titleForm)
    {
      NSString *string;
      NSImage *image;
      
      [obj setTitle: [[sender cellAtIndex: 0] stringValue]];
      [obj setAlternateTitle: [[sender cellAtIndex: 1] stringValue]];

      string = [[sender cellAtIndex: 2] stringValue];
      if ([string length] > 0)
	{   
	  image = [NSImage imageNamed: string];
	  [obj setImage: image];
	}
      string = [[sender cellAtIndex: 3] stringValue];
      if ([string length] > 0)
	{
	  image = [NSImage imageNamed: string];
	  [obj setAlternateImage: image];
	}
    }
  else if (sender == typeButton) 
    {
      [obj setButtonType: [[sender selectedItem] tag]];
    }
  else if (sender == bezelButton) 
    {
      [obj setBezelStyle: [[sender selectedItem] tag]];
    }
  else if (sender == altMod)
    {
      if ([altMod state] == NSOnState)
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] | NSAlternateKeyMask];
	}
      else
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] & ~NSAlternateKeyMask];
	}
    }
  else if (sender == ctrlMod)
    {
      if ([ctrlMod state] == NSOnState)
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] | NSControlKeyMask];
	}
      else
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] & ~NSControlKeyMask];
	}
    }
  else if (sender == shiftMod)
    {
      if ([shiftMod state] == NSOnState)
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] | NSShiftKeyMask];
	}
      else
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] & ~NSShiftKeyMask];
	}
    }
  else if (sender == cmdMod)
    {
      if ([cmdMod state] == NSOnState)
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] | NSCommandKeyMask];
	}
      else
	{
	  [obj setKeyEquivalentModifierMask:
                 [obj keyEquivalentModifierMask] & ~NSCommandKeyMask];
	}
    }

  if ([object respondsToSelector: @selector(prototype)])
    {
      [object setPrototype: obj];
    }

  [super ok: sender];
}

-(void) revert: (id)sender
{
  NSImage *image;
  id      obj = object;

  if ([object respondsToSelector: @selector(prototype)])
    {
      obj = [object prototype];
    }

  if(sender != nil)
    {
      NSString *key = VSTR([obj keyEquivalent]);
      unsigned int flags = [obj keyEquivalentModifierMask];
      
      [alignMatrix selectCellWithTag: [obj alignment]];
      [iconMatrix selectCellWithTag: [obj imagePosition]];
      [[keyForm cellAtIndex: 0] setStringValue: key];
      
      if ([key isEqualToString: @"\r"])
	{
	  [keyEquiv selectItemAtIndex: 1];
	}
      else if ([key isEqualToString: @"\b"])
	{
	  [keyEquiv selectItemAtIndex: 2];
	}
      else if ([key isEqualToString: @"\E"])
	{
	  [keyEquiv selectItemAtIndex: 3];
	}
      else if ([key isEqualToString: @"\t"])
	{
	  [keyEquiv selectItemAtIndex: 4];
	}
      else if ([key isEqualToString: upString])
	{
	  [keyEquiv selectItemAtIndex: 5];
	}
      else if ([key isEqualToString: dnString])
	{
	  [keyEquiv selectItemAtIndex: 6];
	}
      else if ([key isEqualToString: ltString])
	{
	  [keyEquiv selectItemAtIndex: 7];
	}
      else if ([key isEqualToString: rtString])
	{
	  [keyEquiv selectItemAtIndex: 8];
	}
      else
	{
	  [keyEquiv selectItemAtIndex: 0];
	}
      
      [optionMatrix deselectAllCells];
      if ([obj isBordered])
        [optionMatrix selectCellAtRow: 0 column: 0];
      if ([obj isContinuous])
        [optionMatrix selectCellAtRow: 1 column: 0];
      if ([obj isEnabled])
        [optionMatrix selectCellAtRow: 2 column: 0];
      if ([obj state] == NSOnState)
        [optionMatrix selectCellAtRow: 3 column: 0];
      if ([obj isTransparent])
        [optionMatrix selectCellAtRow: 4 column: 0]; 
     
      [[tagForm cellAtIndex: 0] setIntValue: [(NSButton *)obj tag]];
      
      [[titleForm cellAtIndex: 0] setStringValue: VSTR([obj title])];
      [[titleForm cellAtIndex: 1] setStringValue: VSTR([obj alternateTitle])];
      
      image = [obj image];
      if (image != nil)
	{
	  [[titleForm cellAtIndex: 2] setStringValue: VSTR([image name])];
	}
      else
	{
	  [[titleForm cellAtIndex: 2] setStringValue: @""];
	}
      
      image = [obj alternateImage];
      if (image != nil)
	{
	  [[titleForm cellAtIndex: 3] setStringValue: VSTR([image name])];
	}
      else
	{
	  [[titleForm cellAtIndex: 3] setStringValue: @""];
	}
      
      // key modifier mask...
      [altMod setState: NSOffState];
      [ctrlMod setState: NSOffState];
      [shiftMod setState: NSOffState];
      [cmdMod setState: NSOffState];
      if(flags & NSAlternateKeyMask)
	{
	  [altMod setState: NSOnState];
	}
      if(flags & NSControlKeyMask)
	{
	  [ctrlMod setState: NSOnState];
	}
      if(flags & NSShiftKeyMask)
	{
	  [shiftMod setState: NSOnState];
	}
      if(flags & NSCommandKeyMask)
	{
	  [cmdMod setState: NSOnState];
	}

      [typeButton selectItemWithTag: [self buttonTypeForObject: obj]];

      [bezelButton selectItemAtIndex:
		     [bezelButton indexOfItemWithTag: [obj bezelStyle]]];
    }
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  [self ok: [aNotification object]];
}

- (void) selectKeyEquivalent: (id)sender
{
  NSLog(@"Select key equivalent: %d",(int)[[sender selectedItem] tag]);
}
@end
