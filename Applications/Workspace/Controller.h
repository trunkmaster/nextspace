/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014-2021 Sergii Stoian
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

#import <AppKit/AppKit.h>
#import <SystemKit/OSEFileSystemMonitor.h>
#import <SystemKit/OSEMediaManager.h>
#import <DesktopKit/NXTIconBadge.h>
#import <SoundKit/NXTSound.h>

#import "Console.h"

#import "Inspectors/Inspector.h"

@class FileViewer;
@class Inspector;
@class Processes;
@class ProcessManager;
@class OSEScreen;
@class OSEPower;
@class Recycler;
@class Launcher;
@class Finder;
@class Preferences;

@interface Controller : NSObject
{
  id viewMenuItem;

  // Info -> Legal...
  id legalPanel;
  id legalText;

  // Info -> Info Panel...
  id infoPanel;
  id infoPanelImage;
  id hostName, wsVersion, osType, kernelRelease;
  id machineType, cpuType, cpuClock, memory;
  id baseVersion, guiVersion;

  OSEPower *systemPower;

  FileViewer *rootViewer;
  NSMutableArray *fileViewers;
  OSEFileSystemMonitor *fileSystemMonitor;
  OSEMediaManager *mediaManager;
  id<MediaManager> mediaAdaptor;
  Inspector *inspector;
  Console *console;
  ProcessManager *procManager;
  Processes *procPanel;
  NSMutableDictionary *mediaOperations;
  Launcher *launcher;
  Finder *finder;
  Preferences *preferences;

  BOOL dontOpenRootViewer;

  NXTIconBadge *workspaceBadge;
  NXTIconBadge *keyboardBadge;
  Recycler *recycler;

  NXTSound *bellSound;

  // NSWorkspace category ivars
  NSMutableDictionary *_iconMap;
  NSMutableDictionary *_launched;
  NSArray *_wrappers;
  NSNotificationCenter *_windowManagerCenter;
  BOOL _fileSystemChanged;
  BOOL _userDefaultsChanged;
  // ~/Library/Services/.GNUstepAppList
  NSString *_appListPath;
  NSDictionary *_applications;
  // ~/Library/Services/.GNUstepExtPrefs
  NSString *_extPrefPath;
  NSDictionary *_extPreferences;
}

@property (readonly) BOOL isQuitting;

- (FileViewer *)newViewerRootedAt:(NSString *)path viewer:(NSString *)viewerType isRoot:(BOOL)root;
- (FileViewer *)openNewViewerIfNotExistRootedAt:(NSString *)path;

- (void)applicationDidFinishLaunching:(NSNotification *)notif;

//============================================================================
// Access to Workspace data via NSApp
//============================================================================
- (FileViewer *)rootViewer;
- (FileViewer *)fileViewerForWindow:(NSWindow *)window;
- (Inspector *)inspectorPanel;
- (OSEFileSystemMonitor *)fileSystemMonitor;
- (id<MediaManager>)mediaManager;
- (Processes *)processesPanel;
- (Recycler *)recycler;
- (Finder *)finder;

//============================================================================
// Appicon badges
//============================================================================
- (void)createWorkspaceBadge;
- (void)destroyWorkspaceBadge;
- (void)createKeyboardBadge;
- (void)updateKeyboardBadge:(NSString *)layout;

//============================================================================
// Application menu
//============================================================================
- (void)emptyRecycler:(id)sender;
- (void)showConsole:(id)sender;
- (void)newViewer:(id)sender;
- (void)closeViewer:(id)viewer;
- (void)updateViewers:(id)sender;
- (void)showFinder:(id)sender;
- (void)showPrefsPanel:(id)sender;
- (void)showProcesses:(id)sender;
- (void)showInfoPanel:(id)sender;
- (void)showLegalPanel:(id)sender;

- (void)showAttributesInspector:(id)sender;
- (void)showContentsInspector:(id)sender;
- (void)showToolsInspector:(id)sender;
- (void)showPermissionsInspector:(id)sender;

- (void)saveLegalToFile:(id)sender;

- (void)showLauncher:sender;
- (void)setDockVisibility:(id)sender;

- (void)ringBell;

@end
