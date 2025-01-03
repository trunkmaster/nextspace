/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description:  A FileMover.tool wrapper and UI.
//
// Copyright (C) 2018 Sergii Stoian
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

#import <SystemKit/OSEDefaults.h>
#import <DesktopKit/NXTProgressBar.h>
#import <DesktopKit/Utilities.h>

#import <AppKit/AppKit.h>

#import <Processes/ProcessManager.h>
#import <Processes/FileMoverUI.h>

@implementation FileMoverUI

//=============================================================================
// Init and destroy
//=============================================================================

- initWithOperation:(BGOperation *)op
{
  self = [super init];

  ASSIGN(operation, op);

  [NSBundle loadNibNamed:@"FileMoverUI" owner:self];

  ASSIGN(lastViewUpdateDate, [NSDate date]);

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(operationDidChangeState:)
                                               name:WMOperationDidChangeStateNotification
                                             object:operation];

  return self;
}

- (void)awakeFromNib
{
  [super awakeFromNib];

  NSDebugLLog(@"Processes", @"FileMoverUI: awakeFromNib: %@", [operation source]);

  [fromField setStringValue:[operation source]];
  if ([operation type] == DeleteOperation) {
    [fromLabel setStringValue:@"In:"];
  } else {
    [toField setStringValue:[operation currentTargetDirectory]];
  }

  // Hide labels at startup. -updateOperationView later will show
  // appropriate ones.
  [fromLabel setTextColor:[NSColor windowBackgroundColor]];
  [toLabel setTextColor:[NSColor windowBackgroundColor]];

  [progressBar setRatio:0.0];

  [pauseButton setRefusesFirstResponder:YES];
  [pauseButton setEnabled:YES];
}

- (void)dealloc
{
  NSDebugLLog(@"Memory", @"FileMoverUI: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

//=============================================================================

- (id)processView
{
  if ([operation state] == OperationAlert) {
    return [super processView];
  }

  if (!processBox) {
    [NSBundle loadNibNamed:@"FileMoverUI" owner:self];
  }
  return processBox;
}

- (void)updateWithMessage:(NSString *)message
                     file:(NSString *)currFile
                   source:(NSString *)currSourceDir
                   target:(NSString *)currTargetDir
                 progress:(float)progress
{
  // === LOCK
  while (guiLock && ([guiLock tryLock] == NO)) {
    NSDebugLLog(@"Processes", @"[FileMoverUI updateProcessView] LOCK FAILED! Waiting...");
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
  }
  // ===

  // NSDebugLLog(@"Processes", @"==== [FileOperation updateOperationView]");

  // NSDate *now;
  // Do not update view faster than AppKit can update
  // now = [NSDate date];
  // if (lastViewUpdateDate == nil ||
  //     [now timeIntervalSinceDate:lastViewUpdateDate] < 0.1)
  //   {
  //     [guiLock unlock];
  //     return;
  //   }

  if (message && ![message isEqualToString:@""]) {
    [currentField
        setStringValue:NXTShortenString(message, [currentField bounds].size.width - 3,
                                        [currentField font], NXSymbolElement, NXTDotsAtRight)];
  }
  // From:, In: field
  if ([currSourceDir isEqualToString:@""]) {
    [fromLabel setTextColor:[NSColor windowBackgroundColor]];
  } else {
    [fromLabel setTextColor:[NSColor controlTextColor]];
  }
  [fromField setStringValue:NXTShortenString(currSourceDir, [fromField bounds].size.width - 3,
                                             [fromField font], NXPathElement, NXTDotsAtCenter)];
  // To: field
  if ([currTargetDir isEqualToString:@""]) {
    [toLabel setTextColor:[NSColor windowBackgroundColor]];
  } else {
    [toLabel setTextColor:[NSColor controlTextColor]];
  }
  [toField setStringValue:NXTShortenString(currTargetDir, [toField bounds].size.width - 3,
                                           [toField font], NXPathElement, NXTDotsAtCenter)];

  if (progress > 0.0) {
    [progressBar setRatio:progress];
  }

  // ASSIGN(lastViewUpdateDate, now);

  // NSDebugLLog(@"Processes", @"==== [FileOperation updateOperationView] END");

  // === LOCK
  [guiLock unlock];
}

//
//--- Action methods ---------------------------------------------------------
//
- (void)stop:(id)sender
{
  [(FileMover *)operation stop:sender];
  //...and wait for WMOperationDidChangeStateNotification
}

// Suspend/Resume button
- (void)pause:(id)sender
{
  [(FileMover *)operation pause:sender];
  //...and wait for WMOperationDidChangeStateNotification
}

- (void)operationDidChangeState:(NSNotification *)notif
{
  NSString *currMessage = @"";
  BOOL stopOn = YES;
  BOOL pauseOn = YES;

  operationState = [operation state];

  switch (operationState) {
    case OperationPrepare:
      currMessage = @"File Operation preparing...";
      stopOn = NO;
      pauseOn = NO;
      break;
    case OperationStopping:
      currMessage = @"File Operation stopping...";
      stopOn = NO;
      pauseOn = NO;
      break;
    case OperationStopped:
      currMessage = @"File Operation stopped.";
      stopOn = NO;
      pauseOn = NO;
      break;
    case OperationCompleted:
      stopOn = NO;
      pauseOn = NO;
      break;
    case OperationPaused:
      [pauseButton setTitle:@"Resume"];
      break;
    case OperationRunning:
      [pauseButton setTitle:@"Pause"];
      break;
    case OperationAlert:
      break;
  }

  [stopButton setEnabled:stopOn];
  [pauseButton setEnabled:pauseOn];

  if (![currMessage isEqualToString:@""]) {
    [self updateWithMessage:currMessage
                       file:@""
                     source:@""
                     target:@""
                   progress:[operation progressValue]];
  }
}

//
//--- Accessory methods ------------------------------------------------------
//
@end

@implementation FileMoverUI (Alert)

- (void)alertButtonClicked:(id)sender
{
  NSDebugLLog(@"Processes", @"FileMoverUI: alertButtonClicked!");
  [(FileMover *)operation postSolution:[sender tag] applyToSubsequent:[alertRepeatButton state]];
}

@end
