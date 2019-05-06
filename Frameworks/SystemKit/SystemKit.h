/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
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

/*
*   OSESystemInfo
*     - readonly access to othe NXSystem* information;
*     - processor (type,speed), memory, OS (type, bitness);
*   OSEDeviceManager 
*     - register added/removed system devices 
*     - manages storage, monitor, mouse, keyboard, bluetooth devices
*     - uses HAL on Linux, devd or HAL on FreeBSD
*   OSEFileSystem - file system events monitor (create, delete, etc.)
*   NXSystemKeyboard - type, input languages, shortcuts, repeat rate
*   NXSystemMouse - type, acceleration, buttons mapping, pointer
*   NXSystemDisplay - monitors info, resolution, multimonitor modes, alpha
*   NXSystemSound - volume/bass/treble/balance, device information
*   NXSystemPower - power state, battery, hibernate, shutdown, restart, sleep
*   NXSystemNetwork - hostname, interfaces, routes, user initiated up/down, WiFi
*   NXSystemAuth - user authentification, user/groups management
*/

#import <SystemKit/SystemKitInfo.h>
