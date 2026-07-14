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

#ifndef PCDefaultBuildTool 
#define PCDefaultBuildTool @"/usr/bin/make"
#endif

#define SuccessSound            @"SuccessSound"
#define FailureSound            @"FailureSound"
#define RootBuildDirectory      @"RootBuildDirectory"
#define BuildTool               @"BuildTool"
#define DeleteCacheWhenQuitting @"DeleteBuildCacheWhenQuitting"
#define PromptOnClean           @"PromtOnClean"

@interface PCBuildPrefs : NSObject <PCPrefsSection>
{
  id <PCPreferences>   prefs;

  IBOutlet NSBox       *buildingView;

  IBOutlet NSTextField *successField;
  IBOutlet NSButton    *setSuccessButton;
  IBOutlet NSTextField *failureField;
  IBOutlet NSButton    *setFailureButton;

  IBOutlet NSTextField *rootBuildDirField;
  IBOutlet NSButton    *setRootBuildDirButton;
  IBOutlet NSTextField *buildToolField;
  IBOutlet NSButton    *setBuildToolButton;

  IBOutlet NSButton    *deleteCache;
  IBOutlet NSButton    *promptOnClean;
}

@end

