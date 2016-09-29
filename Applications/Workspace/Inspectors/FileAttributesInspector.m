/*
  FileAttributesInspector.m

  The "File Atrributes" inspector.

  Copyright (C) 2014 Sergii Stoian
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
  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import <AppKit/AppKit.h>
#import <NXAppKit/NXAppKit.h>

#import <ProcessManager.h>

#import "FileAttributesInspector.h"
#import "WMPopUp.h"
#import "WMPermissions.h"

#import <sys/types.h>
#import <grp.h>
#import <pwd.h>
#import <unistd.h>

//#ifdef Linux
//#import <sys/capability.h>
//#endif

@interface FileAttributesInspector (Private)

// size
- (NSString *)_stringFromSize:(unsigned long long)filesize;
- (NSString *)_sizeOfSelection;
- (void)_updateSize;

 // find all user accounts on this machine
- (void)locateUsers;
 // find all groups on this machine + mark all that we're a member of
- (void)locateGroups;

- (void)updateOwner;
- (void)updateGroup;

@end

@implementation FileAttributesInspector (Private)

- (NSString *)_stringFromSize:(unsigned long long)filesize
{
  if (filesize < 5 * 1024)
    return [NSString stringWithFormat: _(@"%u Bytes"),
                     (unsigned int) filesize];
  else if (filesize < 1024 * 1024)
    return [NSString stringWithFormat: _(@"%.2f KB"),
                     (CGFloat) filesize / 1024];
  else if (filesize < ((unsigned long long) 1024 * 1024 * 1024))
    return [NSString stringWithFormat: _(@"%.2f MB"),
                     (CGFloat) filesize / (1024 * 1024)];
  else
    return [NSString stringWithFormat: _(@"%.3f GB"),
                     (CGFloat) filesize / (1024 * 1024 * 1024)];
}

- (NSString *)_sizeOfSelection
{
  int i;
  NSMutableArray        *pathArray = [NSMutableArray new];
  NSDirectoryEnumerator *de;
  NSDictionary          *fattrs;
  NSFileManager         *fm = [NSFileManager defaultManager];
  unsigned long long    totalSize = 0;

  for (i=0; i<[files count]; i++)
    {
      [pathArray addObject:
                   [path stringByAppendingPathComponent:
                                   [files objectAtIndex:i]]];
    }

  for (NSString *file in pathArray)
    {
      fattrs = [fm fileAttributesAtPath:file traverseLink:NO];
      if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory])
        {
          // Directories
          de = [fm enumeratorAtPath:file];
          while ([de nextObject] != nil
                 && (fattrs = [de fileAttributes]) != nil)
            {
              totalSize += [fattrs fileSize];
            }
        }
      else
        {
          totalSize += [fattrs fileSize];
        }
    }

  return [self _stringFromSize:totalSize];
}

// 'Size:' field and 'Compute Size' button.
// If one or many files selected - size of selection displayed in field,
// button disabled.
// If any directory selected - empty field and enable button.
- (void)_updateSize
{
  NSDictionary   *fattrs;
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSString       *fPath;
  int            i;
  BOOL           computeSize = YES;
  
  for (i=0; i<[files count]; i++)
    {
      fPath = [path stringByAppendingPathComponent:[files objectAtIndex:i]];
      fattrs = [fm fileAttributesAtPath:fPath traverseLink:NO];
      if ([[fattrs fileType] isEqualToString:NSFileTypeDirectory] &&
          [fm isReadableFileAtPath:fPath])
        {
          computeSize = NO;
          break;
        }
    }

  if (computeSize) // only files was selected
    {
      [fileSizeField setStringValue:[self _sizeOfSelection]];
      [computeSizeBtn setImage:computeSizeBtnAlternateImage];
      [computeSizeBtn setEnabled:NO];
    }
  else
    {
      [fileSizeField setStringValue:nil];
      [computeSizeBtn setImage:computeSizeBtnImage];
      [computeSizeBtn setEnabled:YES];
    }
}

// Sizer:BGOperation notification selector.
- (void)_showSizeOfSelection:(NSNotification *)notif
{
  NSDictionary       *info = [notif userInfo];
  unsigned long long size;

  [[NSNotificationCenter defaultCenter]
    removeObserver:self
              name:WMSizerGotNumbersNotification
            object:[notif object]];

  [[notif object] release];
  
  if (info)
    {
      size = [[info objectForKey:@"Size"] unsignedLongLongValue];
      // NSLog(@"Inspector: got size: %llu", size);
      [fileSizeField setStringValue:[self _stringFromSize:size]];
    }
  else
    {
      [fileSizeField setStringValue:@""];
    }
  
  sizer = nil;
  
  [fileSizeField setTextColor:[NSColor blackColor]];
  [computeSizeBtn setImage:computeSizeBtnImage];
  [computeSizeBtn setEnabled:YES];
}

- (void)locateUsers
{
  struct passwd       *pwd;
  NSMutableDictionary *usrs = [NSMutableDictionary dictionary];

  while ((pwd = getpwent()) != NULL)
    {
      [usrs setObject:[NSNumber numberWithInt:pwd->pw_uid]
               forKey:[NSString stringWithCString:pwd->pw_name]];
    }

  users = [usrs copy];
}

- (void)locateGroups
{
  NSString            *userName = NSUserName();
  struct group        *groupEntry;
  NSMutableDictionary *allGrs = [NSMutableDictionary dictionary];
  NSMutableDictionary *myGrs = [NSMutableDictionary dictionary];

  while ((groupEntry = getgrent()) != NULL)
    {
      char     *member;
      unsigned i;
      NSNumber *gid = [NSNumber numberWithInt:groupEntry->gr_gid];
      NSString *gname = [NSString stringWithCString:groupEntry->gr_name];

      [allGrs setObject:gid forKey:gname];

      for (i=0; (member = groupEntry->gr_mem[i]) != NULL; i++)
        {
          if ([userName isEqualToString:[NSString stringWithCString:member]])
            {
              [myGrs setObject:gid forKey:gname];
              break;
            }
        }
    }

  // add our own group
  groupEntry = getgrgid(getegid());
  [myGrs setObject:[NSNumber numberWithInt:groupEntry->gr_gid]
            forKey:[NSString stringWithCString:groupEntry->gr_name]];

  if (geteuid() == 0)
    ASSIGN(groups, allGrs);
  else
    ASSIGN(groups, myGrs);
}

- (void)updateOwner
{
  NSArray       *sortedUsers = nil;
  NSString      *selectedTitle = nil;
  NSString      *f;
  NSString      *fp;
  NSDictionary  *fattrs;
  NSEnumerator  *e;
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          enableBtn = NO;
  
  [fileOwnerBtn removeAllItems];

  // We're root: fill popup with users and define button state to YES
  if (geteuid() == 0)
    {
      if (users == nil)
        {
          [self locateUsers];
        }

      sortedUsers = [[users allKeys] sortedArrayUsingSelector:
                             @selector(caseInsensitiveCompare:)];
      [fileOwnerBtn addItemsWithTitles:sortedUsers];
      enableBtn = YES;
    }

  // Define selected title in popup
  if ([files count] > 1)
    {
      e = [files objectEnumerator];
      while ((f = [e nextObject]) != nil)
        {
          fp = [path stringByAppendingPathComponent:f];
          fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
          if (selectedTitle == nil)
            {
              selectedTitle = [fattrs fileOwnerAccountName];
            }
          
          // owner of one of the file differs: get out of 'while'
          if (![selectedTitle isEqualToString:[fattrs fileOwnerAccountName]])
            {
              selectedTitle = @"---";
              break;
            }
        }
    }
  else
    {
      fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
      fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
      selectedTitle = [fattrs fileOwnerAccountName];
    }

  [fileOwnerBtn setEnabled:enableBtn];
  [fileOwnerBtn addItemWithTitle:selectedTitle];
  [fileOwnerBtn selectItemWithTitle:selectedTitle];
}

- (void)updateGroup
{
  NSArray  *sortedGroups = nil;
  NSString *selectedTitle = nil;

  NSString      *f;
  NSString      *fp;
  NSDictionary  *fattrs;
  NSEnumerator  *e;
  NSFileManager *fm = [NSFileManager defaultManager];
  BOOL          enableBtn = NO;

  [fileGroupBtn removeAllItems];

  // Fill popup with groups
  if (groups == nil)
    {
      [self locateGroups];
    }
  sortedGroups = [[groups allKeys] sortedArrayUsingSelector:
                           @selector(caseInsensitiveCompare:)];
  [fileGroupBtn addItemsWithTitles:sortedGroups];
  
  if (geteuid() == 0)
    {
      [fileGroupBtn setEnabled:YES];
    }

  // Define selected title in popup
  if ([files count] > 1)
    {
      e = [files objectEnumerator];
      while ((f = [e nextObject]) != nil)
        {
          fp = [path stringByAppendingPathComponent:f];
          fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
          if (selectedTitle == nil)
            {
              selectedTitle = [fattrs fileGroupOwnerAccountName];
              enableBtn = [[fattrs fileOwnerAccountName] isEqual:NSUserName()];
            }
          if (enableBtn == YES)
            {
              enableBtn = [[fattrs fileOwnerAccountName] isEqual:NSUserName()];
            }
          
          // group of one of the file differs: get out of 'while'
          if (![selectedTitle
                 isEqualToString:[fattrs fileGroupOwnerAccountName]])
            {
              selectedTitle = @"---";
              break;
            }
        }
    }
  else
    {
      fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
      fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];

      enableBtn = [[fattrs fileOwnerAccountName] isEqual:NSUserName()];

      selectedTitle = [fattrs fileGroupOwnerAccountName];
    }

  [fileGroupBtn setEnabled:enableBtn];
  [fileGroupBtn addItemWithTitle:selectedTitle];
  [fileGroupBtn selectItemWithTitle:selectedTitle];
}

@end

@implementation FileAttributesInspector

static id attributesInspector = nil;

+ new
{
  if (attributesInspector == nil)
    {
      self = attributesInspector = [super new];

      [NSPopUpButton setCellClass:[PopUpListCell class]];

      if (![NSBundle loadNibNamed:@"FileAttributesInspector"
                            owner:attributesInspector])
        {
          attributesInspector = nil;
        }
    }

  return attributesInspector;
}

- (void)awakeFromNib
{
  NSLog(@"[FileAttributesInspector] awakeFromNib");

  [linkToField setTextColor:[NSColor darkGrayColor]];

  [fileOwnerBtn setCell:[PopUpListCell new]];
  [fileOwnerBtn setTarget:self];
  [fileOwnerBtn setAction:@selector(changeOwner:)];

  [fileGroupBtn setCell:[PopUpListCell new]];
  [fileGroupBtn setTarget:self];
  [fileGroupBtn setAction:@selector(changeGroup:)];

  [permissionsView setDisplaysExecute:YES];
  [permissionsView setTarget:self];
  [permissionsView setAction:@selector(changePerms:)];

  ASSIGN(computeSizeBtnImage, [computeSizeBtn image]);
  ASSIGN(computeSizeBtnAlternateImage, [computeSizeBtn alternateImage]);
  
  [dateView setYearVisible:YES];

  sizer = nil;
  
  NSLog(@"[FileAttributesInspector] awakeFromNib END");
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"FileAttributesInspector: dealloc");

  TEST_RELEASE(path);
  TEST_RELEASE(files);

  TEST_RELEASE(users);
  TEST_RELEASE(groups);

  TEST_RELEASE(user);
  TEST_RELEASE(group);

  TEST_RELEASE(view);

  [super dealloc];
}


// --- Actions ---

- (void)changeOwner:sender
{
  ASSIGN(user, [sender titleOfSelectedItem]);
  [super touch:self];
}

- (void)changeGroup:sender
{
  ASSIGN(group, [sender titleOfSelectedItem]);
  [super touch:self];
}

- (void)computeSize:sender
{
  [fileSizeField setTextColor:[NSColor darkGrayColor]];
  [fileSizeField setStringValue:@"Computing..."];
  [computeSizeBtn setImage:computeSizeBtnAlternateImage];
  [computeSizeBtn setEnabled:NO];

  sizer = [[Sizer alloc] initWithOperationType:SizeOperation
                                     sourceDir:path
                                     targetDir:nil
                                         files:files
                                       manager:[ProcessManager shared]];

  [[NSNotificationCenter defaultCenter]
    addObserver:self
       selector:@selector(_showSizeOfSelection:)
           name:WMSizerGotNumbersNotification
         object:sizer];
}

- (void)changePerms:sender
{
  mode = [permissionsView mode];
  [super touch:self];
}


// --- Overridings and bundle.registry ---

// FIXME
- (BOOL)isLocalFile
{
  NSString *defaultAppName;
  NSString *fileType;
  NSString *fp;
  NSString *selectedPath = nil;
  NSArray  *selectedFiles = nil;

  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];
  
  fp = [selectedPath
         stringByAppendingPathComponent:[selectedFiles objectAtIndex:0]];
  [[NSApp delegate] getInfoForFile:fp
                       application:&defaultAppName
                              type:&fileType];

  if ([fileType isEqualToString:NSFilesystemFileType])
    {
      return NO;
    }

  return YES;
}

- (void)ok:sender
{
  NSFileManager       *fm = [NSFileManager defaultManager];
  NSMutableDictionary *fattrs;
  int                 uid, gid;
  NSEnumerator        *e = [files objectEnumerator];
  NSString            *file, *fp;

  NSLog(@"FileAttributesInspector: ok:%@ %@", [sender className], path);

  // Get UID and GID to apply
  if (user)
    uid = [[users objectForKey:user] intValue];
  else
    uid = -1;
  
  if (group)
    gid = [[groups objectForKey:group] intValue];
  else
    gid = -1;

  // Apply changes to file
  while ((file = [e nextObject]) != nil)
    {
      fp = [path stringByAppendingPathComponent:file];
      
      // Permissions changed
      if (mode != oldMode)
        {
          fattrs = [[fm fileAttributesAtPath:fp traverseLink:NO] mutableCopy];
          [fattrs setObject:[NSNumber numberWithInt:mode]
                     forKey:NSFilePosixPermissions];
          [fm changeFileAttributes:fattrs atPath:fp];
          RELEASE(fattrs);
        }

      // Owner and group
      chown([fp cString], uid, gid);
    }
  
  [super revert:self];
}

- revert:sender
{
  NSCalendarDate *modDate;
  NSDictionary   *fattrs;
  NSFileManager  *fm = [NSFileManager defaultManager];
  NSString       *selectedPath = nil;
  NSArray        *selectedFiles = nil;
  NSString       *fp;

  if (sizer) [sizer stop:self];
 
  [self getSelectedPath:&selectedPath andFiles:&selectedFiles];

  if (sender != [self revertButton] &&
      [path isEqualToString:selectedPath] &&
      [files isEqualToArray:selectedFiles])
    {
      return self;
    }

  // NSLog(@"FAI revert: %@ %@", selectedPath, selectedFiles);
  
  ASSIGN(path, selectedPath);
  ASSIGN(files, selectedFiles);

  // Link To: initial value
  [linkToField setText:@""];

  // Size:
  [self _updateSize];
  
  // Ownership
  DESTROY(user);
  DESTROY(group);
  [self updateOwner];
  [self updateGroup];

  fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
  fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
  if ([files count] == 1)
    {
      // Link To: (NSTextView)
      if ([[fattrs fileType] isEqualToString:NSFileTypeSymbolicLink])
        {
          [linkToField setText:[fm pathContentOfSymbolicLinkAtPath:fp]];
        }

      // Permissions
      modeChanged = NO;
      oldMode = mode = [fattrs filePosixPermissions];
      [permissionsView setMode:mode];
      [permissionsView setNoChangeMask:0000];
      if (![[fattrs fileOwnerAccountName] isEqualToString:NSUserName()]
          && geteuid() != 0)
        [permissionsView setEditable:NO];
      else
        [permissionsView setEditable:YES];
      
      // Date
      modDate = [[fattrs fileModificationDate]
                  dateWithCalendarFormat:nil
                                timeZone:[NSTimeZone localTimeZone]];
      [dateView setCalendarDate:modDate];
    }
  else
    {
      unsigned long mask = 0, m, om;
      NSEnumerator  *e = [files objectEnumerator];
      NSString      *file, *fp;
      NSTimeZone    *tz;

      // First file permission will be XOR'ed with other files' permissions
      fp = [path stringByAppendingPathComponent:[e nextObject]];
      fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
      om = [fattrs filePosixPermissions];
      while ((file = [e nextObject]) != nil)
        {
          fp = [path stringByAppendingPathComponent:file];
          fattrs = [fm fileAttributesAtPath:fp traverseLink:NO];
          m = [fattrs filePosixPermissions];
          
          // XOR 2 files' permissions - non-equal bits return '1'
          // OR result with 'mask' bits - '1' bits in mask remains '1'
          mask = mask | (om ^ m);
          om = m;
        }
      
      // Display permissions
      // TODO: make multiple files permissions editable
      [permissionsView setNoChangeMask:mask];
      [permissionsView setMode:m]; // last file permissions in selection
      [permissionsView setEditable:NO];

      // Date
      tz = [NSTimeZone timeZoneForSecondsFromGMT:0];
      [dateView setCalendarDate:[[NSDate dateWithTimeIntervalSince1970:0]
                                  dateWithCalendarFormat:nil
                                                timeZone:tz]];
    }

  // Buttons and window edited state
  [super revert:self];

  // NSLog(@"File Attributes Inspector: revert END!");
  return self;
}

@end
