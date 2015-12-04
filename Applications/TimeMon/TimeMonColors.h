// Copyright 1994, 1997 Scott Hess.  Permission to use, copy, modify,
// and distribute this software and its documentation for any
// purpose and without fee is hereby granted, provided that this
// copyright notice appear in all copies.
// 
// Scott Hess makes no representations about the suitability of
// this software for any purpose.  It is provided "as is" without
// express or implied warranty.
//
#import <AppKit/AppKit.h>

@interface TimeMonColors:NSMatrix
{
}
- (id)initWithFrame:(NSRect)frameRect;
- (void)readColors;
- (void)mouseDown:(NSEvent *)e;
@end
