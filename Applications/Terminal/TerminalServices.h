/*
  Copyright (c) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (c) 2017 Sergii Stoian <stoyan255@gmail.com>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import <Foundation/Foundation.h>

#ifndef Services_h
#define Services_h

// "Command and Key Equivalent" block
#define Key @"Key"
#define Commandline @"Commandline"

// "Accept" block
#define AcceptTypes @"AcceptTypes"
#define ACCEPT_STRING 1     // "Plain text"
#define ACCEPT_FILENAMES 2  // "Files"
#define ACCEPT_RICH 3       // "Rich text"

// "Use Selection" block
#define Input @"Input"
#define INPUT_NO 0       // no option in Panel
#define INPUT_STDIN 1    // "As Input"
#define INPUT_CMDLINE 2  // "On Command Line"

// "Execution" block
// #define Type @"Type"
// #define TYPE_BACKGROUND  0
// #define TYPE_WINDOW_NEW  1
// #define TYPE_WINDOW_IDLE 2

// 0 - "Run Service in the Background", 1 = "Run Service in a Window"
#define ExecType @"ExecType"
#define EXEC_IN_BACKGROUND 0
#define EXEC_IN_WINDOW 1

// 1 = "New Window", 0 = "Idle Window"
#define WindowType @"WindowType"
#define WINDOW_IDLE 0
#define WINDOW_NEW 1

// 1 = "Return Output", 0 = "Discard Output"
#define ReturnData @"ReturnData"

// 0 = "No Shell", 1 = "Default Shell"
#define ExecInShell @"ExecInShell"

@interface TerminalServices : NSObject
{
  id addArgsPanel;
  id okBtn;
  id cancelBtn;
  id commandField;
  id serviceNameField;
}

+ (NSDictionary *)terminalServicesDictionary;
+ (NSString *)serviceDirectory;
+ (NSDictionary *)plistForServiceNames:(NSArray *)services;
+ (void)updateServicesPlist;

@end

@interface TerminalServices (AddArguments)

- (NSString *)getCommandlineFrom:(NSString *)cmdline
                     selectRange:(NSRange)r
                         service:(NSString *)service_name;
@end

#endif
