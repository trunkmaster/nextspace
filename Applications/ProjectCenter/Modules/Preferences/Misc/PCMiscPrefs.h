// 
// GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html
//
// Copyright (C) 2001-2009 Free Software Foundation
//
// Authors: Sergii Stoian
//
// Description: 
//
// This file is part of GNUstep.
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

#import <AppKit/AppKit.h>
#import <Protocols/Preferences.h>

#ifndef PCDefaultDebugger
#define PCDefaultDebugger @"/usr/bin/gdb"
#endif

#define PromptOnQuit         @"PromtOnQuit"
#define FullPathInFilePanels @"FullPathInFilePanels"
#define RememberWindows      @"RememberWindows"
#define DisplayLog           @"DisplayLog"
#define UseTearOffWindows    @"UseTearOffWindows"
#define Debugger             @"Debugger"
#define Editor               @"Editor"

@interface PCMiscPrefs : NSObject <PCPrefsSection>
{
  id <PCPreferences>   prefs;

  IBOutlet NSBox       *miscView;

  IBOutlet NSButton    *promptWhenQuit;
  IBOutlet NSButton    *fullPathInFilePanels;
  IBOutlet NSButton    *rememberWindows;
  IBOutlet NSButton    *displayLog;
  IBOutlet NSButton    *useTearOffWindows;

  IBOutlet NSTextField *debuggerField;
  IBOutlet NSButton    *debuggerButton;
  IBOutlet NSTextField *editorField;
  IBOutlet NSTextField *editorButton;
}

@end

