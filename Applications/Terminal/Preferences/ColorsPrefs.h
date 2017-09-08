/*
  Copyright (C) 2015-2017 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
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
- (void) setDefault: (id)sender;
- (void) showDefault: (id)sender;
- (void) setWindow: (id)sender;
@end
