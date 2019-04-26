/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Description: Simple background process user interface
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

#import <NXAppKit/NXProgressPie.h>
#import <NXAppKit/NXUtilities.h>

#import <Operations/ProcessManager.h>
#import <Operations/BGOperation.h>

#import "BGProcess.h"

@implementation BGProcess

- (id)initWithOperation:(BGOperation *)op
{
  [super init];
  
  ASSIGN(operation,op);
  [NSBundle loadNibNamed:@"SimpleBGProcess" owner:self];

  ASSIGN(lastViewUpdateDate,[NSDate date]);

  return self;
}

- (void)dealloc
{
  NSLog(@"BGProcess: dealloc");

  RELEASE(processBox);
  processBox = nil;
  
  TEST_RELEASE(alertBox);
  alertBox = nil;

  RELEASE(alertButtons);

  [super dealloc];
}

- (NSImage *)miniIcon
{
  switch ([operation type])
    {
    case PermissionOperation:
      return [NSImage imageNamed:@"miniChmoder"];
    case CopyOperation:
      return [NSImage imageNamed:@"miniCopy"];
    case DeleteOperation:
      return [NSImage imageNamed:@"miniDelete"];
    case MoveOperation:
      return [NSImage imageNamed:@"miniMove"];
    case MountOperation:
    case UnmountOperation:
    case EjectOperation:
      return [NSImage imageNamed:@"miniDisk"];
    case LinkOperation:
      return [NSImage imageNamed:@"miniLink"];
    case RecycleOperation:
      return [NSImage imageNamed:@"miniRecycle"];
    case SizeOperation:
      return [NSImage imageNamed:@"miniSizing"];
    default:
      return nil;
    }
}

- (void)awakeFromNib
{
  if (alertWindow)
    {
      RETAIN(alertBox);
      [alertBox removeFromSuperview];
      DESTROY(alertWindow);

      [alertMessage setBackgroundColor:[NSColor controlBackgroundColor]];
      [alertMessage setFont:[NSFont systemFontOfSize:14.0]];
      [alertMessage setEditable:NO];
      [alertMessage setSelectable:NO];

      [alertDescription setBackgroundColor:[NSColor controlBackgroundColor]];
      [alertDescription setEditable:NO];
      [alertDescription setSelectable:NO];

      [alertRepeatButton setRefusesFirstResponder:YES];

      alertButtons = [[NSArray alloc]
                       initWithObjects:alertButton0, alertButton1, alertButton2,
                       nil];
      [alertButton0 setRefusesFirstResponder:YES];
      [alertButton1 setRefusesFirstResponder:YES];
      [alertButton2 setRefusesFirstResponder:YES];
    }
  else if (window)
    {
      RETAIN(processBox);
      [processBox removeFromSuperview];
      DESTROY(window);

      [currentField setStringValue:@"Preparing for operation..."];

      if ([operation isProgressSupported] == YES)
        {
          [progressPie setRatio:0.0];
        }
      else
        {
          [progressPie removeFromSuperview];
        }

      [stopButton setRefusesFirstResponder:YES];
      if ([operation canBeStopped] == YES)
        {
          [stopButton setEnabled:YES];
        }
      else
        {
          [stopButton setEnabled:NO];
        }
    }
}

- (NSView *)processView
{
  if ([operation state] == OperationAlert)
    {
      if (!alertBox)
        {
          [NSBundle loadNibNamed:@"OperationAlert" owner:self];
        }
      return alertBox;
    }
  else
    {
      if (!processBox)
        {
          [NSBundle loadNibNamed:@"SimpleBGProcess" owner:self];
        }
      return processBox;
    }
}

- (void)updateAlertWithMessage:(NSString *)messageText
                          help:(NSString *)helpText
                     solutions:(NSArray *)buttonLabels
{
  int i, solCount;
  id  button;

  if ([operation state] != OperationAlert)
    {
      NSLog(@"BGProcess: Alert view is not updated because "
            "process not in state OperationAlert!");
      return;
    }

  // 1. Load OperationsAlert.gorm
  [self processView];
      
  [alertMessage setString:messageText];
  [alertDescription setString:helpText];
  [alertRepeatButton setState:NSOffState];
      
  solCount = [buttonLabels count];
  for (i = 0; i < 3; i++)
    {
      button = [alertButtons objectAtIndex:i];

      // Set button title or remove it
      if (i < solCount)
        {
          [button setTitle:[buttonLabels objectAtIndex:i]];
          if ([button superview] == nil)
            {
              NSRect pbFrame;
              NSRect bFrame;
                  
              [alertBox addSubview:button];

              // HACK: When button added and fopAlerBox width wider than
              // .gorm's width button position remains old in X-axis.
              pbFrame = [[alertButtons objectAtIndex:i-1] frame];
              bFrame = [button frame];
              bFrame.origin.x = pbFrame.origin.x - 5 - bFrame.size.width;
              [button setFrame:bFrame];
            }
        }
      else if ([button superview] != nil)
        {
          [button removeFromSuperview];
        }
    }
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
      NSLog(@"[BGProcess update view] LOCK FAILED! Waiting...");
      [[NSRunLoop currentRunLoop] 
        runMode:NSDefaultRunLoopMode 
        beforeDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
    }
  // ===

  // NSLog(@"==== [BGProcess updateOperationView]");

  // Do not update view faster than AppKit can
  // NSDate *now = [NSDate date];
      
  // if (lastViewUpdateDate == nil ||
  //     [now timeIntervalSinceDate:lastViewUpdateDate] < 0.1)
  //   {
  //     [guiLock unlock];
  //     return;
  //   }

  if (![message isEqualToString:@""])
    {
      // [currentField
      //       setStringValue:shortenString(message,
      //                                    [currentField bounds].size.width-3,
      //                                    [currentField font],
      //                                    NXSymbolElement, NXDotsAtRight)];
      [currentField setStringValue:message];
    }

  if (progress > 0.0)
    {
      [progressPie setRatio:progress/100];
    }
      
  // ASSIGN(lastViewUpdateDate, now);

  //NSLog(@"==== [FileOperation updateOperationView] END");

  // === LOCK
  [guiLock unlock];
}

- (void)stop:(id)sender
{
  [operation stop:sender];
}

@end
