/*
   "Workspaces" preferences.

   Copyright (C) 2018 Sergii Stoian

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>
#import <NXAppKit/NXAppKit.h>

#import <Protocols/PrefsModule.h>

@interface WorkspacesPrefs : NSObject <PrefsModule>
{
  // Workspaces
  id window;
  id box;

  id showInDockBtn;
  id ws1, ws2, ws3, ws4, ws5, ws6, ws7, ws8, ws9, ws10;
  id nameField;
  id changeNameBtn;
}

- (void)revert:sender;

@end
