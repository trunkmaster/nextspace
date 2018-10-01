/*
   Controller.h
   The main app controller.

   Copyright (C) 2005 Saso Kiselkov

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, 
   MA02110-1301 USA.
*/

#import <AppKit/AppKit.h>
#import <NXSystem/NXFileSystemMonitor.h>
#import <NXSystem/NXMediaManager.h>
#import <NXAppKit/NXIconBadge.h>

#import "Console.h"

#import "Inspectors/Inspector.h"

@class FileViewer;
@class Inspector;
@class Processes;
@class ProcessManager;
@class NXScreen;
@class NXPower;
@class Recycler;
@class Launcher;
@class Finder;

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

  NXPower  *systemPower;
  
  FileViewer          *rootViewer;
  NSMutableArray      *fileViewers;
  NXFileSystemMonitor *fileSystemMonitor;
  NXMediaManager      *mediaManager;
  id<MediaManager>    mediaAdaptor;
  Inspector           *inspector;
  Console             *console;
  ProcessManager      *procManager;
  Processes           *procPanel;
  NSMutableDictionary *mediaOperations;
  Launcher            *launcher;
  Finder              *finder;
 
  BOOL dontOpenRootViewer;
  BOOL isQuitting;

  // NSWorkspace category ivars
  NSMutableDictionary	*_iconMap;
  NSMutableDictionary	*_launched;
  NSNotificationCenter	*_workspaceCenter;
  BOOL			_fileSystemChanged;
  BOOL			_userDefaultsChanged;

  NXIconBadge		*workspaceBadge;
  Recycler		*recycler;
}

- (FileViewer *)newViewerRootedAt:(NSString *)path
                           viewer:(NSString *)viewerType
                           isRoot:(BOOL)root;
- (FileViewer *)openNewViewerIfNotExistRootedAt:(NSString *)path;

- (void)applicationDidFinishLaunching:(NSNotification *)notif;

//============================================================================
// Access to Workspace data via NSApp
//============================================================================
- (FileViewer *)rootViewer;
- (FileViewer *)fileViewerForWindow:(NSWindow *)window;
- (Inspector *)inspectorPanel;
- (NXFileSystemMonitor *)fileSystemMonitor;
- (id<MediaManager>)mediaManager;
- (Processes *)processesPanel;
- (Recycler *)recycler;

//============================================================================
// Appicon badges
//============================================================================
- (void)createWorkspaceBadge;
- (void)updateWorkspaceBadge;

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

@end
