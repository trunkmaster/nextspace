/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2001-2021 Free Software Foundation

   Author: Serg Stoyan <stoyan@on.com.ua>
           Riccardo Mottola <rm@gnu.org>

   This file is part of GNUstep.

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#import <Foundation/NSFileManager.h>
#import <ProjectCenter/PCMakefileFactory.h>

#import "PCAppProject+Inspector.h"

// ----------------------------------------------------------------------------
// --- Customized text field
// ----------------------------------------------------------------------------
NSString *PCITextFieldGetFocus = @"PCITextFieldGetFocusNotification";

static void
setOrRemove(NSMutableDictionary *m, id v, NSString *k)
{
  if ([v isKindOfClass: [NSString class]])
    {
      v = [v stringByTrimmingSpaces];
      if ([v length] == 0)
	v = nil;
    }
  else if ([v isKindOfClass: [NSArray class]])
    {
      if ([v count] == 0)
	v = nil;
    }
  if (v == nil)
    [m removeObjectForKey: k];
  else
    [m setObject: v forKey: k];
}

static id
cleanup(NSMutableDictionary *m, NSString *k)
{
  id	v;

  setOrRemove(m, [m objectForKey: k], k);
  v = [m objectForKey: k];
  if (v == nil)
    v = @"";
  return v;
}


@implementation PCAppTextField

- (BOOL)becomeFirstResponder
{
  [[NSNotificationCenter defaultCenter]
    postNotificationName:PCITextFieldGetFocus
                  object:self];
		  
  return [super becomeFirstResponder];
}

@end

@implementation PCAppProject (Inspector)

- (void)awakeFromNib
{
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(tfGetFocus:)
                                               name:PCITextFieldGetFocus
                                             object:nil];

  // Icon view
  [iconView setImage:nil];
  [iconView setDelegate:self];

  // Help text view
  [helpText setDrawsBackground:NO];
  [helpText setTextColor:[NSColor darkGrayColor]];
  [helpText setFont:[NSFont systemFontOfSize:10.0]];
  [helpText setText:@"Click on the field and drop file in the box above"];

  // Document types buttons
  [addDocTypeButton setRefusesFirstResponder:YES];
  [removeDocTypeButton setRefusesFirstResponder:YES];
  [docBasedAppButton setRefusesFirstResponder:YES];
  
  [docBasedAppButton setState:
    ([[projectDict objectForKey:PCDocumentBasedApp]
     isEqualToString:@"YES"]) ? NSOnState : NSOffState];
  [self setDocBasedApp:docBasedAppButton];

  [self updateInspectorValues:nil];
}

// ----------------------------------------------------------------------------
// --- User Interface
// ----------------------------------------------------------------------------

- (NSView *)projectAttributesView
{
  if (!projectAttributesView)
    {
      if ([NSBundle loadNibNamed: @"Inspector" owner: self] == NO)
	{
	  NSLog(@"PCAppProject: error loading Inspector NIB!");
	  return nil;
	}
      [projectAttributesView retain];
    }

  return projectAttributesView;
}

// ----------------------------------------------------------------------------
// --- Actions
// ----------------------------------------------------------------------------

- (IBAction)setAppType:(id)sender
{
  NSString       *appType = [appTypeField stringValue];
  NSMutableArray *libs = [[projectDict objectForKey:PCLibraries] mutableCopy];

  if ([appType isEqualToString:@"Renaissance"])
    {
      [libs addObject:@"Renaissance"];
    }
  else
    {
      [libs removeObject:@"Renaissance"];
    }

  [self setProjectDictObject:libs forKey:PCLibraries notify:YES];
  RELEASE(libs);
  [self setProjectDictObject:appType forKey:PCAppType notify:YES];
}

- (IBAction)setAppClass:(id)sender
{
  [self setProjectDictObject:[appClassField stringValue]
                      forKey:PCPrincipalClass
		      notify:YES];
}

- (IBAction)setBundleIdentifier:(id)sender
{
  [self setProjectDictObject:[bundleIdentifierField stringValue]
                      forKey:PCBundleIdentifier
		      notify:YES];
}

// Application Icon
- (void)clearAppIcon:(id)sender
{
  [appImageField setStringValue:@""];
  [infoDict setObject:@"" forKey:@"NSIcon"];
  [infoDict setObject:@"" forKey:@"ApplicationIcon"];
  
  [self setProjectDictObject:@"" forKey:PCAppIcon notify:YES];
}

- (BOOL)setAppIconWithFileAtPath:(NSString *)path
{
  NSImage       *image = [[NSImage alloc] initWithContentsOfFile:path];
  NSString      *imageName = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray       *fileTypes = [self fileTypesForCategoryKey:PCImages];

  NSLog(@"setAppIconWithFileAtPath -- %@", path);

  // TODO: GNUstep bug - NSImage should return nil if image cannot
  // be created, but it doesn't
  if (!path || !image || ![fm fileExistsAtPath:path]
       || ![fileTypes containsObject:[path pathExtension]])
    {
      [iconView setImage:nil];
      [self clearAppIcon:self];
      return NO;
    }

  // TODO: Image nil here even if 'path' exists. Why? It results in
  // empty imageView on drag&drop operation.
  [iconView setImage:image];

  imageName = [path lastPathComponent];
  [appImageField setStringValue:imageName];

  [self addAndCopyFiles:[NSArray arrayWithObject:path] forKey:PCImages];
  
  [infoDict setObject:imageName forKey:@"NSIcon"];
  [infoDict setObject:imageName forKey:@"ApplicationIcon"];

  [self setProjectDictObject:imageName forKey:PCAppIcon notify:YES];

  return YES;
}

// Help file
- (void)clearHelpFile:(id)sender
{
  [infoDict removeObjectForKey:@"GSHelpContentsFile"];
  [self setProjectDictObject:@"" forKey:PCHelpFile notify:YES];
}

- (IBAction)setHelpFile:(id)sender
{
  [self setProjectDictObject:[helpFileField stringValue]
                      forKey:PCHelpFile
		      notify:YES];
}

// Main Interface File
- (void)clearMainNib: (id)sender
{
  [mainNIBField setStringValue:@""];
  [infoDict setObject:@"" forKey:@"NSMainNibFile"];

  [self setProjectDictObject:@"" forKey:PCMainInterfaceFile notify:YES];
}

- (BOOL)setMainNibWithFileAtPath: (NSString *)path
{
  NSString      *nibName = [path lastPathComponent];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray       *fileTypes = [self fileTypesForCategoryKey:PCInterfaces];

  // TODO: check if it's interface file and it exists
  if (![fm fileExistsAtPath:path]
      || ![fileTypes containsObject:[path pathExtension]])
    {
      [iconView setImage:nil];
      [self clearMainNib:self];
      return NO;
    }

  [iconView setImage:[[NSWorkspace sharedWorkspace] iconForFile:path]];

  [self addAndCopyFiles:[NSArray arrayWithObject: path] forKey:PCInterfaces];
  [infoDict setObject:nibName forKey:@"NSMainNibFile"];

  [self setProjectDictObject:nibName forKey:PCMainInterfaceFile notify:YES];

  [mainNIBField setStringValue:nibName];

  return YES;
}

// Document Types
- (void)showDocTypesPanel: (id)sender
{
  [docTypesPanel makeKeyAndOrderFront: nil];
}

- (IBAction)setDocBasedApp: (id)sender
{
  NSString *docBased = [projectDict objectForKey: PCDocumentBasedApp];

  if ([docBasedAppButton state] == NSOnState)
    {
      [docTypeLabel setTextColor: [NSColor blackColor]];
      [docTypeField setBackgroundColor: [NSColor whiteColor]];
      [docTypeField setTextColor: [NSColor blackColor]];
      [docTypeField setEditable: YES];

      [docNameLabel setTextColor: [NSColor blackColor]];
      [docNameField setBackgroundColor: [NSColor whiteColor]];
      [docNameField setTextColor: [NSColor blackColor]];
      [docNameField setEditable: YES];

      [docRoleLabel setTextColor: [NSColor blackColor]];
      [docRoleField setBackgroundColor: [NSColor whiteColor]];
      [docRoleField setTextColor: [NSColor blackColor]];
      [docRoleField setEditable: YES];

      [docClassLabel setTextColor: [NSColor blackColor]];
      [docClassField setBackgroundColor: [NSColor whiteColor]];
      [docClassField setTextColor: [NSColor blackColor]];
      [docClassField setEditable: YES];

      [nameColumn setIdentifier: @"NSHumanReadableName"];
      [[nameColumn headerCell] setStringValue: @"Name"];
      [docTypesList addTableColumn: roleColumn];
      [docTypesList addTableColumn: classColumn];
      RELEASE(roleColumn);
      RELEASE(classColumn);
      
      if (![docBased isEqualToString: @"YES"])
	{
	  [self setProjectDictObject: @"YES" 
	                      forKey: PCDocumentBasedApp
			      notify: YES];
	}
    }
  else
    {
      [docTypeLabel setTextColor: [NSColor darkGrayColor]];
      [docTypeField setBackgroundColor: [NSColor lightGrayColor]];
      [docTypeField setTextColor: [NSColor darkGrayColor]];
      [docTypeField setEditable: NO];

      [docNameLabel setTextColor: [NSColor darkGrayColor]];
      [docNameField setBackgroundColor: [NSColor lightGrayColor]];
      [docNameField setTextColor: [NSColor darkGrayColor]];
      [docNameField setEditable: NO];

      [docRoleLabel setTextColor: [NSColor darkGrayColor]];
      [docRoleField setBackgroundColor: [NSColor lightGrayColor]];
      [docRoleField setTextColor: [NSColor darkGrayColor]];
      [docRoleField setEditable: NO];

      [docClassLabel setTextColor: [NSColor darkGrayColor]];
      [docClassField setBackgroundColor: [NSColor lightGrayColor]];
      [docClassField setTextColor: [NSColor darkGrayColor]];
      [docClassField setEditable: NO];

      // Columns
//      [docTypesList removeTableColumn:nameColumn];
      [nameColumn setIdentifier: @"NSIcon"];
      [[nameColumn headerCell] setStringValue: @"Icon"];
      RETAIN(roleColumn);
      RETAIN(classColumn);
      [docTypesList removeTableColumn: roleColumn];
      [docTypesList removeTableColumn: classColumn];
      
      if (![docBased isEqualToString: @"NO"])
	{
	  [self setProjectDictObject: @"NO" 
	                      forKey: PCDocumentBasedApp
			      notify: YES];
	}
    }
}

- (IBAction)addDocType: (id)sender
{
  NSInteger           row;
  NSMutableDictionary *entry = [NSMutableDictionary dictionaryWithCapacity: 6];
  NSInteger           selectedRow = [docTypesList selectedRow];

  setOrRemove(entry, [docTypeField stringValue], @"NSName");
  setOrRemove(entry, [docNameField stringValue], @"NSHumanReadableName");
  setOrRemove(entry, [[docExtensionsField stringValue] componentsSeparatedByString: @","], @"NSUnixExtensions");
  setOrRemove(entry, [docIconField stringValue], @"NSIcon");
  setOrRemove(entry, [docRoleField stringValue], @"NSRole");
  setOrRemove(entry, [docClassField stringValue], @"NSDocumentClass");

  if (selectedRow >= 0 && [docTypesItems count] > 0)
    {
      [docTypesItems insertObject: entry atIndex: selectedRow + 1];
      row = selectedRow + 1;
    }
  else
    {
      [docTypesItems addObject: entry];
      row = [docTypesItems count] - 1;
    }
  [docTypesList reloadData];
  
  [docTypesList selectRow: row byExtendingSelection: NO];

  [self fillFieldsForRow: row];

  [self setProjectDictObject: docTypesItems 
                      forKey: PCDocumentTypes
		      notify: YES];
}

- (IBAction)removeDocType: (id)sender
{
  int selectedRow = [docTypesList selectedRow];

  if (selectedRow >= 0)
    {
      [docTypesItems removeObjectAtIndex: selectedRow];
      [docTypesList reloadData];
    }

  if (([docTypesList selectedRow] < 0) && ([docTypesItems count] > 0))
    {
      [docTypesList selectRow: [docTypesItems count]-1
	 byExtendingSelection: NO];
      [self fillFieldsForRow: [docTypesItems count]-1];
    }

  [self setProjectDictObject: docTypesItems
                      forKey: PCDocumentTypes
                      notify: YES];
}

- (void)docFieldSet: (id)sender
{
  NSMutableDictionary *object = nil;
 
  NSLog(@"docFieldSet");

  if (sender != docTypeField && sender != docNameField 
    && sender != docIconField && sender != docExtensionsField
    && sender != docRoleField && sender != docClassField)
    {
      return;
    }
    
  if ([docTypesItems count] <= 0)
    {
      [self addDocType: addDocTypeButton];
    }

  object = [[docTypesItems objectAtIndex: [docTypesList selectedRow]] 
    mutableCopy];

  if (sender == docTypeField)
    {
      setOrRemove(object, [sender stringValue], @"NSName");
    }
  else if (sender == docNameField)
    {
      setOrRemove(object, [sender stringValue], @"NSHumanReadableName");
    }
  else if (sender == docIconField)
    {
      setOrRemove(object, [sender stringValue], @"NSIcon");
    }
  else if (sender == docExtensionsField)
    {
      setOrRemove(object,
	[[sender stringValue] componentsSeparatedByString: @","],
	@"NSUnixExtensions");
    }
  else if (sender == docRoleField)
    {
      setOrRemove(object, [sender stringValue], @"NSRole");
    }
  else if (sender == docClassField)
    {
      setOrRemove(object, [sender stringValue], @"NSDocumentClass");
    }

  [docTypesItems replaceObjectAtIndex: [docTypesList selectedRow] 
                          withObject: object];
  [docTypesList reloadData];
  [object release];
}

// ----------------------------------------------------------------------------
// --- Document Types browser
// ----------------------------------------------------------------------------

- (NSInteger)numberOfRowsInTableView: (NSTableView *)aTableView
{
  return [docTypesItems count];
}
    
- (id)            tableView: (NSTableView *)aTableView
  objectValueForTableColumn: (NSTableColumn *)aTableColumn
                        row: (NSInteger)rowIndex
{
  NSDictionary *object = nil;

  if (docTypesItems != nil || [docTypesItems count] > 0)
    {
      object = [docTypesItems objectAtIndex: rowIndex];

      if (aTableColumn == extensionsColumn)
	{
	  return [[object objectForKey: @"NSUnixExtensions"] 
	    componentsJoinedByString: @","];
	}
      else
	{
	  return [object objectForKey: [aTableColumn identifier]];
	}
    }

  return nil;
}
  
- (void)tableView: (NSTableView *)aTableView
   setObjectValue: anObject
   forTableColumn: (NSTableColumn *)aTableColumn
              row: (NSInteger)rowIndex
{
  NSMutableDictionary *type = nil;
  
  if (docTypesItems == nil || [docTypesItems count] == 0)
    {
      return;
    }

  type = [docTypesItems objectAtIndex: rowIndex];
  if ([[aTableColumn identifier] isEqualToString: @"NSUnixExtensions"])
    {
      setOrRemove(type, anObject, @"Extension");
    }
  else if ([[aTableColumn identifier] isEqualToString: @"NSIcon"])
    {
      setOrRemove(type, anObject, @"Icon");
    }
  
  [self setProjectDictObject: docTypesItems
                      forKey: PCDocumentTypes
		      notify: YES];
}

- (BOOL)tableView: (NSTableView *)aTableView shouldSelectRow: (NSInteger)rowIndex
{
  [self fillFieldsForRow: rowIndex];
  return YES;
}

- (void)fillFieldsForRow: (NSInteger)rowIndex
{
  NSMutableDictionary *type = nil;
  NSUInteger      itemCount = [docTypesItems count];

  if (itemCount == 0 || rowIndex > itemCount || rowIndex < 0)
    {
      [docTypeField setStringValue: @""];
      [docNameField setStringValue: @""];
      [docIconField setStringValue: @""];
      [docExtensionsField setStringValue: @""];
      [docRoleField setStringValue: @""];
      [docClassField setStringValue: @""];

      return;
    }

  type = [docTypesItems objectAtIndex: rowIndex];
  
  [docTypeField setStringValue: cleanup(type, @"NSName")];
  [docNameField setStringValue: cleanup(type, @"NSHumanReadableName")];
  [docIconField setStringValue: cleanup(type, @"NSIcon")];

  [docExtensionsField setStringValue: @""];
  if ([[type objectForKey: @"NSUnixExtensions"] count] > 0)
    {
      [docExtensionsField setStringValue:
	[[type objectForKey: @"NSUnixExtensions"] 
	 componentsJoinedByString: @","]];
    }

  [docRoleField setStringValue: cleanup(type, @"NSRole")];
  [docClassField setStringValue: cleanup(type, @"NSDocumentClass")];
}

// ----------------------------------------------------------------------------
// --- Notifications
// ----------------------------------------------------------------------------

- (void)updateInspectorValues: (NSNotification *)aNotif
{
//  NSLog (@"PCAppProject: updateInspectorValues");

  // Project Attributes view
  [appTypeField selectItemWithTitle:[projectDict objectForKey:PCAppType]];
  [appClassField setStringValue:[projectDict objectForKey: PCPrincipalClass]];
  [bundleIdentifierField setStringValue:[projectDict objectForKey: PCBundleIdentifier]];

  [appImageField setStringValue:[projectDict objectForKey:PCAppIcon]];
  [helpFileField setStringValue:[projectDict objectForKey:PCHelpFile]];
  [mainNIBField setStringValue:
    [projectDict objectForKey:PCMainInterfaceFile]];

  docTypesItems = [projectDict objectForKey:PCDocumentTypes];
  [docTypesList reloadData];
}

// TextFields (PCITextField subclass)
// 
// NSTextField become first responder when user clicks on it and immediately
// lost first resonder status, so we can't catch when focus leaves textfield
// with resignFirstResponder: method overriding. Here we're using
// controlTextDidEndEditing (NSTextField's delegate method) to achieve this.

- (void)tfGetFocus: (NSNotification *)aNotif
{
  id       anObject = [aNotif object];
  NSString *file = nil;
  NSString *path = nil;
  NSImage  *image = nil;

  
  if (anObject != appImageField 
    && anObject != helpFileField 
    && anObject != mainNIBField)
    {
//      NSLog(@"tfGetFocus: not that textfield");
      return;
    }

  if (anObject == appImageField)
    {
      file = [appImageField stringValue];

      if (![file isEqualToString: @""])
	{
	  path = [self dirForCategoryKey:PCImages];
	  path = [path stringByAppendingPathComponent:file];
	  image = [[NSImage alloc] initWithContentsOfFile:path];
	}
      activeTextField = appImageField;
    }
  else if (anObject == helpFileField)
    {
      activeTextField = helpFileField;
    }
  else if (anObject == mainNIBField)
    {
      file = [mainNIBField stringValue];
      
      if (![file isEqualToString:@""])
	{
	  path = [projectPath stringByAppendingPathComponent:file];
	  image = [[NSWorkspace sharedWorkspace] iconForFile:path];
	}
      activeTextField = mainNIBField;
    }

  [iconView setImage:image];
}

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
  NSControl *anObject = [aNotification object];
  id        target = [anObject target];
  SEL       action = [anObject action];
  NSString  *fileName;
  NSString  *filePath;

  if (anObject != appImageField
      && anObject != helpFileField
      && anObject != mainNIBField)
    {
      if ([target respondsToSelector:action])
	{
	  [target performSelector:action withObject:anObject];
	}

      return;
    }

  fileName = [anObject stringValue];
  if (anObject == appImageField)
    {
      filePath = [self pathForFile:fileName forKey:PCImages];
      [self setAppIconWithFileAtPath:filePath];
    }
  else if (anObject == helpFileField)
    {
    }
  else if (anObject == mainNIBField)
    {
      filePath = [self pathForFile:fileName forKey:PCInterfaces];
      [self setMainNibWithFileAtPath:filePath];
    }
}

@end

@implementation PCAppProject (FileNameIconDelegate)

- (BOOL)canPerformDraggingOf:(NSArray *)paths
{
  NSString     *categoryKey;
  NSArray      *fileTypes;
  NSEnumerator *e = [paths objectEnumerator];
  NSString     *s;

  if (activeTextField == appImageField)
    {
      categoryKey = PCImages;
    }
  else if (activeTextField == helpFileField)
    {
      return NO;
    }
  else if (activeTextField == mainNIBField)
    {
      categoryKey = PCInterfaces;
    }
  else
    {
      return NO;
    }

  NSLog(@"PCAppProject: canPerformDraggingOf -> %@", 
  [self projectFileFromFile:[paths objectAtIndex:0] forKey:categoryKey]);

  fileTypes = [self fileTypesForCategoryKey:categoryKey];

  // Check if we can accept files of such types
  while ((s = [e nextObject]))
    {
      if (![fileTypes containsObject:[s pathExtension]])
	{
	  return NO;
	}
    }

  return YES;
}

- (BOOL)prepareForDraggingOf:(NSArray *)paths
{
  return YES;
}

- (BOOL)performDraggingOf:(NSArray *)paths
{
  if (activeTextField == appImageField)
    {
      [self setAppIconWithFileAtPath:[paths objectAtIndex:0]];
    }
  else if (activeTextField == helpFileField)
    {
    }
  else if (activeTextField == mainNIBField)
    {
      [self setMainNibWithFileAtPath:[paths objectAtIndex:0]];
    }

  return YES;
}

@end
