/* All rights reserved */

#import "Preferences.h"

@implementation Preferences

- (instancetype)initWithProvider:(WeatherProvider *)theProvider
{
  [super init];

  if ([NSBundle loadNibNamed:@"Preferences" owner:self] == NO) {
    NSLog(@"Failed to load NIB Prefeences.");
    return self;
  }

  return self;
}

- (NSPanel *)window
{
  return panel;
}

- (void)awakeFromNib {
  for (NSControl *option in [locationTypeMatrix cells]) {
    [option setRefusesFirstResponder:YES];
  }
  [temperatureUnitPopup setRefusesFirstResponder:YES];
}

- (IBAction)setLocationType:(id)sender
{
  if ([[sender selectedCell] tag] == 0) {
    [latitudeField setEditable:YES];
    [latitudeField setBackgroundColor:[NSColor whiteColor]];
    [longitudeField setEditable:YES];
    [longitudeField setBackgroundColor:[NSColor whiteColor]];

    [geoNameField setEditable:NO];
    [geoNameField setBackgroundColor:[NSColor controlBackgroundColor]];
  } else {
    [latitudeField setEditable:NO];
    [latitudeField setBackgroundColor:[NSColor controlBackgroundColor]];
    [longitudeField setEditable:NO];
    [longitudeField setBackgroundColor:[NSColor controlBackgroundColor]];

    [geoNameField setEditable:YES];
    [geoNameField setBackgroundColor:[NSColor whiteColor]];
  }
}

- (IBAction)setLatitude:(id)sender
{
  
}

- (IBAction)setLongitude:(id)sender
{
}

- (IBAction)setGeoName:(id)sender
{
}

- (IBAction)setTemperatureUnit:(id)sender
{
}

@end
