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

#import <AppKit/AppKit.h>

@class BGOperation;

@interface BGProcess : NSObject
{
  BGOperation *operation;

  NSLock *guiLock;
  NSDate *lastViewUpdateDate;

  // SimpleBGProcess.gorm
  id window;
  id processBox;
  id currentField;
  id progressPie;
  id stopButton;

  // OperationAlert.gorm
  id alertWindow;
  id alertBox;
  id alertDescription;
  id alertMessage;
  IBOutlet NSButton *alertRepeatButton;
  id alertButton0, alertButton1, alertButton2;

  NSArray *alertButtons;
}

- (id)initWithOperation:(BGOperation *)op;

// Process view or alert view
- (NSView *)processView;

// Used for processes list
- (NSImage *)miniIcon;

// Process views (below process list)
- (void)updateAlertWithMessage:(NSString *)messageText
                          help:(NSString *)helpText
                     solutions:(NSArray *)buttonLabels;

- (void)updateWithMessage:(NSString *)message
                     file:(NSString *)currFile
                   source:(NSString *)currSourceDir
                   target:(NSString *)currTargetDir
                 progress:(float)progress;

- (void)stop:(id)sender;

@end
