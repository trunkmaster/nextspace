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
#import "OWMForecast.h"

#define QUERY_PREFIX @"http://api.openweathermap.org/data/2.5/weather?"

/*
NSDictionary *units = @{@"Kelvin":@"standard",
                        @"Metric":@"metric",
                        @"Imperial":@"imperial"};
NSDictionary *language = @{@"Arabic":@"ar", @"Bulgarian":@"bg", @"Catalan":@"ca",
                           @"Czech":@"cz", @"German":@"de", @"Greek":@"el",
                           @"English":@"en", @"Persian (Farsi)":@"fa",
                           @"Finnish":@"fi", @"French":@"fr", @"Galician":@"gl",
                           @"Croatian":@"hr", @"Hungarian":@"hu", @"Italian":@"it",
                           @"Japanese":@"ja", @"Korean":@"kr", @"Latvian":@"la",
                           @"Lithuanian":@"lt", @"Macedonian":@"mk", @"Dutch":@"nl",
                           @"Polish":@"pl", @"Portuguese":@"pt", @"Romanian":@"ro",
                           @"Russian":@"ru", @"Swedish":@"se", @"Slovak":@"sk",
                           @"Slovenian":@"sl", @"Spanish":@"es", @"Turkish":@"tr",
                           @"Ukrainian":@"ua", @"Vietnamese":@"vi",
                           @"Chinese Simplified":@"zh_cn",
                           @"Chinese Traditional":@"zh_tw"};
*/

@implementation OWMForecast : NSObject

- (void)dealloc
{
  [weatherCondition release];
  [forecastList release];
  
  [super dealloc];
}

- (id)init
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary   *owmDefs = [defaults objectForKey:@"OpenWeatherMap"];

  NSLog(@"City: %@ Language: %@ Units: %@ APIKey: %@",
        owmDefs[@"CityName"], owmDefs[@"Language"],
        owmDefs[@"Units"], owmDefs[@"APIKey"]);
  
  forecastList = [[NSMutableArray alloc] init];
  weatherCondition = [[NSMutableDictionary alloc] init];
  [weatherCondition setObject:forecastList forKey:@"Forecasts"];

  if (owmDefs && [owmDefs isKindOfClass:[NSDictionary class]]) {
    if ((apiKey = owmDefs[@"APIKey"]) == nil) {
      NSLog(@"[OpenWeatherMap] unable to find API key. "
            "Please check preferences. Aborting.");
      return nil;
    }
    if ((units = owmDefs[@"Units"]) == nil) {
      [self setUnits:@"imperial"];
    }
    if ((language = owmDefs[@"Language"]) == nil) {
      [self setLanguage:@"en"];
    }
    if ((city = owmDefs[@"CityName"]) == nil) {
      [self setCityByName:@"London,uk"];
    }
  }
  
  return self;
}

- (void)setCityByName:(NSString *)name
{
  if (city) {
    [city release];
  }
  city = [name copy];
}
- (void)setCityByID:(NSString *)cid
{
  if (cityID) {
    [cityID release];
  }
  cityID = [cid copy];
}
- (void)setUnits:(NSString *)name
{
  if (units) {
    [units release];
  }
  units = [name copy];
}
- (void)setLanguage:(NSString *)code
{
  if (language) {
    [language release];
  }
  language = [code copy];
}

- (void)appendForecastForDay:(NSString *)day
                    highTemp:(NSString *)high
                     lowTemp:(NSString *)low
                 description:(NSString *)desc
{
  NSDictionary *dayForecast;

  dayForecast = @{@"Day":day, @"High":high, @"Low":low, @"Description":desc};
  // NSLog(@"Append forecast: %@", dayForecast);
  [forecastList addObject:dayForecast];
}

- (NSDictionary *)parseWeather:(NSDictionary *)results
{
  NSString *imageName;
  
  if (results != nil) {
    [weatherCondition setObject:results[@"main"][@"temp"]
                         forKey:@"Temperature"];
    [weatherCondition setObject:results[@"weather"][0][@"description"]
                         forKey:@"Description"];
    [weatherCondition setObject:results[@"main"][@"humidity"]
                         forKey:@"Humidity"];

    // imageName = [NSString stringWithFormat:@"%@.png",
    //                       channel[@"item"][@"condition"][@"code"]];
    // [weatherCondition setObject:[NSImage imageNamed:imageName]
    //                      forKey:@"Image"];
      
    // for (NSDictionary *forecast in channel[@"item"][@"forecast"]) {
    //     [self appendForecastForDay:forecast[@"day"]
    //                       highTemp:forecast[@"high"]
    //                        lowTemp:forecast[@"low"]
    //                    description:forecast[@"desc"]];
    //   }
      
    [weatherCondition setObject:[NSDate date] forKey:@"Fetched"];
  }
  else {
    [weatherCondition setObject:@"Error getting weather data from OpenWeatherMap!"
                         forKey:@"ErrorText"];
    NSLog(@"Error getting data from Yahoo! Results are: %@", results);
  }
  return weatherCondition;
}

- (NSDictionary *)_query:(NSString *)statement
{
  NSString     *query;
  NSData       *jsonData;
  NSError      *error = nil;
  NSDictionary *results = nil;

  // Prepare query using modified NSString method implemented above
  query = [NSString stringWithFormat:@"%@%@&APPID=%@",
                    QUERY_PREFIX, statement, apiKey];
  NSLog(@"OWM query URL: %@", query);

  // if ((jsonData = [queryData dataUsingEncoding:NSUTF8StringEncoding]))
  // Using above code doesn't always receive data from server.
  // Data will be get from cache of NSURLHandler.
  // TODO: something wrong with GNUstep code.
  if ((jsonData = [[NSURL URLWithString:query] resourceDataUsingCache:NO])) {
    NSLog(@"Got %lu bytes with query: %@", [jsonData length], query);
    results = [NSJSONSerialization JSONObjectWithData:jsonData
                                              options:0
                                                error:&error];
    if (error || !results) {
      NSLog(@"[%@ %@] JSON error: %@",
            NSStringFromClass([self class]),
            NSStringFromSelector(_cmd),
            error.localizedDescription);
      results = nil;
    }
  }

  return results;
}

- (NSDictionary *)fetchWeather
{
  NSString	*queryString = @"";
  NSDictionary	*results;

  [weatherCondition removeObjectForKey:@"ErrorText"];

  if (cityID != nil && [cityID length] > 0) {
    queryString = [queryString stringByAppendingFormat:@"id=%@",
                               cityID];
  }
  else if (city != nil && [city length] > 0) {
    queryString = [queryString stringByAppendingFormat:@"q=%@",
                               city];
  }
  
  if (units != nil && [units length] > 0) {
    queryString = [queryString stringByAppendingFormat:@"&units=%@",
                               units];
  }
  
  if (language != nil && [language length] > 0) {
    queryString = [queryString stringByAppendingFormat:@"&langauge=%@",
                               language];
  }
  
  results = [self _query:queryString];
  [self parseWeather:results];
  
  return weatherCondition;
}

@end
