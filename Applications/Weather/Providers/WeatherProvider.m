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
- (void)setTemperatureUnit:(NSString *)name
{
}
- (BOOL)fetchWeather
{
  return NO;
}
@end