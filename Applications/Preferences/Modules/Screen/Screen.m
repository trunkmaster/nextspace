/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#import <AppKit/NSApplication.h>
#import <AppKit/NSNibLoading.h>
#import <AppKit/NSView.h>
#import <AppKit/NSBox.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSGraphics.h>

#import <AppKit/PSOperators.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSWindow.h>

#import <AppKit/NSScreen.h>
#import <AppKit/NSPanel.h>

#import <SystemKit/OSEDisplay.h>

#import "ScreenCanvas.h"
#import "DisplayBox.h"
#import "Screen.h"

@implementation ScreenPreferences

@synthesize dockImage;
@synthesize appIconYardImage;
@synthesize iconYardImage;

- (id)init
{
  NSString *imagePath;
  NSBundle *bundle;
  
  self = [super init];
  
  bundle = [NSBundle bundleForClass:[self class]];
  
  imagePath = [bundle pathForResource:@"Screen" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];

  imagePath = [bundle pathForResource:@"dock" ofType:@"tiff"];
  dockImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
  imagePath = [bundle pathForResource:@"appiconyard" ofType:@"tiff"];
  appIconYardImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
  imagePath = [bundle pathForResource:@"iconyard" ofType:@"tiff"];
  iconYardImage = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"Screen: -dealloc");
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  
  [image release];
  [dockImage release];
  [appIconYardImage release];
  [iconYardImage release];
  
  if (displayBoxList) [displayBoxList release];
  if (systemScreen) [systemScreen release];
  if (power) [power release];
  if (view) [view release];
  
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  systemScreen = [OSEScreen new];
  [systemScreen setUseAutosave:YES];
  
  // Get info about monitors and layout
  displayBoxList = [[NSMutableArray alloc] init];
  [self updateDisplayBoxList];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(screenDidUpdate:)
           name:OSEScreenDidUpdateNotification
         object:systemScreen];

  // Open/close lid events
  power = [OSEPower new];
  [power startEventsMonitor];
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(lidDidChange:)
           name:OSEPowerLidDidChangeNotification
         object:power];
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(displayBoxPositionDidChange:)
           name:@"DisplayBoxPositionDidChange"
         object:nil];
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Screen" owner:self])
        {
          NSLog (@"Screen.preferences: Could not load NIB, aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Screen Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//
- (void)displayBoxClicked:(DisplayBox *)sender
{
  [sender setSelected:YES];
  selectedBox = sender;
  for (DisplayBox *db in displayBoxList)
    {
      if (db != sender) [db setSelected:NO];
    }

  [setMainBtn setEnabled:(![sender isMain]&&[sender isActive])];
  
  [setStateBtn setTitle:[sender isActive] ? @"Disable" : @"Enable"];
  
  if (([sender isActive] &&
       [[systemScreen activeDisplays] count] > 1) ||
      (![sender isActive] && ![OSEPower isLidClosed]))
    {
      [setStateBtn setEnabled:YES];
    }
  else
    {
      [setStateBtn setEnabled:NO];
    }  
}

- (void)setMainDisplay:(id)sender
{
  OSEDisplay *display;
  
  display = [systemScreen displayWithName:selectedBox.displayName];
  // [OSEDisplay setMain:] will generate OSEScreenDidChangeNotification.
  [systemScreen setMainDisplay:display];
}

- (void)setDisplayState:(id)sender
{
  OSEDisplay *display;
  
  display = [systemScreen displayWithName:selectedBox.displayName];
  
  if ([[sender title] isEqualToString:@"Disable"])
    {
      [systemScreen deactivateDisplay:display];
    }
  else
    {
      [systemScreen activateDisplay:display];
    }
}

- (void)revertArrangement:(id)sender
{
  [systemScreen applyDisplayLayout:[systemScreen arrangedDisplayLayout]];
  [self updateDisplayBoxList];
  
  [revertBtn setEnabled:NO];
  [applyBtn setEnabled:NO];
}

NSComparisonResult compareDisplayBoxes(DisplayBox *displayA,
                                       DisplayBox *displayB,
                                       void *context)
{
  NSPoint aPoint = displayA.frame.origin;
  NSPoint bPoint = displayB.frame.origin;
  BOOL    aIsActive, bIsActive;

  aIsActive = [displayA.display isActive];
  bIsActive = [displayB.display isActive];

  if (aIsActive == NO && bIsActive == YES)
    return NSOrderedDescending;
  else if (aIsActive == YES && bIsActive == NO)
    return NSOrderedAscending;

  if (aPoint.x < bPoint.x || aPoint.y < bPoint.y)
    return NSOrderedAscending;
  else
    return NSOrderedDescending;
}

- (void)applyArrangement:(id)sender
{
  NSLog(@"Convert DisplayBox positions and set to OSEDisplay.");

  NSArray		*dbList;
  NSArray		*layout = [systemScreen currentLayout];
  NSMutableArray	*newLayout = [NSMutableArray new];
  NSMutableDictionary	*displayDesc;
  NSRect		boxGroupRect = [canvas boxGroupRect];
  NSRect		boxFrame, boxLastFrame;
  NSRect		displayFrame, displayLastFrame;
  CGFloat		xOffset = .0, yOffset = .0;

  dbList = [displayBoxList sortedArrayUsingFunction:compareDisplayBoxes
                                            context:NULL];
  displayLastFrame = NSMakeRect(0,0,0,0);
  for (DisplayBox *db in dbList)
    {
      // 1. Get frame of OSEDisplay
      displayFrame = db.display.frame;

      // 2. Calculate NSPoint for OSEDisplay
      boxFrame = db.frame;

      if (NSIsEmptyRect(displayLastFrame) &&
          boxFrame.origin.x == boxGroupRect.origin.x)
        displayFrame.origin.x = 0;
      else if (NSMinX(boxFrame) == NSMinX(boxLastFrame)) // top|bottom: left aligned
        displayFrame.origin.x = displayLastFrame.origin.x;
      else if (NSMaxX(boxFrame) == NSMaxX(boxLastFrame)) // top|bottom: right aligned
        displayFrame.origin.x = NSMaxX(displayLastFrame) - NSWidth(displayFrame);
      else if (NSMaxX(boxFrame) > NSMaxX(boxLastFrame))  // right
        displayFrame.origin.x = displayLastFrame.size.width;
      else                                         // left - starts new row of displays
        displayFrame.origin.x = NSMinX(displayLastFrame) - NSWidth(displayFrame);
      
      if (displayFrame.origin.x < xOffset)
        xOffset = fabs(displayFrame.origin.x);

      if (NSIsEmptyRect(displayLastFrame) &&
          boxFrame.origin.y == boxGroupRect.origin.y)
        displayFrame.origin.y = 0;
      else if (NSMinY(boxFrame) == NSMinY(boxLastFrame)) // right|left: bottom aligned
        displayFrame.origin.y = displayLastFrame.origin.y;
      else if (NSMaxY(boxFrame) == NSMaxY(boxLastFrame)) // right|left: top aligned
        displayFrame.origin.y = NSMaxY(displayLastFrame) - NSHeight(displayFrame);
      else if (NSMaxY(boxFrame) > NSMaxY(boxLastFrame))  // top
        displayFrame.origin.y = NSHeight(displayLastFrame);
      else // bottom - should never be called
        displayFrame.origin.y = NSMinY(displayLastFrame) - NSHeight(displayFrame);
      
      if (displayFrame.origin.y < yOffset)
        yOffset = fabs(displayFrame.origin.y);
      
      displayLastFrame = displayFrame;
      boxLastFrame = boxFrame;
      
      // 3. Change frame origin of OSEDisplay in layout description
      displayDesc = [[systemScreen descriptionOfDisplay:db.display
                                               inLayout:layout] mutableCopy];
      [displayDesc setObject:NSStringFromRect(displayFrame)
                      forKey:OSEDisplayFrameKey];
      NSLog(@"Set frame for %@: %@", db.displayName, NSStringFromRect(displayFrame));
      [newLayout addObject:displayDesc];
      [displayDesc release];
    }

  if (xOffset > 0 || yOffset > 0)
    {
      for (NSMutableDictionary *d in newLayout)
        {
          displayFrame = NSRectFromString([d objectForKey:OSEDisplayFrameKey]);
          displayFrame.origin.x += xOffset;
          displayFrame.origin.y += yOffset;
          NSLog(@"Adjust frame for %@: %@", [d objectForKey:OSEDisplayNameKey],
                NSStringFromRect(displayFrame));
          [d setObject:NSStringFromRect(displayFrame) forKey:OSEDisplayFrameKey];
        }
    }

  [systemScreen applyDisplayLayout:newLayout];
  // [newLayout writeToFile:@"PreferencesDisplays.config" atomically:YES];
  [newLayout release];
  
  [revertBtn setEnabled:NO];
  [applyBtn setEnabled:NO];
}

//
// Helper methods
//

- (void)selectFirstEnabledMonitor
{
  DisplayBox *db = nil;
  
  for (db in displayBoxList)
    {
      // if ([[db display] isActive])
      if ([[systemScreen displayWithName:db.displayName] isActive])
        {
          [db setSelected:YES];
          break;
        }
    }

  [self displayBoxClicked:db];
}

// Translates OSEDisplay coordinates into ScreenCanvas coordinates
- (void)updateDisplayBoxList
{
  NSArray *displays;
  NSRect  canvasRect = [[canvas contentView] frame];
  NSRect  displayRect, dBoxRect;
  CGFloat dMaxWidth = 0.0, dMaxHeight = 0.0;
  CGFloat scaleWidth, scaleHeight;
  DisplayBox *dBox;

  NSLog(@"Screen: update display box list.");

  // Clear view and array
  for (dBox in displayBoxList)
    {
      [dBox removeFromSuperview];
    }
  [displayBoxList removeAllObjects];
  
  displays = [systemScreen connectedDisplays];
  
  // Calculate scale factor
  for (OSEDisplay *d in displays)
    {
      displayRect = [d frame];
      if (dMaxWidth < displayRect.size.width ||
          dMaxHeight < displayRect.size.height)
        {
          dMaxWidth = displayRect.size.width;
          dMaxHeight = displayRect.size.height;
        }
    }
  scaleWidth = (canvasRect.size.width/dMaxWidth) / 3;
  scaleHeight = (canvasRect.size.height/dMaxHeight) / 3;
  scaleFactor = (scaleWidth < scaleHeight) ? scaleWidth : scaleHeight;

  // Create and add display boxes
  for (OSEDisplay *d in displays)
    {
      if ([d isActive] == NO)
        displayRect = d.hiddenFrame;
      else
        displayRect = d.frame;
      
      dBoxRect.origin.x = floor(displayRect.origin.x*scaleFactor);
      dBoxRect.origin.y = floor(displayRect.origin.y*scaleFactor);
      dBoxRect.size.width = floor(displayRect.size.width*scaleFactor);
      dBoxRect.size.height = floor(displayRect.size.height*scaleFactor);

      dBox = [[DisplayBox alloc] initWithFrame:dBoxRect display:d owner:self];
      dBox.displayFrame = displayRect;
      dBox.displayName = [d outputName];
      [dBox setActive:[d isActive]];
      [dBox setMain:[d isMain]];
      if ([displays indexOfObject:d] != 0)
        {
          [canvas addSubview:dBox
                  positioned:NSWindowAbove
                  relativeTo:[displayBoxList lastObject]];
        }
      else
        {
          [canvas addSubview:dBox];
        }
      [displayBoxList addObject:dBox];
      [dBox release];
    }

  [(ScreenCanvas *)canvas centerBoxes];
  [self selectFirstEnabledMonitor];
}

//
// Notifications
//
- (void)screenDidUpdate:(NSNotification *)aNotif
{
  NSLog(@"Screen: XRandR screen resources was updated, refreshing...");
  [self updateDisplayBoxList];
}

- (void)lidDidChange:(NSNotification *)aNotif
{
  OSEDisplay *builtinDisplay = nil;

  // for (DisplayBox *db in displayBoxList)
  for (OSEDisplay *d in [systemScreen connectedDisplays])
    {
      if ([d isBuiltin])
        {
          builtinDisplay = d;
          break;
        }
    }
  
  if (builtinDisplay)
    {
      if (![[aNotif object] isLidClosed] && ![builtinDisplay isActive])
        {
          NSLog(@"Screen: activating display %@", [builtinDisplay outputName]);
          [systemScreen activateDisplay:builtinDisplay];
        }
      else if ([[aNotif object] isLidClosed] && [builtinDisplay isActive])
        {
          NSLog(@"Screen: DEactivating display %@",
                [builtinDisplay outputName]);
          [systemScreen deactivateDisplay:builtinDisplay];
        }
    }
}

- (void)displayBoxPositionDidChange:(NSNotification *)aNotif
{
  [revertBtn setEnabled:YES];
  [applyBtn setEnabled:YES];  
}

@end
