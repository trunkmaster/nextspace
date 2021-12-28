/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
//
// Description: NSFileManager extensions. File meta information
//              (attributes, file type description...).
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

#import <Foundation/NSString.h>
#import <Foundation/NSFileManager.h>
 
@class NSString, NSObject;

// Utility functions
NSString *NXTIntersectionPath(NSString *aPath, NSString *bPath);

typedef enum {
  NXTSortByName = 0, // by name only, folders mixed with files
  NXTSortByKind = 1, // folders first + NXTSortByName
  NXTSortByType = 2, // file extention + NXTSortByKind
  NXTSortByDate = 3, // + NXTSortByName
  NXTSortBySize = 4, // + NXTSortByName
  NXTSortByOwner = 5 // + NXTSortByName
} NXTSortType;

// Preferences used by File Viewer, NSOpenPanel and NSSavePanel
extern NSString *NXTSortFilesBy;
extern NSString *NXTShowHiddenFiles;

@interface NXTFileManager : NSFileManager
{
}

+ (NXTFileManager *)defaultManager;

- (BOOL)isShowHiddenFiles;
- (void)setShowHiddenFiles:(BOOL)yn;
- (NXTSortType)sortFilesBy;
- (void)setSortFilesBy:(NXTSortType)type;

- (NSArray *)directoryContentsAtPath:(NSString *)path;
- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                          showHidden:(BOOL)showHidden;
- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                            sortedBy:(NXTSortType)sortType
                          showHidden:(BOOL)showHidden;

- (NSArray *)executablesForSubstring:(NSString *)substring;
- (NSArray *)completionForPath:(NSString *)path
                    isAbsolute:(BOOL)isAbsolute;
- (NSString *)absolutePathForPath:(NSString *)path;
- (NSString *)absolutePathForCommand:(NSString *)command;
- (BOOL)directoryExistsAtPath:(NSString *)path;

// libmagic
- (NSString *)mimeTypeForFile:(NSString *)fullPath;
- (NSString *)mimeEncodingForFile:(NSString *)fullPath;
- (NSString *)descriptionForFile:(NSString *)fullPath;

@end
