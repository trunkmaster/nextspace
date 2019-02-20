/* -*- mode: objc -*- */
/*
  Project: SoundKit framework.

  Copyright (C) 2019 Sergii Stoian

  This application is free software; you can redistribute it and/or
  modify it under the terms of the GNU General Public
  License as published by the Free Software Foundation; either
  version 2 of the License, or (at your option) any later version.

  This application is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  Library General Public License for more details.

  You should have received a copy of the GNU General Public
  License along with this library; if not, write to the Free
  Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import "NXSoundOut.h"

@implementation NXSoundOut

- (void)dealloc
{
  [super dealloc];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"`%@` on %@. Active port: %@",
                   _sink.description, super.card.name, _sink.activePortDesc];
}

/*--- Sink proxy ---*/
- (NSArray *)availablePorts
{
  if (_sink == nil) {
    NSLog(@"SoundDevice: avaliablePorts was called without Sink was being set.");
    return nil;
  }
  return _sink.portsDesc;
}
- (NSString *)activePort
{
  return _sink.activePortDesc;
}
- (void)setActivePort:(NSString *)portName
{
}

@end
