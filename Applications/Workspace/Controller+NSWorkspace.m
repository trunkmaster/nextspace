/*
   Copied from NSWorkspace.h

   Interface to Workspace Manager application.
   Workspace Manager application can by set by command:

   > defaults write NSGlobalDomain GSWorkspaceApplication <name of app>

   Copyright (C) 1996-2002 Free Software Foundation, Inc.

   Author:  Scott Christley <scottc@net-community.com>
   Date: 1996

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; see the file COPYING.LIB.
   If not, see <http://www.gnu.org/licenses/> or write to the
   Free Software Foundation, 51 Franklin Street, Fifth Floor,
   Boston, MA 02110-1301, USA.
*/

#include <sys/mount.h>
#include <sys/param.h>
#include <sys/types.h>
#include <unistd.h>

#import <AppKit/AppKit.h>
#import <Foundation/Foundation.h>
#import <GNUstepGUI/GSDisplayServer.h>

#import <SystemKit/OSEDefaults.h>
#import <SystemKit/OSEFileManager.h>
#import <SystemKit/OSEUDisksAdaptor.h>
#import <SystemKit/OSEUDisksDrive.h>
#import <SystemKit/OSEUDisksVolume.h>

#import <DesktopKit/NXTAlert.h>

#import "Viewers/FileViewer.h"
#import "WMNotificationCenter.h"
#import "Processes/ProcessManager.h"
#import "Workspace+WM.h"
#import "Controller+NSWorkspace.h"

#define PosixExecutePermission (0111)

#define FILE_CONTENTS_SCAN_SIZE 100

static NSMutableDictionary *folderPathIconDict = nil;
static NSMutableDictionary *folderIconCache = nil;

static NSImage *folderImage = nil;
static NSImage *multipleFiles = nil;
static NSImage *unknownApplication = nil;
static NSImage *unknownTool = nil;
static NSString *_rootPath = @"/";

//-------------------------------------------------------------------------------------------------
// Workspace private methods
//-------------------------------------------------------------------------------------------------

@interface Controller (NSWorkspacePrivate)

// Icon handling
- (NSImage *)_extIconForApp:(NSString *)appName info:(NSDictionary *)extInfo;
- (NSImage *)_unknownFiletypeImage;
- (NSImage *)_imageFromFile:(NSString *)iconPath;
- (NSImage *)_iconForExtension:(NSString *)ext;
- (NSImage *)_iconForFileContents:(NSString *)fullPath;
- (BOOL)_extension:(NSString *)ext role:(NSString *)role app:(NSString **)app;

- (NSString *)_getBestIconForExtension:(NSString *)ext;
- (NSBundle *)_bundleForApp:(NSString *)appName;
- (NSImage *)_appIconForApp:(NSString *)appName;
- (NSString *)_locateApplicationBinary:(NSString *)appName;
- (void)_setBestIcon:(NSString *)iconPath forExtension:(NSString *)ext;

// Preferences
// - (void)_workspacePreferencesChanged:(NSNotification *)aNotification;

// application communication
- (BOOL)_launchApplication:(NSString *)appName arguments:(NSArray *)args;
- (id)_connectApplication:(NSString *)appName;
- (NSDictionary *)_bundleInfoForApp:(NSString *)appName;

@end

//-------------------------------------------------------------------------------------------------
// Workspace OPENSTEP methods
//-------------------------------------------------------------------------------------------------
@implementation Controller (NSWorkspace)

//-------------------------------------------------------------------------------------------------
//--- Creating a Workspace
//-------------------------------------------------------------------------------------------------
- (void)initPrefs
{
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSString *service;
  NSArray *libraryDirs;
  NSData *data;
  NSDictionary *dict;

  libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
  service = [[libraryDirs objectAtIndex:0] stringByAppendingPathComponent:@"Services"];

  // Load file extension preferences.
  _extPreferencesPath = [service stringByAppendingPathComponent:@".GNUstepExtPrefs"];
  RETAIN(_extPreferencesPath);
  if ([mgr isReadableFileAtPath:_extPreferencesPath] == YES) {
    data = [NSData dataWithContentsOfFile:_extPreferencesPath];
    if (data) {
      dict = [NSDeserializer deserializePropertyListFromData:data mutableContainers:NO];
      _extPreferences = RETAIN(dict);
    }
    [[self fileSystemMonitor] addPath:_extPreferencesPath];
  }

  // Load cached application information.
  _appListPath = [service stringByAppendingPathComponent:@".GNUstepAppList"];
  RETAIN(_appListPath);
  if ([mgr isReadableFileAtPath:_appListPath] == YES) {
    data = [NSData dataWithContentsOfFile:_appListPath];
    if (data) {
      dict = [NSDeserializer deserializePropertyListFromData:data mutableContainers:NO];
      _appList = RETAIN(dict);
    }
    [[self fileSystemMonitor] addPath:_appListPath];
  }

  _appDirs = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, YES);
  [_appDirs retain];
  for (NSString *dirPath in _appDirs) {
    // NSLog(@"Directory `%@` will be added to filesystem monitor.", dirPath);
    [[self fileSystemMonitor] addPath:dirPath];
  }
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_fileSystemPathChanged:)
                                               name:OSEFileSystemChangedAtPath
                                             object:nil];
}

// NEXTSPACE
- (id)initNSWorkspace
{
  NSArray *sysAppDir;
  NSString *sysDir;
  int i;

  [self initPrefs];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(noteUserDefaultsChanged)
                                               name:NSUserDefaultsDidChangeNotification
                                             object:nil];

  _iconMap = [NSMutableDictionary new];
  _launched = [NSMutableDictionary new];
  if (_appList == nil) {
    [self findApplications];
  }

  /* icon association and caching */
  folderPathIconDict = [[NSMutableDictionary alloc] initWithCapacity:5];

  sysAppDir = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSSystemDomainMask, YES);

  /* we try to guess a System directory and check if looks like one */
  sysDir = nil;
  if ([sysAppDir count] > 0) {
    sysDir = [[sysAppDir objectAtIndex:0] stringByDeletingLastPathComponent];
    if (![[sysDir lastPathComponent] isEqualToString:@"System"]) {
      sysDir = nil;
    }
  }
  if (sysDir != nil) {
    [folderPathIconDict setObject:@"NXFolder" forKey:sysDir];
  }

  [folderPathIconDict setObject:@"NXHomeDirectory" forKey:NSHomeDirectory()];
  [folderPathIconDict setObject:@"NXRoot" forKey:_rootPath];
  folderIconCache = [[NSMutableDictionary alloc] init];

  // list of extensions of wrappers (will be shown as plain file in Workspace)
  _wrappers = [@"(bundle, preferences, inspector, service)" propertyList];
  [_wrappers retain];
  // NSDebugLLog(@"NSWorkspace", @"Wrappers list: %@(0=%@)", wrappers, [wrappers objectAtIndex:0]);

  return self;
}

//-------------------------------------------------------------------------------------------------
//--- Opening Files
//-------------------------------------------------------------------------------------------------
- (BOOL)openFile:(NSString *)fullPath
{
  return [self openFile:fullPath withApplication:nil andDeactivate:YES];
}

- (BOOL)openFile:(NSString *)fullPath withApplication:(NSString *)appName
{
  return [self openFile:fullPath withApplication:appName andDeactivate:YES];
}

// NEXTSPACE modifications
- (BOOL)openFile:(NSString *)fullPath withApplication:(NSString *)appName andDeactivate:(BOOL)flag
{
  id app;

  if (appName == nil) {
    return [self openFile:fullPath fromImage:nil at:NSZeroPoint inView:nil];
  }

  if (flag != NO) {
    [NSApp deactivate];
  }

  app = [self _connectApplication:appName];
  if (app == nil) {
    return [self _launchApplication:appName
                          arguments:@[ @"-GSFilePath", fullPath, @"-autolaunch", @"YES" ]];
  } else {
    @try {
      if (flag == NO) {
        [app application:NSApp openFileWithoutUI:fullPath];
      } else {
        [app application:NSApp openFile:fullPath];
      }
    } @catch (NSException *e) {
      NSWarnLog(@"Failed to contact '%@' to open file", appName);
      NXTRunAlertPanel(_(@"Workspace"), _(@"Failed to contact app '%@' to open file."), nil, nil,
                       nil, appName);
      return NO;
    }
  }

  return YES;
}

- (BOOL)openTempFile:(NSString *)fullPath
{
  id app;
  NSString *appName;
  NSString *ext;

  ext = [fullPath pathExtension];
  if ([self _extension:ext role:nil app:&appName] == NO) {
    appName = [[OSEDefaults userDefaults] objectForKey:@"DefaultEditor"];
  }

  app = [self _connectApplication:appName];
  if (app == nil) {
    return [self _launchApplication:appName arguments:@[ @"-GSTempPath", fullPath ]];
  } else {
    @try {
      [app application:NSApp openTempFile:fullPath];
    } @catch (NSException *e) {
      NSWarnLog(@"Failed to open temporary file '%@' with application '%@'!", fullPath, appName);
      return NO;
    }
  }

  [NSApp deactivate];

  return YES;
}

// NEXTSPACE modification - calls Window Manager functions
// `raceLock` used to prevent condition on multiple files opening
static NSLock *raceLock = nil;
- (BOOL)openFile:(NSString *)fullPath
       fromImage:(NSImage *)anImage
              at:(NSPoint)point
          inView:(NSView *)aView
{
  NSString *fileType = nil, *appName = nil;
  NSPoint destPoint = {0, 0};
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *fattrs = nil;

  if (![fm fileExistsAtPath:fullPath]) {
    NXTRunAlertPanel(_(@"Workspace"), _(@"File '%@' does not exist!"), nil, nil, nil,
                     [fullPath lastPathComponent]);
    return NO;
  }

  // Sliding coordinates
  point = [[aView window] convertBaseToScreen:[aView convertPoint:point toView:nil]];

  // Get file type and application name
  [self getInfoForFile:fullPath application:&appName type:&fileType];

  NSDebugLLog(@"Workspace", @"[Workspace] openFile: type '%@' with app: %@", fileType, appName);

  if (!raceLock) {
    raceLock = [NSLock new];
  }

  if ([fileType isEqualToString:NSApplicationFileType]) {
    // .app should be launched
    NSDictionary *appInfo;

    // Don't launch ourself and Login panel
    if ([appName isEqualToString:@"Workspace"] || [appName isEqualToString:@"Login"]) {
      return YES;
    }

    appInfo = [self _bundleInfoForApp:fullPath];
    if (appInfo) {
      [raceLock lock];
      wLaunchingAppIconCreate([appInfo[@"WMName"] cString], [appInfo[@"WMClass"] cString],
                              [appInfo[@"LaunchPath"] cString], point.x, point.y,
                              [appInfo[@"IconPath"] cString]);
      [raceLock unlock];

      if ([self launchApplication:fullPath] == NO) {
        NXTRunAlertPanel(_(@"Workspace"), _(@"Failed to start application \"%@\""), nil, nil, nil,
                         appName);
      } else {
        return YES;
      }
    }
  } else if ([fileType isEqualToString:NSDirectoryFileType] ||
             [fileType isEqualToString:NSFilesystemFileType] ||
             [_wrappers containsObject:[fullPath pathExtension]]) {
    // Open new FileViewer window
    [self openNewViewerIfNotExistRootedAt:fullPath];
    return YES;
  } else if (appName) {
    // .app found for opening file type
    NSDictionary *appInfo;

    appInfo = [self _bundleInfoForApp:appName];
    if (appInfo) {
      [raceLock lock];
      wLaunchingAppIconCreate([appInfo[@"WMName"] cString], [appInfo[@"WMClass"] cString],
                              [appInfo[@"LaunchPath"] cString], point.x, point.y,
                              [appInfo[@"IconPath"] cString]);
      [raceLock unlock];

      if ([self openFile:fullPath withApplication:appName andDeactivate:YES] == NO) {
        NXTRunAlertPanel(_(@"Workspace"), _(@"Failed to start application \"%@\" for file \"%@\""),
                         nil, nil, nil, appName, [fullPath lastPathComponent]);
      } else {
        // If multiple files are opened at once we need to wait for app to start.
        // Otherwise two copies of one application become alive.
        if ([appInfo[@"WMClass"] isEqualToString:@"GNUstep"]) {
          return ([self _connectApplication:appName] == nil) ? NO : YES;
        } else {
          return YES;
        }
      }
    }
  }

  return NO;
}

//-------------------------------------------------------------------------------------------------
//--- Manipulating Files
//-------------------------------------------------------------------------------------------------
// Operation types supported by ProcessManager: Copy, Duplicate, Move, Link, Delete, Recycle
- (BOOL)performFileOperation:(NSString *)operation
                      source:(NSString *)source
                 destination:(NSString *)destination
                       files:(NSArray *)files
                         tag:(int *)tag
{
  OperationType opType = 0;

  if ([operation isEqualToString:NSWorkspaceCopyOperation]) {
    opType = CopyOperation;
  } else if ([operation isEqualToString:NSWorkspaceDuplicateOperation]) {
    opType = DuplicateOperation;
  } else if ([operation isEqualToString:NSWorkspaceMoveOperation]) {
    opType = MoveOperation;
  } else if ([operation isEqualToString:NSWorkspaceLinkOperation]) {
    opType = LinkOperation;
  } else if ([operation isEqualToString:NSWorkspaceDestroyOperation]) {
    opType = DeleteOperation;
  } else if ([operation isEqualToString:NSWorkspaceRecycleOperation]) {
    opType = RecycleOperation;
  } /*else if ([operation isEqualToString:NSWorkspaceCompressOperation]) {
    opType = ;
  } else if ([operation isEqualToString:NSWorkspaceDecompressOperation]) {
    opType = ;
  } else if ([operation isEqualToString:NSWorkspaceEncryptOperation]) {
    opType = ;
  } else if ([operation isEqualToString:NSWorkspaceDecryptOperation]) {
    opType = ;
  }*/

  if (opType) {
    id operation = [procManager startOperationWithType:opType
                                                source:source
                                                target:destination
                                                 files:files];
    if (operation) {
      NSNumber *opHash = [NSNumber numberWithUnsignedInteger:[operation hash]];
      *tag = [opHash intValue];
      return YES;
    } else {
      return NO;
    }
  }
  return NO;
}

// From OpenUp:
// [[NSWorkspace sharedWorkspace] selectFile:archivePath
//                  inFileViewerRootedAtPath:[archivePath stringByDeletingLastPathComponent]];
- (BOOL)selectFile:(NSString *)fullPath inFileViewerRootedAtPath:(NSString *)rootFullpath
{
  FileViewer *fv;

  if (!fullPath || fullPath.length == 0) {
    return NO;
  }

  if (rootFullpath && rootFullpath.length > 0) {
    fv = [self newViewerRootedAt:rootFullpath
                          viewer:[[OSEDefaults userDefaults] objectForKey:@"PreferredViewer"]
                          isRoot:NO];
    if (fv) {
      if ([rootFullpath isEqualToString:fullPath]) {
        [fv displayPath:@"/" selection:nil sender:self];
      } else {
        [fv displayPath:@"/" selection:@[ fullPath.lastPathComponent ] sender:self];
      }
    }
  } else {
    fv = [self rootViewer];
    [fv displayPath:fullPath.stringByDeletingLastPathComponent
          selection:@[ fullPath.lastPathComponent ]
             sender:self];
  }

  if (fv) {
    [[fv window] makeKeyAndOrderFront:self];
    return YES;
  }

  return NO;
}

- (BOOL)getFileSystemInfoForPath:(NSString *)fullPath
                     isRemovable:(BOOL *)removableFlag
                      isWritable:(BOOL *)writableFlag
                   isUnmountable:(BOOL *)unmountableFlag
                     description:(NSString **)description
                            type:(NSString **)fileSystemType
{
  OSEUDisksAdaptor *uda = [OSEUDisksAdaptor new];
  OSEUDisksVolume *volume = [uda mountedVolumeForPath:fullPath];
  OSEUDisksDrive *drive = [volume drive];

  if (volume == nil) {
    return NO;
  }

  if (drive == nil) {
    return NO;
  }

  *removableFlag = drive.isRemovable;
  *writableFlag = volume.isWritable;
  *unmountableFlag = !volume.isSystem;

  switch (volume.filesystemType) {
    case NXTFSTypeEXT:
      *fileSystemType = @"EXT";
      break;
    case NXTFSTypeXFS:
      *fileSystemType = @"XFS";
      break;
    case NXTFSTypeFAT:
      *fileSystemType = @"FAT";
      break;
    case NXTFSTypeISO:
      *fileSystemType = @"ISO";
      break;
    case NXTFSTypeNTFS:
      *fileSystemType = @"NTFS";
      break;
    case NXTFSTypeSwap:
      *fileSystemType = @"SWAP";
      break;
    case NXTFSTypeUDF:
      *fileSystemType = @"UDF";
      break;
    case NXTFSTypeUFS:
      *fileSystemType = @"UFS";
      break;
    default:
      *fileSystemType = @"UNKNOWN";
  }

  *description = [NSString stringWithFormat:@"%@ %@ filesystem at %@ drive",
                                            (volume.isWritable ? @"Writable" : @"Readonly"),
                                            *fileSystemType, drive.humanReadableName];
  [uda release];

  return YES;
}

- (BOOL)getInfoForFile:(NSString *)fullPath application:(NSString **)appName type:(NSString **)type
{
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *attributes;
  NSString *fileType;
  NSString *extension = [fullPath pathExtension];

  attributes = [fm fileAttributesAtPath:fullPath traverseLink:YES];

  if (attributes != nil) {
    // application
    [self _extension:extension role:nil app:appName];

    // file type
    fileType = [attributes fileType];
    if ([fileType isEqualToString:NSFileTypeRegular]) {
      if ([attributes filePosixPermissions] & PosixExecutePermission) {
        *type = NSShellCommandFileType;
        *appName = @"Terminal";
      } else {
        *type = NSPlainFileType;
      }
      if (*appName == nil) {
        [self _extension:@"" role:nil app:appName];
      }
    } else if ([fileType isEqualToString:NSFileTypeDirectory]) {
      if ([extension isEqualToString:@"app"] || [extension isEqualToString:@"debug"] ||
          [extension isEqualToString:@"profile"]) {
        *type = NSApplicationFileType;
      } else if ([_wrappers containsObject:extension]) {
        *type = NSPlainFileType;
      } else if (*appName != nil && [extension length] > 0) {
        *type = NSPlainFileType;
      }
      // The idea here is that if the parent directory's
      // fileSystemNumber differs, this must be a filesystem mount point.
      else if ([[fm fileAttributesAtPath:[fullPath stringByDeletingLastPathComponent]
                            traverseLink:YES] fileSystemNumber] != [attributes fileSystemNumber]) {
        *type = NSFilesystemFileType;
        *appName = nil;
      } else {
        *type = NSDirectoryFileType;
        *appName = nil;
      }
    } else {
      // This catches sockets, character special, block special, symblic links and unknown file
      // types
      *type = NSPlainFileType;
      *appName = nil;
    }
    return YES;
  } else {
    *appName = nil;
    *type = nil;
    return NO;
  }
}

// NEXTSPACE changes
- (NSImage *)iconForFile:(NSString *)fullPath
{
  NSImage *image = nil;
  NSString *pathExtension = [[fullPath pathExtension] lowercaseString];
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSDictionary *attributes;
  NSString *fileType;
  NSString *wmFileType, *appName;
  NSArray *searchPath;

  attributes = [fileManager fileAttributesAtPath:fullPath traverseLink:YES];
  fileType = [attributes objectForKey:NSFileType];
  // NSLog(@"(NSWorkspace-iconForFile): %@, file type: %@, extension: %@", fullPath, fileType,
  //       pathExtension);
  if (([fileType isEqual:NSFileTypeDirectory] == YES) &&
      [fileManager isReadableFileAtPath:fullPath] == NO) {
    image = [NSImage imageNamed:@"badFolder"];
  } else if ([fileType isEqual:NSFileTypeDirectory] == YES) {
    NSString *iconPath = nil;

    // Mount point
    [self getInfoForFile:fullPath application:&appName type:&wmFileType];
    if ([wmFileType isEqualToString:NSFilesystemFileType]) {
      NXTFSType fsType;

      fsType = [[OSEMediaManager defaultManager] filesystemTypeAtPath:fullPath];
      if (fsType == NXTFSTypeFAT) {
        image = [NSImage imageNamed:@"DOS_FD.fs"];
      } else if (fsType == NXTFSTypeISO) {
        image = [NSImage imageNamed:@"CDROM.fs"];
      } else if (fsType == NXTFSTypeNTFS) {
        image = [NSImage imageNamed:@"NTFS_HDD.fs"];
      } else {
        image = [NSImage imageNamed:@"HDD.fs"];
      }
    }

    // Application
    if ([pathExtension isEqualToString:@"app"] || [pathExtension isEqualToString:@"debug"] ||
        [pathExtension isEqualToString:@"profile"]) {
      image = [self _appIconForApp:fullPath];

      if (image == nil) {
        image = [NSImage _standardImageWithName:@"NXApplication"];
      }
    } else if ([_wrappers containsObject:pathExtension] != NO) {
      image = [NSImage imageNamed:@"bundle"];
    }

    // Users home directory (/Users)
    searchPath = NSSearchPathForDirectoriesInDomains(NSUserDirectory, NSSystemDomainMask, YES);
    if ([searchPath count] > 0 && [fullPath isEqualToString:[searchPath objectAtIndex:0]]) {
      image = [NSImage imageNamed:@"neighbor"];
    }

    // Directory icon '.dir.tiff', '.dir.png'
    if (iconPath == nil) {
      iconPath = [fullPath stringByAppendingPathComponent:@".dir.png"];
      if ([fileManager isReadableFileAtPath:iconPath] == NO) {
        iconPath = [fullPath stringByAppendingPathComponent:@".dir.tiff"];
        if ([fileManager isReadableFileAtPath:iconPath] == NO) {
          iconPath = nil;
        }
      }
      // Directory icon path found - get icon
      if (iconPath != nil) {
        image = [self _imageFromFile:iconPath];
      }
    }

    // It's not mount point, not bundle, not user homes,
    // folder doesn't contain dir icon
    if (image == nil) {
      image = [self _iconForExtension:pathExtension];
      if (image == nil || image == [self _unknownFiletypeImage]) {
        NSString *iconName;

        iconName = [folderPathIconDict objectForKey:fullPath];
        if (iconName != nil) {
          NSImage *iconImage;

          iconImage = [folderIconCache objectForKey:iconName];
          if (iconImage == nil) {
            iconImage = [NSImage _standardImageWithName:iconName];
            /* the dictionary retains the image */
            [folderIconCache setObject:iconImage forKey:iconName];
          }
          image = iconImage;
        } else {
          if (folderImage == nil) {
            folderImage = RETAIN([NSImage _standardImageWithName:@"NXFolder"]);
          }
          image = folderImage;
        }
      }
    }
  } else if ([fileManager isReadableFileAtPath:fullPath] == YES) {
    // NSFileTypeRegular, NSFileType
    NSDebugLog(@"pathExtension is '%@'", pathExtension);

    // By extension
    if (image == nil) {
      image = [self _iconForExtension:pathExtension];
    }

    // By file contents
    if (image == nil || image == [self _unknownFiletypeImage]) {
      image = [self _iconForFileContents:fullPath];
    }

    // By executable bit
    if (image == nil && ([fileType isEqual:NSFileTypeRegular] == YES) &&
        ([fileManager isExecutableFileAtPath:fullPath] == YES)) {
      if (unknownTool == nil) {
        unknownTool = RETAIN([NSImage _standardImageWithName:@"NXTool"]);
      }
      image = unknownTool;
    }

  } else if ([fileManager isReadableFileAtPath:fullPath] == NO) {
    image = [NSImage imageNamed:@"badFile"];
  }

  if (image == nil) {
    image = [self _unknownFiletypeImage];
  }

  return image;
}

- (NSImage *)iconForFiles:(NSArray *)pathArray
{
  if ([pathArray count] == 1) {
    return [self iconForFile:[pathArray firstObject]];
  }
  if (multipleFiles == nil) {
    multipleFiles = [NSImage imageNamed:@"MultipleSelection"];
  }

  return multipleFiles;
}

- (NSImage *)iconForFileType:(NSString *)fileType
{
  return [self _iconForExtension:fileType];
}

// NEXTSPACE addon
- (NSImage *)iconForOpenedDirectory:(NSString *)fullPath
{
  NSString *appName, *fileType;
  NSString *openDirIconPath;
  NSString *usersDir;
  NSImage *icon;

  [self getInfoForFile:fullPath application:&appName type:&fileType];

  usersDir = [GNUstepConfig(nil) objectForKey:@"GNUSTEP_SYSTEM_USERS_DIR"];

  openDirIconPath = [fullPath stringByAppendingPathComponent:@".opendir.tiff"];

  if ([[NSFileManager defaultManager] fileExistsAtPath:openDirIconPath]) {
    return [[[NSImage alloc] initByReferencingFile:openDirIconPath] autorelease];
  } else if ([fileType isEqualToString:NSFilesystemFileType]) {
    NXTFSType fsType;

    fsType = [[OSEMediaManager defaultManager] filesystemTypeAtPath:fullPath];
    if (fsType == NXTFSTypeFAT) {
      return [NSImage imageNamed:@"DOS_FD.openfs"];
    } else if (fsType == NXTFSTypeISO) {
      return [NSImage imageNamed:@"CDROM.openfs"];
    }
    return [NSImage imageNamed:@"HDD.openfs"];
  } else if ([fileType isEqualToString:NSPlainFileType]) {  // e.g. .gorm
    return [self iconForFile:fullPath];
  } else if ([fullPath isEqualToString:@"/"]) {
    return [NSImage imageNamed:@"openRoot"];
  } else if ([fullPath isEqualToString:usersDir]) {
    return [NSImage imageNamed:@"openNeighbor"];
  } else if ([fullPath isEqualToString:NSHomeDirectory()]) {
    return [NSImage imageNamed:@"openHome"];
  } else if ([fileType isEqualToString:NSDirectoryFileType]) {
    return [NSImage imageNamed:@"openFolder"];
  }

  return [self iconForFile:fullPath];
}

- (NSDictionary *)applicationsForExtension:(NSString *)ext
{
  NSDictionary *map;

  ext = [ext lowercaseString];
  map = [_appList objectForKey:@"GSExtensionsMap"];
  return [map objectForKey:ext];
}

//-------------------------------------------------------------------------------------------------
//--- Tracking Changes to the File System
//-------------------------------------------------------------------------------------------------
- (BOOL)fileSystemChanged
{
  BOOL flag = _fileSystemChanged;

  _fileSystemChanged = NO;
  return flag;
}

- (void)noteFileSystemChanged
{
  _fileSystemChanged = YES;
}

//-------------------------------------------------------------------------------------------------
//--- Updating Registered Services and File Types
//-------------------------------------------------------------------------------------------------
- (void)findApplications
{
  static NSString *path = nil;
  NSTask *task;

  // Try to locate and run an executable copy of 'make_services'
  if (path == nil) {
    path = [[NSTask launchPathForTool:@"make_services"] retain];
  }
  if (path != nil) {
    task = [NSTask launchedTaskWithLaunchPath:path arguments:nil];
    if (task != nil) {
      [task waitUntilExit];
    }
  }
}

//-------------------------------------------------------------------------------------------------
//--- Launching and Manipulating Applications
//-------------------------------------------------------------------------------------------------

- (void)hideOtherApplications
{
  Window xWindow = (Window)[GSCurrentServer() windowDevice:[[NSApp keyWindow] windowNumber]];
  NSDictionary *info =
      @{@"WindowID" : [NSNumber numberWithUnsignedLong:xWindow], @"ApplicationName" : @"Workspace"};

  [[NSDistributedNotificationCenter defaultCenter]
      postNotificationName:CF_NOTIFICATION(WMShouldHideOthersNotification)
                    object:@"GSWorkspaceNotification"
                  userInfo:info];
}

- (BOOL)launchApplication:(NSString *)appName
{
  return [self launchApplication:appName showIcon:YES autolaunch:NO];
}

- (BOOL)launchApplication:(NSString *)appName showIcon:(BOOL)showIcon autolaunch:(BOOL)autolaunch
{
  id app = [self _connectApplication:appName];
  if (app == nil) {
    NSArray *args = (autolaunch != NO) ? @[ @"-autolaunch", @"YES" ] : nil;

    return [self _launchApplication:appName arguments:args];
  } else {
    [app activateIgnoringOtherApps:YES];
  }

  return YES;
}

- (NSDictionary *)activeApplication
{
  return [[ProcessManager shared] activeApplication];
}

- (NSArray *)launchedApplications
{
  return [[ProcessManager shared] applications];
}

- (NSString *)fullPathForApplication:(NSString *)appName
{
  NSString *appPath;
  NSString *appExt;
  NSFileManager *fm;
  BOOL isDir;

  if (appName == nil || [appName length] == 0) {
    return nil;
  }

  if ([appName isAbsolutePath] != NO) {
    return appName;
  }

  fm = [NSFileManager defaultManager];
  appExt = [appName pathExtension];

  for (NSString *appDir in _appDirs) {
    appPath = [appDir stringByAppendingPathComponent:appName];

    if (appExt == nil || [appExt length] == 0) {  // no extension, let's find one
      appPath =
          [appDir stringByAppendingPathComponent:[appName stringByAppendingPathExtension:@"app"]];
      if ([fm fileExistsAtPath:appPath isDirectory:&isDir] == NO || isDir == NO) {
        appPath = [appDir
            stringByAppendingPathComponent:[appName stringByAppendingPathExtension:@"debug"]];
        if ([fm fileExistsAtPath:appPath isDirectory:&isDir] == NO || isDir == NO) {
          appPath = [appDir
              stringByAppendingPathComponent:[appName stringByAppendingPathExtension:@"profile"]];
        }
      }
    }

    if ([fm fileExistsAtPath:appPath isDirectory:&isDir] != NO && isDir != NO) {
      break;
    } else {
      appPath = nil;
    }
  }

  return appPath;
}

/**
 * Sets up a user preference for which app should be used to open files
 * of the specified extension.
 */
- (void)setBestApp:(NSString *)appName inRole:(NSString *)role forExtension:(NSString *)ext
{
  NSMutableDictionary *map;
  NSMutableDictionary *inf;
  NSData *data;

  ext = [ext lowercaseString];
  if (_extPreferences != nil) {
    map = [_extPreferences mutableCopy];
  } else {
    map = [NSMutableDictionary new];
  }

  inf = [[map objectForKey:ext] mutableCopy];
  if (inf == nil) {
    inf = [NSMutableDictionary new];
  }
  if (appName == nil) {
    if (role == nil) {
      NSString *iconPath = [inf objectForKey:@"Icon"];

      RETAIN(iconPath);
      [inf removeAllObjects];
      if (iconPath) {
        [inf setObject:iconPath forKey:@"Icon"];
        RELEASE(iconPath);
      }
    } else {
      [inf removeObjectForKey:role];
    }
  } else {
    [inf setObject:appName forKey:(role ? (id)role : (id) @"Editor")];
  }
  [map setObject:inf forKey:ext];
  RELEASE(inf);
  RELEASE(_extPreferences);
  _extPreferences = map;
  data = [NSSerializer serializePropertyList:_extPreferences];
  if ([data writeToFile:_extPreferencesPath atomically:YES]) {
    // [NSNotificationCenter defaultCenter] postNotificationName:GSWorkspacePreferencesChanged
    //                                 object:self];
  } else {
    NSDebugLLog(@"Workspace", @"Update %@ of failed", _extPreferencesPath);
  }
}

//-------------------------------------------------------------------------------------------------
//--- Unmounting a Device
//-------------------------------------------------------------------------------------------------

- (BOOL)unmountAndEjectDeviceAtPath:(NSString *)path
{
  [[OSEMediaManager defaultManager] unmountAndEjectDeviceAtPath:path];
  return YES;
}

//-------------------------------------------------------------------------------------------------
//--- Tracking Status Changes for Devices
//-------------------------------------------------------------------------------------------------

- (void)checkForRemovableMedia
{
  [mediaAdaptor checkForRemovableMedia];
}

- (NSArray *)mountNewRemovableMedia
{
  return [mediaAdaptor mountNewRemovableMedia];
}

- (NSArray *)mountedRemovableMedia
{
  return [mediaAdaptor mountedRemovableMedia];
}

//-------------------------------------------------------------------------------------------------
//--- Notification Center
//-------------------------------------------------------------------------------------------------

- (NSNotificationCenter *)notificationCenter
{
  return _windowManagerCenter;
}

//-------------------------------------------------------------------------------------------------
//--- Tracking Changes to the User Defaults Database
//-------------------------------------------------------------------------------------------------
/**
 * Simply makes a note that the user defaults database has changed.
 */
- (void)noteUserDefaultsChanged
{
  _userDefaultsChanged = YES;
}

/**
 * Returns a flag to say if the defaults database has changed since
 * the last time this method was called.
 */
- (BOOL)userDefaultsChanged
{
  BOOL hasChanged = _userDefaultsChanged;

  _userDefaultsChanged = NO;
  return hasChanged;
}

//-------------------------------------------------------------------------------------------------
//--- Animating an Image
//-------------------------------------------------------------------------------------------------

- (void)slideImage:(NSImage *)image from:(NSPoint)fromPoint to:(NSPoint)toPoint
{
  [GSCurrentServer() slideImage:image from:fromPoint to:toPoint];
}

//-------------------------------------------------------------------------------------------------
//--- Requesting Additional Time before Power Off or Logout
// + Workspace sends NSWorkspaceWillPowerOffNotification
// + Wait for -extendPowerOffBy: for 1 second
// + Workspace checks if NSTimer is valid. If timer is vaild, wait for timer invalidation.
// + Workspace starts to -terminate: applications
//
// + -extendPowerOffBy: sets NSTimer for requested number of milliseconds.
//-------------------------------------------------------------------------------------------------
- (int)extendPowerOffBy:(int)requested
{
  if (powerOffTimeout <= 0) {
    powerOffTimeout = requested;
    powerOffTimer = [NSTimer scheduledTimerWithTimeInterval:(powerOffTimeout / 1000.0)
                                                    repeats:NO
                                                      block:^(NSTimer *timer) {
                                                        powerOffTimeout = 0;
                                                        [timer invalidate];
                                                        powerOffTimer = nil;
                                                        [NSApp abortModal];
                                                      }];
    [[NSRunLoop currentRunLoop] addTimer:powerOffTimer forMode:NSModalPanelRunLoopMode];
  }

  return powerOffTimeout;
}

@end

@implementation Controller (NSWorkspacePrivate)

//-------------------------------------------------------------------------------------------------
//--- Images and icons
//-------------------------------------------------------------------------------------------------
- (NSImage *)_extIconForApp:(NSString *)appName info:(NSDictionary *)extInfo
{
  NSDictionary *typeInfo = [extInfo objectForKey:appName];
  NSString *file = [typeInfo objectForKey:@"NSIcon"];

  /*
   * If the NSIcon entry isn't there and the CFBundle entries are,
   * get the first icon in the list if it's an array, or assign
   * the icon to file if it's a string.
   *
   * FIXME: CFBundleTypeExtensions/IconFile can be arrays which assign
   * multiple types to icons.  This needs to be handled eventually.
   */
  if (file == nil) {
    id icon = [typeInfo objectForKey:@"CFBundleTypeIconFile"];
    if ([icon isKindOfClass:[NSArray class]]) {
      if ([icon count]) {
        file = [icon objectAtIndex:0];
      }
    } else {
      file = icon;
    }
  }

  if (file && [file length] != 0) {
    if ([file isAbsolutePath] == NO) {
      NSString *iconPath;
      NSBundle *bundle;

      bundle = [self _bundleForApp:appName];
      iconPath = [bundle pathForImageResource:file];
      /*
       * If the icon is not in the Resources of the app, try looking
       * directly in the app wrapper.
       */
      if (iconPath == nil) {
        iconPath = [[bundle bundlePath] stringByAppendingPathComponent:file];
      }
      file = iconPath;
    }
    if ([[NSFileManager defaultManager] isReadableFileAtPath:file] == YES) {
      return [self _imageFromFile:file];
    }
  }
  return nil;
}

/** Returns the default icon to display for a file */
- (NSImage *)_unknownFiletypeImage
{
  static NSImage *image = nil;

  if (image == nil) {
    image = RETAIN([NSImage _standardImageWithName:@"NXUnknown"]);
  }

  return image;
}

/** Try to create the image in an exception handling context */
- (NSImage *)_imageFromFile:(NSString *)iconPath
{
  NSImage *tmp = nil;

  NS_DURING
  {
    tmp = [[NSImage alloc] initWithContentsOfFile:iconPath];
    if (tmp != nil) {
      AUTORELEASE(tmp);
    }
  }
  NS_HANDLER
  {
    NSLog(@"Bad or unsupported image file format '%@'", iconPath);
  }
  NS_ENDHANDLER

  return tmp;
}

- (NSImage *)_iconForExtension:(NSString *)ext
{
  NSImage *icon = nil;

  if (ext == nil || [ext isEqualToString:@""]) {
    return nil;
  }
  /*
   * extensions are case-insensitive - convert to lowercase.
   */
  ext = [ext lowercaseString];
  if ((icon = [_iconMap objectForKey:ext]) == nil) {
    NSDictionary *prefs;
    NSDictionary *extInfo;
    NSString *iconPath;

    /*
     * If there is a user-specified preference for an image -
     * try to use that one.
     */
    prefs = [_extPreferences objectForKey:ext];
    iconPath = [prefs objectForKey:@"Icon"];
    if (iconPath) {
      icon = [self _imageFromFile:iconPath];
    }

    if (icon == nil && (extInfo = [self applicationsForExtension:ext]) != nil) {
      NSString *appName;

      /*
       * If there are any application preferences given, try to use the
       * icon for this file that is used by the preferred app.
       */
      if (prefs) {
        if ((appName = [prefs objectForKey:@"Editor"]) != nil) {
          icon = [self _extIconForApp:appName info:extInfo];
        }
        if (icon == nil && (appName = [prefs objectForKey:@"Viewer"]) != nil) {
          icon = [self _extIconForApp:appName info:extInfo];
        }
      }

      if (icon == nil) {
        NSEnumerator *enumerator;

        /*
         * Still no icon - try all the apps that handle this file
         * extension.
         */
        enumerator = [extInfo keyEnumerator];
        while (icon == nil && (appName = [enumerator nextObject]) != nil) {
          icon = [self _extIconForApp:appName info:extInfo];
        }
      }
    }

    /*
     * Nothing found at all - use the unknowntype icon.
     */
    if (icon == nil) {
      if ([ext isEqualToString:@"app"] == YES || [ext isEqualToString:@"debug"] == YES ||
          [ext isEqualToString:@"profile"] == YES) {
        if (unknownApplication == nil) {
          unknownApplication = RETAIN([NSImage _standardImageWithName:@"NXUnknownApplication"]);
        }
        icon = unknownApplication;
      } else {
        icon = [self _unknownFiletypeImage];
      }
    }

    /*
     * Set the icon in the cache for next time.
     */
    if (icon != nil) {
      [_iconMap setObject:icon forKey:ext];
    }
  }
  return icon;
}

// ADDON
/** Use libmagic to determine file type*/
- (NSImage *)_iconForFileContents:(NSString *)fullPath
{
  OSEFileManager *fm = [OSEFileManager defaultManager];
  NSString *mimeType = [fm mimeTypeForFile:fullPath];
  ;
  NSString *mime0, *mime1;
  NSImage *image = nil;

  // NSDebugLLog(@"NSWorkspace", @"%@: MIME type: %@ ", [fullPath lastPathComponent], mimeType);

  mime0 = [[mimeType pathComponents] objectAtIndex:0];
  mime1 = [[mimeType pathComponents] objectAtIndex:1];
  if ([mime0 isEqualToString:@"text"]) {
    image = [NSImage imageNamed:@"TextFile"];
  } else if ([mime0 isEqualToString:@"image"]) {
    image = [self _iconForExtension:mime1];
  }

  return image;
}

- (BOOL)_extension:(NSString *)ext role:(NSString *)role app:(NSString **)app
{
  NSString *appName = nil;
  NSDictionary *apps = [self applicationsForExtension:ext];
  NSDictionary *prefs;
  NSDictionary *info;

  ext = [ext lowercaseString];
  *app = nil;  // no sense for getBestApp... now

  /*
   * Look for the name of the preferred app in this role.
   * A 'nil' roll is a wildcard - find the preferred Editor or Viewer.
   */
  prefs = [_extPreferences objectForKey:ext];
  if (role == nil || [role isEqualToString:@"Editor"]) {
    appName = [prefs objectForKey:@"Editor"];
    if (appName != nil) {
      info = [apps objectForKey:appName];
      if (info != nil) {
        if (app != 0) {
          *app = appName;
        }
        return YES;
      } else if ([self _locateApplicationBinary:appName] != nil) {
        /*
         * Return the preferred application even though it doesn't
         * say it opens this type of file ... preferences overrule.
         */
        if (app != 0) {
          *app = appName;
        }
        return YES;
      }
    }
  }
  if (role == nil || [role isEqualToString:@"Viewer"]) {
    appName = [prefs objectForKey:@"Viewer"];
    if (appName != nil) {
      info = [apps objectForKey:appName];
      if (info != nil) {
        if (app != 0) {
          *app = appName;
        }
        return YES;
      } else if ([self _locateApplicationBinary:appName] != nil) {
        /*
         * Return the preferred application even though it doesn't
         * say it opens this type of file ... preferences overrule.
         */
        if (app != 0) {
          *app = appName;
        }
        return YES;
      }
    }
  }

  /*
   * Go through the dictionary of apps that know about this file type and
   * determine the best application to open the file by examining the
   * type information for each app.
   * The 'NSRole' field specifies what the app can do with the file - if it
   * is missing, we assume an 'Editor' role.
   */
  if (apps == nil || [apps count] == 0) {
    return NO;
  }

  if (role == nil) {
    /*
     * If the requested role is 'nil', we can accept an app that is either
     * an Editor (preferred) or a Viewer, or unknown.
     */
    for (appName in [apps allKeys]) {
      info = [apps objectForKey:appName];
      role = [info objectForKey:@"NSRole"];
      /* NB. If `role` is nil or an empty string, there is no role set,
       * and we treat this as an Editor since the role is unrestricted.
       */
      if ([role length] == 0 || [role isEqualToString:@"Editor"]) {
        if (app != 0) {
          *app = appName;
        }
        return YES;
      }
      if ([role isEqualToString:@"Viewer"]) {
        if (app != 0) {
          *app = appName;
        }
        return YES;
      }
    }
  } else {
    for (appName in [apps allKeys]) {
      NSString *str;

      info = [apps objectForKey:appName];
      str = [info objectForKey:@"NSRole"];
      if ((str == nil && [role isEqualToString:@"Editor"]) || [str isEqualToString:role]) {
        if (app != 0) {
          *app = appName;
        }
        return YES;
      }
    }
  }

  return NO;
}

//-------------------------------------------------------------------------------------------------
//--- ~/Livrary/Services and Applications
//-------------------------------------------------------------------------------------------------
- (void)_fileSystemPathChanged:(NSNotification *)aNotification
{
  NSString *changedPath = [aNotification userInfo][@"ChangedPath"];
  NSString *changedFile = [aNotification userInfo][@"ChangedFile"];
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSData *data;
  NSDictionary *dict;
  BOOL isAppListChanged = NO;

  // NSLog(@"NSWorkspace: changed path: %@ - %@ (operation: %@)", changedPath,
  //       [aNotification userInfo][@"ChangedFile"], [aNotification userInfo][@"Operations"]);

  if ([_appDirs doesContain:changedPath]) {
    [self findApplications];
    isAppListChanged = YES;
  }

  if ([changedFile containsString:[_extPreferencesPath lastPathComponent]] ||
      isAppListChanged != NO) {
    [[self fileSystemMonitor] removePath:_extPreferencesPath];
    if ([mgr isReadableFileAtPath:_extPreferencesPath] == YES) {
      data = [NSData dataWithContentsOfFile:_extPreferencesPath];
      if (data) {
        dict = [NSDeserializer deserializePropertyListFromData:data mutableContainers:NO];
        ASSIGN(_extPreferences, dict);
      }
      [[self fileSystemMonitor] addPath:_extPreferencesPath];
    } else {
      NSLog(@"ERROR: Failed to track extension preferences!");
    }
  }

  if ([changedFile containsString:[_appListPath lastPathComponent]] || isAppListChanged != NO) {
    [[self fileSystemMonitor] removePath:_appListPath];
    if ([mgr isReadableFileAtPath:_appListPath] == YES) {
      data = [NSData dataWithContentsOfFile:_appListPath];
      if (data) {
        dict = [NSDeserializer deserializePropertyListFromData:data mutableContainers:NO];
        ASSIGN(_appList, dict);
      }
      [[self fileSystemMonitor] addPath:_appListPath];
    } else {
      NSLog(@"ERROR: Failed to read applications list at %@!", _appListPath);
    }
  }
  // Invalidate the cache of icons for file extensions.
  [_iconMap removeAllObjects];

  // Update inspector info (may be opened at "Tools" section)
  if (inspector != nil && isAppListChanged != NO) {
    [inspector revert:[inspector revertButton]];
  }
}

//-------------------------------------------------------------------------------------------------
//--- Application management
//-------------------------------------------------------------------------------------------------
/**
 * Launch an application locally (ie without reference to the workspace
 * manager application).  We should only call this method when we want
 * the application launched by this process, either because what we are
 * launching IS the workspace manager, or because we have tried to get
 * the workspace manager to do the job and been unable to do so.
 */
// NEXTSPACE changes
- (BOOL)_launchApplication:(NSString *)appName arguments:(NSArray *)args
{
  NSTask *task;
  NSString *path;
  NSDictionary *userinfo;
  NSString *host;

  path = [self _locateApplicationBinary:appName];
  if (path == nil) {
    return NO;
  }

  /*
   * Try to ensure that apps we launch display in this workspace
   * ie they have the same -NSHost specification.
   */
  host = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSHost"];
  if (host != nil) {
    NSHost *h;

    h = [NSHost hostWithName:host];
    if ([h isEqual:[NSHost currentHost]] == NO) {
      if ([args containsObject:@"-NSHost"] == NO) {
        NSMutableArray *a;

        if (args == nil) {
          a = [NSMutableArray arrayWithCapacity:2];
        } else {
          a = AUTORELEASE([args mutableCopy]);
        }
        [a insertObject:@"-NSHost" atIndex:0];
        [a insertObject:host atIndex:1];
        args = a;
      }
    }
  }
  /*
   * App being launched, send
   * NSWorkspaceWillLaunchApplicationNotification
   */
  userinfo = @{
    @"NSApplicationName" : [[appName lastPathComponent] stringByDeletingPathExtension],
    @"NSApplicationPath" : appName
  };
  NSDebugLLog(@"NSWorkspace", @"Application UserInfo: %@", userinfo);
  [_windowManagerCenter postNotificationName:NSWorkspaceWillLaunchApplicationNotification
                                      object:self
                                    userInfo:userinfo];
  task = [NSTask launchedTaskWithLaunchPath:path arguments:args];
  if (task == nil || [task isRunning] == NO) {
    return NO;
  }
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(_launchedApplicationDidTerminate:)
                                               name:NSTaskDidTerminateNotification
                                             object:task];
  /*
   * The NSWorkspaceDidLaunchApplicationNotification will be
   * sent by the started application itself.
   */
  [_launched setObject:task forKey:appName];
  return YES;
}

// NEXTSPACE addon
- (void)_launchedApplicationDidTerminate:(NSNotification *)aNotif
{
  NSTask *task = [aNotif object];
  int exitCode = [task terminationStatus];
  NSString *appCommand = [task launchPath];
  WAppIcon *appicon;

  [[NSNotificationCenter defaultCenter] removeObserver:self
                                                  name:NSTaskDidTerminateNotification
                                                object:task];

  appicon = wLaunchingAppIconForCommand(wDefaultScreen(), (char *)[appCommand cString]);
  if (appicon) {
    wLaunchingAppIconDestroy(wDefaultScreen(), appicon);
  }
  [_windowManagerCenter
      postNotificationName:NSWorkspaceDidTerminateApplicationNotification
                    object:self
                  userInfo:@{@"NSApplicationName" : [appCommand lastPathComponent]}];
  // Update GSLaunchedApplications file state
  [[NSWorkspace sharedWorkspace] launchedApplications];

  if (exitCode != 0) {
    NXTRunAlertPanel(_(@"Workspace"), _(@"Application '%@' exited with code %i"), nil, nil, nil,
                     [appCommand lastPathComponent], exitCode);
  }
}

- (id)_connectApplication:(NSString *)appName
{
  NSTimeInterval replyTimeout = 0.0;
  NSTimeInterval requestTimeout = 0.0;
  NSString *host;
  NSString *port;
  NSDate *when = nil;
  NSConnection *conn = nil;
  id app = nil;

  while (app == nil) {
    host = [[NSUserDefaults standardUserDefaults] stringForKey:@"NSHost"];
    if (host == nil) {
      host = @"";
    } else {
      NSHost *h = [NSHost hostWithName:host];
      if ([h isEqual:[NSHost currentHost]] == YES) {
        host = @"";
      }
    }
    port = [[appName lastPathComponent] stringByDeletingPathExtension];
    /*
     *	Try to contact a running application.
     */
    @try {
      conn = [NSConnection connectionWithRegisteredName:port host:host];
      requestTimeout = [conn requestTimeout];
      [conn setRequestTimeout:5.0];
      replyTimeout = [conn replyTimeout];
      [conn setReplyTimeout:5.0];
      app = [conn rootProxy];
    } @catch (NSException *e) {
      /* Fatal error in DO */
      conn = nil;
      app = nil;
    }

    if (app == nil) {
      NSTask *task = [_launched objectForKey:appName];
      NSDate *limit;

      if (task == nil || [task isRunning] == NO) {
        if (task != nil) {  // Not running
          [_launched removeObjectForKey:appName];
        }
        break;  // Need to launch the app
      }

      if (when == nil) {
        when = [[NSDate alloc] init];
      } else if ([when timeIntervalSinceNow] < -5.0) {
        int result;

        DESTROY(when);
        result = NXTRunAlertPanel(appName, @"Application seems to have hung", @"Continue",
                                  @"Terminate", @"Wait");

        if (result == NSAlertDefaultReturn) {
          break;  // Finished without app
        } else if (result == NSAlertOtherReturn) {
          // Continue to wait for app startup.
        } else {
          [task terminate];
          [_launched removeObjectForKey:appName];
          break;  // Terminate hung app
        }
      }

      // Give it another 0.5 of a second to start up.
      limit = [[NSDate alloc] initWithTimeIntervalSinceNow:0.5];
      [[NSRunLoop currentRunLoop] runUntilDate:limit];
      RELEASE(limit);
    }
  }
  if (conn != nil) {
    /* Use original timeouts */
    [conn setRequestTimeout:requestTimeout];
    [conn setReplyTimeout:replyTimeout];
  }
  TEST_RELEASE(when);
  return app;
}

/* Get application bundle, validates its Info-gnustep.plist and return dictionary with keys:
   "WMName" - application name. For Xlib applications it first part of "name.class"
   NSExecutable "WMClass" - second part of of NSExecutable. For GNUstep applications value is
   "GNUstep". ExecutablePath - absolute path to executable used for NSTask. IconPath - icon
   file for sliding appicon.
*/
- (NSDictionary *)_bundleInfoForApp:(NSString *)appName
{
  NSBundle *appBundle;
  NSDictionary *appInfo;
  NSString *wmName;
  NSString *wmClass;
  NSString *launchPath;
  NSString *iconName;
  NSString *iconPath;

  appBundle = [self _bundleForApp:appName];
  appInfo = [appBundle infoDictionary];

  if (!appInfo) {
    NXTRunAlertPanel(_(@"Workspace"),
                     _(@"Failed to start application \"%@\".\n"
                        "Application info dictionary was not found or broken."),
                     nil, nil, nil, [appName lastPathComponent]);
    return nil;
  }

  wmName = [appInfo objectForKey:@"NSExecutable"];
  if (!wmName) {
    NSDebugLLog(@"NSWorkspace", @"No application NSExecutable found.");
    NXTRunAlertPanel(_(@"Workspace"),
                     _(@"Failed to start application '%@'.\n"
                        "Executable name is unknown. It may be damaged or incomplete."),
                     nil, nil, nil, [appName lastPathComponent]);
    return nil;
  }

  wmClass = [wmName pathExtension];
  if ([wmClass isEqualToString:@""] == NO) {
    wmName = [wmName stringByDeletingPathExtension];
  } else if (appInfo[@"NSPrincipalClass"] != nil) {
    wmClass = @"GNUstep";
  } else {
    NXTRunAlertPanel(_(@"Workspace"),
                     @"Failed to start application \"%@\" for selected file.\n"
                      "Application is not GNUstep nor Xlib based.\n"
                      "Please check contents of application Info-gnustep.plist.",
                     nil, nil, nil, [appName lastPathComponent]);
    return nil;
  }

  launchPath = [self _locateApplicationBinary:appName];
  if (launchPath == nil) {
    NXTRunAlertPanel(_(@"Workspace"),
                     _(@"Failed to start application '%@'.\n"
                        "Executable was not found inside application bundle."),
                     nil, nil, nil, [appName lastPathComponent]);
    return nil;
  }

  iconName = appInfo[@"NSIcon"];
  if (iconName) {
    iconPath = [appBundle pathForImageResource:iconName];
    if (iconPath == nil) {
      iconPath = [[NSBundle mainBundle] pathForImageResource:@"NXUnknownApplication"];
    }
  } else {
    iconPath = [[NSBundle mainBundle] pathForImageResource:@"NXUnknownApplication"];
  }

  return @{
    @"WMName" : wmName,
    @"WMClass" : wmClass,
    @"ExecutablePath" : launchPath,
    @"IconPath" : iconPath
  };
}

/**
 * Returns the application bundle for the named application. Accepts
 * either a full path to an app or just the name. The extension (.app,
 * .debug, .profile) is optional, but if provided it will be used.<br />
 * Returns nil if the specified app does not exist as requested.
 */
- (NSBundle *)_bundleForApp:(NSString *)appName
{
  if (appName == nil || [appName length] == 0) {
    return nil;
  }
  appName = [self fullPathForApplication:appName];
  if (appName == nil) {
    return nil;
  }
  return [NSBundle bundleWithPath:appName];
}

/**
 * Returns the path set for the icon matching the image by
 * -_setBestIcon:forExtension:
 */
- (NSString *)_getBestIconForExtension:(NSString *)ext
{
  NSString *iconPath = nil;

  if (_extPreferences != nil) {
    NSDictionary *inf;

    inf = [_extPreferences objectForKey:[ext lowercaseString]];
    if (inf != nil) {
      iconPath = [inf objectForKey:@"Icon"];
    }
  }
  return iconPath;
}

/**
 * Returns the application icon for the given app.
 * Or null if none defined or appName is not a valid application name.
 */
- (NSImage *)_appIconForApp:(NSString *)appName
{
  NSBundle *bundle;
  NSImage *image = nil;
  NSFileManager *mgr = [NSFileManager defaultManager];
  NSString *iconPath = nil;
  NSString *fullPath;

  if ([appName isAbsolutePath] != NO) {
    fullPath = appName;
  } else {
    fullPath = [self fullPathForApplication:appName];
  }

  if ([fullPath isAbsolutePath] != NO) {
    bundle = [[NSBundle alloc] initWithPath:fullPath];
  } else {
    bundle = [self _bundleForApp:fullPath];
  }
  if (bundle == nil) {
    return nil;
  }

  iconPath = [[bundle infoDictionary] objectForKey:@"NSIcon"];
  if (iconPath == nil) {
    // Try the CFBundleIconFile property.
    iconPath = [[bundle infoDictionary] objectForKey:@"CFBundleIconFile"];
  }

  if (iconPath && [iconPath isAbsolutePath] == NO) {
    NSString *file = iconPath;

    iconPath = [bundle pathForImageResource:file];

    /*
     * If there is no icon in the Resources of the app, try
     * looking directly in the app wrapper.
     */
    if (iconPath == nil) {
      iconPath = [fullPath stringByAppendingPathComponent:file];
      if ([mgr isReadableFileAtPath:iconPath] == NO) {
        iconPath = nil;
      }
    }
  }

  /*
   * If there is no icon specified in the Info.plist for app
   * try 'wrapper/app.png'
   */
  if (iconPath == nil) {
    NSString *str;

    str = [fullPath lastPathComponent];
    str = [str stringByDeletingPathExtension];
    iconPath = [fullPath stringByAppendingPathComponent:str];
    iconPath = [iconPath stringByAppendingPathExtension:@"png"];
    if ([mgr isReadableFileAtPath:iconPath] == NO) {
      iconPath = [iconPath stringByAppendingPathExtension:@"tiff"];
      if ([mgr isReadableFileAtPath:iconPath] == NO) {
        iconPath = [iconPath stringByAppendingPathExtension:@"icns"];
        if ([mgr isReadableFileAtPath:iconPath] == NO) {
          iconPath = nil;
        }
      }
    }
  }

  if (iconPath != nil) {
    image = [self _imageFromFile:iconPath];
  }

  return image;
}

/**
 * Requires the path to an application wrapper as an argument, and returns
 * the full path to the executable.
 */
- (NSString *)_locateApplicationBinary:(NSString *)appName
{
  NSString *path;
  NSString *file;
  NSBundle *bundle = [self _bundleForApp:appName];

  if (bundle == nil) {
    return nil;
  }
  path = [bundle bundlePath];
  file = [[bundle infoDictionary] objectForKey:@"NSExecutable"];

  if (file == nil) {
    /*
     * If there is no executable specified in the info property-list, then
     * we expect the executable to reside within the app wrapper and to
     * have the same name as the app wrapper but without the extension.
     */
    file = [path lastPathComponent];
    file = [file stringByDeletingPathExtension];
    path = [path stringByAppendingPathComponent:file];
  } else {
    /*
     * If there is an executable specified in the info property-list, then
     * it can be either an absolute path, or a path relative to the app
     * wrapper, so we make sure we end up with an absolute path to return.
     */
    if ([file isAbsolutePath] == YES) {
      path = file;
    } else {
      path = [path stringByAppendingPathComponent:file];
    }
  }

  return path;
}

/**
 * Sets up a user preference for which icon should be used to
 * represent the specified file extension.
 */
- (void)_setBestIcon:(NSString *)iconPath forExtension:(NSString *)ext
{
  NSMutableDictionary *map;
  NSMutableDictionary *inf;
  NSData *data;

  ext = [ext lowercaseString];
  if (_extPreferences != nil) {
    map = [_extPreferences mutableCopy];
  } else {
    map = [NSMutableDictionary new];
  }

  inf = [[map objectForKey:ext] mutableCopy];
  if (inf == nil) {
    inf = [NSMutableDictionary new];
  }
  if (iconPath) {
    [inf setObject:iconPath forKey:@"Icon"];
  } else {
    [inf removeObjectForKey:@"Icon"];
  }
  [map setObject:inf forKey:ext];
  RELEASE(inf);
  RELEASE(_extPreferences);
  _extPreferences = map;
  data = [NSSerializer serializePropertyList:_extPreferences];
  if ([data writeToFile:_extPreferencesPath atomically:YES]) {
    // [NSNotificationCenter defaultCenter] postNotificationName:GSWorkspacePreferencesChanged
    //                                 object:self];
  } else {
    NSDebugLLog(@"Workspace", @"Update %@ of failed", _extPreferencesPath);
  }
}

@end
