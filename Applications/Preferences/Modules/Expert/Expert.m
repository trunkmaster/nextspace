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

#import <AppKit/AppKit.h>
#import <Foundation/NSDistributedNotificationCenter.h>
#import <SystemKit/OSEFileManager.h>

#import <sys/types.h>
#import <sys/stat.h>

#import "Expert.h"
#import "WMPermissions.h"

// Global defaults key holding the file-creation umask (octal), e.g. 022.
// The value is the POSIX umask -- the complement of the permission bits
// granted to newly created files and folders. Workspace (the session
// leader) applies it with umask() at startup and again, live, whenever
// this module posts FileCreationMaskDidChangeNotification, so the setting
// takes effect immediately without re-logging in.
static NSString * const FileCreationMaskKey = @"NXFileCreationMask";

// Posted (distributed) when the user edits the mask so Workspace re-applies
// it to the running session. Mirrors the Font module's live-apply pattern.
static NSString * const FileCreationMaskDidChangeNotification =
    @"NXFileCreationMaskDidChangeNotification";

@implementation Expert

- (id)init
{
  self = [super init];
  
  defaults = [OSEDefaults globalUserDefaults];
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *imagePath = [bundle pathForResource:@"Expert" ofType:@"tiff"];
  image = [[NSImage alloc] initWithContentsOfFile:imagePath];
      
  return self;
}

- (void)dealloc
{
  NSLog(@"Expert -dealloc");
  [image release];
  if (view) {
    [view release];
  }
  [super dealloc];
}

- (void)awakeFromNib
{
  [view retain];
  [window release];

  [sortByBtn setRefusesFirstResponder:YES];
  [showHiddenFilesBtn setRefusesFirstResponder:YES];
  [privateWindowServerBtn setRefusesFirstResponder:YES];
  [privateSoundServerBtn setRefusesFirstResponder:YES];

  [sortByBtn
    selectItemWithTag:[[OSEFileManager defaultManager] sortFilesBy]];
  [showHiddenFilesBtn
    setState:[[OSEFileManager defaultManager] isShowHiddenFiles]];

  // The "File Creation Mask" control is a WMPermissions custom view placed
  // in the NIB. It is not wired to a Gorm connection, so locate it in the
  // loaded view hierarchy and finish its setup here.
  permissionsView = [self permissionsViewInView:view];
  if (permissionsView != nil) {
    unsigned long grantedMode;
    mode_t mask;

    // Show all three permission rows (Read/Write/Execute) to match the
    // Owner/Group/Others x Read/Write/Execute layout of the panel.
    [permissionsView setDisplaysExecute:YES];
    [permissionsView setEditable:YES];
    [permissionsView setTarget:self];
    [permissionsView setAction:@selector(setFileCreationMask:)];

    // Seed the matrix from the saved default; fall back to the current
    // process umask when the key is absent (objectForKey: nil-check, since
    // a "default present" semantics cannot be expressed with boolForKey:).
    if ([defaults objectForKey:FileCreationMaskKey] != nil) {
      mask = (mode_t)[defaults integerForKey:FileCreationMaskKey];
    } else {
      mask = umask(0);   // read current umask ...
      umask(mask);       // ... and restore it immediately
    }
    // WMPermissions displays *granted* permission bits, i.e. the complement
    // of the umask, limited to the rwxrwxrwx (0777) range.
    grantedMode = (~mask) & 0777;
    [permissionsView setMode:grantedMode];
  }
}

// Depth-first search for the WMPermissions view loaded from the NIB.
- (id)permissionsViewInView:(NSView *)aView
{
  NSArray *subviews = [aView subviews];
  NSUInteger i, count = [subviews count];

  for (i = 0; i < count; i++) {
    NSView *subview = [subviews objectAtIndex:i];
    id found;

    if ([subview isKindOfClass:[WMPermissions class]]) {
      return subview;
    }
    found = [self permissionsViewInView:subview];
    if (found != nil) {
      return found;
    }
  }
  return nil;
}

- (NSView *)view
{
  if (view == nil)
    {
      if (![NSBundle loadNibNamed:@"Expert" owner:self])
        {
          NSLog (@"Expert.preferences: Could not load NIB, aborting.");
          return nil;
        }
    }
  
  return view;
}

- (NSString *)buttonCaption
{
  return @"Expert Preferences";
}

- (NSImage *)buttonImage
{
  return image;
}

//
// Action methods
//

- (void)setSortBy:(id)sender
{
  [[OSEFileManager defaultManager] setSortFilesBy:[[sender selectedItem] tag]];
}

- (void)setShowHiddenFiles:(id)sender
{
  [[OSEFileManager defaultManager] setShowHiddenFiles:[sender state]];
}

- (void)setFileCreationMask:(id)sender
{
  unsigned long grantedMode = [(WMPermissions *)sender mode] & 0777;
  mode_t mask = (mode_t)((~grantedMode) & 0777);

  // Persist as the POSIX umask, then notify Workspace so it re-applies the
  // mask to the running session immediately (no re-login required).
  [defaults setInteger:(NSInteger)mask forKey:FileCreationMaskKey];
  [defaults synchronize];

  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:FileCreationMaskDidChangeNotification
                    object:@"Preferences"];
}

@end

