/*
  Protocol and data classes for weather searvice specific bundles.
  Implementation located in Providers/WeatherProvider.m and should
  be linked only with provider bundles.

  Copyright (C) 2023-present Sergii Stoian <stoian255@gmail.com>

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


#import <Foundation/Foundation.h>

@protocol WeatherProtocol

- (NSString *)name;

/* Returns YES if latitude and logitude were found for `name` */
- (BOOL)setLocationByName:(NSString *)name;
/* If -setCityByname was not successfull present city list to user selection */
- (NSArray *)locationsListForName:(NSString *)name;

/* Key is human readable name, value is provider specific. */
- (NSArray *)temperatureUnitsList;
- (void)setTemperatureUnit:(NSString *)name;

- (BOOL)fetchWeather;

@end


@interface WeatherCurrent : NSObject

@property (readwrite, copy) NSString *temperature;
@property (readwrite, copy) NSString *humidity;
@property (readwrite, copy) NSImage *image;
@property (readwrite, copy) NSString *error;

@end


@interface WeatherForecast : NSObject

@property (readwrite, copy) NSString *minTemperature;
@property (readwrite, copy) NSString *maxTemperature;
@property (readwrite, copy) NSString *maxWindSpeed;
@property (readwrite, copy) NSString *maxWindGusts;

@end


@interface WeatherProvider : NSObject <WeatherProtocol>

@property (readwrite, copy) NSString *locationName;
@property (readwrite, copy) NSString *latitude;
@property (readwrite, copy) NSString *longitude;
@property (readwrite, copy) NSString *temperatureUnit;

@property (readwrite, copy) NSDate *fetchedDate;
@property (readwrite, copy) WeatherCurrent *current;
@property (readwrite, copy) NSMutableArray<WeatherForecast *> *forecast;

@end
