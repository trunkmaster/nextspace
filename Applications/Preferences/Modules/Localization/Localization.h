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

#import <AppKit/NSImage.h>
#import <Preferences.h>

#import "LanguageList.h"

@interface Localization: NSObject <PrefsModule>
{
  LanguageList *languageList;
  id languageScrollView;
  id dateExample;		// NSDateFormatString
  id shortDateExample;		// NSShortDateFormatString
  id timeExample; 		// NSTimeFormatString
  id timeDateExample;		// NSTimeDateFormatString
  id shortTimeDateExample;	// NSShortTimeDateFormatString
  id numbersExample;		// NSPositiveCurrencyFormatString
  id encodingBtn;
  // id papersizeBtn;
  id unitsBtn;
  id view;
  id window;

  NSImage *image;

  NSArray *languages;
  NSArray *encodings;
}

- (void)readUserDefaults;

@end
