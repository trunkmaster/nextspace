/*
  Copyright (C) 2015 Sergii Stoian <stoyan255@ukr.net>

  This file is a part of Terminal.app. Terminal.app is free software; you
  can redistribute it and/or modify it under the terms of the GNU General
  Public License as published by the Free Software Foundation; version 2
  of the License. See COPYING or main.m for more information.
*/

#import "Preferences.h"

@interface ShellPrefs : NSObject <PrefsModule>
{
  id shellPopup;
  id loginShellBtn;
  id commandLabel;
  id commandField;
  id window;
  id view;
}
@end
