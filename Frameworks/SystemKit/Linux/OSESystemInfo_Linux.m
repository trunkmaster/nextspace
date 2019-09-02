/*
 * OSESystemInfo_Linux.m - Linux specific backend for OSESystemInfo
 *
 * Copyright 2006, Serg Stoyan
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

#ifdef LINUX

// Supress clang message: 
// "warning: category is implementing a method which will also be implemented 
// by its primary class [-Wobjc-protocol-method-implementation]"
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"

#import <sys/utsname.h>

#import <Foundation/Foundation.h>
#import "OSESystemInfo.h"

@implementation OSESystemInfo (Linux)

// TODO
+ (unsigned int)batteryLife
{
  return 0;
}

// TODO
+ (unsigned char)batteryPercent
{
  return 0;
}

// TODO
+ (BOOL)isUsingMains
{
  return YES;
}

// TODO
+ (unsigned long long)realMemory
{
  NSString *memInfo = [NSString stringWithContentsOfFile:@"/proc/meminfo"];
  NSString *memTotal;
  // NSRange  memRange = [memInfo rangeOfString:@"MemTotal"];
  NSRange  memLineRange = [memInfo lineRangeForRange:[memInfo rangeOfString:@"MemTotal"]];
  NSArray *lineComps;

  memLineRange.length--; // drop EOL
  memTotal = [memInfo substringWithRange:memLineRange];

  lineComps = [memTotal componentsSeparatedByString:@" "];

  return atol([[lineComps objectAtIndex:[lineComps count]-2] cString])*1024;
}

+ (unsigned int)cpuMHzSpeed
{
  NSString     *name = [self cpuName];
  NSRange      speedSeparator = [name rangeOfString:@"@"];
  char         unit[2];
  double       speedValue;

  // If this isn't a format we recognise, give up.
  if (speedSeparator.location == NSNotFound)
    {
      return 0;
    }

  name = [name substringFromIndex:speedSeparator.location + 2];
 
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
  NSString *cpuInfo = [NSString stringWithContentsOfFile:@"/proc/cpuinfo"];
  NSString *modelName;
  NSRange  modelRange = [cpuInfo rangeOfString:@"model name"];
  NSRange  modelLineRange = [cpuInfo lineRangeForRange:modelRange];

  modelLineRange.length--; // drop EOL
  modelName = [cpuInfo substringWithRange:modelLineRange];

  return [[modelName componentsSeparatedByString:@":"] objectAtIndex:1];
}

+ (NSString *)_releaseFileValueForField:(NSString *)fieldName
{
  NSString *releaseFile = @"/etc/os-release";
  NSString *fileText;
  NSRange  fieldRange;
  NSString *value = nil;
  
  if ([[NSFileManager defaultManager] fileExistsAtPath:releaseFile]) {
    fileText = [NSString stringWithContentsOfFile:releaseFile];
    fieldRange = [fileText lineRangeForRange:[fileText rangeOfString:fieldName]];
    fieldRange.length--;
    
    value = [fileText substringWithRange:fieldRange];
    value = [[value componentsSeparatedByString:@"="] objectAtIndex:1];
    value = [value stringByReplacingOccurrencesOfString:@"\""
                                             withString:@""];
  }

  return value;
}

+ (NSString *)operatingSystem
{
  struct utsname buf;
  NSString       *osName;

  osName = [OSESystemInfo _releaseFileValueForField:@"NAME"];
  if (osName == nil) {
    uname(&buf);
    osName = [NSString stringWithUTF8String:buf.sysname];
  }

  return osName;
}

+ (NSString *)operatingSystemVersion
{
  struct utsname buf;
  NSString       *osVersion;

  osVersion = [OSESystemInfo _releaseFileValueForField:@"VERSION"];
  if (osVersion == nil) {
    uname(&buf);
    osVersion = [NSString stringWithUTF8String:buf.release];
  }

  return osVersion;
}

+ (BOOL)platformSupported
{
  return YES;
}

@end

#pragma clang diagnostic pop

#endif // LINUX
