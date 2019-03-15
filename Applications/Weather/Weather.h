/* -*- mode:objc -*- */

#import <Foundation/Foundation.h>

@protocol Forecast

- (void)setCityByName:(NSString *)name;
- (void)setUnits:(NSString *)name;
- (void)setLanguage:(NSString *)code;
- (NSDictionary *)fetchWeather;

@end
