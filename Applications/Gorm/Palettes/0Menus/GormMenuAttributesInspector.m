/*
   GormMenuAttributesInspector.m

   Copyright (C) 1999-2005 Free Software Foundation, Inc.

   Author:  Richard frith-Macdonald (richard@brainstorm.co.uk>
   Date: 1999
   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2003
   
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

#include <GormCore/GormCore.h>

#include "GormMenuAttributesInspector.h"
#include "GormNSMenu.h"



#define WINDOWSMENUTAG         0
#define SERVICESMENUTAG        1 
#define RECENTDOCUMENTSMENUTAG 2
#define NORMALMENUTAG          3

@implementation GormMenuAttributesInspector

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

-(void) ok:(id) sender
{
  if ( sender == titleText ) 
    {
      [object setTitle:[titleText stringValue]];
    }
  if ( sender == autoenable ) 
    {
      BOOL flag;
      
      // look at the values passed back in the matrix.
      flag = ([autoenable state] == NSOnState) ? YES : NO;
      [object setAutoenablesItems: flag];
    }
  else if ( sender == menuType ) 
    {
      GormDocument *doc = (GormDocument *)[(id<IB>)[NSApp delegate] activeDocument];
      int tag = [[menuType selectedCell] tag];
      
      switch ( tag ) 
	{
	case WINDOWSMENUTAG: 
	  [doc setWindowsMenu:object];
	  if ( [doc servicesMenu] == object ) 
	    [doc setServicesMenu: nil];
	  else if ( [doc recentDocumentsMenu] == object )	  
	    [doc setRecentDocumentsMenu: nil];
	  break;
	  
	case SERVICESMENUTAG:
	  [doc setServicesMenu: object];	  
	  if ( [doc windowsMenu] == object )	  
	    [doc setWindowsMenu: nil];
	  else if ( [doc recentDocumentsMenu] == object )	  
	    [doc setRecentDocumentsMenu: nil];
	  break;
	  
	case NORMALMENUTAG:
	  if ( [doc windowsMenu] == object )
	    [doc setWindowsMenu: nil]; 
	  if ( [doc servicesMenu] == object )
	    [doc setServicesMenu: nil];
	  break;
	  
	case RECENTDOCUMENTSMENUTAG: 
	  [doc setRecentDocumentsMenu:object];
	  if ( [doc servicesMenu] == object ) 
	    [doc setServicesMenu: nil];
	  else if ( [doc windowsMenu] == object )	  
	    [doc setWindowsMenu: nil];
	  break;
	}
    }

  [super ok:sender];
}



- (void) revert: (id)sender
{
  GormDocument *doc;
  
  if ( object == nil ) 
    return;

  doc = (GormDocument *)[(id<IB>)[NSApp delegate] activeDocument];

  [titleText setStringValue: [object title]];
  [autoenable setState: ([object realAutoenablesItems]?NSOnState:NSOffState)];

  // set up the menu type matrix...
  if([doc windowsMenu] == object)
    {
      [menuType selectCellAtRow:WINDOWSMENUTAG column: 0];
    }
  else if([doc servicesMenu] == object)
    {
      [menuType selectCellAtRow:SERVICESMENUTAG column: 0];
    }
  else if([doc recentDocumentsMenu] == object)
    {
      [menuType selectCellAtRow:RECENTDOCUMENTSMENUTAG column: 0];
    } 
  else 
    {
      [menuType selectCellAtRow:NORMALMENUTAG column: 0];
    }
}


/* delegate method used for menu title */
- (void)controlTextDidChange:(NSNotification *)aNotification
{
  GormDocument *doc = (GormDocument *)[(id<IB>)[NSApp delegate] activeDocument];
  [object setTitle: [titleText stringValue]];
  [doc touch];
}

@end

