/** <title>GormFilePrefsManager</title>

  <abstract>Sets the information about the .gorm file's version.  
  This allows a file to be saved as an older version of the .gorm 
  format so that older releases can still use .gorm files created 
  by people who have the latest GNUstep and Gorm version.</abstract>

   Copyright (C) 2003 Free Software Foundation, Inc.

   Author: Gregory John Casamento
   Date: July 2003.
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library;
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

/* All rights reserved */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <InterfaceBuilder/InterfaceBuilder.h>

#include <GNUstepBase/GSObjCRuntime.h>
#include <GNUstepGUI/GSGormLoading.h>

#include "GormFilePrefsManager.h"
#include "GormFunctions.h"
#include "GormDocument.h"

NSString *formatVersion(NSInteger version)
{
  NSInteger bit16 = 65536;
  NSInteger bit8  = 256;
  NSInteger maj   = 0; 
  NSInteger min   = 0;
  NSInteger pch   = 0;
  NSInteger v     = version;

  // pull the version fromt the number
  maj = (int)((float)v / (float)bit16);
  v -= (bit16 * maj);
  min = (int)((float)v / (float)bit8);
  v -= (bit8 * min);
  pch = v;
  
  return [NSString stringWithFormat: @"%ld.%ld.%ld / %ld",(long)maj,(long)min,(long)pch,(long)version];
}


@implementation GormFilePrefsManager

// initializers...
- (id) init
{
  if((self = [super init]) != nil)
    {
      NSBundle *bundle = [NSBundle bundleForClass: [self class]];
      NSString *path = [bundle pathForResource: @"VersionProfiles" ofType: @"plist"];
      versionProfiles = RETAIN([[NSString stringWithContentsOfFile: path] propertyList]);
    }
  return self;
}

- (void) dealloc
{
  NSDebugLog(@"Deallocating...");
  [iwindow performClose: self];
  RELEASE(iwindow);
  RELEASE(versionProfiles);
  [super dealloc];
}

+ (int) currentVersion
{
  return appVersion(1, 5, 0); 
}

- (void) awakeFromNib
{
  version = [GormFilePrefsManager currentVersion];
  [gormAppVersion setStringValue: formatVersion(version)];
  ASSIGN(targetVersionName, [[targetVersion selectedItem] title]);
  ASSIGN(archiveTypeName, [[archiveType selectedItem] title]);
  [self selectTargetVersion: targetVersion];
}

// set class versions
- (void) setClassVersions
{
  NSEnumerator *en = [currentProfile keyEnumerator];
  id className = nil;
  
  NSDebugLog(@"set the class versions to the profile selected... %@",targetVersionName);
  while((className = [en nextObject]) != nil)
    {
      Class cls = NSClassFromString(className);
      NSDictionary *info = [currentProfile objectForKey: className];
      NSInteger v = [[info objectForKey: @"version"] intValue];
      NSDebugLog(@"Setting version %ld for class %@",(long)v,className);
      [cls setVersion: v];
    }
}

- (void) restoreClassVersions
{
  NSDictionary *latestVersion = [versionProfiles objectForKey: @"Latest Version"];
  NSEnumerator *en = [latestVersion keyEnumerator];
  id className = nil;
  
  // The "Latest Version" key must always exist.
  NSDebugLog(@"restore the class versions to the latest version...");
  while((className = [en nextObject]) != nil)
    {
      Class cls = NSClassFromString(className);
      NSDictionary *info = [latestVersion objectForKey: className];
      NSInteger v = [[info objectForKey: @"version"] intValue];
      NSDebugLog(@"Setting version %ld for class %@",(long)v,className);
      [cls setVersion: v];
    }
}

// class profile
- (void) loadProfile: (NSString *)profileName
{
  NSDebugLog(@"Loading profile %@",profileName);
  currentProfile = [versionProfiles objectForKey: targetVersionName];
}

// actions...
- (void) showIncompatibilities: (id)sender
{
  [itable reloadData];
  [iwindow orderFront: self];
  [iwindow center];
}

- (void) selectTargetVersion: (id)sender
{
  ASSIGN(targetVersionName, [[sender selectedItem] title]);
  [self loadProfile: targetVersionName];
  [itable reloadData];
}

- (void) selectArchiveType: (id)sender
{
  ASSIGN(archiveTypeName, [[sender selectedItem] title]);
  NSDebugLog(@"Set Archive type... %@",sender);
}

// Loading and saving the file.
- (BOOL) saveToFile: (NSString *)path
{
  return [[self data] writeToFile: path atomically: YES];
}

// Loading and saving the file.
- (NSData *) data
{
  // upon saving, update to the latest.
  version = [GormFilePrefsManager currentVersion];
  [gormAppVersion setStringValue: formatVersion(version)];

  // return the data...
  return  [NSArchiver archivedDataWithRootObject: self];
}

- (NSData *) nibDataWithOpenItems: (NSArray *)openItems
{
  NSMutableDictionary *dict = 
    [NSMutableDictionary dictionary];
  NSRect docLocation = 
    [[(GormDocument *)[(id<IB>)[NSApp delegate] activeDocument] window] frame];
  NSRect screenRect = [[NSScreen mainScreen] frame];
  NSString *stringRect = [NSString stringWithFormat: @"%d %d %d %d %d %d %d %d",
				   (int)docLocation.origin.x, (int)docLocation.origin.y, 
				   (int)docLocation.size.width, (int)docLocation.size.height,
				   (int)screenRect.origin.x, (int)screenRect.origin.y, 
				   (int)screenRect.size.width, (int)screenRect.size.height];

  // upon saving, update to the latest.
  version = [GormFilePrefsManager currentVersion];
  [gormAppVersion setStringValue: formatVersion(version)];
  
  [dict setObject: stringRect forKey: @"IBDocumentLocation"];
  [dict setObject: @"437.0" forKey: @"IBFramework Version"];
  [dict setObject: @"8I127" forKey: @"IBSystem Version"];
  [dict setObject: [NSNumber numberWithBool: YES] 
	forKey: @"IBUsesTextArchiving"]; // for now.
  [dict setObject: openItems forKey: @"IBOpenItems"];

  return [NSPropertyListSerialization dataFromPropertyList: dict 
				      format: NSPropertyListXMLFormat_v1_0
				      errorDescription: NULL];
}

- (int) versionOfClass: (NSString *)className 
{
  NSInteger result = -1; 

  NSDictionary *clsProfile = [currentProfile objectForKey: className];
  if(clsProfile != nil)
    {
      NSString *versionString = [clsProfile objectForKey: @"version"];
      if(versionString != nil)
	{
	  result = [versionString intValue];
	}
    }

  return result;
		      
}

/**
 * Current profile for the current model file.
 */
- (NSDictionary *) currentProfile;
{
  return currentProfile;
}

/**
 * Version information for the model file.
 */
- (NSDictionary *) versionProfiles;
{
  return versionProfiles;
}

- (BOOL) loadFromFile: (NSString *)path
{
  return [self loadFromData: [NSData dataWithContentsOfFile: path]];
}

- (BOOL) loadFromData: (NSData *)data
{
  BOOL result = YES;

  NS_DURING
    {
      GormFilePrefsManager *object = (GormFilePrefsManager *)
	[NSUnarchiver unarchiveObjectWithData: data];
      [gormAppVersion setStringValue: formatVersion([object version])];
      version = [object version];
      [targetVersion selectItemWithTitle: [object targetVersionName]];
      ASSIGN(targetVersionName,[object targetVersionName]);
      [archiveType selectItemWithTitle: [object archiveTypeName]];
      ASSIGN(archiveTypeName, [object archiveTypeName]);
      [self selectTargetVersion: targetVersion];
      result = YES;
    }
  NS_HANDLER
    {
      NSLog(@"Problem loading info file: %@",[localException reason]);
      result = NO;
    }
  NS_ENDHANDLER;
  
  return result;
}

// encoding...
- (void) encodeWithCoder: (NSCoder *)coder
{
  [coder encodeValueOfObjCType: @encode(int) at: &version];
  [coder encodeObject: targetVersionName];
  [coder encodeObject: archiveTypeName];
}

- (id) initWithCoder: (NSCoder *)coder
{
  if((self = [super init]) != nil)
    {
      [coder decodeValueOfObjCType: @encode(int) at: &version];
      targetVersionName = [coder decodeObject];
      archiveTypeName = [coder decodeObject];
    }

  return self;
}

// accessors
- (int) version
{
  return version;
}

- (NSString *)targetVersionName
{
  return targetVersionName;
}

- (NSString *)archiveTypeName
{
  return archiveTypeName;
}

- (BOOL) isLatest
{
  return ([targetVersionName isEqual: @"Latest Version"]);
}

- (void) setFileTypeName: (NSString *)ft
{
  [fileType setStringValue: ft];
}

- (NSString *) fileTypeName
{
  return [fileType stringValue];
}

// Data Source
- (NSInteger) numberOfRowsInTableView: (NSTableView *)aTableView
{
  return [currentProfile count];
}

- (id) tableView: (NSTableView *)aTableView 
objectValueForTableColumn: (NSTableColumn *)aTableColumn 
	     row: (NSInteger)rowIndex
{
  id obj = nil;

  if([[aTableColumn identifier] isEqual: @"item"])
    {
      obj = [NSString stringWithFormat: @"#%ld",(long int)rowIndex+1];
    }
  else if([[aTableColumn identifier] isEqual: @"description"])
    {
      NSArray *keys = [currentProfile allKeys];
      NSString *key = [keys objectAtIndex: rowIndex];
      NSDictionary *info = [currentProfile objectForKey: key];
      obj = [info objectForKey: @"comment"];
    }

  return obj;
}

- (void) tableView: (NSTableView *)aTableView 
    setObjectValue: (id)anObject 
    forTableColumn: (NSTableColumn *)aTableColumn
	       row: (NSInteger)rowIndex
{
}

@end

