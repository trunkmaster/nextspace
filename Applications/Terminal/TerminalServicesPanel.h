/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <AppKit/AppKit.h>

@interface TerminalServicesPanel : NSObject <NSTextFieldDelegate>
{
  NSMutableDictionary *services;
  NSMutableArray *serviceList;
  int current;

  id panel;
  // Table view
  id serviceTable;
  id tableScrollView;
  NSTextField *nameChangeTF;

  // Command and key equivalent
  id commandTF;
  id keyTF;

  // Selection
  id selectionMatrix;

  // Accept
  id acceptFilesBtn;
  id acceptPlainTextBtn;
  id acceptRichTextBtn;

  // Execution
  id executeTypeBtn;
  id outputMatrix;  // polymorphicMatrix
  id shellMatrix;

  id okBtn;
  id saveBtn;

  // Save Panel
  id accView;
  id saveServicesTable;
}

- (void)activatePanel;

@end
