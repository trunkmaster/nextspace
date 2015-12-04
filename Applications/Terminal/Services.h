/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#ifndef Services_h
#define Services_h

#define Key @"Key"
#define ReturnData @"ReturnData"
#define Commandline @"Commandline"
#define Input @"Input"
#define Type @"Type"
#define AcceptTypes @"AcceptTypes"

#define INPUT_NO      0
#define INPUT_STDIN   1
#define INPUT_CMDLINE 2

#define ACCEPT_STRING    1
#define ACCEPT_FILENAMES 2

#define TYPE_BACKGROUND  0
#define TYPE_WINDOW_NEW  1
#define TYPE_WINDOW_IDLE 2

@interface TerminalServices : NSObject
{
}

+(void) updateServicesPlist;

+(NSDictionary *) terminalServicesDictionary;

@end

#endif

