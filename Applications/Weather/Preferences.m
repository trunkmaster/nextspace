/* All rights reserved */

#import "Preferences.h"
#include "Foundation/NSObjCRuntime.h"
#include "AppKit/NSScrollView.h"
#include "AppKit/NSTableColumn.h"

@implementation Preferences

- (instancetype)initWithProvider:(WeatherProvider *)theProvider
{
  [super init];

  ASSIGN(provider, theProvider);
  
  if ([NSBundle loadNibNamed:@"Preferences" owner:self] == NO) {
    NSLog(@"Failed to load NIB Prefeences.");
    [provider release];
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

  NSLog(@"Locattions list %@ document class: %@", [locationsSV className], [locationsSV documentView]);
  locationsList = [locationsSV documentView];
  [locationsList setHeaderView:nil];
  [locationsList setCornerView:nil];
  [locationsList setDrawsGrid:NO];
  [locationsList setDataSource:self];
  [locationsList setTarget:self];
  [locationsList setAction:@selector(locationListAction:)];

  NSTableColumn *col = [locationsList tableColumns][0];
  [col setMinWidth:locationsSV.documentVisibleRect.size.width];
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

- (IBAction)checkGeoName:(id)sender
{
  if (locationsCache) {
    [locationsCache release];
  }
  locationsCache = [[provider locationsListForName:[geoNameField stringValue]] copy];
  [locationsList reloadData];
}

- (IBAction)setTemperatureUnit:(id)sender
{
  [provider setTemperatureUnit:[[sender selectedCell] stringValue]];
}

@end

@implementation Preferences (GeoNameDelegate)

- (void)controlTextDidChange:(NSNotification *)aNotification
{
  NSTextField *field = [aNotification object];
  NSLog(@"GeoName text changed to: %@", [field stringValue]);
}

@end

@implementation Preferences (LocationsListDelegate)
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  return locationsCache ? [locationsCache count] : 0;
}

- (id)tableView:(NSTableView *)aTableView
    objectValueForTableColumn:(NSTableColumn *)aTableColumn
                          row:(NSInteger)rowIndex
{
  return locationsCache[rowIndex];
}

// - (void)tableView:(NSTableView *)aTableView
//     setObjectValue:(id)anObject
//     forTableColumn:(NSTableColumn *)aTableColumn
//                row:(NSInteger)rowIndex
// {
// }
@end