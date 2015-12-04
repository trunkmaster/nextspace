/*
copyright 2002 Alexander Malmberg <alexander@malmberg.org>

This file is a part of Terminal.app. Terminal.app is free software; you
can redistribute it and/or modify it under the terms of the GNU General
Public License as published by the Free Software Foundation; version 2
of the License. See COPYING or main.m for more information.
*/

#include "Label.h"

@implementation NSTextField (label)
+ newLabel: (NSString *)title
{
  NSTextField *f;

  f=[[self alloc] init];
  [f setStringValue: title];
  [f setEditable: NO];
  [f setDrawsBackground: NO];
  [f setBordered: NO];
  [f setBezeled: NO];
  [f setSelectable: NO];
  [f sizeToFit];

  return f;
}
@end
