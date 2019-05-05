/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// MiscProgressPie.h -- a simple view class for displaying a pie
// Written and Copyright (c) 1993 by James Heiser.  (jheiser@adobe.com)
// Version 1.0.  All rights reserved.
//
// This notice may not be removed from this source code.
//
// This object is included in the MiscKit by permission from the author
// and its use is governed by the MiscKit license, found in the file
// "LICENSE.rtf" in the MiscKit distribution.  Please refer to that file
// for a list of all applicable permissions and restrictions.
//	

#import "NXTProgressView.h"

@interface NXTProgressPie : NXTProgressView
{
	BOOL	isHidden;
}

- (void)setHidden:(BOOL)aBool;
- (BOOL)isHidden;

@end
