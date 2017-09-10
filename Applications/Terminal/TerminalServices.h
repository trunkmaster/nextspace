/*
  Copyright (C) 2002 Alexander Malmberg <alexander@malmberg.org>
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#ifndef Services_h
#define Services_h

// "Command and Key Equivalent" block
#define Key @"Key"
#define Commandline @"Commandline"

// "Accept" block
#define AcceptTypes @"AcceptTypes"
#define ACCEPT_STRING    1 // "Plain text"
//#define ACCEPT_RICH      3 // "Rich text"
#define ACCEPT_FILENAMES 2 // "Files"

// "Use Selection" block
#define Input @"Input"
#define INPUT_NO      0 // no option in Panel
#define INPUT_STDIN   1 // "As Input"
#define INPUT_CMDLINE 2 // "On Command Line"

// "Execution" block
#define Type @"Type"
#define TYPE_BACKGROUND  0 // "Run Service in the Background"
#define TYPE_WINDOW_NEW  1 // "Run Service in the New Window"
#define TYPE_WINDOW_IDLE 2 // "Run Service in the Idle Window"
// 1 = "Return Output", 0 = "Discard Output"
#define ReturnData @"ReturnData"

@interface TerminalServices : NSObject
{
}

+ (void)updateServicesPlist;

+ (NSDictionary *)terminalServicesDictionary;

@end

#endif

