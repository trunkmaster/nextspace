/** <title>GSThemePanel</title>

   <abstract>Theme management utility</abstract>

   Copyright (C) 2010 Free Software Foundation, Inc.

   Author: Gregory John Casamento <greg.casamento@gmail.com>
   Date: 2010
   
   This file is part of the GNU Objective C User interface library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the 
   Free Software Foundation, 51 Franklin Street, Fifth Floor, 
   Boston, MA 02110-1301, USA.
*/

#import <Foundation/NSString.h>
#import <Foundation/NSArchiver.h>
#import "AppKit/NSMenu.h"
#import "AppKit/NSPanel.h"
#import "AppKit/NSWindow.h"
#import "AppKit/NSMenuView.h"
#import "AppKit/NSApplication.h"
#import "AppKit/NSImage.h"

#import "GNUstepGUI/GSTheme.h"
#import "GNUstepGUI/GSWindowDecorationView.h"

#import "NSToolbarFrameworkPrivate.h"
#import "GSGuiPrivate.h"


@interface NSWindow (Private)
- (GSWindowDecorationView *) windowView;
- (void) _setMenu: (NSMenu *)menu;
@end

@implementation NSWindow (Private)
- (GSWindowDecorationView *) windowView
{
  return _wv;
}

- (void) _setMenu: (NSMenu *)menu
{
  [super setMenu: menu];
}
@end

@interface NSMenu (GNUstepPrivate)

- (BOOL) _isMain;

- (void) _organizeMenu;

@end

@implementation	GSTheme (Menu)
- (void) setMenu: (NSMenu *)menu
       forWindow: (NSWindow *)window
{
  GSWindowDecorationView *wv = [window windowView];

  // protect against stupid calls from updateAllWindowsWithMenu:
  if ([window menu] == menu)
    return;

  // Prevent recursion
  [window _setMenu: menu];

  // Remove any possible old menu view
  [wv removeMenuView];

  //NSLog(@"Adding menu %@ to window %@", menu, window);
  if (menu != nil)
  {
    NSMenuView *menuView = [[NSMenuView alloc] initWithFrame: NSZeroRect];

    [menuView setMenu: menu];
    [menuView setHorizontal: YES];
    [menuView setInterfaceStyle: NSWindows95InterfaceStyle];
    [wv addMenuView: menuView];
    [menuView sizeToFit];
    RELEASE(menuView);
  } 
}

- (void) rightMouseDisplay: (NSMenu *)menu
		  forEvent: (NSEvent *)theEvent
{
  NSMenuView *mv = [menu menuRepresentation];
  if ([mv isHorizontal] == NO)
    {
      [menu displayTransient];
      [mv mouseDown: theEvent];
      [menu closeTransient];
    }
}

- (void) displayPopUpMenu: (NSMenuView *)mr
	    withCellFrame: (NSRect)cellFrame
	controlViewWindow: (NSWindow *)cvWin
	    preferredEdge: (NSRectEdge)edge
	     selectedItem: (int)selectedItem
{
  BOOL pe = [[GSTheme theme] doesProcessEventsForPopUpMenu];

  /* Ensure the window responds when run in modal and should
   * process events. Or revert this if theme has changed.
   */
  if (pe && ![[mr window] worksWhenModal])
    {
      [(NSPanel *)[mr window] setWorksWhenModal: YES];
    }

  if (!pe && [[mr window] worksWhenModal])
    {
      [(NSPanel *)[mr window] setWorksWhenModal: NO];
    }

  // Ask the MenuView to attach the menu to this rect
  [mr setWindowFrameForAttachingToRect: cellFrame
			      onScreen: [cvWin screen]
			 preferredEdge: edge
		     popUpSelectedItem: selectedItem];
  
  // Set to be above the main window
  [cvWin addChildWindow: [mr window] ordered: NSWindowAbove];

  // Last, display the window
  [[mr window] orderFrontRegardless];
}

- (void) processCommand: (void *)context
{
  // this is only implemented when we handle native menus.
  // put code in here to handle commands from the native menu structure.
}

- (float) menuHeightForWindow: (NSWindow *)window
{
  return [NSMenuView menuBarHeight];
}

- (void) updateMenu: (NSMenu *)menu forWindow: (NSWindow *)window
{
  [self setMenu: menu 
	forWindow: window];
}

- (void) updateAllWindowsWithMenu: (NSMenu *) menu
{
  NSEnumerator *en = [[NSApp windows] objectEnumerator];
  id            o = nil;

  while ((o = [en nextObject]) != nil)
    {
      if([o canBecomeMainWindow])
	{
	  [self updateMenu: menu forWindow: o];
	}
    }
}

- (BOOL) doesProcessEventsForPopUpMenu
{
  return NO; // themes that handle events in a popUpMenu should return YES
}

- (BOOL) menuShouldShowIcon
{
  return YES; // override whether or not to show the icon in the menu.
}

- (NSRect) modifyRect: (NSRect)aRect
	   forMenu: (NSMenu *)aMenu
	   isHorizontal: (BOOL) horizontal;
{
  return aRect;
}

- (CGFloat) proposedTitleWidth: (CGFloat)proposedWidth
		   forMenuView: (NSMenuView *)aMenuView
{
  return proposedWidth;
}

- (NSString *) keyForKeyEquivalent: (NSString *)aString
{
  return aString;
}

- (NSString *) proposedTitle: (NSString *)title
		 forMenuItem: (NSMenuItem *)menuItem
{
  return title;
}

- (void) organizeMenu: (NSMenu *)menu
	 isHorizontal: (BOOL)horizontal
{
  NSString *infoString = _(@"Info");
  NSString *servicesString = _(@"Services");
  int i;

  if ([menu _isMain])
    {
      NSString *appTitle;
      NSMenu *appMenu;
      id <NSMenuItem> appItem;

      appTitle = [[[NSBundle mainBundle] localizedInfoDictionary]
                     objectForKey: @"ApplicationName"];
      if (nil == appTitle)
        {
          appTitle = [[NSProcessInfo processInfo] processName];
        }
      appItem = [menu itemWithTitle: appTitle];
      appMenu = [appItem submenu];

      if (horizontal == YES)
        {
          NSMutableArray *itemsToMove;
	  
          itemsToMove = [NSMutableArray new];
          
          if (appMenu == nil)
            {
              [menu insertItemWithTitle: appTitle
                    action: NULL
                    keyEquivalent: @"" 
                    atIndex: 0];
              appItem = [menu itemAtIndex: 0];
              appMenu = [NSMenu new];
              [menu setSubmenu: appMenu forItem: appItem];
              RELEASE(appMenu);
            }
          else
            {
              int index = [menu indexOfItem: appItem];
              
              if (index != 0)
                {
                  RETAIN (appItem);
                  [menu removeItemAtIndex: index];
                  [menu insertItem: appItem atIndex: 0];
                  RELEASE (appItem);
                }
            }

	  if ([[GSTheme theme] menuShouldShowIcon])
	    {
              NSImage *ti;
              float bar;
	      ti = [[NSApp applicationIconImage] copy];
	      if (ti == nil)
		{
		  ti = [[NSImage imageNamed: @"GNUstep"] copy];
		}
	      [ti setScalesWhenResized: YES];
	      bar = [NSMenuView menuBarHeight] - 4;
	      [ti setSize: NSMakeSize(bar, bar)];
	      [appItem setImage: ti];
	      RELEASE(ti);
	    }

          // Collect all simple items plus "Info" and "Services"
          for (i = 1; i < [[menu itemArray] count]; i++)
            {
              NSMenuItem *anItem = [[menu itemArray] objectAtIndex: i];
              NSString *title = [anItem title];
              NSMenu *submenu = [anItem submenu];

              if (submenu == nil)
                {
                  [itemsToMove addObject: anItem];
                }
              else
                {
                  // The menu may not be localized, so we have to 
                  // check both the English and the local version.
                  if ([title isEqual: @"Info"] ||
                      [title isEqual: @"Services"] ||
                      [title isEqual: infoString] ||
                      [title isEqual: servicesString])
                    {
                      [itemsToMove addObject: anItem];
                    }
                }
            }
          
          for (i = 0; i < [itemsToMove count]; i++)
            {
              NSMenuItem *anItem = [itemsToMove objectAtIndex: i];

              [menu removeItem: anItem];
              [appMenu addItem: anItem];
            }
          
          RELEASE(itemsToMove);
        }      
      else 
        {
          [appItem setImage: nil];
          if (appMenu != nil)
            {
              NSArray	*array = [NSArray arrayWithArray: [appMenu itemArray]];
              /* 
               * Everything above the Serives menu goes into the info submenu,
               * the rest into the main menu.
               */
              int k = [appMenu indexOfItemWithTitle: servicesString];

              // The menu may not be localized, so we have to 
              // check both the English and the local version.
              if (k == -1)
                k = [appMenu indexOfItemWithTitle: @"Services"];

              if ((k > 0) && ([[array objectAtIndex: k - 1] isSeparatorItem]))
                k--;

              if (k == 1)
                {
                  // Exactly one info item
                  NSMenuItem *anItem = [array objectAtIndex: 0];

                  [appMenu removeItem: anItem];
                  [menu insertItem: anItem atIndex: 0];
                }
              else if (k > 1)
                {
                  id <NSMenuItem> infoItem;
                  NSMenu *infoMenu;

                  // Multiple info items, add a submenu for them
                  [menu insertItemWithTitle: infoString
                        action: NULL
                        keyEquivalent: @"" 
                        atIndex: 0];
                  infoItem = [menu itemAtIndex: 0];
                  infoMenu = [NSMenu new];
                  [menu setSubmenu: infoMenu forItem: infoItem];
                  RELEASE(infoMenu);

                  for (i = 0; i < k; i++)
                    {
                      NSMenuItem *anItem = [array objectAtIndex: i];
                  
                      [appMenu removeItem: anItem];
                      [infoMenu addItem: anItem];
                    }
                }
              else
                {
                  // No service menu, or it is the first item.
                  // We still look for an info item.
                  NSMenuItem *anItem = [array objectAtIndex: 0];
                  NSString *title = [anItem title];

                  // The menu may not be localized, so we have to 
                  // check both the English and the local version.
                  if ([title isEqual: @"Info"] ||
                      [title isEqual: infoString])
                    {
                      [appMenu removeItem: anItem];
                      [menu insertItem: anItem atIndex: 0];
                      k = 1;
                    }
                  else
                    {
                      k = 0;
                    }
                }

              // Copy the remaining entries.
              for (i = k; i < [array count]; i++)
                {
                  NSMenuItem *anItem = [array objectAtIndex: i];
                  
                  [appMenu removeItem: anItem];
                  [menu addItem: anItem];
                }

              [menu removeItem: appItem];
            }
        }  
    }

  // recurse over all submenus
  for (i = 0; i < [[menu itemArray] count]; i++)
    {
      NSMenuItem *anItem = [[menu itemArray] objectAtIndex: i];
      NSMenu *submenu = [anItem submenu];

      if (submenu != nil)
        {
          if ([submenu isTransient])
            {
              [submenu closeTransient];
            }
          [submenu close];
          [submenu _organizeMenu];
        }
    }

  [[menu menuRepresentation] update];
  [menu sizeToFit];
}

- (BOOL) proposedVisibility: (BOOL)visible
	 forMenu: (NSMenu *) menu
{
  return visible;
}
@end

