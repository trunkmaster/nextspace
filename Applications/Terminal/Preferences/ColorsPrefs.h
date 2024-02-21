/*
  Copyright (c) 2015-2017 Sergii Stoian <stoyan255@gmail.com>

  This program is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program; if not, write to the Free Software
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#include <AppKit/AppKit.h>

#include "Preferences.h"

@interface ColorsPrefs : NSObject <PrefsModule>
{
  id windowBGColorBtn;
  id blinkTextColorBtn;
  id boldTextColorBtn;
  id useBoldBtn;
  id cursorBlinkingBtn;
  id cursorColorBtn;
  id cursorStyleMatrix;
  id inverseTextBGColorBtn;
  id inverseTextFGColor;
  id inverseTextLabel;
  id normalTextColorBtn;
  id windowSelectionColorBtn;
  id window;

  id view;
}
- (void)setDefault:(id)sender;
- (void)showDefault:(id)sender;
- (void)setWindow:(id)sender;
@end
