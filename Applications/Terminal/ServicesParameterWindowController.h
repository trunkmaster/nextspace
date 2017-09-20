/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#ifndef ServicesParameterWindowController_h
#define ServicesParameterWindowController_h

#include <AppKit/NSWindowController.h>

@class NSTextField;

@interface TerminalServicesParameterWindowController : NSWindowController
{
  NSTextField *tf_cmdline;
}

+ (NSString *)getCommandlineFrom:(NSString *)cmdline
                     selectRange:(NSRange)r
                         service:(NSString *)service_name;

@end

#endif

