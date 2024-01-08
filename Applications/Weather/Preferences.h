/* All rights reserved */

#import <AppKit/AppKit.h>
#include "AppKit/NSScrollView.h"
#import "WeatherProvider.h"

@interface Preferences : NSObject
{
  IBOutlet id panel;
  IBOutlet id locationTypeMatrix;
  IBOutlet id latitudeField;
  IBOutlet id longitudeField;
  IBOutlet id geoNameField;
  IBOutlet id temperatureUnitPopup;

  WeatherProvider *provider;

  IBOutlet NSScrollView *locationsSV;
  NSTableView *locationsList;
  NSArray *locationsCache;
}

- (instancetype)initWithProvider:(WeatherProvider *)theProvider;
- (NSPanel *)window;

- (IBAction)setLocationType:(id)sender;
- (IBAction)setLatitude:(id)sender;
- (IBAction)setLongitude:(id)sender;
- (IBAction)setGeoName:(id)sender;
- (IBAction)setTemperatureUnit:(id)sender;

@end
