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

@interface TerminalServicesPanel : NSObject
{
  NSMutableDictionary *services;
  NSMutableArray      *serviceList;
  int                 current;

  // NSPopUpButton *pb_input,*pb_output,*pb_type;
  // NSTextField *tf_name,*tf_cmdline,*tf_key;
  // NSButton *cb_string,*cb_filenames;

  id panel;
  // Table view
  id serviceTable;
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
  id outputMatrix;
  id shellMatrix;
}

- (void)activatePanel;

@end
