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

#import "OSESystemInfo.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSString.h>

#import <sys/utsname.h>

// Ordered array of SI unit prefixes
static const char *UnitPrefixes = "kMGTPEZY";

static inline int
my_round(double value)
{
  return (int) (value + 0.5);
}

/**
 * Reformats a number and returns a string with SI unit suffixes
 * as necessary.
 *
 * @param value The value which to reformat
 * @param unitScale Defines the size of the unit between two unit skips.
 *      For example, for bytes, this is 1024 (1024B = 1kB, 1024kB = 1MB, ...),
 *      and frequencies it is 1000 (1000Hz = 1kHz, 1000kHz = 1MHz, ...).
 * @param unit The unit name which to append to the reformatted number,
 *      e.g. @"Hz" or @"B".
 * @param maxRoundedPrefix An index into the UnitPrefixes array which
 *      defines which of the units (at most) to round. For example for
 *      an input value which lies in the 'M' (mega) unit scale, which
 *      is index '1' in the array, if this argument is greater than or
 *      equal to one, the resulting number will be rounded to the nearest
 *      integer. Otherwise it would have been a real-number representation.
 *      This is useful for rounding memory sizes up to the MB scale,
 *      but representing them with real-numbers in scales higher than that.
 */
static NSString *
humanReadableNumber(double value,
		    unsigned int unitScale,
		    NSString *unit,
		    int maxRoundedPrefix)
{
  int prefix = -1;
  // Divide by the size of a prefix interval until we have a value
  // smaller than the prefix interval

  while (value >= unitScale)
    {
      value /= unitScale;
      prefix++;
    }

  if (prefix <= maxRoundedPrefix)
    {
      if (prefix >= 0)
	{
	  return [NSString stringWithFormat:@"%d %c%@", my_round (value),
		 UnitPrefixes[prefix], unit];
	}
      else
	{
	  return [NSString stringWithFormat:@"%d %@", my_round (value), unit];
	}
    }
  else
    {
      if (prefix >= 0)
	{
	  return [NSString stringWithFormat:@"%#3.2f %c%@", value,
		 UnitPrefixes[prefix], unit];
	}
      else
	{
	  return [NSString stringWithFormat:@"%#3.2f %@", value, unit];
	}
    }
}

@implementation OSESystemInfo

//-------------------------------------------------------------------------------
// -- Platform specific methods. Must be overriden in category.
//-------------------------------------------------------------------------------

/**
 * Returns the remaining battery life in minutes
 */
+ (unsigned int)batteryLife
{
  return 0;
}

/**
 * Returns the remaining battery life as a percentage
 */
+ (unsigned char)batteryPercent
{
  return 0;
}

/**
 * Indicates whether system is running on battery power.
 */
+ (BOOL)isUsingBattery
{
  return NO;
}

/**
 * Returns the real memory size in bytes.
 */
+ (unsigned long long)realMemory
{
  return 0;
}

/**
 * Returns the CPU speed in MHz.
 */
+ (unsigned int)cpuMHzSpeed
{
  return 0;
}

/**
 * Returns the plain CPU name as known to the operating system.
 * The default class implementation always returns 'nil'.
 */
+ (NSString *)cpuName
{
  return nil;
}

/**
 * Returns whether the current platform is supported.
 * This is used by other routines inside OSESystemInfo to determine whether to
 * return strings like "(unknown)".
 * The default class implementation always returns 'NO'.
 */
+ (BOOL)platformSupported
{
  return NO;
}

//-------------------------------------------------------------------------------
// -- Platform independent methods.
//-------------------------------------------------------------------------------

/**
 * Retrurns a reformatted real memory size.
 */
+ (NSString *)humanReadableRealMemory
{
  if ([self platformSupported])
    {
      return humanReadableNumber ((double) [self realMemory], 1024, @"B", 1);
    }
  else
    {
      return _(@"(unknown)");
    }
}

/**
 * Returns a reformatted CPU MHz speed.
 */
+ (NSString *)humanReadableCPUSpeed
{
  if ([self platformSupported])
    {
      // Reformat the MHz speed
      return humanReadableNumber ((double) [self cpuMHzSpeed] * 1000000, 1000,
				  @"Hz", 1);
    }
  else
    {
      return _(@"(unknown)");
    }
}

/**
 * Returns the CPU name with the following modifications:
 *
 * - '(R)' sequences are removed
 * - '(TM)' sequences are removed
 * - 'processor' sequences are removed
 * - converts a tab character to a single space
 * - if a 'CPU' word is found, it is stripped and anything that follows it.
 * - sequences of spaces are reduced to a single space
 *
 * @return The cleaned CPU name.
 */
+ (NSString *)tidyCPUName
{
  if ([self platformSupported])
    {
      NSMutableString *name = [NSMutableString stringWithString: [self
	cpuName]];
      NSRange cpuStringRange;

      [name replaceOccurrencesOfString: @"(R)"
			    withString: @""
			       options: NSCaseInsensitiveSearch
				 range: NSMakeRange (0, [name length])];
      [name replaceOccurrencesOfString: @"(TM)"
			    withString: @""
			       options: NSCaseInsensitiveSearch
				 range: NSMakeRange (0, [name length])];
      [name replaceOccurrencesOfString: @"processor"
			    withString: @""
			       options: NSCaseInsensitiveSearch
				 range: NSMakeRange (0, [name length])];
      [name replaceString: @"\t" withString: @" "];

      cpuStringRange = [name rangeOfString: @"CPU"];
      if (cpuStringRange.location != NSNotFound)
	{
	  [name deleteCharactersInRange:
	    NSMakeRange (cpuStringRange.location,
			 [name length] - cpuStringRange.location)];
	}

      int i, n;

      for (i = 0, n = [name length]; i < n; i++)
	{
	  unichar c = [name characterAtIndex: i];

	  if (c == ' ' && i < n - 1 && [name characterAtIndex: i + 1] == ' ')
	    {
	      [name deleteCharactersInRange: NSMakeRange (i, 1)];
	      i--;
	      n--;
	    }
	}

      return name;
    }
  else
    {
      return _(@"(unknown)");
    }
}

+ (NSString *)operatingSystemRelease
{
  return [NSString stringWithFormat:@"%@ %@",
                   [OSESystemInfo operatingSystem],
                   [OSESystemInfo operatingSystemVersion]];
}

/**
 * Returns the operating system's name.
 */
+ (NSString *)operatingSystem
{
  struct utsname buf;

  uname(&buf);

  return [NSString stringWithUTF8String:buf.sysname];
}

/**
 * Returns the operating system version.
 */
+ (NSString *)operatingSystemVersion
{
  struct utsname buf;

  uname(&buf);

  return [NSString stringWithUTF8String:buf.version];
}

/**
 * Returns the host on which we are running.
 */
+ (NSString *)hostName
{
  struct utsname buf;
  NSString *hostname;
  NSArray *components;

  uname (&buf);

  hostname = [NSString stringWithUTF8String:buf.nodename];
  components = [hostname componentsSeparatedByString:@"."];

  return [components objectAtIndex:0];
}

/**
 * Returns the host on which we are running.
 */
+ (NSString *)domainName
{
  struct utsname buf;
  NSString       *nodename;
  NSArray        *comps;
  NSMutableArray *domainComps = [NSMutableArray new];
  NSString       *domain;

  uname(&buf);

  nodename = [NSString stringWithUTF8String:buf.nodename];
  comps = [nodename componentsSeparatedByString:@"."];
  for (NSUInteger i = 1; i < [comps count]; i++) {
    [domainComps addObject:[comps objectAtIndex:i]];
  }
  domain = [domainComps componentsJoinedByString:@"."];
  [domainComps release];

  return domain;
}

/**
 * Returns the machine type we are running on.
 */
+ (NSString *)machineType
{
  struct utsname buf;

  uname (&buf);

  return [NSString stringWithUTF8String: buf.machine];
}

@end
