/* GormPluginManager.m
 *
 * Copyright (C) 1999 Free Software Foundation, Inc.
 *
 * Author:	Richard Frith-Macdonald <richard@brainstrom.co.uk>
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	1999, 2004, 2008
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

#include <GNUstepBase/GSObjCRuntime.h>

#include "GormPrivate.h"
#include "GormFunctions.h"
#include "GormPluginManager.h"

#define BUILTIN_PLUGINS @"BuiltinPlugins"
#define USER_PLUGINS    @"UserPlugins"

@implementation GormPluginManager

- (void) dealloc
{
  [[NSNotificationCenter defaultCenter] removeObserver: self];
  RELEASE(bundles);
  RELEASE(plugins);
  RELEASE(pluginsDict);
  [super dealloc];
}

- (id) init
{
  NSArray	 *array;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray        *userPlugins = [defaults arrayForKey: USER_PLUGINS];
  NSBundle       *bundle = [NSBundle bundleForClass: [self class]];
  
  self = [super init];
  if (self == nil)
    {
      return nil;
    }
  
  //
  // Initialize dictionary
  //
  pluginsDict = [[NSMutableDictionary alloc] init];
  plugins = [[NSMutableArray alloc] init];
  pluginNames = [[NSMutableArray alloc] init];
 
  array = [bundle pathsForResourcesOfType: @"plugin"
			      inDirectory: nil];
  if ([array count] > 0)
    {
      unsigned	index;
      
      array = [array sortedArrayUsingSelector: @selector(compare:)];
      
      for (index = 0; index < [array count]; index++)
	{
	  [self loadPlugin: [array objectAtIndex: index]];
	}
    }
  
  // if we have any user plugins load them as well.
  if(userPlugins != nil)
    {
      NSEnumerator *en = [userPlugins objectEnumerator];
      id pluginName = nil;
      while((pluginName = [en nextObject]) != nil)
        {
          [self loadPlugin: pluginName];
        }
    }

  return self;
}

- (BOOL) bundlePathIsLoaded: (NSString *)path
{
  int		col = 0;  
  NSBundle	*bundle;
  for (col = 0; col < [bundles count]; col++)
    {
      bundle = [bundles objectAtIndex: col];
      if ([path isEqualToString: [bundle bundlePath]] == YES)
	{
	  return YES;
	}
    }
  return NO;
}

- (BOOL) loadPlugin: (NSString*)path
{
  NSBundle	*bundle;
  NSString	*className;
  IBPlugin	*plugin;
  Class		pluginClass;

  if([self bundlePathIsLoaded: path])
    {
      NSRunAlertPanel (nil, _(@"Plugin has already been loaded"), 
		       _(@"OK"), nil, nil);
      return NO;
    }
  bundle = [NSBundle bundleWithPath: path]; 
  if (bundle == nil)
    {
      NSRunAlertPanel(nil, _(@"Could not load Plugin"), 
		      _(@"OK"), nil, nil);
      return NO;
    }

  className = [[bundle infoDictionary] objectForKey: @"NSPrincipalClass"];
  if (className == nil)
    {
      NSRunAlertPanel(nil, _(@"No plugin class in plist"),
		      _(@"OK"), nil, nil);
      return NO;
    }

  pluginClass = [bundle classNamed: className];
  if (pluginClass == 0)
    {
      NSRunAlertPanel (nil, _(@"Could not load plugin class"), 
		       _(@"OK"), nil, nil);
      return NO;
    }

  plugin = [[pluginClass alloc] init];
  if ([plugin isKindOfClass: [IBPlugin class]] == NO)
    {
      NSRunAlertPanel (nil, _(@"Plugin contains wrong type of class"), 
		       _(@"OK"), nil, nil);
      RELEASE(plugin);
      return NO;
    }

  // add to the bundles list...
  [bundles addObject: bundle];	
  [plugin didLoad];

  // manage plugin data.
  [pluginsDict setObject: plugin forKey: className];
  [plugins addObject: plugin];
  [pluginNames addObject: className];

  RELEASE(plugin);

  return YES;
}

- (id) openPlugin: (id) sender
{
  NSArray	 *fileTypes = [NSArray arrayWithObject: @"plugin"];
  NSOpenPanel	 *oPanel = [NSOpenPanel openPanel];
  int		 result;
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSArray        *userPlugins = [defaults arrayForKey: USER_PLUGINS];
  NSMutableArray *newUserPlugins = 
    (userPlugins == nil)?[NSMutableArray array]:[NSMutableArray arrayWithArray: userPlugins];

  [oPanel setAllowsMultipleSelection: YES];
  [oPanel setCanChooseFiles: YES];
  [oPanel setCanChooseDirectories: NO];
  result = [oPanel runModalForDirectory: NSHomeDirectory()
				   file: nil
				  types: fileTypes];

  if (result == NSOKButton)
    {
      NSArray	*filesToOpen = [oPanel filenames];
      unsigned	count = [filesToOpen count];
      unsigned	i;

      for (i = 0; i < count; i++)
	{
	  NSString	*aFile = [filesToOpen objectAtIndex: i];

	  if([self bundlePathIsLoaded: aFile] == YES &&
	     [userPlugins containsObject: aFile] == NO)
	    {
	      [newUserPlugins addObject: aFile];
	    }
	  else if([self loadPlugin: aFile] == NO)
	    {
	      return nil;
	    }
	  else
	    {
	      [newUserPlugins addObject: aFile];
	    }
	}

      // reset the defaults to include the new plugin.
      [defaults setObject: newUserPlugins forKey: USER_PLUGINS];
      return self;
    }
  return nil;
}

@end
