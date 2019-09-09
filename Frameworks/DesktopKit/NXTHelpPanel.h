/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: Standard panel for application help.
//
// Copyright (C) 2019 Sergii Stoian
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
#import <AppKit/NSApplication.h>
#import <AppKit/NSPanel.h>

@class NSString;

@interface NSApplication (NSApplicationHelpExtension)
- (void)orderFrontHelpPanel:(id)sender;
@end

@interface NXTHelpPanel : NSPanel
{
  // Attributes
}

//
// Accessing the Help Panel
//
+ (NSHelpPanel *)sharedHelpPanel;
+ (NSHelpPanel *)sharedHelpPanelWithDirectory:(NSString *)helpDirectory;

//
// Managing the Contents
//
+ (void)setHelpDirectory:(NSString *)helpDirectory;
- (void)addSupplement:(NSString *)helpDirectory
               inPath:(NSString *)supplementPath;
- (NSString *)helpDirectory;
- (NSString *)helpFile;

//
// Attaching Help to Objects 
//
+ (void)attachHelpFile:(NSString *)filename
            markerName:(NSString *)markerName
                    to:(id)anObject;
+ (void)detachHelpFrom:(id)anObject;

//
// Showing Help 
//
- (void)showFile:(NSString *)filename
        atMarker:(NSString *)markerName;
- (BOOL)showHelpAttachedTo:(id)anObject;

//
// Printing 
//
- (void)print:(id)sender;

@end
