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
#import "Operations/Mounter.h"

@implementation Mounter

- (id)initWithInfo:(NSDictionary *)userInfo
{
  NSString *opName = [userInfo objectForKey:@"Operation"];
  OperationType op = EjectOperation;
  NSString *s;

  if ([opName isEqualToString:@"Mount"])
    op = MountOperation;
  else if ([opName isEqualToString:@"Unmount"])
    op = UnmountOperation;

  self = [super initWithOperationType:op
                            sourceDir:[userInfo objectForKey:@"UNIXDevice"]
                            targetDir:nil
                                files:nil
                              manager:nil];

  [self setState:OperationRunning];

  return self;
}

- (BGProcess *)userInterface
{
  [super userInterface];

  if (processUI && (state == OperationPrepare || state == OperationRunning)) {
    if (type == MountOperation)
      message = [NSString stringWithFormat:@"Mounting %@", source];
    else if (type == UnmountOperation)
      message = [NSString stringWithFormat:@"Unmounting %@", source];
    else if (type == EjectOperation)
      message = [NSString stringWithFormat:@"Ejecting %@", source];

    [processUI updateWithMessage:message file:nil source:source target:nil progress:0.0];
  }

  return processUI;
}

- (BOOL)canBePaused
{
  return NO;
}

- (BOOL)canBeStopped
{
  return NO;
}

// This method used on logout sequence
- (void)stop:(id)sender
{
  [self destroyOperation:nil];
}

- (void)destroyOperation:(id)object
{
  NSDictionary *info = nil;
  BOOL showAlert = NO;

  if (object && [object isKindOfClass:[NSTimer class]]) {
    info = [object userInfo];
  } else {
    info = object;
  }

  // Notify ProcessManager
  [[NSNotificationCenter defaultCenter] postNotificationName:WMOperationWillDestroyNotification
                                                      object:self];

  if (info && [[info objectForKey:@"Message"] isEqualToString:@""] == NO &&
      ([[info objectForKey:@"Success"] isEqualToString:@"false"] != NO)) {
    [NSApp activateIgnoringOtherApps:YES];
    NXTRunAlertPanel([info objectForKey:@"Title"], [info objectForKey:@"Message"], nil, nil, nil);
  }
}

- (void)finishOperation:(NSDictionary *)userInfo
{
  [self setState:OperationCompleted];

  if (processUI) {
    [processUI updateWithMessage:[userInfo objectForKey:@"Message"]
                            file:nil
                          source:source
                          target:nil
                        progress:0.0];
  }

  if (userInfo && [[userInfo objectForKey:@"Operation"] isEqualToString:@"Eject"]) {
    // NSLog(@"Mounter: Eject [%@]", userInfo);
    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     target:self
                                   selector:@selector(destroyOperation:)
                                   userInfo:userInfo
                                    repeats:NO];
  } else {
    // NSLog(@"Mounter: userInfo is empty or operation is not Eject [%@]", userInfo);
    [self destroyOperation:nil];
  }
}

@end
