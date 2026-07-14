/* GormSoundEditor.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Gregory John Casamento <greg_casamento@yahoo.com>
 * Date:	2002
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

#include <AppKit/AppKit.h>

#include "GormSoundEditor.h"
#include "GormProtocol.h"
#include "GormFunctions.h"
#include "GormPalettesManager.h"
#include "GormSound.h"

@implementation	GormSoundEditor

static NSMapTable *docMap = 0;

+ (void) initialize
{
  if (self == [GormSoundEditor class])
    {
      docMap = NSCreateMapTable(NSNonRetainedObjectMapKeyCallBacks,
				NSNonRetainedObjectMapValueCallBacks, 2);
    }
}

+ (GormSoundEditor*) editorForDocument: (id<IBDocuments>)aDocument
{
  id	editor = NSMapGet(docMap, (void*)aDocument);

  if (editor == nil)
    {
      editor = [[self alloc] initWithObject: nil inDocument: aDocument];
      AUTORELEASE(editor);
    }
  return editor;
}

- (NSArray *) fileTypes
{
  return [NSSound soundUnfilteredFileTypes];
}

- (NSArray *)pbTypes
{
  return [NSArray arrayWithObject: GormSoundPboardType]; 
}

- (NSString *) resourceType
{
  return @"sound";
}

- (id) placeHolderWithPath: (NSString *)string
{
  return [GormSound soundForPath: string];
}

- (void) addSystemResources
{
  NSMutableArray    *list = [NSMutableArray array];
  NSEnumerator      *en;
  id                obj;
  GormPalettesManager *palettesManager = [(id<GormAppDelegate>)[NSApp delegate] palettesManager];
      
  // add all of the system objects...
  [list addObjectsFromArray: systemSoundsList()];
  [list addObjectsFromArray: [palettesManager importedSounds]];
  en = [list objectEnumerator];
  while((obj = [en nextObject]) != nil)
    {
      GormSound *sound = [GormSound soundForPath: obj];
      [sound setSystemResource: YES];
      [self addObject: sound];
    }  
}

/*
 *	Initialisation - register to receive DnD with our own types.
 */
- (id) initWithObject: (id)anObject inDocument: (id<IBDocuments>)aDocument
{
  id	old = NSMapGet(docMap, (void*)aDocument);

  if (old != nil)
    {
      RELEASE(self);
      self = RETAIN(old);
      [self addObject: anObject];
      return self;
    }

  if ((self = [super initWithObject: anObject inDocument: aDocument]) != nil)
    {
      NSMapInsert(docMap, (void*)aDocument, (void*)self);
    }

  return self;
}

- (void) willCloseDocument: (NSNotification *)aNotification
{
  NSMapRemove(docMap,document);
  [super willCloseDocument: aNotification];
}

- (void) close
{
  [super close];
  NSMapRemove(docMap,document);
}
@end
