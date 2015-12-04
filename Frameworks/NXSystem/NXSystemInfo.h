/*
 * NXSystemInfo.h - NXSystemInfo class for determining information about the
 * current machine.  All platform-specific code is handled by extending
 * categories, the class only includes platform independent code.
 *
 * Copyright 2006, David Chisnall
 * Copyright 2013, Serg Stoyan
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without 
 * modification, are permitted provided that the following conditions are met:
 *
 * Redistributions of source code must retain the above copyright notice, 
 * this list of conditions and the following disclaimer.
 * 
 * Redistributions in binary form must reproduce the above copyright notice, 
 * this list of conditions and the following disclaimer in the documentation 
 * and/or other materials provided with the distribution.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */
#import <Foundation/NSObject.h>

@class NSString;

@interface NXSystemInfo : NSObject

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
+ (NSString *)operatingSystem;
+ (NSString *)operatingSystemVersion;
+ (NSString *)hostName;
+ (NSString *)machineType;

@end
