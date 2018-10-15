/*
   FileMoverUI.m
   A FileMover.tool wrapper.

   Copyright (C) 2015 Sergii Stoian

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <NXFoundation/NXDefaults.h>
#import <NXAppKit/NXProgressBar.h>
#import <NXAppKit/NXUtilities.h>

#import <AppKit/AppKit.h>

#import <Operations/ProcessManager.h>
#import <Processes/FileMoverUI.h>

@implementation FileMoverUI

//=============================================================================
// Init and destroy
//=============================================================================

- initWithOperation:(BGOperation *)op
{
  self = [super init];
  
  ASSIGN(operation,op);
  
  [NSBundle loadNibNamed:@"FileMoverUI" owner:self];
  
  ASSIGN(lastViewUpdateDate,[NSDate date]);
  
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(operationDidChangeState:)
           name:WMOperationDidChangeStateNotification
         object:operation];

  return self;
}

- (void)awakeFromNib
{
  [super awakeFromNib];

  NSLog(@"FileMoverUI: awakeFromNib: %@", [operation source]);
  
  [fromField setStringValue:[operation source]];
  if ([operation type] == DeleteOperation)
    {
      [fromLabel setStringValue:@"In:"];
    }
  else
    {
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
  NSLog(@"FileMoverUI: dealloc");

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [super dealloc];
}

//=============================================================================

- (id)processView
{
  if ([operation state] == OperationAlert)
    {
      return [super processView];
    }
  
  if (!processBox)
    {
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
  while (guiLock && ([guiLock tryLock] == NO))
    {
      NSLog(@"[FileMoverUI updateProcessView] LOCK FAILED! Waiting...");
      [[NSRunLoop currentRunLoop] 
        runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
  // ===

  //NSLog(@"==== [FileOperation updateOperationView]");

  // NSDate *now;
  // Do not update view faster than AppKit can update
  // now = [NSDate date]; 
  // if (lastViewUpdateDate == nil ||
  //     [now timeIntervalSinceDate:lastViewUpdateDate] < 0.1)
  //   {
  //     [guiLock unlock];
  //     return;
  //   }

  if (![message isEqualToString:@""])
    {
      [currentField
            setStringValue:NXShortenString(message,
                                           [currentField bounds].size.width-3,
                                           [currentField font],
                                           NXSymbolElement, NXDotsAtRight)];
    }
  // From:, In: field
  if ([currSourceDir isEqualToString:@""])
    {
      [fromLabel setTextColor:[NSColor windowBackgroundColor]];
    }
  else
    {
      [fromLabel setTextColor:[NSColor controlTextColor]];
    }
  [fromField setStringValue:NXShortenString(currSourceDir,
                                            [fromField bounds].size.width-3,
                                            [fromField font], 
                                            NXPathElement, NXDotsAtLeft)];
  // To: field
  if ([currTargetDir isEqualToString:@""])
    {
      [toLabel setTextColor:[NSColor windowBackgroundColor]];
    }
  else
    {
      [toLabel setTextColor:[NSColor controlTextColor]];
    }
  [toField setStringValue:NXShortenString(currTargetDir,
                                          [toField bounds].size.width-3,
                                          [toField font], 
                                          NXPathElement, NXDotsAtLeft)];

  if (progress > 0.0)
    {
      [progressBar setRatio:progress];
    }
      
  // ASSIGN(lastViewUpdateDate, now);

  //NSLog(@"==== [FileOperation updateOperationView] END");

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
  BOOL     stopOn = YES;
  BOOL     pauseOn = YES;

  operationState = [operation state];
  
  switch (operationState)
    {
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
  
  if (![currMessage isEqualToString:@""])
    {
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
  NSLog(@"FileMoverUI: alertButtonClicked!");
  [(FileMover *)operation postSolution:[sender tag]
                     applyToSubsequent:[alertRepeatButton state]];
}

@end
