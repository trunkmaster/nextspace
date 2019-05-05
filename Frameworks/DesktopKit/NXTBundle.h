/* -*- mode: objc -*- */
//
// Project: NEXTSPACE - DesktopKit framework
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

//-----------------------------------------------------------------------------
//---> bundle.registry
//-----------------------------------------------------------------------------
// 
// Bundles should be located in application specific directories
// (/Applications/AppName.app/Resources, /Library/Bundles/AppName)
// 
// type     - Type of bundle. Examples: InspectorCommand, PreferencesModule,
//            TextParser, ProjectType, whatever...
//            Example:
//              type = "InspectorCommand";
// mode     - Mode specific to bundle usage. Make sense for application which
//            uses bundle. Can be used for grouping similar bundles.
//            Example:
//              mode = "attributes";
// class    - Principal class name used to initialize object
//            Example:
//              class = "FileAttributesInspector";
// selp     - Workspace selection count or number of objects this bundle
//            can operate on.
//            Example: selp = "selectionOneOrMore";
// nodep    - The name of method used by Inspector to determine if given
//            inspector can be shown for current selection. This method must
//            return BOOL value ('YES' or 'NO'). If inspector bundle returns
//            NO, Inspector shows 'No <mode name> Inspector'.
//            Example: nodep = "isLocalFile";
// priority - If several bundles with other appropriate properties found,
//            bundle with higher number in 'priority' field will be used.
//            Example:
//              priority = 1;
//
// Bundles are able to add custom fields. These custom fields must be processed
// whith application. For example:
// 
// icon     - File name of icon if any.
// name     - Name of popup button element or section selection control.
//            Examples:
//            for Workspace: "Attributes", "Contents", "Tools",
//            "Access Control".
//            for Preferences: "Fonts", "Login", "Localization", "Time",
//            "Display", "Keyboard", "Sound"
//
// Field added by NXTBundle while registering bundles:            
//              
// path     - Absolute path to bundle. Added by NXTBundle registering methods.

// Returns NSDictionary in format:
// <path to bundle dir> = {<bundle.registry content>};
// 
// bundleFileExtension - extension of bundle directory, Font.preferences
// subDirName - subdirectory inside Bundles which contain bundle.registry
//              or nil if search shouldn't go deeper.
//              For example: Resources will search in
//              Font.preferences/Resources
//
//-----------------------------------------------------------------------------
//---> Bundle searching and registering
//-----------------------------------------------------------------------------
//
// Searches for bundles in:
// enum
// {
//   NSUserDomainMask = 1,         /** The user's personal items */
//   NSLocalDomainMask = 2,        /** Local for all users on the machine */
//   NSNetworkDomainMask = 4,      /** Public for all users on network */
//   NSSystemDomainMask = 8,       /** Standard GNUstep items */
//   NSAllDomainsMask = 0x0ffff    /** all domains */
// };
// directoriesMask = NSApplicationDirectory | // $DOMAIN/Applications
//                   NSLibraryDirectory     | // $DOMAIN/Library
//                   NSUserDirectory          // /Users
//   /Applications/<app name>,
//   /Library/Bundles/<app name>,
//   /Library/Bundles
//
//For Preferences.app:
// NSUserDomainMask(~)
//   ~/Applications
//   ~/Library/Bundles
//   ~/Library/Bundles/Preferences
// NSLocalDomainMask (/)
//   /Applications
//   /Library/Bundles
//   /Library/Bundles/Preferences
// NSSystemDomainMask (/usr/NextSpace)
//   /usr/NextSpace/Apps
//
// Search and registering process contains following steps:
// - get list of bundles' full paths with 'bundleExtension' in Domains and
//   Directories noted above;
// - load bundle registry information from found bundles (Info.table,
//   bundle.registry);
// - provide access to common for all bundles field values (type, mode,
//   principal class);
// - load bundle and return principal class instance object;
// - check if bundle conforms to specified protocol;


#import <Foundation/NSObject.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSProtocolChecker.h>

@interface NXTBundle : NSObject

+ (id)shared;

//-----------------------------------------------------------------------------
//--- Searching and registering
//-----------------------------------------------------------------------------

// Returns list of bundles' absolute path located in directory and subdirectory.
- (NSArray *)bundlePathsOfType:(NSString *)fileExtension
                        atPath:(NSString *)dirPath;

// Returns list of bundles' absolute path found in Library, Applications
// and Users domains.
- (NSArray *)bundlePathsOfType:(NSString *)fileExtension;

// Returned dictionary contains:
//  (NSString *)              (NSDictionary *)
// "full path to the bundle" = "bundle.registry contents"
- (NSDictionary *)registerBundlesOfType:(NSString *)fileExtension
                                 atPath:(NSString *)dirPath;

- (NSArray *)loadRegisteredBundles:(NSDictionary *)bundleRegistry
                              type:(NSString *)registryType
                          protocol:(Protocol *)aProtocol;

//-----------------------------------------------------------------------------
//--- Validating and loading
//-----------------------------------------------------------------------------

// Load bundles and check for conformance to protocol
// If inDicrectory == nil bundles searched in standard places across filesystem
// (/Applications, ~/Applications, /usr/NextSpace/Apps, /Library, ~/Library,
// /usr/NextSpace)
- (NSArray *)loadBundlesOfType:(NSString *)fileType
                      protocol:(Protocol *)protocol
                   inDirectory:(NSString *)dir;
@end
