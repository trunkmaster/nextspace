/*
  Class:               YahooForecast
  Inherits from:       NSObject
  Class descritopn:    Get and parse weather condition and forecast 
                       from yahoo.com.

  Copyright (C) 2016 Sergii Stoian <stoian255@ukr.net>

  -query: method 
  Created by Guilherme Chapiewski on 10/19/12.
  Copyright (c) 2012 Guilherme Chapiewski. All rights reserved.

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/NSImage.h>
#import "YahooForecast.h"

#define QUERY_PREFIX @"http://query.yahooapis.com/v1/public/yql?q="
#define QUERY_SUFFIX @"&format=json&env=store%3A%2F%2Fdatatables.org%2Falltableswithkeys&callback="

@implementation NSString (Modifications)

// TODO: modify original gnustep-back method
- (NSString*)stringByAddingPercentEscapes
{
  NSData        *data = [self dataUsingEncoding:NSASCIIStringEncoding];
  NSString      *s = nil;

  if (data != nil)
    {
      unsigned char     *src = (unsigned char*)[data bytes];
      unsigned int      slen = [data length];
      unsigned char     *dst;
      unsigned int      spos = 0;
      unsigned int      dpos = 0;
      BOOL              openQuote = NO;

      dst = (unsigned char*)NSZoneMalloc(NSDefaultMallocZone(), slen * 3);
      while (spos < slen)
        {
          unsigned char c = src[spos++];
          unsigned int  hi;
          unsigned int  lo;

          if (c <= 32 || c > 126 || c == 34 || c == 35 || c == 37
              || c == 60 || c == 61|| c == 62 || c == 91 || c == 92 || c == 93
              || c == 94 || c == 96 || c == 123 || c == 124 || c == 125)
            {
              // quoted text ends with space: adding quote before space
              if (c == 32 && openQuote == YES)
                {
                  dst[dpos++] = '%';
                  dst[dpos++] = '2';
                  dst[dpos++] = '2';
                  openQuote = NO;
                }
              
              dst[dpos++] = '%';
              hi = (c & 0xf0) >> 4;
              dst[dpos++] = (hi > 9) ? 'A' + hi - 10 : '0' + hi;
              lo = (c & 0x0f);
              dst[dpos++] = (lo > 9) ? 'A' + lo - 10 : '0' + lo;

              // '=' found: adding quote
              if (c == 61)
                {
                  dst[dpos++] = '%';
                  dst[dpos++] = '2';
                  dst[dpos++] = '2';
                  openQuote = YES;
                }
            }
          else
            {
              dst[dpos++] = c;
            }
        }
      if (openQuote == YES)
        {
          dst[dpos++] = '%';
          dst[dpos++] = '2';
          dst[dpos++] = '2';
        }
      s = [[NSString alloc] initWithBytes: dst
                                   length: dpos
                                 encoding: NSASCIIStringEncoding];
      NSZoneFree(NSDefaultMallocZone(), dst);
      IF_NO_GC([s autorelease];);
    }
  return s;
}

@end

@implementation YahooForecast : NSObject

- (id)init
{
  forecastList = [[NSMutableArray alloc] init];
  weatherCondition = [[NSMutableDictionary alloc] init];
  [weatherCondition setObject:forecastList forKey:@"Forecasts"];
  
  return self;
}

- (void)dealloc
{
  [weatherCondition release];
  [forecastList release];
  
  [super dealloc];
}

- (void)appendForecastForDay:(NSString *)day
                    highTemp:(NSString *)high
                     lowTemp:(NSString *)low
                 description:(NSString *)desc
{
  NSDictionary *dayForecast;

  dayForecast =
    [NSDictionary dictionaryWithObjectsAndKeys:
                    day,  @"Day",
                  high, @"High",
                  low,  @"Low",
                  desc, @"Description",
                  nil];
  // NSLog(@"Append forecast: %@", dayForecast);
  [forecastList addObject:dayForecast];
}

- (NSDictionary *)fetchWeatherWithWOEID:(NSString *)woeid
                                zipCode:(NSString *)zip
                                  units:(NSString *)units
{
  NSString	*queryString = @"select * from weather.forecast where";
  NSDictionary	*results;

  [weatherCondition removeObjectForKey:@"ErrorText"];

  if (!units || [units length] == 0)
    units = @"c";
  
  if (woeid != nil && [woeid length] > 0)
    {
      queryString = [queryString stringByAppendingFormat:@" woeid=%@", woeid];
    }
  else
    {
      queryString = [queryString stringByAppendingFormat:@" in (select woeid from geo.places(1) where text=%@", zip];
    }
  
  if (units != nil && [units length] > 0)
    {
      queryString = [queryString stringByAppendingFormat:@" and u=%@", units];
    }

  results = [self query:queryString];
  
  // NSLog(@"%@", results[@"query"][@"count"]);
  // NSLog(@"%@", results[@"query"][@"results"]);

  // id itemForecast =
  //   results[@"query"][@"results"][@"channel"][@"item"][@"forecast"];
  // id itemCondition =
  //   results[@"query"][@"results"][@"channel"][@"item"][@"condition"];
  
  // NSLog(@"condition is a %@; forecast is a %@",
  //       [itemCondition className], [itemForecast className]);
  // NSLog(@"forecast # of items = %lu", [itemForecast count]);

  // NSLog(@"Temp = %@ Text = %@ Code = %@",
  //       itemCondition[@"temp"],
  //       itemCondition[@"text"],
  //       itemCondition[@"code"]);

  // NSLog(@"results is a %@ (%lu)",
  //       [results className], [[results allKeys] count]);
  
  if (results != nil &&
      ![results[@"query"][@"results"] isKindOfClass:[NSNull class]])
    {
      NSString     *imageName;
      NSDictionary *channel = results[@"query"][@"results"][@"channel"];
        
      [weatherCondition setObject:channel[@"title"]
                           forKey:@"Title"];
      [weatherCondition setObject:channel[@"item"][@"condition"][@"temp"]
                           forKey:@"Temperature"];
      [weatherCondition setObject:channel[@"item"][@"condition"][@"text"]
                           forKey:@"Description"];
      [weatherCondition setObject:channel[@"atmosphere"][@"humidity"]
                           forKey:@"Humidity"];

      imageName = [NSString stringWithFormat:@"%@.png",
                            channel[@"item"][@"condition"][@"code"]];
      [weatherCondition setObject:[NSImage imageNamed:imageName]
                           forKey:@"Image"];
      
      for (NSDictionary *forecast in channel[@"item"][@"forecast"])
        {
          [self appendForecastForDay:forecast[@"day"]
                            highTemp:forecast[@"high"]
                             lowTemp:forecast[@"low"]
                         description:forecast[@"desc"]];
        }
      
      [weatherCondition setObject:[NSDate date] forKey:@"Fetched"];
    }
  else
    {
      [weatherCondition setObject:@"Error getting data from Yahoo!"
                           forKey:@"ErrorText"];
      NSLog(@"Error getting data from Yahoo! Results are: %@", results);
    }

  return weatherCondition;
}

- (NSDictionary *)query:(NSString *)statement
{
  NSString     *query;
  // NSString     *queryData;
  NSData       *jsonData;
  NSError      *error = nil;
  NSDictionary *results = nil;

  // Prepare query using modified NSString method implemented above
  query = [NSString stringWithFormat:@"%@%@%@",
                    QUERY_PREFIX,
                    [statement stringByAddingPercentEscapes],
                    QUERY_SUFFIX];
  // NSLog(@"Yahoo query URL: %@", query);

  // queryData = [NSString stringWithContentsOfURL:[NSURL URLWithString:query]
  //                                      encoding:NSUTF8StringEncoding
  //                                         error:&error];
  // if (error)
  //   {
  //     NSLog(@"[%@ %@] NSURL error: %@",
  //           NSStringFromClass([self class]),
  //           NSStringFromSelector(_cmd),
  //           error.localizedDescription);
  //     return nil;
  //   }
  
  // if ((jsonData = [queryData dataUsingEncoding:NSUTF8StringEncoding]))
  // Using above code doesn't always receive data from server.
  // Data will be get from cache of NSURLHandler.
  // TODO: something wrong with GNUstep code.
  if ((jsonData = [[NSURL URLWithString:query] resourceDataUsingCache:NO]))
    {
      NSLog(@"Got %lu bytes with query: %@", [jsonData length], query);
      results = [NSJSONSerialization JSONObjectWithData:jsonData
                                                options:0
                                                  error:&error];
      if (error || !results)
        {
          NSLog(@"[%@ %@] JSON error: %@",
                NSStringFromClass([self class]),
                NSStringFromSelector(_cmd),
                error.localizedDescription);
          results = nil;
        }
    }

  return results;
}

@end
