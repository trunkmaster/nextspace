/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2014 Sergii Stoian
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

#import <Sizer.h>

#import "Inspector.h"

@class WMPermissions;

@interface FileAttributesInspector : Inspector
{
  // id window;  // important for connection with Workspace
  id view;
  id computeSizeBtn;
  id dateView;
  id fileGroupBtn;
  id fileOwnerBtn;
  id fileSizeField;
  id linkToField;
  WMPermissions *permissionsView;

  Sizer *sizer;
  NSImage *computeSizeBtnImage;
  NSImage *computeSizeBtnAlternateImage;

  NSString *path;
  NSArray  *files;

  NSDictionary *users;
  NSDictionary *groups;
  NSDictionary *myGroups;

  NSString *user;
  NSString *group;
  BOOL     modeChanged;
  unsigned oldMode;
  unsigned mode;
}

- (void) changeOwner:sender;
- (void) changeGroup:sender;
- (void) computeSize:sender;
- (void) changePerms:sender;

@end
