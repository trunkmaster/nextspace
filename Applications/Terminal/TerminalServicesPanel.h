/*
  Copyright (C) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (C) 2017 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/


@class NSMutableDictionary,NSMutableArray;
@class GSVbox,NSTableView,NSPopUpButton,NSTextField;

@interface TerminalServicesPanel : NSObject <NSTextFieldDelegate>
{
  NSMutableDictionary *services;
  NSMutableArray      *serviceList;
  int                 current;

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
  id outputMatrix; // polymorphicMatrix
  id shellMatrix;

  id okBtn;

  // Save Panel
  id accView;
  id saveServicesTable;
}

- (void)activatePanel;

@end
