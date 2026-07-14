/*
   GormMenuItemAttributesInspector.m

   Copyright (C) 1999-2005 Free Software Foundation, Inc.

   Author:  Richard frith-Macdonald (richard@brainstorm.co.uk>
   Date: 1999
   
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
  July 2005 : Spilt inspector in separate classes.
  Always use ok: revert: methods
  Clean up
  Author : Fabien Vallon <fabien@sonappart.net>
*/

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include "GormMenuItemAttributesInspector.h"

const unichar up[]={NSUpArrowFunctionKey};
const unichar dn[]={NSDownArrowFunctionKey};
const unichar lt[]={NSLeftArrowFunctionKey};
const unichar rt[]={NSRightArrowFunctionKey};

#define VSTR(str) ({NSString *_str = (NSString *)str; ((NSString *)_str) ? (NSString *)_str : (NSString *)@"";})

@implementation GormMenuItemAttributesInspector

- (id) init
{
  if ([super init] == nil)
    return nil;

  if ([NSBundle loadNibNamed: @"GormMenuItemAttributesInspector" owner: self]
      == NO)
    {
      NSLog(@"Could not gorm GormMenuItemAttributesInspector");
      return nil;
    }

  // initialize the strings.
  upString = RETAIN([NSString stringWithCharacters: up length: 1]);
  dnString = RETAIN([NSString stringWithCharacters: dn length: 1]);
  ltString = RETAIN([NSString stringWithCharacters: lt length: 1]);
  rtString = RETAIN([NSString stringWithCharacters: rt length: 1]);

  return self;
}

- (void) awakeFromNib
{
  NSArray *cells = [keyType cells];
  NSEnumerator *en = [cells objectEnumerator];
  NSCell *cell = nil;
  while ((cell = [en nextObject]) != nil)
    {
      [cell setRefusesFirstResponder: YES];
    }
}

- (void) dealloc
{
  RELEASE(upString);
  RELEASE(dnString);
  RELEASE(ltString);
  RELEASE(rtString);
  [super dealloc];
}

- (void) revert: (id)sender
{
  unsigned int flags = [object keyEquivalentModifierMask];
  NSString *key = VSTR([object keyEquivalent]);

  if ( object == nil )
    return;

  [titleText setStringValue: VSTR([object title])];
  [tagText setIntValue: [object tag]];

  [shortCut setEnabled: NO];
  if([key isEqualToString: @"\n"])
    {
      [keyPopup selectItemAtIndex: 1];
    }
  else if([key isEqualToString: @"\b"])
    {
      [keyPopup selectItemAtIndex: 2];
    }
  else if([key isEqualToString: @"\E"])
    {
      [keyPopup selectItemAtIndex: 3];
    }
  else if([key isEqualToString: @"\t"])
    {
      [keyPopup selectItemAtIndex: 4];
    }
  else if([key isEqualToString: upString])
    {
      [keyPopup selectItemAtIndex: 5];
    }
  else if([key isEqualToString: dnString])
    {
      [keyPopup selectItemAtIndex: 6];
    }
  else if([key isEqualToString: ltString])
    {
      [keyPopup selectItemAtIndex: 7];
    }
  else if([key isEqualToString: rtString])
    {
      [keyPopup selectItemAtIndex: 8];
    }
  else
    {
      [keyPopup selectItemAtIndex: 0];
      [keyPopup setEnabled: NO];
      [keyType selectCellWithTag: 0];
      [shortCut setEnabled: YES];
      [shortCut setStringValue: key];
    }
  
  // key modifier mask...
  [altBtn setState: NSOffState];
  [ctrlBtn setState: NSOffState];
  [shiftBtn setState: NSOffState];
  [cmdBtn setState: NSOffState];
  if(flags & NSAlternateKeyMask)
    {
      [altBtn setState: NSOnState];
    }
  if(flags & NSControlKeyMask)
    {
      [ctrlBtn setState: NSOnState];
    }
  if(flags & NSShiftKeyMask)
    {
      [shiftBtn setState: NSOnState];
    }
  if(flags & NSCommandKeyMask)
    {
      [cmdBtn setState: NSOnState];
    }  
}

- (void) _setFunctionKeyEquivalent
{
  unsigned int tag = [[keyPopup selectedItem] tag];
  switch(tag)
    {
    case 0: // none
      {
        [object setKeyEquivalent: nil];
      }
      break;
    case 1: // return
      {
        [object setKeyEquivalent: @"\n"];
      }
      break;
    case 2: // delete 
      {
        [object setKeyEquivalent: @"\b"];
      }
      break;
    case 3: // escape
      {
        [object setKeyEquivalent: @"\E"];
      }
      break;
    case 4: // tab
      {
        [object setKeyEquivalent: @"\t"];
      }
      break;
    case 5: // up
      {
        [object setKeyEquivalent: upString];
      }
      break;
    case 6: // down
      {
        [object setKeyEquivalent: dnString];
      }
      break;
    case 7: // left
      {
        [object setKeyEquivalent: ltString];
      }
      break;
    case 8: // right
      {
        [object setKeyEquivalent: rtString];
      }
      break;
    default: // should never happen..
      {
        [object setKeyEquivalent: nil];
        NSLog(@"This shouldn't happen.");
      }
      break;
    }
}

-(void) ok: (id)sender
{
  if (sender == titleText)
    {
      [object setTitle: [titleText stringValue]];
    }
  if (sender == shortCut)
    {
      NSString *keyEq = [shortCut stringValue];
      if ([keyEq length] > 1)
        {
          keyEq = [NSString stringWithFormat:@"%c", [keyEq characterAtIndex: 0]];
          [shortCut setStringValue: keyEq];
          NSBeep();
        }
      [object setKeyEquivalent:[keyEq stringByTrimmingSpaces]];
    }
  if (sender == tagText)
    {
      [object setTag: [tagText intValue]];
    }
  else if (sender == keyPopup)
    {
      [self _setFunctionKeyEquivalent];
    }
  else if (sender == keyType)
    {
      switch ([[keyType selectedCell] tag])
        {
        case 0:
          [keyPopup selectItemWithTag: 0];
          [keyPopup setEnabled: NO];
          [shortCut setEnabled: YES];
          [object setKeyEquivalent:[[shortCut stringValue] stringByTrimmingSpaces]];
          break;
        case 1:
          // [shortCut setStringValue: @""];
          [shortCut setEnabled: NO];
          [keyPopup setEnabled: YES];
          [self _setFunctionKeyEquivalent];
          break;
        }
    }
  else if (sender == altBtn)
    {
      if([altBtn state] == NSOnState)
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] | NSAlternateKeyMask];
	}
      else
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] & ~NSAlternateKeyMask];
	}
      [[object menu] itemChanged: object];
    }
  else if (sender == ctrlBtn)
    {
      if([ctrlBtn state] == NSOnState)
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] | NSControlKeyMask];
	}
      else
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] & ~NSControlKeyMask];
	}
      [[object menu] itemChanged: object];
    }
  else if (sender == shiftBtn)
    {
      if([shiftBtn state] == NSOnState)
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] | NSShiftKeyMask];
	}
      else
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] & ~NSShiftKeyMask];
	}
      [[object menu] itemChanged: object];
    }
  else if (sender == cmdBtn)
    {
      if([cmdBtn state] == NSOnState)
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] | NSCommandKeyMask];
	}
      else
	{
	  [object setKeyEquivalentModifierMask: 
		    [object keyEquivalentModifierMask] & ~NSCommandKeyMask];
	}
      [[object menu] itemChanged: object];
    }

  [super ok:sender];
}

- (void) controlTextDidChange: (NSNotification *)aNotification
{
  [self ok: [aNotification object]];
}

@end
