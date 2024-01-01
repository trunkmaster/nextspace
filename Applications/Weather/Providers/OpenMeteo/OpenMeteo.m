/*
  Class:               OpenMeteoForecast
  Class descritopn:    Get and parse weather condition and forecast 
                       from yahoo.com.

  Copyright (C) 2016 Sergii Stoian <stoian255@gmail.com>

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
#import "OpenMeteo.h"

#define QUERY_PREFIX @"https://api.open-meteo.com/v1/forecast?timezone=auto"
// Options
/*
   latitude=
   longitude=
   current=temperature_2m,apparent_temperature,is_day,weather_code,cloud_cover,wind_speed_10m
   timezone=auto
 */
// "latitude=%@&longitude=%@"
// "current=temperature_2m,apparent_temperature,is_day,weather_code,cloud_cover,wind_speed_10m,relative_humidity_2m"
#define QUERY_CURRENT                                                                            \
  @"current=temperature_2m,apparent_temperature,is_day,weather_code,cloud_cover,wind_speed_10m," \
  @"relative_humidity_2m"

@implementation OpenMeteo

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

- (NSString *)name
{
  return @"OpenMeteo";
}

- (void)setCityByName:(NSString *)name
{
  // Fetch latitude & longtidute from GeoNames
  // Geolocation - http://api.geonames.org/search?type=json&name=___&username=nextspace"
  coordiantes.latitude = @"50.45466";
  coordiantes.longtitude = @"30.5238";
}

- (void)setUnits:(NSString *)name
{
  //
}

- (void)setLanguage:(NSString *)code
{
  //
}

- (void)appendForecastForDay:(NSString *)day
                    highTemp:(NSString *)high
                     lowTemp:(NSString *)low
                 description:(NSString *)desc
{
  NSDictionary *dayForecast;

  dayForecast = @{@"Day" : day, @"High" : high, @"Low" : low, @"Description" : desc};
  // NSLog(@"Append forecast: %@", dayForecast);
  [forecastList addObject:dayForecast];
}

- (NSDictionary *)fetchCurrentWeather
{
  NSString *queryString;
  NSDictionary *results;

  queryString = [NSString stringWithFormat:@"%@&latitude=%@&longitude=%@&%@",
                                           QUERY_PREFIX,
                                           coordiantes.latitude, coordiantes.longtitude,
                                           QUERY_CURRENT];
  NSLog(@"Query string: %@", queryString);
  results = [self query:queryString];
  if (results != nil && [results[@"current"] isKindOfClass:[NSNull class]] == NO) {
    if (results[@"error"] == nil) {
      [weatherCondition setObject:@"Current Weather" forKey:@"Title"];
      [weatherCondition setObject:results[@"current"][@"temperature_2m"] forKey:@"Temperature"];
      // [weatherCondition setObject:results[@"current"][@""] forKey:@"Description"];
      [weatherCondition setObject:results[@"current"][@"relative_humidity_2m"] forKey:@"Humidity"];
    } else {
      [weatherCondition setObject:results[@"reason"] forKey:@"ErrorText"];
    }
  }

  return weatherCondition;
}

- (NSDictionary *)fetchWeather
{
  return [self fetchCurrentWeather];
  // NSDictionary *results = [self fetchCurrentWeather];

  // if (results != nil && ![results[@"query"][@"results"] isKindOfClass:[NSNull class]]) {
  //   NSString *imageName;
  //   NSDictionary *channel = results[@"query"][@"results"][@"channel"];

  //   [weatherCondition setObject:channel[@"title"] forKey:@"Title"];
  //   [weatherCondition setObject:channel[@"item"][@"condition"][@"temp"] forKey:@"Temperature"];
  //   [weatherCondition setObject:channel[@"item"][@"condition"][@"text"] forKey:@"Description"];
  //   [weatherCondition setObject:channel[@"atmosphere"][@"humidity"] forKey:@"Humidity"];

  //   imageName = [NSString stringWithFormat:@"%@.png", channel[@"item"][@"condition"][@"code"]];
  //   [weatherCondition setObject:[NSImage imageNamed:imageName] forKey:@"Image"];

  //   // for (NSDictionary *forecast in channel[@"item"][@"forecast"]) {
  //   //   [self appendForecastForDay:forecast[@"day"]
  //   //                     highTemp:forecast[@"high"]
  //   //                      lowTemp:forecast[@"low"]
  //   //                  description:forecast[@"desc"]];
  //   // }

  //   [weatherCondition setObject:[NSDate date] forKey:@"Fetched"];
  // } else {
  //   [weatherCondition setObject:@"Error getting data from Yahoo!" forKey:@"ErrorText"];
  //   NSLog(@"Error getting data from Yahoo! Results are: %@", results);
  // }

  // return weatherCondition;
}

- (NSDictionary *)query:(NSString *)statement
{
  // NSString     *queryData;
  // NSString *query;
  NSData *jsonData;
  NSError *error = nil;
  NSDictionary *results = nil;

  // Prepare query using modified NSString method implemented above
  // query =
  //     [NSString stringWithFormat:@"%@%@", QUERY_PREFIX, [statement stringByAddingPercentEscapes]];
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
  if ((jsonData = [[NSURL URLWithString:statement] resourceDataUsingCache:NO])) {
    NSLog(@"Got %lu bytes with query: %@", [jsonData length], statement);
    results = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error || !results) {
      NSLog(@"[%@ %@] JSON error: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd),
            error.localizedDescription);
      results = nil;
    }
  }

  return results;
}

@end
