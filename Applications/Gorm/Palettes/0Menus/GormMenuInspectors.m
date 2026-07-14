/* GormMenuInspectors.m
 *
 * Copyright (C) 2000 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Date:	2000
 * Author:  Gregory John Casamento <greg_casamento@yahoo.com>
 * Date: 2003
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

#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>
#include <GormCore/GormCore.h>

@interface GormMenuAttributesInspector : IBInspector
{
  NSTextField	*titleText;
  NSMatrix      *menuType;
  id             autoenable;
}
- (void) updateMenuType: (id)sender;
- (void) updateAutoenable: (id)sender;
@end

@implementation GormMenuAttributesInspector

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  [object setTitle: [titleText stringValue]];
  [super ok: self];
}

- (id) init
{
  if ([super init] == nil)
    return nil;

  if ([NSBundle loadNibNamed: @"GormMenuAttributesInspector" owner: self] == NO)
    {
      NSLog(@"Could not gorm GormMenuAttributesInspector");
      return nil;
    }
  return self;
}

- (void) setObject: (id)anObject
{
  GormDocument *doc = (GormDocument *)[(id<IB>)[NSApp delegate] activeDocument];

  ASSIGN(object, nil); // remove reference to old object...
  [super setObject: anObject];
  [titleText setStringValue: [object title]];
  [autoenable setState: ([object autoenablesItems]?NSOnState:NSOffState)];

  // set up the menu type matrix...
  if([doc windowsMenu] == anObject)
    {
      [menuType selectCellAtRow: 0 column: 0];
    }
  else if([doc servicesMenu] == anObject)
    {
      [menuType selectCellAtRow: 1 column: 0];
    }
  else // normal menu without any special function
    {
      [menuType selectCellAtRow: 2 column: 0];
    }
}

- (void) updateMenuType: (id)sender
{
  BOOL flag;
  GormDocument *doc = (GormDocument *)[(id<IB>)[NSApp delegate] activeDocument];

  // look at the values passed back in the matrix.
  flag = ([[menuType cellAtRow: 0 column: 0] state] == NSOnState) ? YES : NO; // windows menu...

  if(flag) 
    { 
      [doc setWindowsMenu: [self object]]; 
      if([doc servicesMenu] == [self object])
	{
	  [doc setServicesMenu: nil];
	}
    }

  flag = ([[menuType cellAtRow: 1 column: 0] state] == NSOnState) ? YES : NO; // services menu...
  if(flag) 
    { 
      [doc setServicesMenu: [self object]];
      if([doc windowsMenu] == [self object])
	{
	  [doc setWindowsMenu: nil];
	}
    }

  flag = ([[menuType cellAtRow: 2 column: 0] state] == NSOnState) ? YES : NO; // normal menu...
  if(flag) 
    {
      if([doc windowsMenu] == [self object])
	{
	  [doc setWindowsMenu: nil];
	}
      if([doc servicesMenu] == [self object])
	{
	  [doc setServicesMenu: nil];
	}
    }

  [super ok: sender];
}

- (void) updateAutoenable: (id)sender
{
  BOOL flag;

  // look at the values passed back in the matrix.
  flag = ([autoenable state] == NSOnState) ? YES : NO;
  [object setAutoenablesItems: flag];

  [super ok: sender];
}

@end



@interface GormMenuItemAttributesInspector : IBInspector
{
  NSTextField	*titleText;
  NSTextField	*shortCut;
  NSTextField	*tagText;
}
@end

@implementation GormMenuItemAttributesInspector

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  id	o = [aNotification object];
  id<IBDocuments> doc = [(id<IB>)[NSApp delegate] activeDocument];

  if (o == titleText)
    {
      [object setTitle: [titleText stringValue]];
    }
  if (o == shortCut)
    {
      NSString	*s = [[shortCut stringValue] stringByTrimmingSpaces];

      [object setKeyEquivalent: s];
    }
  if (o == tagText)
    {
      [object setTag: [tagText intValue]];
    }

  [doc touch];
  [[object menu] display];
}

- (id) init
{
  if ([super init] == nil)
    {
      return nil;
    }
  
  if ([NSBundle loadNibNamed: @"GormMenuItemAttributesInspector"
                       owner: self] == NO)
    {
      NSLog(@"Could not gorm GormMenuItemAttributesInspector");
      return nil;
    }
  
  return self;
}

- (void) setObject: (id)anObject
{
  [super setObject: anObject];
  [titleText setStringValue: [object title]];
  [shortCut setStringValue: [object keyEquivalent]];
  [tagText setIntValue: [object tag]];
}

@end
