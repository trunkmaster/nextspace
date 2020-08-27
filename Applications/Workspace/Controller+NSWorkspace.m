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

#include <unistd.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/mount.h>

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>

#import <DesktopKit/NXTDefaults.h>
#import <DesktopKit/NXTFileManager.h>
#import <DesktopKit/NXTAlert.h>

#import "Workspace+WM.h"
#import "Controller+NSWorkspace.h"
#import "Controller+WorkspaceCenter.h"

#define PosixExecutePermission	(0111)

#define FILE_CONTENTS_SCAN_SIZE 100

static NSArray *wrappers = nil;

static NSMutableDictionary *folderPathIconDict = nil;
static NSMutableDictionary *folderIconCache = nil;

static NSImage	*folderImage = nil;
static NSImage	*multipleFiles = nil;
static NSImage	*unknownApplication = nil;
static NSImage	*unknownTool = nil;

//-----------------------------------------------------------------------------
// Workspace private methods
//-----------------------------------------------------------------------------

@interface Controller (NSWorkspacePrivate)

// Icon handling
- (NSImage*)_extIconForApp:(NSString*)appName
                      info:(NSDictionary*)extInfo;
- (NSImage*)unknownFiletypeImage;
- (NSImage*)_saveImageFor:(NSString*)iconPath;
- (NSString*)_thumbnailForFile:(NSString *)file;
- (NSImage*)_iconForExtension:(NSString*)ext;
- (NSImage *)_iconForFileContents:(NSString *)fullPath;
- (NSImage *)_iconForFileContents:(NSString *)fullPath;
- (BOOL)_extension:(NSString*)ext
              role:(NSString*)role
               app:(NSString**)app;

// Preferences
- (void)_workspacePreferencesChanged:(NSNotification *)aNotification;

// application communication
- (BOOL)_launchApplication:(NSString*)appName
                 arguments:(NSArray*)args;
- (id)_connectApplication:(NSString*)appName;

@end

@interface Controller (NSWorkspaceGNUstep)

- (NSString*)getBestIconForExtension:(NSString*)ext;
- (NSDictionary*)infoForExtension:(NSString*)ext;
- (NSBundle*)bundleForApp:(NSString*)appName;
- (NSImage*)appIconForApp:(NSString*)appName;
- (NSString*)locateApplicationBinary:(NSString*)appName;
- (void)setBestApp:(NSString*)appName
	     inRole:(NSString*)role
       forExtension:(NSString*)ext;
- (void)setBestIcon:(NSString*)iconPath
       forExtension:(NSString*)ext;

@end

//-----------------------------------------------------------------------------
// Workspace OPENSTEP methods
//-----------------------------------------------------------------------------
@implementation	Controller (NSWorkspace)

// ~/Library/Services/.GNUstepAppList
static NSString		*appListPath = nil;
static NSDictionary	*applications = nil;

// ~/Library/Services/.GNUstepExtPrefs
static NSString		*extPrefPath = nil;
static NSDictionary	*extPreferences = nil;

static NSString		*_rootPath = @"/";

//-----------------------------------------------------------------------------
//--- Creating a Workspace
//-----------------------------------------------------------------------------
- (void)dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_workspaceCenter removeObserver:self];
  
  TEST_RELEASE(_iconMap);
  TEST_RELEASE(_launched);
  TEST_RELEASE(_workspaceCenter);

  TEST_RELEASE(wrappers);
 
  [super dealloc];
}

- (void)initPrefs
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSString	*service;
  NSArray       *libraryDirs;
  NSData	*data;
  NSDictionary	*dict;

  libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, 
                                                    NSUserDomainMask, YES);
  service = [[libraryDirs objectAtIndex:0]
              stringByAppendingPathComponent:@"Services"];
	  
  /*
   * Load file extension preferences.
   */
  extPrefPath = [service stringByAppendingPathComponent:@".GNUstepExtPrefs"];
  RETAIN(extPrefPath);
  if ([mgr isReadableFileAtPath: extPrefPath] == YES) {
    data = [NSData dataWithContentsOfFile: extPrefPath];
    if (data) {
      dict = [NSDeserializer deserializePropertyListFromData:data
                                           mutableContainers:NO];
      extPreferences = RETAIN(dict);
    }
  }
	  
  /*
   * Load cached application information.
   */
  appListPath = [service stringByAppendingPathComponent:@".GNUstepAppList"];
  RETAIN(appListPath);
  if ([mgr isReadableFileAtPath:appListPath] == YES) {
    data = [NSData dataWithContentsOfFile:appListPath];
    if (data) {
      dict = [NSDeserializer deserializePropertyListFromData:data
                                           mutableContainers:NO];
      applications = RETAIN(dict);
    }
  }
}

// NEXTSPACE
- (id)initNSWorkspace
{
  NSArray *documentDir;
  NSArray *libraryDirs;
  NSArray *sysAppDir;
  NSArray *downloadDir;
  NSArray *desktopDir;
  NSString *sysDir;
  int i;

  [self initPrefs];

  [[NSNotificationCenter defaultCenter]
    addObserver: self
       selector: @selector(noteUserDefaultsChanged)
           name: NSUserDefaultsDidChangeNotification
         object: nil];

  /* There's currently no way of knowing if things have changed due to
   * apps being installed etc ... so we actually poll regularly.
   */
  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(_workspacePreferencesChanged:)
           name:@"GSHousekeeping"
         object:nil];

  _workspaceCenter = [WorkspaceCenter new];
  _iconMap = [NSMutableDictionary new];
  _launched = [NSMutableDictionary new];
  if (applications == nil) {
    [self findApplications];
  }
  [_workspaceCenter addObserver:self
                       selector:@selector(_workspacePreferencesChanged:)
                           name:GSWorkspacePreferencesChanged
                         object:nil];

  /* icon association and caching */
  folderPathIconDict = [[NSMutableDictionary alloc] initWithCapacity:5];

  documentDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                    NSUserDomainMask, YES);
  downloadDir = NSSearchPathForDirectoriesInDomains(NSDownloadsDirectory,
                                                    NSUserDomainMask, YES);
  desktopDir = NSSearchPathForDirectoriesInDomains(NSDesktopDirectory,
                                                   NSUserDomainMask, YES);
  libraryDirs = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,
                                                    NSAllDomainsMask, YES);
  sysAppDir = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory,
                                                  NSSystemDomainMask, YES);

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
  // [folderPathIconDict
  //   setObject:@"ImageFolder"
  //      forKey:[NSHomeDirectory() stringByAppendingPathComponent:@"Images"]];
  // [folderPathIconDict
  //   setObject:@"MusicFolder"
  //      forKey:[NSHomeDirectory() stringByAppendingPathComponent:@"Music"]];
  
  [folderPathIconDict setObject:@"NXRoot" forKey:_rootPath];

  // for (i = 0; i < [libraryDirs count]; i++) {
  //   [folderPathIconDict setObject:@"LibraryFolder"
  //                          forKey:[libraryDirs objectAtIndex: i]];
  // }
  // for (i = 0; i < [documentDir count]; i++) {
  //   [folderPathIconDict setObject:@"DocsFolder"
  //                          forKey:[documentDir objectAtIndex:i]];
  // }
  // for (i = 0; i < [downloadDir count]; i++) {
  //   [folderPathIconDict setObject:@"DownloadFolder"
  //                          forKey:[downloadDir objectAtIndex:i]];
  // }
  // for (i = 0; i < [desktopDir count]; i++) {
  //   [folderPathIconDict setObject:@"Desktop"
  //                          forKey:[desktopDir objectAtIndex:i]];
  // }
  folderIconCache = [[NSMutableDictionary alloc] init];

  // list of extensions of wrappers (will be shown as plain file in Workspace)
  wrappers = [@"(bundle, preferences, inspector, service)" propertyList];
  [wrappers retain];
  // NSLog(@"Wrappers list: %@(0=%@)", wrappers, [wrappers objectAtIndex:0]);

  return self;
}

//-----------------------------------------------------------------------------
//--- Opening Files
//-----------------------------------------------------------------------------
- (BOOL)openFile:(NSString*)fullPath
{
  return [self openFile:fullPath withApplication:nil andDeactivate:YES];
}

// NEXTSPACE
- (BOOL)openFile: (NSString*)fullPath
       fromImage:(NSImage*)anImage
              at:(NSPoint)point
          inView:(NSView*)aView
{
  NSString      *fileType = nil, *appName = nil;
  NSPoint       destPoint = {0,0};
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary  *fattrs = nil;

  if (![fm fileExistsAtPath:fullPath]) {
    NXTRunAlertPanel(_(@"Workspace"),
                     _(@"File '%@' does not exist!"), 
                     nil, nil, nil, [fullPath lastPathComponent]);
    return NO;
  }

  // Sliding coordinates
  point = [[aView window] convertBaseToScreen:[aView convertPoint:point
                                                           toView:nil]];

  // Get file type and application name
  [self getInfoForFile:fullPath application:&appName type:&fileType];

  // Application is not associated - set `appName` to default editor.
  if (appName == nil) {
    if ([self _extension:[fullPath pathExtension] role:nil app:&appName] == NO) {
      appName = [[NXTDefaults userDefaults] objectForKey:@"DefaultEditor"];
      if (!appName || [appName isEqualToString:@""]) {
        appName = @"TextEdit";
      }
    }
  }

  NSDebugLLog(@"Workspace", @"[Workspace] openFile: type '%@' with app: %@",
              fileType, appName);
  
  if ([fileType isEqualToString:NSApplicationFileType]) {
    // .app should be launched
      NSString     *wmName;
      NSBundle     *appBundle;
      NSDictionary *appInfo;
      NSString     *iconPath;
      NSString     *launchPath;
      
      // Don't launch ourself and Login panel
      if ([appName isEqualToString:@"Workspace"] ||
          [appName isEqualToString:@"Login"]) {
        return YES;
      }

      appBundle = [[NSBundle alloc] initWithPath:fullPath];
      appInfo = [appBundle infoDictionary];
      if (!appInfo) {
        NXTRunAlertPanel(_(@"Workspace"),
                         _(@"Failed to start application \"%@\".\n"
                           "Application info dictionary was not found or broken."), 
                         nil, nil, nil, appName);
        return NO;
      }
      wmName = [appInfo objectForKey:@"NSExecutable"];
      if (!wmName) {
        NSLog(@"No application NSExecutable found.");
        NXTRunAlertPanel(_(@"Workspace"),
                         _(@"Failed to start application \"%@\".\n"
                           "Executable name is unknown (info doctionary is broken)."),
                         nil, nil, nil, appName);
        return NO;
      }
      if ([[wmName componentsSeparatedByString:@"."] count] == 1) {
        wmName = [NSString stringWithFormat:@"%@.GNUstep",
                           [wmName stringByDeletingPathExtension]];
      }
      launchPath = [self locateApplicationBinary:fullPath];
      if (launchPath == nil) {
        NXTRunAlertPanel(_(@"Workspace"),
                         _(@"Failed to start application \"%@\".\n"
                           "Executable \"%@\" was not found.\n"),
                         nil, nil, nil, appName, fullPath);
        return NO;
      }
      iconPath = [appBundle pathForResource:[appInfo objectForKey:@"NSIcon"]
                                     ofType:nil];
      
      WMCreateLaunchingIcon(wmName, launchPath, anImage, point, iconPath);
      
      if ([self launchApplication:fullPath] == NO) {
        NXTRunAlertPanel(_(@"Workspace"),
                         _(@"Failed to start application \"%@\""), 
                         nil, nil, nil, appName);
        return NO;
      }
      return YES;
  }
  else if ([fileType isEqualToString:NSDirectoryFileType] ||
           [fileType isEqualToString:NSFilesystemFileType] ||
           [wrappers containsObject:[fullPath pathExtension]]) {
      // Open new FileViewer window
      [self openNewViewerIfNotExistRootedAt:fullPath];
      return YES;
    }
  else if (appName) {
    // .app found for opening file type
    NSBundle     *appBundle;
    NSDictionary *appInfo;
    NSString     *wmName;
    NSString     *iconPath;
    NSString     *launchPath;
      
    appBundle = [self bundleForApp:appName];
    if (appBundle) {
      appInfo = [appBundle infoDictionary];
      iconPath = [appBundle pathForResource:[appInfo objectForKey:@"NSIcon"]
                                     ofType:nil];
      
      wmName = [appInfo objectForKey:@"NSExecutable"];
      if ([[wmName componentsSeparatedByString:@"."] count] == 1) {
        wmName = [NSString stringWithFormat:@"%@.GNUstep",
                           [appName stringByDeletingPathExtension]];
      }
      launchPath = [self locateApplicationBinary:appName];
      if (launchPath == nil) {
        return NO;
      }
      WMCreateLaunchingIcon(wmName, launchPath, anImage, point, iconPath);
    }
      
    if (![self openFile:fullPath withApplication:appName andDeactivate:YES]) {
      NXTRunAlertPanel(_(@"Workspace"),
                       _(@"Failed to start application \"%@\" for file \"%@\""), 
                       nil, nil, nil, appName, [fullPath lastPathComponent]);
      return NO;
    }
    return YES;
  }

  return NO;
}

- (BOOL) openFile:(NSString*)fullPath
  withApplication:(NSString*)appName
{
  return [self openFile:fullPath withApplication:appName andDeactivate:YES];
}

// NEXTSPACE
- (BOOL)openFile:(NSString*)fullPath
 withApplication:(NSString*)appName
   andDeactivate:(BOOL)flag
{
  id app;

  if (appName == nil) {
    [self openFile:fullPath fromImage:nil at:NSZeroPoint inView:nil];
  }

  app = [self _connectApplication:appName];
  if (app == nil) {
    NSArray *args;

    args = [NSArray arrayWithObjects:@"-GSFilePath",fullPath,nil];
    return [self _launchApplication:appName arguments:args];
  }
  else {
    @try {
      if (flag == NO) {
        [app application:NSApp openFileWithoutUI:fullPath];
      }
      else {
        [app application:NSApp openFile:fullPath];
      }
    }
    @catch (NSException *e) {
      NSWarnLog(@"Failed to contact '%@' to open file", appName);
      NXTRunAlertPanel(_(@"Workspace"),
                       _(@"Failed to contact app '%@' to open file"), 
                       nil, nil, nil, appName);
      return NO;
    }
  }
  if (flag) {
    [NSApp deactivate];
  }
  return YES;
}

- (BOOL)openTempFile:(NSString*)fullPath
{
  id		app;
  NSString	*appName;
  NSString	*ext;

  ext = [fullPath pathExtension];
  if ([self _extension:ext role:nil app:&appName] == NO) {
    appName = [[NXTDefaults userDefaults] objectForKey:@"DefaultEditor"];
  }

  app = [self _connectApplication:appName];
  if (app == nil) {
    NSArray *args = [NSArray arrayWithObjects:@"-GSTempPath", fullPath, nil];
    return [self _launchApplication:appName arguments:args];
  }
  else {
    @try {
      [app application:NSApp openTempFile:fullPath];
    }
    @catch (NSException *e) {
      NSWarnLog(@"Failed to contact '%@' to open temp file", appName);
      return NO;
    }
  }

  [NSApp deactivate];

  return YES;
}

//-----------------------------------------------------------------------------
//--- Manipulating Files
//-----------------------------------------------------------------------------
// FIXME: TODO
- (BOOL)performFileOperation:(NSString*)operation
                      source:(NSString*)source
                 destination:(NSString*)destination
                       files:(NSArray*)files
                         tag:(int*)tag
{
  // FiXME

  return NO;
}

// FIXME: TODO
- (BOOL)       selectFile:(NSString*)fullPath
 inFileViewerRootedAtPath:(NSString*)rootFullpath
{
  // TODO
  return NO;
}

- (NSString*)fullPathForApplication:(NSString*)appName
{
  NSString	*base;
  NSString	*path;
  NSString	*ext;

  if ([appName length] == 0) {
    return nil;
  }
  if ([[appName lastPathComponent] isEqual:appName] == NO) {
    if ([appName isAbsolutePath] == YES) {
      return appName;		// MacOS-X implementation behavior.
    }
    /*
     * Relative path ... get standarized absolute path
     */
    path = [[NSFileManager defaultManager] currentDirectoryPath];
    appName = [path stringByAppendingPathComponent: appName];
    appName = [appName stringByStandardizingPath];
  }
  base = [appName stringByDeletingLastPathComponent];
  appName = [appName lastPathComponent];
  ext = [appName pathExtension];
  if ([ext length] == 0) { // no extension, let's find one
    path = [appName stringByAppendingPathExtension: @"app"];
    path = [applications objectForKey: path];
    if (path == nil) {
      path = [appName stringByAppendingPathExtension: @"debug"];
      path = [applications objectForKey: path];
    }
    if (path == nil) {
      path = [appName stringByAppendingPathExtension: @"profile"];
      path = [applications objectForKey: path];
    }
  }
  else {
    path = [applications objectForKey: appName];
  }

  /*
   * If the original name included a path, check that the located name
   * matches it.  If it doesn't we return nil as MacOS-X does.
   */
  if ([base length] > 0
      && [base isEqual: [path stringByDeletingLastPathComponent]] == NO) {
    path = nil;
  }
  return path;
}

// FIXME: TODO
- (BOOL)getFileSystemInfoForPath:(NSString*)fullPath
                     isRemovable:(BOOL*)removableFlag
                      isWritable:(BOOL*)writableFlag
                   isUnmountable:(BOOL*)unmountableFlag
                     description:(NSString **)description
                            type:(NSString **)fileSystemType
{
  // uid_t uid;
  // struct statfs m;
  // NSStringEncoding enc;

  // if (statfs([fullPath fileSystemRepresentation], &m))
  //   return NO;

  // uid = geteuid();
  // enc = [NSString defaultCStringEncoding];
  // *removableFlag = NO; // FIXME
  // *writableFlag = (m.f_flags & MNT_RDONLY) == 0;
  // *unmountableFlag =
  //   (m.f_flags & MNT_ROOTFS) == 0 && (uid == 0 || uid == m.f_owner);
  // *description = @"filesystem"; // FIXME
  // *fileSystemType =
  // [[NSString alloc] initWithCString: m.f_fstypename encoding: enc];

  return YES;
}

- (BOOL)getInfoForFile:(NSString*)fullPath
           application:(NSString **)appName
                  type:(NSString **)type
{
  NSFileManager	*fm = [NSFileManager defaultManager];
  NSDictionary  *attributes;
  NSString      *fileType;
  NSString      *extension = [fullPath pathExtension];

  attributes = [fm fileAttributesAtPath:fullPath traverseLink:YES];

  if (attributes != nil) {
    // application
    [self _extension:extension role:nil app:appName];

    // file type
    fileType = [attributes fileType];
    if ([fileType isEqualToString:NSFileTypeRegular]) {
      if ([attributes filePosixPermissions] & PosixExecutePermission) {
        *type = NSShellCommandFileType;
      }
      else {
        *type = NSPlainFileType;
      }
    }
    else if ([fileType isEqualToString:NSFileTypeDirectory]) {
      if ([extension isEqualToString:@"app"]
          || [extension isEqualToString:@"debug"]
          || [extension isEqualToString:@"profile"]) {
        *type = NSApplicationFileType;
      }
      else if ([wrappers containsObject:extension]) {
        *type = NSPlainFileType;
      }
      else if (*appName != nil && [extension length] > 0) {
        *type = NSPlainFileType;
      }
      // The idea here is that if the parent directory's
      // fileSystemNumber differs, this must be a filesystem mount point.
      else if ([[fm fileAttributesAtPath:
                      [fullPath stringByDeletingLastPathComponent]
                            traverseLink:YES] fileSystemNumber]
               != [attributes fileSystemNumber]) {
        *type = NSFilesystemFileType;
      }
      else {
        *type = NSDirectoryFileType;
      }
    }
    else {
      // This catches sockets, character special, block special,
      // and unknown file types
      *type = NSPlainFileType;
    }
    return YES;
  }
  else {
    *appName = nil;
    *type = nil;
    return NO;
  }
}

// NEXTSPACE changes
- (NSImage*)iconForFile:(NSString*)fullPath
{
  NSImage	*image = nil;
  NSString	*pathExtension = [[fullPath pathExtension] lowercaseString];
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSDictionary	*attributes;
  NSString	*fileType;
  NSString	*wmFileType, *appName;
  NSArray       *searchPath;

  attributes = [mgr fileAttributesAtPath:fullPath traverseLink:YES];
  fileType = [attributes objectForKey:NSFileType];
  if (([fileType isEqual:NSFileTypeDirectory] == YES) &&
      [mgr isReadableFileAtPath:fullPath] == NO) {
    image = [NSImage imageNamed:@"badFolder"];
  }
  else if ([fileType isEqual:NSFileTypeDirectory] == YES) {
    NSString *iconPath = nil;

    // Mount point
    [self getInfoForFile:fullPath application:&appName type:&wmFileType];
    if ([wmFileType isEqualToString:NSFilesystemFileType]) {
      NXTFSType fsType;
          
      fsType = [[OSEMediaManager defaultManager]
                     filesystemTypeAtPath:fullPath];
      if (fsType == NXTFSTypeFAT) {
        image = [NSImage imageNamed:@"DOS_FD.fs"];
      }
      else if (fsType == NXTFSTypeISO) {
        image = [NSImage imageNamed:@"CDROM.fs"];
      }
      else if (fsType == NXTFSTypeNTFS) {
        image = [NSImage imageNamed:@"NTFS_HDD.fs"];
      }
      else {
        image = [NSImage imageNamed:@"HDD.fs"];
      }
    }

    // Application
    if ([pathExtension isEqualToString:@"app"] ||
        [pathExtension isEqualToString:@"debug"] ||
        [pathExtension isEqualToString:@"profile"]) {
      image = [self appIconForApp:fullPath];
	  
      if (image == nil) {
        image = [NSImage _standardImageWithName:@"NXApplication"];
      }
    }
    else if ([pathExtension isEqualToString:@"bundle"]) {
      image = [NSImage imageNamed:@"bundle"];
    }
      
    // Users home directory (/Users)
    searchPath = NSSearchPathForDirectoriesInDomains(NSUserDirectory,
                                                     NSSystemDomainMask,
                                                     YES);
    if ([searchPath count] > 0
        && [fullPath isEqualToString:[searchPath objectAtIndex:0]]) {
      image = [NSImage imageNamed:@"neighbor"];
    }

    // Directory icon '.dir.tiff', '.dir.png'
    if (iconPath == nil) {
      iconPath = [fullPath stringByAppendingPathComponent:@".dir.png"];
      if ([mgr isReadableFileAtPath:iconPath] == NO) {
        iconPath = [fullPath stringByAppendingPathComponent:@".dir.tiff"];
        if ([mgr isReadableFileAtPath:iconPath] == NO) {
          iconPath = nil;
        }
      }
      // Directory icon path found - get icon
      if (iconPath != nil) {
        image = [self _saveImageFor:iconPath];
      }
    }

    // It's not mount point, not bundle, not user homes,
    // folder doesn't contain dir icon
    if (image == nil) {
      image = [self _iconForExtension:pathExtension];
      if (image == nil || image == [self unknownFiletypeImage]) {
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
        }
        else {
          if (folderImage == nil) {
            folderImage = RETAIN([NSImage _standardImageWithName:
                                            @"NXFolder"]);
          }
          image = folderImage;
        }
      }
    }
  }
  else if ([mgr isReadableFileAtPath:fullPath] == YES) {
    // NSFileTypeRegular, NSFileType
    NSDebugLog(@"pathExtension is '%@'", pathExtension);

    // TODO: Thumbnail of file
    // if ([[NSUserDefaults standardUserDefaults]
    //         boolForKey:@"GSUseFreedesktopThumbnails"]) {
    //   // This image will be 128x128 pixels as oposed to the 48x48 
    //   // of other GNUstep icons or the 32x32 of the specification
    //   image = [self _saveImageFor:[self _thumbnailForFile:fullPath]];
    //   if (image != nil) {
    //     return image;
    //   }
    // }

      // By executable bit
    if (image == nil
        && ([fileType isEqual:NSFileTypeRegular] == YES)
        && ([mgr isExecutableFileAtPath:fullPath] == YES)) {
      if (unknownTool == nil) {
        unknownTool = RETAIN([NSImage _standardImageWithName:
                                        @"NXTool"]);
      }
      image = unknownTool;
    }

    // By extension
    if (image == nil) {
      image = [self _iconForExtension:pathExtension];
    }
      
    // By file contents
    if (image == nil || image == [self unknownFiletypeImage]) {
      image = [self _iconForFileContents:fullPath];
    }
  }
  else if ([mgr isReadableFileAtPath:fullPath] == NO) {
    image = [NSImage imageNamed:@"badFile"];
  }

  if (image == nil) {
    image = [self unknownFiletypeImage];
  }

  return image;
}

- (NSImage*)iconForFiles:(NSArray*)pathArray
{
  if ([pathArray count] == 1) {
    return [self iconForFile:[pathArray objectAtIndex:0]];
  }
  if (multipleFiles == nil) {
    multipleFiles = [NSImage imageNamed:@"MultipleSelection"];
  }

  return multipleFiles;
}

- (NSImage*)iconForFileType:(NSString*)fileType
{
  return [self _iconForExtension:fileType];
}

// NEXTSPACE addon
- (NSImage *)openIconForDirectory:(NSString *)fullPath
{
  NSString *appName, *fileType;
  NSString *openDirIconPath;
  NSString *usersDir;
  NSImage  *icon;

  [self getInfoForFile:fullPath application:&appName type:&fileType];

  usersDir = [GNUstepConfig(nil) objectForKey:@"GNUSTEP_SYSTEM_USERS_DIR"];

  openDirIconPath = [fullPath stringByAppendingPathComponent:@".opendir.tiff"];

  if ([[NSFileManager defaultManager] fileExistsAtPath:openDirIconPath]) {
    return [[[NSImage alloc] initByReferencingFile:openDirIconPath] autorelease];
  }
  else if ([fileType isEqualToString:NSFilesystemFileType]) {
    NXTFSType fsType;
    
    fsType = [[OSEMediaManager defaultManager] filesystemTypeAtPath:fullPath];
    if (fsType == NXTFSTypeFAT) {
      return [NSImage imageNamed:@"DOS_FD.openfs"];
    }
    else if (fsType == NXTFSTypeISO) {
      return [NSImage imageNamed:@"CDROM.openfs"];
    }
    return [NSImage imageNamed:@"HDD.openfs"];
  }
  else if ([fileType isEqualToString:NSPlainFileType]) { // e.g. .gorm
    return [self iconForFile:fullPath];
  }
  else if ([fullPath isEqualToString:@"/"]) {
    return [NSImage imageNamed:@"openRoot"];
  }
  else if ([fullPath isEqualToString:usersDir]) {
    return [NSImage imageNamed:@"openNeighbor"];
  }
  else if ([fullPath isEqualToString:NSHomeDirectory()]) {
    return [NSImage imageNamed:@"openHome"];
  }
  else if ([fileType isEqualToString:NSDirectoryFileType]) {
    return [NSImage imageNamed:@"openFolder"];
  }

  return [self iconForFile:fullPath];
}

//-----------------------------------------------------------------------------
//--- Tracking Changes to the File System
//-----------------------------------------------------------------------------
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

//-----------------------------------------------------------------------------
//--- Updating Registered Services and File Types
//-----------------------------------------------------------------------------
- (void)findApplications
{
  static NSString	*path = nil;
  NSTask		*task;

  // Try to locate and run an executable copy of 'make_services'
  if (path == nil) {
    path = [[NSTask launchPathForTool:@"make_services"] retain];
  }
  task = [NSTask launchedTaskWithLaunchPath:path
				  arguments:nil];
  if (task != nil) {
    [task waitUntilExit];
  }
  [self _workspacePreferencesChanged:
          [NSNotification notificationWithName:GSWorkspacePreferencesChanged
                                        object:self]];
}

//-----------------------------------------------------------------------------
//--- Launching and Manipulating Applications
//-----------------------------------------------------------------------------

// FIXME: TODO
- (void)hideOtherApplications
{
  // TODO
}

- (BOOL)launchApplication:(NSString*)appName
{
  return [self launchApplication:appName
			showIcon:YES
		      autolaunch:NO];
}

- (BOOL)launchApplication:(NSString*)appName
                 showIcon:(BOOL)showIcon
               autolaunch:(BOOL)autolaunch
{
  id app;

  app = [self _connectApplication:appName];
  if (app == nil) {
      NSArray *args = nil;

      if (autolaunch == YES) {
        args = [NSArray arrayWithObjects: @"-autolaunch", @"YES", nil];
      }
      return [self _launchApplication:appName arguments:args];
  }
  else {
    [app activateIgnoringOtherApps:YES];
  }

  return YES;
}


//-----------------------------------------------------------------------------
//--- Unmounting a Device
//-----------------------------------------------------------------------------

- (BOOL)unmountAndEjectDeviceAtPath:(NSString*)path
{
  [[OSEMediaManager defaultManager] unmountAndEjectDeviceAtPath:path];
  return YES;
}

//-----------------------------------------------------------------------------
//--- Tracking Status Changes for Devices
//-----------------------------------------------------------------------------

- (void)checkForRemovableMedia
{
  [mediaAdaptor checkForRemovableMedia];
}

- (NSArray*)mountNewRemovableMedia
{
  return [mediaAdaptor mountNewRemovableMedia];
}

- (NSArray*)mountedRemovableMedia
{
  return [mediaAdaptor mountedRemovableMedia];
}

//-----------------------------------------------------------------------------
//--- Notification Center
//-----------------------------------------------------------------------------

- (NSNotificationCenter*)notificationCenter
{
  return _workspaceCenter;
}

//-----------------------------------------------------------------------------
//--- Tracking Changes to the User Defaults Database
//-----------------------------------------------------------------------------
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
  BOOL	hasChanged = _userDefaultsChanged;

  _userDefaultsChanged = NO;
  return hasChanged;
}

//-----------------------------------------------------------------------------
//--- Animating an Image
//-----------------------------------------------------------------------------

- (void)slideImage:(NSImage*)image
              from:(NSPoint)fromPoint
                to:(NSPoint)toPoint
{
  [GSCurrentServer() slideImage:image from:fromPoint to:toPoint];
}

//-----------------------------------------------------------------------------
//--- Requesting Additional Time before Power Off or Logout
//-----------------------------------------------------------------------------

// FIXME: TODO
- (int)extendPowerOffBy:(int)requested
{
  // TODO
  return 0;
}

@end

@implementation Controller (NSWorkspacePrivate)

//-----------------------------------------------------------------------------
//--- Images and icons
//-----------------------------------------------------------------------------
- (NSImage *)_extIconForApp:(NSString *)appName info:(NSDictionary*)extInfo
{
  NSDictionary	*typeInfo = [extInfo objectForKey: appName];
  NSString	*file = [typeInfo objectForKey: @"NSIcon"];
  
  /*
   * If the NSIcon entry isn't there and the CFBundle entries are,
   * get the first icon in the list if it's an array, or assign
   * the icon to file if it's a string.
   *
   * FIXME: CFBundleTypeExtensions/IconFile can be arrays which assign
   * multiple types to icons.  This needs to be handled eventually.
   */
  if (file == nil)
    {
      id icon = [typeInfo objectForKey: @"CFBundleTypeIconFile"];
      if ([icon isKindOfClass: [NSArray class]])
	{
	  if ([icon count])
	    {
	      file = [icon objectAtIndex: 0];
	    }
	}
      else
	{
	  file = icon;
	}
    }

  if (file && [file length] != 0)
    {
      if ([file isAbsolutePath] == NO)
	{
	  NSString *iconPath;
	  NSBundle *bundle;

	  bundle = [self bundleForApp: appName];
	  iconPath = [bundle pathForImageResource: file];
	  /*
	   * If the icon is not in the Resources of the app, try looking
	   * directly in the app wrapper.
	   */
	  if (iconPath == nil)
	    {
	      iconPath = [[bundle bundlePath]
		stringByAppendingPathComponent: file];
	    }
	  file = iconPath;
	}
      if ([[NSFileManager defaultManager] isReadableFileAtPath: file] == YES)
	{
	  return [self _saveImageFor: file];
	}
    }
  return nil;
}

/** Returns the default icon to display for a file */
- (NSImage *)unknownFiletypeImage
{
  static NSImage *image = nil;

  if (image == nil) {
    image = RETAIN([NSImage _standardImageWithName:@"NXUnknown"]);
  }

  return image;
}

/** Try to create the image in an exception handling context */
- (NSImage *)_saveImageFor:(NSString *)iconPath
{
  NSImage *tmp = nil;

  NS_DURING {
    tmp = [[NSImage alloc] initWithContentsOfFile:iconPath];
    if (tmp != nil) {
      AUTORELEASE(tmp);
    }
  }
  NS_HANDLER {
    NSLog(@"BAD TIFF FILE '%@'", iconPath);
  }
  NS_ENDHANDLER

  return tmp;
}

/** Returns the freedesktop thumbnail file name for a given file name */
- (NSString *)_thumbnailForFile:(NSString *)file
{
  NSString *absolute;
  NSString *digest;
  NSString *thumbnail;

  absolute = [[NSURL fileURLWithPath:[file stringByStandardizingPath]] 
               absoluteString];
  /* This compensates for a feature we have in NSURL, that is there to have 
   * MacOSX compatibility.
   */
  if ([absolute hasPrefix:  @"file://localhost/"])
    {
      absolute = [@"file:///" stringByAppendingString: 
		       [absolute substringWithRange: 
				     NSMakeRange(17, [absolute length] - 17)]];
    }

  // FIXME: Not sure which encoding to use here. 
  digest = [[[[absolute dataUsingEncoding: NSASCIIStringEncoding]
		 md5Digest] hexadecimalRepresentation] lowercaseString];
  thumbnail = [@"~/.thumbnails/normal" stringByAppendingPathComponent: 
		    [digest stringByAppendingPathExtension: @"png"]];

  return [thumbnail stringByStandardizingPath];
}

- (NSImage *)_iconForExtension:(NSString *)ext
{
  NSImage	*icon = nil;

  if (ext == nil || [ext isEqualToString:@""]) {
    return nil;
  }
  /*
   * extensions are case-insensitive - convert to lowercase.
   */
  ext = [ext lowercaseString];
  if ((icon = [_iconMap objectForKey: ext]) == nil)
    {
      NSDictionary	*prefs;
      NSDictionary	*extInfo;
      NSString		*iconPath;

      /*
       * If there is a user-specified preference for an image -
       * try to use that one.
       */
      prefs = [extPreferences objectForKey: ext];
      iconPath = [prefs objectForKey: @"Icon"];
      if (iconPath)
	{
	  icon = [self _saveImageFor: iconPath];
	}

      if (icon == nil && (extInfo = [self infoForExtension: ext]) != nil)
	{
	  NSString	*appName;

	  /*
	   * If there are any application preferences given, try to use the
	   * icon for this file that is used by the preferred app.
	   */
	  if (prefs)
	    {
	      if ((appName = [prefs objectForKey: @"Editor"]) != nil)
		{
		  icon = [self _extIconForApp: appName info: extInfo];
		}
	      if (icon == nil
                  && (appName = [prefs objectForKey: @"Viewer"]) != nil)
		{
		  icon = [self _extIconForApp: appName info: extInfo];
		}
	    }

	  if (icon == nil)
	    {
	      NSEnumerator	*enumerator;

	      /*
	       * Still no icon - try all the apps that handle this file
	       * extension.
	       */
	      enumerator = [extInfo keyEnumerator];
	      while (icon == nil && (appName = [enumerator nextObject]) != nil)
		{
		  icon = [self _extIconForApp: appName info: extInfo];
		}
	    }
	}

      /*
       * Nothing found at all - use the unknowntype icon.
       */
      if (icon == nil)
	{
	  if ([ext isEqualToString: @"app"] == YES
	    || [ext isEqualToString: @"debug"] == YES
	    || [ext isEqualToString: @"profile"] == YES)
	    {
	      if (unknownApplication == nil)
		{
		  unknownApplication = RETAIN([NSImage _standardImageWithName:
		    @"NXUnknownApplication"]);
		}
	      icon = unknownApplication;
	    }
          else
	    {
	      icon = [self unknownFiletypeImage];
	    }
	}

      /*
       * Set the icon in the cache for next time.
       */
      if (icon != nil)
	{
	  [_iconMap setObject:icon forKey:ext];
	}
    }
  return icon;
}

// ADDON
/** Use libmagic to determine file type*/
- (NSImage *)_iconForFileContents:(NSString *)fullPath
{
  NXTFileManager *fm = [NXTFileManager defaultManager];
  NSString       *mimeType = [fm mimeTypeForFile:fullPath];;
  NSString       *mime0, *mime1;
  NSImage        *image = nil;

  // NSLog(@"%@: MIME type: %@ ", [fullPath lastPathComponent], mimeType);

  mime0 = [[mimeType pathComponents] objectAtIndex:0];
  mime1 = [[mimeType pathComponents] objectAtIndex:1];
  if ([mime0 isEqualToString:@"text"]) {
    image = [NSImage imageNamed:@"TextFile"];
  }
  else if ([mime0 isEqualToString:@"image"]) {
    image = [self _iconForExtension:mime1];
  }
  
  return image;
}

- (BOOL) _extension:(NSString*)ext
               role:(NSString*)role
	        app:(NSString**)app
{
  NSEnumerator	*enumerator;
  NSString      *appName = nil;
  NSDictionary	*apps = [self infoForExtension: ext];
  NSDictionary	*prefs;
  NSDictionary	*info;

  ext = [ext lowercaseString];
  *app = nil; // no sense for getBestApp... now

  /*
   * Look for the name of the preferred app in this role.
   * A 'nil' roll is a wildcard - find the preferred Editor or Viewer.
   */
  prefs = [extPreferences objectForKey: ext];
  if (role == nil || [role isEqualToString: @"Editor"])
    {
      appName = [prefs objectForKey: @"Editor"];
      if (appName != nil)
	{
	  info = [apps objectForKey: appName];
	  if (info != nil)
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	  else if ([self locateApplicationBinary: appName] != nil)
	    {
	      /*
	       * Return the preferred application even though it doesn't
	       * say it opens this type of file ... preferences overrule.
	       */
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	}
    }
  if (role == nil || [role isEqualToString: @"Viewer"])
    {
      appName = [prefs objectForKey: @"Viewer"];
      if (appName != nil)
	{
	  info = [apps objectForKey: appName];
	  if (info != nil)
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	  else if ([self locateApplicationBinary: appName] != nil)
	    {
	      /*
	       * Return the preferred application even though it doesn't
	       * say it opens this type of file ... preferences overrule.
	       */
	      if (app != 0)
		{
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
  if (apps == nil || [apps count] == 0)
    {
      return NO;
    }
  enumerator = [apps keyEnumerator];

  if (role == nil)
    {
      BOOL	found = NO;

      /*
       * If the requested role is 'nil', we can accept an app that is either
       * an Editor (preferred) or a Viewer, or unknown.
       */
      while ((appName = [enumerator nextObject]) != nil)
	{
	  NSString	*str;

	  info = [apps objectForKey: appName];
	  str = [info objectForKey: @"NSRole"];
	  /* NB. If str is nil or an empty string, there is no role set,
	   * and we treat this as an Editor since the role is unrestricted.
	   */
	  if ([str length] == 0 || [str isEqualToString: @"Editor"])
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	  if ([str isEqualToString: @"Viewer"])
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      found = YES;
	    }
	}
      return found;
    }
  else
    {
      while ((appName = [enumerator nextObject]) != nil)
	{
	  NSString	*str;

	  info = [apps objectForKey: appName];
	  str = [info objectForKey: @"NSRole"];
	  if ((str == nil && [role isEqualToString: @"Editor"])
	    || [str isEqualToString: role])
	    {
	      if (app != 0)
		{
		  *app = appName;
		}
	      return YES;
	    }
	}
      return NO;
    }
}

//-----------------------------------------------------------------------------
//--- Preferences
//-----------------------------------------------------------------------------
- (void)_workspacePreferencesChanged:(NSNotification *)aNotification
{
  /* FIXME reload only those preferences that really were changed
   * TODO  add a user info to aNotification, which includes a bitmask
   *       denoting the updated preference files.
   */
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSData		*data;
  NSDictionary		*dict;

  if ([mgr isReadableFileAtPath: extPrefPath] == YES)
    {
      data = [NSData dataWithContentsOfFile: extPrefPath];
      if (data)
	{
	  dict = [NSDeserializer deserializePropertyListFromData: data
					       mutableContainers: NO];
	  ASSIGN(extPreferences, dict);
	}
    }

  if ([mgr isReadableFileAtPath: appListPath] == YES)
    {
      data = [NSData dataWithContentsOfFile: appListPath];
      if (data)
	{
	  dict = [NSDeserializer deserializePropertyListFromData: data
					       mutableContainers: NO];
	  ASSIGN(applications, dict);
	}
    }
  /*
   *	Invalidate the cache of icons for file extensions.
   */
  [_iconMap removeAllObjects];
}

//-----------------------------------------------------------------------------
//--- Application management
//-----------------------------------------------------------------------------
/**
 * Launch an application locally (ie without reference to the workspace
 * manager application).  We should only call this method when we want
 * the application launched by this process, either because what we are
 * launching IS the workspace manager, or because we have tried to get
 * the workspace manager to do the job and been unable to do so.
 */
// NEXTSPACE changes
- (BOOL)_launchApplication:(NSString*)appName
                 arguments:(NSArray*)args
{
  NSTask	*task;
  NSString	*path;
  NSDictionary	*userinfo;
  NSString	*host;

  path = [self locateApplicationBinary:appName];
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
        NSMutableArray	*a;

        if (args == nil) {
          a = [NSMutableArray arrayWithCapacity:2];
        }
        else {
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
  userinfo = [NSDictionary
               dictionaryWithObjectsAndKeys:
                 [[appName lastPathComponent] stringByDeletingPathExtension], 
               @"NSApplicationName",
               appName, @"NSApplicationPath",
               nil];
  [_workspaceCenter
    postNotificationName:NSWorkspaceWillLaunchApplicationNotification
                  object:self
                userInfo:userinfo];
  task = [NSTask launchedTaskWithLaunchPath:path arguments:args];
  if (task == nil) {
    return NO;
  }
  [[NSNotificationCenter defaultCenter]
    addObserver:self
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
  NSTask   *task = [aNotif object];
  int      exitCode = [task terminationStatus];
  WAppIcon *appicon;
  char     *command;

  [[NSNotificationCenter defaultCenter]
    removeObserver:self
              name:NSTaskDidTerminateNotification
            object:task];
  
  command = (char *)[[task launchPath] cString];
  appicon = WSLaunchingIconForCommand(command);
  if (appicon) {
    WMDestroyLaunchingIcon(appicon);
  }
  [_workspaceCenter
    postNotificationName:NSWorkspaceDidTerminateApplicationNotification
                  object:self
                userInfo:@{@"NSApplicationName":[[task launchPath] lastPathComponent]}];
  
  if (exitCode != 0) {
    NXTRunAlertPanel(_(@"Workspace"),
                     _(@"Application '%s' exited with code %i"), 
                     nil, nil, nil, command, exitCode);
  }
}

- (id)_connectApplication:(NSString*)appName
{
  NSTimeInterval        replyTimeout = 0.0;
  NSTimeInterval        requestTimeout = 0.0;
  NSString		*host;
  NSString		*port;
  NSDate		*when = nil;
  NSConnection  	*conn = nil;
  id			app = nil;

  while (app == nil) {
    host = [[NSUserDefaults standardUserDefaults] stringForKey: @"NSHost"];
    if (host == nil) {
      host = @"";
    }
    else {
      NSHost	*h;

      h = [NSHost hostWithName: host];
      if ([h isEqual: [NSHost currentHost]] == YES) {
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
    }
    @catch (NSException *e) {
      /* Fatal error in DO */
      conn = nil;
      app = nil;
    }

    if (app == nil) {
      NSTask	*task = [_launched objectForKey:appName];
      NSDate	*limit;

      if (task == nil || [task isRunning] == NO) {
        if (task != nil) {	// Not running
          [_launched removeObjectForKey:appName];
        }
        break;		// Need to launch the app
      }

      if (when == nil) {
        when = [[NSDate alloc] init];
      }
      else if ([when timeIntervalSinceNow] < -5.0) {
        int		result;

        DESTROY(when);
        result = NXTRunAlertPanel(appName,
                                  @"Application seems to have hung",
                                  @"Continue", @"Terminate", @"Wait");

        if (result == NSAlertDefaultReturn) {
          break;		// Finished without app
        }
        else if (result == NSAlertOtherReturn) {
          // Continue to wait for app startup.
        }
        else {
          [task terminate];
          [_launched removeObjectForKey:appName];
          break;		// Terminate hung app
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

@end

@implementation	Controller (NSWorkspaceGNUstep)

/**
 * Returns the path set for the icon matching the image by
 * -setBestIcon:forExtension:
 */
- (NSString*)getBestIconForExtension:(NSString*)ext
{
  NSString	*iconPath = nil;

  if (extPreferences != nil) {
    NSDictionary	*inf;

    inf = [extPreferences objectForKey:[ext lowercaseString]];
    if (inf != nil) {
      iconPath = [inf objectForKey:@"Icon"];
    }
  }
  return iconPath;
}

/**
 * Gets the applications cache (generated by the make_services tool)
 * and looks up the special entry that contains a dictionary of all
 * file extensions recognised by GNUstep applications.  Then finds
 * the dictionary of applications that can handle our file and
 * returns it.
 */
- (NSDictionary*)infoForExtension:(NSString*)ext
{
  NSDictionary  *map;

  ext = [ext lowercaseString];
  map = [applications objectForKey:@"GSExtensionsMap"];
  return [map objectForKey:ext];
}

/**
 * Returns the application bundle for the named application. Accepts
 * either a full path to an app or just the name. The extension (.app,
 * .debug, .profile) is optional, but if provided it will be used.<br />
 * Returns nil if the specified app does not exist as requested.
 */
- (NSBundle*)bundleForApp:(NSString*)appName
{
  if ([appName length] == 0) {
    return nil;
  }
  if ([[appName lastPathComponent] isEqual:appName]) { // it's a name
    appName = [self fullPathForApplication:appName];
  }
  else {
    NSFileManager	*fm;
    NSString		*ext;
    BOOL		flag;

    fm = [NSFileManager defaultManager];
    ext = [appName pathExtension];
    if ([ext length] == 0) { // no extension, let's find one
      NSString	*path;

      path = [appName stringByAppendingPathExtension:@"app"];
      if ([fm fileExistsAtPath:path isDirectory:&flag] == NO || flag == NO) {
        {
          path = [appName stringByAppendingPathExtension: @"debug"];
          if ([fm fileExistsAtPath:path isDirectory:&flag] == NO || flag == NO) {
            path = [appName stringByAppendingPathExtension: @"profile"];
          }
        }
        appName = path;
      }
      if ([fm fileExistsAtPath:appName isDirectory:&flag] == NO || flag == NO) {
        appName = nil;
      }
    }
  }
  if (appName == nil) {
    return nil;
  }
  return [NSBundle bundleWithPath:appName];
}

/**
 * Returns the application icon for the given app.
 * Or null if none defined or appName is not a valid application name.
 */
- (NSImage*)appIconForApp:(NSString*)appName
{
  NSBundle	*bundle;
  NSImage	*image = nil;
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSString	*iconPath = nil;
  NSString	*fullPath;
  
  fullPath = [self fullPathForApplication:appName];
  bundle = [self bundleForApp:fullPath];
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
      iconPath = [fullPath stringByAppendingPathComponent: file];
      if ([mgr isReadableFileAtPath: iconPath] == NO) {
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
    iconPath = [fullPath stringByAppendingPathComponent: str];
    iconPath = [iconPath stringByAppendingPathExtension: @"png"];
    if ([mgr isReadableFileAtPath: iconPath] == NO) {
      iconPath = [iconPath stringByAppendingPathExtension: @"tiff"];
      if ([mgr isReadableFileAtPath: iconPath] == NO) {
        iconPath = [iconPath stringByAppendingPathExtension: @"icns"];
        if ([mgr isReadableFileAtPath: iconPath] == NO) {		  
          iconPath = nil;
        }
      }
    }
  }

  if (iconPath != nil) {
    image = [self _saveImageFor:iconPath];
  }
  
  return image;
}

/**
 * Requires the path to an application wrapper as an argument, and returns
 * the full path to the executable.
 */
- (NSString*)locateApplicationBinary:(NSString*)appName
{
  NSString	*path;
  NSString	*file;
  NSBundle	*bundle = [self bundleForApp:appName];

  if (bundle == nil) {
    return nil;
  }
  path = [bundle bundlePath];
  file = [[bundle infoDictionary] objectForKey: @"NSExecutable"];

  if (file == nil) {
    /*
     * If there is no executable specified in the info property-list, then
     * we expect the executable to reside within the app wrapper and to
     * have the same name as the app wrapper but without the extension.
     */
    file = [path lastPathComponent];
    file = [file stringByDeletingPathExtension];
    path = [path stringByAppendingPathComponent:file];
  }
  else {
    /*
     * If there is an executable specified in the info property-list, then
     * it can be either an absolute path, or a path relative to the app
     * wrapper, so we make sure we end up with an absolute path to return.
     */
    if ([file isAbsolutePath] == YES) {
      path = file;
    }
    else {
      path = [path stringByAppendingPathComponent:file];
    }
  }

  return path;
}

/**
 * Sets up a user preference  for which app should be used to open files
 * of the specified extension.
 */
- (void)setBestApp:(NSString*)appName
            inRole:(NSString*)role
      forExtension:(NSString*)ext
{
  NSMutableDictionary	*map;
  NSMutableDictionary	*inf;
  NSData		*data;

  ext = [ext lowercaseString];
  if (extPreferences != nil) {
    map = [extPreferences mutableCopy];
  }
  else {
    map = [NSMutableDictionary new];
  }

  inf = [[map objectForKey: ext] mutableCopy];
  if (inf == nil) {
    inf = [NSMutableDictionary new];
  }
  if (appName == nil) {
    if (role == nil) {
      NSString	*iconPath = [inf objectForKey: @"Icon"];

      RETAIN(iconPath);
      [inf removeAllObjects];
      if (iconPath) {
        [inf setObject: iconPath forKey: @"Icon"];
        RELEASE(iconPath);
      }
    }
    else {
      [inf removeObjectForKey: role];
    }
  }
  else {
    [inf setObject:appName forKey:(role ? (id)role : (id)@"Editor")];
  }
  [map setObject:inf forKey:ext];
  RELEASE(inf);
  RELEASE(extPreferences);
  extPreferences = map;
  data = [NSSerializer serializePropertyList:extPreferences];
  if ([data writeToFile:extPrefPath atomically:YES]) {
    [_workspaceCenter postNotificationName:GSWorkspacePreferencesChanged
                                    object:self];
  }
  else {
    NSLog(@"Update %@ of failed", extPrefPath);
  }
}

/**
 * Sets up a user preference for which icon should be used to
 * represent the specified file extension.
 */
- (void)setBestIcon:(NSString*)iconPath
       forExtension:(NSString*)ext
{
  NSMutableDictionary	*map;
  NSMutableDictionary	*inf;
  NSData		*data;

  ext = [ext lowercaseString];
  if (extPreferences != nil) {
    map = [extPreferences mutableCopy];
  }
  else {
    map = [NSMutableDictionary new];
  }

  inf = [[map objectForKey:ext] mutableCopy];
  if (inf == nil) {
    inf = [NSMutableDictionary new];
  }
  if (iconPath) {
    [inf setObject:iconPath forKey:@"Icon"];
  }
  else {
    [inf removeObjectForKey:@"Icon"];
  }
  [map setObject:inf forKey:ext];
  RELEASE(inf);
  RELEASE(extPreferences);
  extPreferences = map;
  data = [NSSerializer serializePropertyList:extPreferences];
  if ([data writeToFile:extPrefPath atomically:YES]) {
    [_workspaceCenter postNotificationName:GSWorkspacePreferencesChanged
                                    object:self];
  }
  else {
    NSLog(@"Update %@ of failed", extPrefPath);
  }
}

@end
