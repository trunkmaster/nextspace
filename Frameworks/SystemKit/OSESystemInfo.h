/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Copyright (C) 2006 David Chisnall
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
 * OSESystemInfo.h - OSESystemInfo class for determining information about the
 * current machine.  All platform-specific code is handled by extending
 * categories, the class only includes platform independent code.
 */
#import <Foundation/NSObject.h>

@class NSString;

@interface OSESystemInfo : NSObject

/*
 * These methods must be overridden by platform-specific categories
 * to return the real info. The class-implemented methods are simply
 * dummy placeholders which get invoked in case the platform we're
 * running on doesn't have it's platform-specific implementation.
 */
+ (unsigned int)batteryLife;
+ (unsigned char)batteryPercent;
+ (BOOL)isUsingBattery;
+ (unsigned long long)realMemory;
+ (unsigned int)cpuMHzSpeed;
+ (NSString *)cpuName;
+ (BOOL)platformSupported;

// Platform independent portions
+ (NSString *)humanReadableRealMemory;
+ (NSString *)humanReadableCPUSpeed;
+ (NSString *)tidyCPUName;
+ (NSString *)operatingSystemRelease;
+ (NSString *)operatingSystem;
+ (NSString *)operatingSystemVersion;
+ (NSString *)hostName;
+ (NSString *)domainName;
+ (NSString *)machineType;

@end
