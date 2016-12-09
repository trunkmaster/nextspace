/*
  Class:               YahooForecast
  Inherits from:       NSObject
  Class descritopn:    Get and parse weather forecast from yahoo.com

  Copyright (C) 2014-2016 Doug Torrance <dtorrance@piedmont.edu>
  Copyright (C) 2016 Sergii Stoian <stoian255@ukr.net>

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

#import "YQL.h"
#import "YahooForecast.h"

@implementation YahooForecast : NSObject

- (id)init
{
  forecastList = [[NSMutableArray alloc] init];
  weatherCondition = [[NSMutableDictionary alloc] init];
  [weatherCondition setObject:forecastList forKey:@"Forecasts"];
  
  yql = [[YQL alloc] init];
  
  return self;
}

- (void)dealloc
{
  [weatherCondition release];
  [forecastList release];
  [yql release];
  
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
  NSLog(@"Append forecast: %@", dayForecast);
  [forecastList addObject:dayForecast];
}

- (NSDictionary *)fetchWeatherWithWOEID:(NSString *)woeid
                                zipCode:(NSString *)zip
                                  units:(NSString *)units
{
  NSString	*queryString = @"select * from weather.forecast where";
  NSDictionary	*results;

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

  results = [yql query:queryString];
  
   // NSLog(@"%@", results[@"query"][@"count"]);
  NSLog(@"%@", results[@"query"][@"results"]);

  // id itemForecast = results[@"query"][@"results"][@"channel"][@"item"][@"forecast"];

  // id itemCondition = results[@"query"][@"results"][@"channel"][@"item"][@"condition"];
  // NSLog(@"condition is a %@; forecast is a %@",
  //       [itemCondition className], [itemForecast className]);
  // NSLog(@"forecast # of items = %lu", [itemForecast count]);

  // NSLog(@"Temp = %@ Text = %@ Code = %@",
  //       itemCondition[@"temp"], itemCondition[@"text"], itemCondition[@"code"]);

  NSLog(@"results is a %@ (%lu)", [results className], [[results allKeys] count]);
  
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
      NSLog(@"Error getting data from Yahoo!");
    }

  return weatherCondition;
}

@end
