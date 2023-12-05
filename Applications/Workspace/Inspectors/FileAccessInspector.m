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

#import <DesktopKit/NXTAlert.h>
#import "FileAccessInspector.h"
#import "WMPermissions.h"

#import <unistd.h>
#import <sys/types.h>
#import <sys/stat.h>

@interface FileAccessInspector (Private)

- (void)_setPermissionsRecursively:(unsigned)aMode forDirectory:(NSString *)dir;

// update the warning about suid root executable binaries
// - (void) updateWarnSuidRootExec: (unsigned) aMode;

@end

@implementation FileAccessInspector (Private)

// Not used
// - (void)updateWarnSuidRootExec:(unsigned)aMode
// {
//   NSDictionary *fattrs = [[NSFileManager defaultManager]
//                             fileAttributesAtPath:path traverseLink:NO];
//   if ((aMode & S_ISUID) &&
//       ((aMode & S_IXOTH) || (aMode & S_IXGRP)) &&
//       [[fattrs fileType] isEqualToString:NSFileTypeRegular])
//     {
//       if ([fattrs fileOwnerAccountID] == 0)
//         {
//           [suidWarn setStringValue:_(@"Warning: SUID root executable!")];
//         }
//       else
//         {
//           [suidWarn setStringValue:_(@"Warning: SUID executable!")];
//         }
//     }
//   else
//     {
//       [suidWarn setStringValue:nil];
//     }
// }

- (void)_setPermissionsRecursively:(unsigned)aMode forDirectory:(NSString *)dir
{
  NSString *file, *fp;
  NSMutableDictionary *fattrs;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator *e = [fm enumeratorAtPath:dir];

  while ((file = [e nextObject]) != nil) {
    // NSDebugLLog(@"Inspector", @"FileAccessInspector _setPerms:forDirectory: %@ - %@", dir, file);
    fp = [dir stringByAppendingPathComponent:file];
    fattrs = [[fm fileAttributesAtPath:fp traverseLink:NO] mutableCopy];

    [fattrs setObject:[NSNumber numberWithInt:aMode] forKey:NSFilePosixPermissions];
    if ([fm changeFileAttributes:fattrs atPath:fp] == NO) {
      NXTRunAlertPanel(_(@"Workspace Inspector"), _(@"Couldn't change permissions for \n%@."), nil,
                       nil, nil, fp);
      RELEASE(fattrs);
      return;
    }
    RELEASE(fattrs);
  }
}

@end

@implementation FileAccessInspector

static id accessInspector = nil;

+ new
{
  if (accessInspector == nil) {
    accessInspector = [super new];
    if (![NSBundle loadNibNamed:@"FileAccessInspector" owner:accessInspector]) {
      accessInspector = nil;
    }
  }

  return accessInspector;
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"FileAccessInspector: dealloc");

  TEST_RELEASE(warnText);
  TEST_RELEASE(applyButton);
  TEST_RELEASE(view);
  TEST_RELEASE(path);

  [super dealloc];
}

- (void)awakeFromNib
{
  warnText = [[warnField stringValue] copy];
  applyRecursively = [applyButton state];
  [applyButton retain];

  [permissionsView setDisplaysExecute:YES];
  [permissionsView setTarget:self];
  [permissionsView setAction:@selector(permissionsChanged:)];
}

// --- Actions ---

- (void)permissionsChanged:sender
{
  mode = (mode & (S_ISUID | S_ISGID | S_ISVTX)) | [(WMPermissions *)sender mode];

  [super touch:self];
}

- (void)changeSuid:sender
{
  if ([sender state] == YES) {
    mode |= S_ISUID;
  } else {
    mode &= ~(S_ISUID);
  }

  [super touch:self];
}

- (void)changeGuid:sender
{
  if ([sender state] == YES) {
    mode |= S_ISGID;
  } else {
    mode &= ~(S_ISGID);
  }

  [super touch:self];
}

- (void)changeSticky:sender
{
  if ([sender state] == YES) {
    mode |= S_ISVTX;
  } else {
    mode &= ~(S_ISVTX);
  }

  [super touch:self];
}

- (void)applyRecursively:senderPath
{
  applyRecursively = [applyButton state];

  if (applyRecursively) {
    [warnField setStringValue:warnText];
    [super touch:self];
  } else {
    [warnField setStringValue:@""];
  }
}

// --- Overrides and bundle.registry ---

// FIXME
- (BOOL)isLocalFile
{
  NSString *defaultAppName;
  NSString *fileType;
  NSString *fp;
  NSString *selectedPath = nil;
  NSArray *selectedFiles = nil;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  fp = [selectedPath stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];
  [[NSApp delegate] getInfoForFile:fp application:&defaultAppName type:&fileType];

  if ([fileType isEqualToString:NSFilesystemFileType]) {
    return NO;
  }

  return YES;
}

- (void)ok:sender
{
  NSString *file, *fp;
  NSMutableDictionary *fattrs;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSEnumerator *e = [files objectEnumerator];

  // Apply changes to file
  while ((file = [e nextObject]) != nil) {
    // NSDebugLLog(@"Inspector", @"FileAccessInspector ok: %@ - %@", path, file);
    fp = [path stringByAppendingPathComponent:file];
    fattrs = [[fm fileAttributesAtPath:fp traverseLink:NO] mutableCopy];

    [fattrs setObject:[NSNumber numberWithInt:mode] forKey:NSFilePosixPermissions];
    if ([fm changeFileAttributes:fattrs atPath:fp] == NO) {
      NXTRunAlertPanel(_(@"Workspace Inspector"), _(@"Couldn't change permissions for \n%@."), nil,
                       nil, nil, fp);
      RELEASE(fattrs);
      return;
    }

    // 'file' is a directory and "Apply..." selected
    if (applyRecursively && [[fattrs fileType] isEqualToString:NSFileTypeDirectory]) {
      [self _setPermissionsRecursively:mode forDirectory:fp];
    }

    RELEASE(fattrs);
  }

  oldMode = mode;
  [self revert:self];
}

- revert:sender
{
  NSString *selectedPath = nil;
  NSArray *selectedFiles = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *fp;
  NSDictionary *fattrs;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  // if (sender != [self revertButton] &&
  //     [path isEqualToString:selectedPath] &&
  //     [files isEqualToArray:selectedFiles])
  //    {
  //      return;
  //    }

  ASSIGN(path, selectedPath);
  ASSIGN(files, selectedFiles);

  // NSDebugLLog(@"Inspector", @"FileAccessInspector path: %@ files: %@", path, files);

  // Set initial editable state for permission controls
  [permissionsView setEditable:YES];
  [suidButton setEnabled:YES];
  [guidButton setEnabled:YES];
  [stickyButton setEnabled:NO];
  [applyButton setEnabled:YES];

  // Initial state of "Apply..." button and text field below
  [warnField setStringValue:@""];
  [applyButton setState:NSOffState];
  applyRecursively = NO;
  if ([applyButton superview]) {
    [applyButton removeFromSuperview];
  }

  if ([files count] > 1) {
    unsigned long mask = 0, m, om;
    NSEnumerator *e = [files objectEnumerator];
    NSString *file, *fp;

    // Get first file permissions in selection and set to 'om' ivar
    fp = [path stringByAppendingPathComponent:[e nextObject]];
    fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
    om = [fattrs filePosixPermissions];
    while ((file = [e nextObject]) != nil) {
      // This code must be here to cover first file (which attributes
      // set outside of cycle)
      if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory] && ![applyButton superview]) {
        [view addSubview:applyButton];
      }

      fp = [path stringByAppendingPathComponent:file];
      fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
      m = [fattrs filePosixPermissions];

      // XOR 2 files' permissions - non-equal bits return '1'
      // OR result with 'mask' bits - '1' bits in mask remains '1'
      mask = mask | (om ^ m);
      om = m;

      // don't allow changes when we're not the owner
      if (![[fattrs fileOwnerAccountName] isEqualToString:NSUserName()] && geteuid() != 0) {
        [permissionsView setEditable:NO];
        [suidButton setEnabled:NO];
        [guidButton setEnabled:NO];
        [stickyButton setEnabled:NO];
      }
    }

    // Display permissions
    [permissionsView setNoChangeMask:mask];
    [permissionsView setMode:m];  // last file permissions in selection

    oldMode = m;
  } else {
    fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
    fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];

    oldMode = [fattrs filePosixPermissions];
    mode = oldMode;

    if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory] && ![applyButton superview]) {
      [view addSubview:applyButton];
      [stickyButton setEnabled:YES];
    }

    // don't allow changes when we're not the owner
    if (![[fattrs fileOwnerAccountName] isEqualToString:NSUserName()] && geteuid() != 0) {
      [permissionsView setEditable:NO];
      [suidButton setEnabled:NO];
      [guidButton setEnabled:NO];
      [stickyButton setEnabled:NO];
      [applyButton setEnabled:NO];
    }

    // Permissions grid
    [permissionsView setNoChangeMask:0];
    [permissionsView setMode:mode];
    // Special bits
    [suidButton setState:(mode & S_ISUID)];
    [guidButton setState:(mode & S_ISGID)];
    [stickyButton setState:(mode & S_ISVTX)];
  }

  // Buttons state and title, window edited state
  [super revert:self];

  return self;
}

@end
