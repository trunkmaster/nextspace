/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
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
#import <DesktopKit/NXTSavePanel.h>

@class NSString;
@class NSArray;

@interface NXTOpenPanel : NXTSavePanel
{
  BOOL _canChooseDirectories;
  BOOL _canChooseFiles;
}
// Accessing the NXTOpenPanel shared instance
+ (NXTOpenPanel *)openPanel;

// Running an NXTOpenPanel 
- (NSInteger)runModalForTypes:(NSArray *)fileTypes;
- (NSInteger)runModalForDirectory:(NSString *)path
                             file:(NSString *)name
                            types:(NSArray *)fileTypes;

- (NSInteger)runModalForDirectory:(NSString *)path
                             file:(NSString *)name
                            types:(NSArray *)fileTypes
                 relativeToWindow:(NSWindow*)window;
- (void)beginSheetForDirectory:(NSString *)path
                          file:(NSString *)name
                         types:(NSArray *)fileTypes
                modalForWindow:(NSWindow *)docWindow
                 modalDelegate:(id)delegate
                didEndSelector:(SEL)didEndSelector
                   contextInfo:(void *)contextInfo;
- (void)beginForDirectory:(NSString *)absoluteDirectoryPath
                     file:(NSString *)filename
                    types:(NSArray *)fileTypes
         modelessDelegate:(id)modelessDelegate
           didEndSelector:(SEL)didEndSelector
              contextInfo:(void *)contextInfo;

- (NSArray *) filenames;

- (NSArray *) URLs; 

// Filtering Files 
- (BOOL)canChooseDirectories;
- (BOOL)canChooseFiles;
- (void)setCanChooseDirectories: (BOOL)flag;
- (void)setCanChooseFiles: (BOOL)flag;

- (void)setResolvesAliases:(BOOL)flag; 
- (BOOL)resolvesAliases; 

- (BOOL)allowsMultipleSelection;
- (void)setAllowsMultipleSelection:(BOOL)flag;
@end
