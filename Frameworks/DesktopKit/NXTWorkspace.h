/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-present Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <Foundation/NSString.h>

/*
   Notifications to communicate with applications. Manadatory prefixes in
   notification names are:
     - WMShould for notification from application to perform some action
     - WMDid to notify application about action completion
   Every WMDid should complement WMShould notification.

   All notifications object must be set to @"GSWorkspaceNotification".
   Otherwise Workspace Manager will ignore this notification.
*/
// WM.plist
extern NSString* WMDidChangeAppearanceSettingsNotification;
// WMState.plist
extern NSString* WMDidChangeDockContentNotification;

/*
   All WMShould and WMDid notifications must contain in userInfo:
     "WindowID" = CFNumber;
     "ApplicationName" = CFString;
 */
// Hide All
extern NSString* WMShouldHideOthersNotification;
extern NSString* WMDidHideOthersNotification;
// Quit or Force Quit
extern NSString* WMShouldTerminateApplicationNotification;
extern NSString* WMDidTerminateApplicationNotification;
// Zoom Window
/* additional userInfo element:
   "ZoomType" = "Vertical" | "Horizontal" | "Maximize"; */
extern NSString* WMShouldZoomWindowNotification;
extern NSString* WMDidZoomWindowNotification;
// Tile Window
/* additional userInfo element:
   "TileDirection" = "Left" | "Right" | "Top" | "Bottom"; */
extern NSString* WMShouldTileWindowNotification;
extern NSString* WMDidTileWindowNotification;
// Shade Window
extern NSString* WMShouldShadeWindowNotification;
extern NSString* WMDidShadeWindowNotification;
// Arrange in Front
extern NSString* WMShouldArrangeWindowsNotification;
extern NSString* WMDidArrangeWindowsNotification;
// Miniaturize Window
extern NSString* WMShouldMinmizeWindowNotification;
extern NSString* WMDidMinmizeWindowNotification;
// Close Window
extern NSString* WMShouldCloseWindowNotification;
extern NSString* WMDidCloseWindowNotification;