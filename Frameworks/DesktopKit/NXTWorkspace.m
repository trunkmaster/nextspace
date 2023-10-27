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

#import "NXTWorkspace.h"

// WM.plist
NSString* WMDidChangeAppearanceSettingsNotification = @"WMDidChangeAppearanceSettingsNotification";
// WMState.plist
NSString* WMDidChangeDockContentNotification = @"WMDidChangeDockContentNotification";
// Hide Others
NSString* WMShouldHideOthersNotification = @"WMShouldHideOthersNotification";
NSString* WMDidHideOthersNotification = @"WMDidHideOthersNotification";
// Quit or Force Quit
NSString* WMShouldTerminateApplicationNotification = @"WMShouldTerminateApplicationNotification";
NSString* WMDidTerminateApplicationNotification = @"WMDidTerminateApplicationNotification";
// Windows -> Zoom Window
NSString* WMShouldZoomWindowNotification = @"WMShouldZoomWindowNotification";
NSString* WMDidZoomWindowNotification = @"WMDidZoomWindowNotification";
// Windows -> Tile Window -> Left | Right | Top | Bottom
NSString* WMShouldTileWindowNotification = @"WMShouldTileWindowNotification";
NSString* WMDidTileWindowNotification = @"WMDidTileWindowNotification";
// Windows -> Shade Window
NSString* WMShouldShadeWindowNotification = @"WMShouldShadeWindowNotification";
NSString* WMDidShadeWindowNotification = @"WMDidShadeWindowNotification";
// Windows -> Arrange in Front
NSString* WMShouldArrangeWindowsNotification = @"WMShouldArrangeWindowsNotification";
NSString* WMDidArrangeWindowsNotification = @"WMDidArrangeWindowsNotification";
// Windows -> Miniaturize Window
NSString * WMShouldMinmizeWindowNotification = @"WMShouldMinmizeWindowNotification";
NSString* WMDidMinmizeWindowNotification = @"WMDidMinmizeWindowNotification";
// Windows -> Close Window
NSString* WMShouldCloseWindowNotification = @"WMShouldCloseWindowNotification";
NSString* WMDidCloseWindowNotification = @"WMDidCloseWindowNotification";
