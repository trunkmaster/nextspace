/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014 Sergii Stoian
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

#import <DesktopKit/NXTBundle.h>
#import <SystemKit/OSEFileManager.h>

#import "AppInspector.h"

static id appInspector = nil;

@interface AppInspector (Private)
- (void)_emptyMatrix;
- (void)_fillMatrixForTypes:(NSDictionary *)types appPath:(NSString *)path;
@end

@implementation AppInspector (Private)

- (void)_emptyMatrix
{
  NSUInteger count = [docListMtrx numberOfColumns];
  NSUInteger i;

  for (i = 0; i < count; i++) {
    [docListMtrx removeColumn:0];
  }
}

- (void)_fillMatrixForTypes:(NSDictionary *)types appPath:(NSString *)path
{
  NSEnumerator *e;
  NSButtonCell *cell;
  NSUInteger i, count;
  NSDictionary *type;
  NSString *iconName, *iconPath;
  NSImage *icon;
  NSArray *exts;

  [self _emptyMatrix];

  e = [types objectEnumerator];
  while ((type = [e nextObject]) != nil) {
    iconName = [type objectForKey:@"NSIcon"];
    iconPath = [NSBundle pathForResource:[iconName stringByDeletingPathExtension]
                                  ofType:[iconName pathExtension]
                             inDirectory:path];
    icon = [[NSImage alloc] initByReferencingFile:iconPath];
    exts = [type objectForKey:@"NSUnixExtensions"];
    for (i = 0; i < [exts count]; i++) {
      [docListMtrx addColumn];
      [docListMtrx sizeToCells];
      cell = [docListMtrx cellAtRow:0 column:[docListMtrx numberOfColumns] - 1];
      [cell setTitle:[exts objectAtIndex:i]];
      [cell setImage:icon];
    }
    [icon release];
  }
  [docListMtrx sizeToCells];
}

@end

@implementation AppInspector

// Class Methods

+ new
{
  if (appInspector == nil) {
    appInspector = [super new];
    if (![NSBundle loadNibNamed:@"AppInspector" owner:appInspector]) {
      appInspector = nil;
    }
  }

  return appInspector;
}

- (void)dealloc
{
  NSDebugLLog(@"AppInspector", @"AppInspector: dealloc");

  TEST_RELEASE(appVersionField);
  TEST_RELEASE(docListView);

  // release controls here

  [super dealloc];
}

- (void)awakeFromNib
{
  NSButtonCell *cell;

  [[docListView horizontalScroller] setArrowsPosition:NSScrollerArrowsNone];

  cell = [[NSButtonCell new] autorelease];
  [cell setImagePosition:NSImageAbove];
  [cell setFont:[NSFont toolTipsFontOfSize:0.0]];
  [cell setButtonType:NSOnOffButton];
  [cell setRefusesFirstResponder:YES];

  docListMtrx = [docListView documentView];
  [docListMtrx setMode:NSListModeMatrix];
  [docListMtrx setPrototype:cell];

  // [self _emptyMatrix];
}

- (BOOL)isValidApplication
{
  NSString *path = nil;
  NSArray *files = nil;
  NSString *appPath = nil;
  NSString *appInfoPath = nil;

  [self getSelectedPath:&path andFiles:&files];

  if ((appPath = [path stringByAppendingPathComponent:[files objectAtIndex:0]]) == nil) {
    return NO;
  }

  if ((appInfoPath = [NSBundle pathForResource:@"Info-gnustep"
                                        ofType:@"plist"
                                   inDirectory:appPath]) == nil) {
    return NO;
  }

  return YES;
}

// Control actions

// Public Methods - overrides of superclass

- touch:sender
{
  // do nothing
  return self;
}

- ok:sender
{
  // do nothing
  return self;
}

- revert:sender
{
  NSString *path = nil;
  NSArray *files = nil;
  NSString *appPath = nil;
  NSString *appInfoPath = nil;
  NSDictionary *appInfo;

  [self getSelectedPath:&path andFiles:&files];
  appPath = [path stringByAppendingPathComponent:[files objectAtIndex:0]];

  if (appPath == nil) {
    return self;
  }

  appInfoPath = [NSBundle pathForResource:@"Info-gnustep" ofType:@"plist" inDirectory:appPath];
  if (appInfoPath) {
    appInfo = [NSDictionary dictionaryWithContentsOfFile:appInfoPath];
    [appVersionField setStringValue:[appInfo objectForKey:@"ApplicationRelease"]];
    [self _fillMatrixForTypes:[appInfo objectForKey:@"NSTypes"] appPath:appPath];
  }

  NSDebugLLog(@"Inspector", @"NSTypes = %@", [appInfo objectForKey:@"NSTypes"]);

  // Buttons state and title, window edited state
  return [super revert:self];
}

@end
