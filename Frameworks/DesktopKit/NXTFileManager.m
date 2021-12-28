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

#include <magic.h> // libmagic

#import <Foundation/NSDictionary.h>
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSFileManager.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>

#import "NXTDefaults.h"
#import "NXTFileManager.h"

NSString *NXTSortFilesBy = @"SortFilesBy";
NSString *NXTShowHiddenFiles = @"ShowHiddenFiles";

static NXTFileManager *sharedManager;
static NSString      *dirPath;

NSString *NXTIntersectionPath(NSString *aPath, NSString *bPath)
{
  NSString   *subPath = [[NSString new] autorelease];
  NSArray    *aPathComps = [aPath pathComponents];
  NSArray    *bPathComps = [bPath pathComponents];
  NSUInteger i, aCount, bCount, count;
  NSString   *tmpPathComp;

  aCount = [aPathComps count];
  bCount = [bPathComps count];
  count =  (aCount < bCount)  ? aCount : bCount;

  // find intersection between changed and selected paths
  for (i=0; i<count; i++)
    {
      tmpPathComp = [aPathComps objectAtIndex:i];
      if ([tmpPathComp isEqualToString:[bPathComps objectAtIndex:i]])
	{
	  subPath = [subPath stringByAppendingPathComponent:tmpPathComp];
	}
      else
	{
	  break;
	}
    }

  return subPath;
}

@implementation NSString (Sorting)

- (NSComparisonResult)byTypeCompare:(NSString *)string
{
  NSString *ext1 = [self pathExtension];
  NSString *ext2 = [string pathExtension];
  
  return [ext1 localizedCompare:ext2];
}

- (NSComparisonResult)byDateCompare:(NSString *)string
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSString      *path1 = [dirPath stringByAppendingPathComponent:self];
  NSDate        *date1 = [[fm fileAttributesAtPath:path1 traverseLink:NO]
                           fileCreationDate];
  
  NSString      *path2 = [dirPath stringByAppendingPathComponent:string];
  NSDate        *date2 = [[fm fileAttributesAtPath:path2 traverseLink:NO]
                           fileCreationDate];
  
  return [date1 compare:date2];
}

- (NSComparisonResult)bySizeCompare:(NSString *)string
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSString           *path1 = [dirPath stringByAppendingPathComponent:self];
  unsigned long long size1;
  NSString           *path2 = [dirPath stringByAppendingPathComponent:string];
  unsigned long long size2;

  size1 = [[fm fileAttributesAtPath:path1 traverseLink:NO] fileSize];
  size2 = [[fm fileAttributesAtPath:path2 traverseLink:NO] fileSize];

  if (size1 == size2)
    return NSOrderedSame;

  if (size1 > size2)
    return NSOrderedDescending;

  if (size1 < size2)
    return NSOrderedAscending;

  return NSOrderedSame;
}

- (NSComparisonResult)byOwnerCompare:(NSString *)string
{
  NSFileManager *fm = [NSFileManager defaultManager];
  
  NSString *path1 = [dirPath stringByAppendingPathComponent:self];
  NSString *owner1 = [[fm fileAttributesAtPath:path1 traverseLink:NO]
                       fileOwnerAccountName];
  NSString *path2 = [dirPath stringByAppendingPathComponent:string];
  NSString *owner2 = [[fm fileAttributesAtPath:path2 traverseLink:NO]
                       fileOwnerAccountName];
  
  return [owner1 localizedCompare:owner2];
}

@end

@implementation NXTFileManager

+ (NXTFileManager *)defaultManager
{
  if (sharedManager == nil) {
    sharedManager = [[NXTFileManager alloc] init];
  }
  return sharedManager;
}

- (id)init
{
  self = [super init];

  return self;
}

- (void)dealloc
{
  [super dealloc];
}

// --- Preferences

- (BOOL)isShowHiddenFiles
{
  return [[[NXTDefaults globalUserDefaults] reload] boolForKey:NXTShowHiddenFiles];
}
- (void)setShowHiddenFiles:(BOOL)yn
{
  NXTDefaults *defs = [[NXTDefaults globalUserDefaults] reload];
  
  [defs setBool:yn forKey:NXTShowHiddenFiles];
  [defs synchronize];
}
- (NXTSortType)sortFilesBy
{
  NXTDefaults *defs = [[NXTDefaults globalUserDefaults] reload];
  NSInteger  type = [defs integerForKey:NXTSortFilesBy];

  if (type == -1)
    type = NXTSortByKind;
  
  return type;
}
- (void)setSortFilesBy:(NXTSortType)type
{
  NXTDefaults *defs = [[NXTDefaults globalUserDefaults] reload];

  [defs setInteger:type forKey:NXTSortFilesBy];
  [defs synchronize];
}

// --- Directory contents

- (NSArray *)directoryContentsAtPath:(NSString *)path
{
  return [self directoryContentsAtPath:path
                               forPath:nil
                              sortedBy:[self sortFilesBy]
                            showHidden:[self isShowHiddenFiles]];
}

- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                          showHidden:(BOOL)showHidden
{
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *dirContents;

  dirContents = [[fm directoryContentsAtPath:path] mutableCopy];

  if (showHidden == NO) {
    NSString *hiddenFilename;
    unsigned i, n;
    NSString *filename;
    NSString *pathIntersection = NXTIntersectionPath(path, targetPath);

    hiddenFilename = [path stringByAppendingPathComponent:@".hidden"];
    if ([fm fileExistsAtPath:hiddenFilename])	{
      NSString     *h = [NSString stringWithContentsOfFile:hiddenFilename];
      NSArray      *hidden = [h componentsSeparatedByString:@"\n"];
      NSEnumerator *e = [hidden objectEnumerator];

      while ((filename = [e nextObject]) != nil) {
        if (![targetPath
                     hasPrefix:[path stringByAppendingPathComponent:filename]]) {
          [dirContents removeObject:filename];
        }
      }
    }
    for (i = 0, n = [dirContents count]; i < n; i++) {
      NSString *filename = [dirContents objectAtIndex:i];

      if ([filename length] <= 0 || [filename hasPrefix:@"."]) {
        [dirContents removeObjectAtIndex:i];
        n--;
        i--;
      }
    }
  }

  [dirContents sortUsingSelector:@selector(localizedCompare:)];

  return [dirContents autorelease];
}

- (NSArray *)directoryContentsAtPath:(NSString *)path
                             forPath:(NSString *)targetPath
                            sortedBy:(NXTSortType)sortType
                          showHidden:(BOOL)showHidden
{
  
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSMutableArray *dirContents;
  SEL            compareSelector = 0;
  BOOL           foldersFirst = NO;

  dirPath = path;
  
  switch (sortType)
    {
    case NXTSortByName:  // = 0
      compareSelector = @selector(localizedCompare:);
      break;
    case NXTSortByKind:  // = 1
      compareSelector = @selector(localizedCompare:);
      foldersFirst = YES;
      break;
    case NXTSortByType:  // = 2
      compareSelector = @selector(byTypeCompare:);
      foldersFirst = YES;
      break;
    case NXTSortByDate:  // = 3
      compareSelector = @selector(byDateCompare:);
      break;
    case NXTSortBySize:  // = 4
      compareSelector = @selector(bySizeCompare:);
      break;
    case NXTSortByOwner: // = 5
      compareSelector = @selector(byOwnerCompare:);
      break;
    }

  dirContents = [[self directoryContentsAtPath:path
                                       forPath:targetPath
                                    showHidden:showHidden] mutableCopy];
  if (!dirContents)
    return nil;
  
  if (foldersFirst) {
    NSEnumerator   *e = [dirContents objectEnumerator];
    NSMutableArray *dirs = [[NSMutableArray alloc] init];
    NSMutableArray *files = [[NSMutableArray alloc] init];
    NSString       *entry = nil;
    NSDictionary   *fattrs;
    BOOL           isDir;
    NSString       *fp;

    while ((entry = [e nextObject]) != nil) {
      fp = [path stringByAppendingPathComponent:entry];
      fattrs = [fm fileAttributesAtPath:fp traverseLink:YES];

      if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory]) {
        [dirs addObject:entry];
      }
      else {
        [files addObject:entry];
      }
    }

    // Empty dirContents
    [dirContents removeAllObjects];

    // Add sorted directories
    [dirs sortUsingSelector:compareSelector];
    [dirContents addObjectsFromArray:dirs];
    [dirs release];

    // Add sorted files
    [files sortUsingSelector:compareSelector];
    [dirContents addObjectsFromArray:files];
    [files release];
  }
  else {
    [dirContents sortUsingSelector:compareSelector];
  }

  return AUTORELEASE(dirContents);
}

// --- Search path
- (NSArray *)executablesForSubstring:(NSString *)substring
{
  NSString       *envPath;
  NSArray        *searchPaths;
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  NSArray        *dirContents;
  NSString       *absPath;
  BOOL           isDir;
  
  envPath = [[[NSProcessInfo processInfo] environment] objectForKey:@"PATH"];
  searchPaths = [NSArray
                  arrayWithArray:[envPath componentsSeparatedByString:@":"]];
  
  for (NSString *dir in searchPaths) {
    dirContents = [self directoryContentsAtPath:dir];
    for (NSString *file in dirContents) {
      if ([file rangeOfString:substring].location == 0) {
        absPath = [dir stringByAppendingPathComponent:file];
        if ([self isExecutableFileAtPath:absPath]) {
          [variants addObject:absPath];
        }
      }
    }
  }

  return [variants autorelease];
}

- (NSArray *)completionForPath:(NSString *)path
                    isAbsolute:(BOOL)isAbsolute
{
  NSMutableArray *variants = [[NSMutableArray alloc] init];
  NXTFileManager *fm = [NXTFileManager defaultManager];
  NSArray        *dirContents;
  NSString       *pathBase, *absPath;
  BOOL           isDir;

  path = [fm absolutePathForPath:path];
  if (path != nil) {
    pathBase = [NSString stringWithString:path];

    // Do filesystem scan
    while ([fm fileExistsAtPath:pathBase isDirectory:&isDir] == NO) {
      pathBase = [pathBase stringByDeletingLastPathComponent];
    }
    dirContents = [self directoryContentsAtPath:pathBase
                                        forPath:nil
                                     showHidden:YES];
    for (NSString *file in dirContents) {
      absPath = [pathBase stringByAppendingPathComponent:file];
      if ([absPath rangeOfString:path].location == 0) {
        if (isAbsolute != NO) {
          [variants addObject:absPath];
        }
        else {
          [variants addObject:[absPath lastPathComponent]];
        }
      }
    }
  }

  return [variants autorelease];
}

- (NSString *)absolutePathForPath:(NSString *)path
{
  const char *c_t;
  NSString   *absPath = nil;

  if (!path || [path length] == 0 || [path isEqualToString:@""]) {
    return nil;
  }

  c_t = [path cString];
  if (c_t[0] == '/') {
    absPath = path;
  }
  else if (c_t[0] == '~') {
    absPath = [path stringByReplacingCharactersInRange:NSMakeRange(0,1)
                                            withString:NSHomeDirectory()];
  }
  else if (([path length] > 1) && (c_t[0] == '.' && c_t[1] == '/')) {
    absPath = [path stringByReplacingCharactersInRange:NSMakeRange(0,2)
                                            withString:NSHomeDirectory()];
  }

  return absPath;
}

- (NSString *)absolutePathForCommand:(NSString *)command
{
  NSString *commandFile;
  NSString *envPath;

  if ([command isAbsolutePath]) {
    return command;
  }

  commandFile = [[command componentsSeparatedByString:@" "] objectAtIndex:0];
  envPath = [NSString stringWithCString:getenv("PATH")];

  for (NSString *path in [envPath componentsSeparatedByString:@":"]) {
    if ([[self directoryContentsAtPath:path] containsObject:commandFile]) {
      return [path stringByAppendingPathComponent:commandFile];
    }
  }

  return nil;
}

- (BOOL)directoryExistsAtPath:(NSString *)path
{
  BOOL isDir, isExist;

  isExist = [self fileExistsAtPath:path isDirectory:&isDir];

  return (isExist && isDir);
}


// --- Files (libmagic)
- (NSString *)mimeTypeForFile:(NSString *)fullPath
{
  magic_t    cookie;
  const char *mime_type;
  NSString   *mimeType;
  
  cookie = magic_open(MAGIC_MIME_TYPE);
  magic_load(cookie, NULL);

  mime_type = magic_file(cookie, [fullPath cString]);
  
  mimeType = [NSString stringWithCString:mime_type];

  magic_close(cookie);

  return mimeType;
}

- (NSString *)mimeEncodingForFile:(NSString *)fullPath
{
  magic_t    cookie;
  const char *mime_enc;
  NSString   *mimeEncoding;
  
  cookie = magic_open(MAGIC_MIME_ENCODING);
  magic_load(cookie, NULL);

  mime_enc = magic_file(cookie, [fullPath cString]);
  
  mimeEncoding = [NSString stringWithCString:mime_enc];

  magic_close(cookie);

  return mimeEncoding;
}

- (NSString *)descriptionForFile:(NSString *)fullPath
{
  magic_t    cookie;
  const char *description;
  NSString   *fileDescription;
  
  cookie = magic_open(MAGIC_NONE);
  magic_load(cookie, NULL);

  description = magic_file(cookie, [fullPath cString]);
  
  fileDescription = [NSString stringWithCString:description];
  
  magic_close(cookie);

  return fileDescription;
}

@end
