/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - SystemKit framework
//
// Description: FreeBSD specific backend for OSESystemInfo
//
// Copyright (C) 2006, David Chisnall, All rights reserved
// Copyright (C) 2014-2019 Sergii Stoian
//
// Redistribution and use in source and binary forms, with or without 
// modification, are permitted provided that the following conditions are met:
 
// Redistributions of source code must retain the above copyright notice, 
// this list of conditions and the following disclaimer.
  
// Redistributions in binary form must reproduce the above copyright notice, 
// this list of conditions and the following disclaimer in the documentation 
// and/or other materials provided with the distribution.
  
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
// POSSIBILITY OF SUCH DAMAGE.
//

#ifdef FREEBSD

// Supress clang message: 
// "warning: category is implementing a method which will also be implemented 
// by its primary class [-Wobjc-protocol-method-implementation]"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#import "OSESystemInfo.h"
#import "TRSysctlByName.h"

@implementation OSESystemInfo (FreeBSD)

+ (unsigned int)batteryLife
{
  return (unsigned int) performIntegerSysctlNamed("hw.acpi.battery.time");
}

+ (unsigned char)batteryPercent
{
  return (unsigned char) performIntegerSysctlNamed("hw.acpi.battery.life");
}

+ (BOOL)isUsingMains
{
  return (BOOL) performIntegerSysctlNamed("hw.acpi.acline");
}

+ (unsigned long long)realMemory
{
  return (unsigned long long) performIntegerSysctlNamed ("hw.physmem");
}

+ (unsigned int)cpuMHzSpeed
{
  unsigned int speed = 0;
  NSString     *name;
  NSRange      speedSeparator;
  char         unit[2];
  double       speedValue;

  speed = (unsigned int)performIntegerSysctlNamed("hw.clockrate");
  if (speed != 0)
    {
      return speed;
    }

  // We should not get to this point normally.
  // Code here is a work-around for the fact that old (pre-5.x) versions
  // of FreeBSD do not support the hw.clockrate sysctl, but instead append
  // the clock frequency of the CPU to the name.

  name = [self cpuName];
  speedSeparator = [name rangeOfString: @"CPU"];

  // If this isn't a format we recognise, give up.
  if (speedSeparator.location == NSNotFound)
    {
      return 0;
    }

  name = [name substringFromIndex:speedSeparator.location + 3];

  // We are expecting this string to contain xGHz.  If it doesn't,
  // then we don't know what to do with it, so give up
  if (sscanf ([name UTF8String]," %lf%cHz", &speedValue, unit) != 2)
    {
      return 0;
    }

  switch (unit[0])
    {
    case 'M':
      return (unsigned int) speedValue;
    case 'G':
      return (unsigned int) (speedValue * 1000.0);
    default:
      return 0;
    }
}

+ (NSString *)cpuName
{
  return performSysctlNamed ("hw.model");
}

+ (BOOL)platformSupported
{
  return YES;
}

@end

#pragma clang diagnostic pop

#endif // FREEBSD
