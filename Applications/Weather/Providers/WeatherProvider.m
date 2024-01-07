#import <WeatherProvider.h>

@implementation WeatherCurrent
@end

@implementation WeatherForecast
@end

@implementation WeatherProvider
- (NSString *)name
{
  return @"WeatherProvider";
}
- (BOOL)setLocationByName:(NSString *)name
{
  return NO;
}
- (NSArray *)locationsListForName:(NSString *)name {
  return nil;
}
- (NSDictionary *)temperatureUnitsList {
  return nil;
}
- (BOOL)fetchWeather
{
  return NO;
}
@end