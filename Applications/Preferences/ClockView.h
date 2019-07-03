/* -*- mode: objc -*- */
//
// Project: Preferences
//
// Copyright (C) 2014-2019 Sergii Stoian
//
// This application is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public
// License as published by the Free Software Foundation; either
// version 2 of the License, or (at your option) any later version.
//
// This application is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
// Library General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this library; if not, write to the Free
// Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
//

#include <Foundation/NSCalendarDate.h>

#include <AppKit/NSNibDeclarations.h>
#include <AppKit/NSView.h>

@interface ClockView: NSView
{
  BOOL		drawsTile;
  NSImage	*tileImage;

  NSTimer	*timer;

  NSImage	*colon;
  NSImage	*no_colon;
  NSImage	*mask;
  NSImage	*min1, *min2;
  NSImage	*hour1, *hour2, *ampm;
  NSImage	*dom1, *dom2, *dow;
  NSImage	*month;

  int		_sec, lastsec;
  int		_min, lastmin;
  int		_hour, lasthour;
  int		_dow, _dom, lastdom;
  int		_month, lastmonth;

  BOOL		use24Hours, last24;
  BOOL		isAnalog;
  BOOL		hasSecondHand, lastSecHand;


  BOOL	        dateChanged;
  NSPoint	colonLocation;
  BOOL          colonOn;
}

- (void)setDate:(NSCalendarDate *)aDate;

- (BOOL)isAnalog;
- (BOOL)hasAnalogSecondHand;

- (void)setAnalog:(BOOL)flag;
- (void)setAnalogSecondHand:(BOOL)flag;

@end

