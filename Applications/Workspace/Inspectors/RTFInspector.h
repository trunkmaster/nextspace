/*
  RTFInspector.h

  The default file contents inspector. 
  Shows file description returned by NXFileManager (libmagic functionality).

  Copyright (C) 2014 Sergii Stoian

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
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>

#import <Workspace.h>

@interface RTFInspector : WMInspector
{
  id view;
  id fileInfoText;
  id linesLabel;
  id linesField;
  id encodingLabel;
  id encodingField;

  NSString *selectedPath;
  NSArray  *selectedFiles;

}

@end
