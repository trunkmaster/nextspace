/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#include "Preferences.h"

@interface StartupPrefs : NSObject <PrefsModule>
{
  id actionsMatrix;
  id autolaunchBtn;
  id filePathField;
  id window;
  id view;
}
- (void) setFilePath: (id)sender;
- (void) setAction: (id)sender;
- (void) setAutolaunch: (id)sender;
@end
