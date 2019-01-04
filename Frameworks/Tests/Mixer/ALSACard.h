/*
   Project: TEMP

   Copyright (C) 2019 Free Software Foundation

   Author: Developer

   Created: 2019-01-04 16:35:06 +0200 by me

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

#import <alsa/asoundlib.h>
#import <Foundation/Foundation.h>

@interface ALSACard : NSObject
{
  int            card_index;
  NSString       *cardName;
  NSString       *chipName;
  NSString       *deviceName;
  
  snd_mixer_t    *alsa_mixer;

  NSMutableArray *controls;
}

- initWithNumber:(int)number;
- (void)fetchDefaultInfo;

- (NSString *)name;
- (NSString *)chipName;
- (NSArray *)controls;

- (snd_mixer_t *)createMixer;
- (void)deleteMixer;
  
@end

