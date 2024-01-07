/* All rights reserved */

#import "Preferences.h"

@implementation Preferences

- (instancetype)initWithProvider:(WeatherProvider *)theProvider
{
  [super init];

  ASSIGN(provider, theProvider);
  
  if ([NSBundle loadNibNamed:@"Preferences" owner:self] == NO) {
    NSLog(@"Failed to load NIB Prefeences.");
    TEST_RELEASE(provider);
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
  [panel makeFirstResponder:geoNameField];

  [temperatureUnitPopup setRefusesFirstResponder:YES];
  [temperatureUnitPopup removeAllItems];
  [temperatureUnitPopup addItemsWithTitles:[provider temperatureUnitsList]];
  [temperatureUnitPopup selectItemAtIndex:0];
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
  if ([[sender stringValue] length] == 0) {
    return;
  }

  provider.locationName = [sender stringValue];
  [latitudeField setStringValue:provider.latitude];
  [longitudeField setStringValue:provider.longitude];
}

- (IBAction)setTemperatureUnit:(id)sender
{
  [provider setTemperatureUnit:[[sender selectedCell] stringValue]];
}

@end
