/*
 * NXSystemInfo_Linux.m - Linux specific backend for NXSystemInfo
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
#import "NXSystemInfo.h"

@implementation NXSystemInfo (Linux)

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

+ (NSString *)operatingSystemRelease
{
  struct utsname buf;
  NSString *osRelease;
  NSRange  typeRange;
  NSString *osType, *value;
  NSString *releaseFile;

  if ([[NSFileManager defaultManager] fileExistsAtPath:@"/etc/os-release"])
    {
      osRelease = [NSString stringWithContentsOfFile:@"/etc/os-release"];

      // OS type
      typeRange = [osRelease lineRangeForRange:[osRelease rangeOfString:@"ID"]];
      typeRange.length--;
      osType = [osRelease substringWithRange:typeRange];
      value = [[osType componentsSeparatedByString:@"="] objectAtIndex:1];
      osType = [value stringByReplacingOccurrencesOfString:@"\"" withString:@""];

      releaseFile = [NSString stringWithFormat:@"/etc/%@-release", osType];
      if ([[NSFileManager defaultManager] fileExistsAtPath:releaseFile])
        {
          return [NSString stringWithContentsOfFile:releaseFile];
        }
      else
        {
          return [NXSystemInfo operatingSystem];
        }
    }

  return @"unknown";
}

// OPTIMIZE
+ (NSString *)operatingSystem
{
  struct utsname buf;
  NSString *osRelease;
  NSRange  nameRange;
  NSString *osName;
  NSString *value;

  if ([[NSFileManager defaultManager] fileExistsAtPath:@"/etc/os-release"])
    {
      osRelease = [NSString stringWithContentsOfFile:@"/etc/os-release"];

      nameRange = [osRelease
                    lineRangeForRange:[osRelease rangeOfString:@"NAME"]];
      nameRange.length--;
      osName = [osRelease substringWithRange:nameRange];
      
      value = [[osName componentsSeparatedByString:@"="] objectAtIndex:1];

      return [value stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    }

  uname(&buf);

  return [NSString stringWithUTF8String:buf.sysname];
}

// OPTIMIZE
+ (NSString *)operatingSystemVersion
{
  struct utsname buf;
  NSString *osRelease;
  NSRange  range;
  NSString *line;
  NSString *value;

  if ([[NSFileManager defaultManager] fileExistsAtPath:@"/etc/os-release"])
    {
      osRelease = [NSString stringWithContentsOfFile:@"/etc/os-release"];
      range = [osRelease lineRangeForRange:[osRelease rangeOfString:@"VERSION"]];
      range.length--;
      line = [osRelease substringWithRange:range];
      value = [[line componentsSeparatedByString:@"="] objectAtIndex:1];
      
      return [value stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    }

  uname(&buf);

  return [NSString stringWithUTF8String:buf.release];
}

+ (BOOL)platformSupported
{
  return YES;
}

@end

#pragma clang diagnostic pop

#endif // LINUX
