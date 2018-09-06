/*
   Icon preferences.

   Copyright (C) 2005 Saso Kiselkov

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

#define BROWSER_DEF_COLUMN_WIDTH 180
#define BROWSER_MIN_COLUMN_WIDTH 110
#define BROWSER_MAX_COLUMN_WIDTH 226

NSString *BrowserViewerColumnWidth = @"BrowserViewerColumnWidth";
NSString *BrowserViewerColumnWidthDidChangeNotification = @"BrowserViewerColumnWidthDidChangeNotification";

@interface BrowserPrefs : NSObject <PrefsModule>
{
  id    bogusWindow;
  id    button;
  id    rightArr;
  id    browser;
  NSBox *box;
  NSBox	*box2;
}

- (void)revert:sender;

@end
