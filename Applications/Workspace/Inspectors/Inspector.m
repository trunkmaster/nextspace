/* -*- mode: objc -*- */
//
// Project: Workspace
//
// Copyright (C) 2015-2019 Sergii Stoian
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

#import <SystemKit/OSEFileManager.h>

#import <Viewers/FileViewer.h>
#import <Controller.h>

#import "FileAttributesInspector.h"
#import "FileToolsInspector.h"
#import "FileAccessInspector.h"

// Contents inspectors concrete class
#import <Workspace.h>
#import "Inspector.h"

@interface Inspector (Private)

- (void)_updateDisplay;
- (void)_setInspector:(Inspector *)inspector;

- (NSArray *)_bundlesRegistryInDirectories:(NSArray *)paths;
- (void)_registerInspectors;
- (id)_inspectorWithRegistry:(NSDictionary *)registry;
- (id)_inspectorWithRegistryIndex:(NSUInteger)index;
- (id)_inspectorWithClassName:(NSString *)className;
- (NSDictionary *)_registryForInspector:(id)Inspector;
- (id)_inspectorForMode:(NSString *)mode path:(NSString *)path files:(NSArray *)files;
@end

@implementation Inspector (Private)

- (void)_updateDisplay
{
  NSString *fileNamePath;
  NSString *fileName;
  CGFloat width;
  CGFloat fontSize = 18.0;
  NSFont *font = [NSFont systemFontOfSize:fontSize];

  // Update 'filePath' and 'fileSelection' ivars
  [self getSelectedPath:&filePath andFiles:&fileSelection];

  if (filePath == nil) {
    return;
  }

  [fileNameField setFont:font];

  if ([fileSelection count] == 1) {
    fileNamePath = [filePath stringByAppendingPathComponent:[fileSelection objectAtIndex:0]];

    [fileIconButton setImage:[[NSApp delegate] iconForFile:fileNamePath]];

    fileName = [fileNamePath lastPathComponent];
    width = [fileNameField frame].size.width - 2;
    while (([font widthOfString:fileName] > width) && fontSize > 12.0) {
      fontSize -= 1;
      font = [NSFont systemFontOfSize:fontSize];
    }

    [fileNameField setFont:font];

    if ([font widthOfString:fileName] > width) {
      [fileNameField
          setStringValue:NXTShortenString(fileName, width, font, NXSymbolElement, NXTDotsAtRight)];
    } else {
      [fileNameField setStringValue:fileName];
    }
  } else {
    [fileIconButton setImage:[NSImage imageNamed:@"MultipleSelection"]];
    [fileNameField
        setStringValue:[NSString stringWithFormat:@"%lu Elements", [fileSelection count]]];
  }

  [dirNameField setStringValue:NXTShortenString(filePath, [dirNameField frame].size.width,
                                                [dirNameField font], NXPathElement, NXTDotsAtLeft)];
}

- (void)_setInspector:(WMInspector *)inspector
{
  NSDictionary *registry = [self _registryForInspector:inspector];
  NSString *nodep = [registry objectForKey:@"nodep"];
  SEL nodepSel = NSSelectorFromString(nodep);
  BOOL validInspector = YES;
  NSString *title;

  // By default inspector will be shown. Inspector subclass must implement
  // 'nodep' method to define special cases in which 'No ... Inspector'
  // should be displayed.
  if ([inspector respondsToSelector:nodepSel]) {
    validInspector = [inspector performSelector:nodepSel] ? YES : NO;
  }

  if (inspector == nil || validInspector == NO) {
    if (currentInspector != nil) {
      [box setContentView:noInspectorBox];
      [self revert:revertButton];
    }
    inspector = nil;  // if inspector is not vaid for selection
  } else {
    [inspector revert:revertButton];
    if (currentInspector != inspector) {
      [window setTitle:[[inspector window] title]];
      [box setContentView:[registry objectForKey:@"view"]];
    }
  }

  if (currentInspector != inspector) {
    ASSIGN(currentInspector, inspector);
  }
  NSDebugLLog(@"Inspector", @"Current inspector: %@", [currentInspector className]);
}

// Returns array of bundle.registry files contents for 'contents' inpector
// bundles.
// bundle.registry contains dictionary with the following key words:
// type       - The type of registration. For inspectors must be
//              'InspectorCommand'.
// mode       - The mode of inspector panel. Possible values are:
//              'attributes' for 'Attributes' section
//              'contents' for 'Contents' section
//              'tools' for 'Tools' section
//              'access' for 'Access Control' section
// extensions - The array of file extensions to be associated with this
//              inspector. (Don't include the '.' in the extension.).
//              Wildcard characters aren't permitted. This key is mandatory
//              only for 'contents' inspectors.
// class      - The name of the subclass of Inspector or WMInspector.
// selp       - The selection predicate. The value can be either
//              'selectionOneOnly' or 'selectionOneOrMore'.
// nodep      - The name of method used by Inspector to determine if given
//              inspector can be shown for current selection. This method must
//              return BOOL value ('YES' or 'NO'). If inspector bundle returns
//              NO, Inspector shows 'No <mode name> Inspector'.
//
//              [class performSelector:NSSelectorFromString(nodep)].
- (NSArray *)_bundlesRegistryInDirectories:(NSArray *)paths
{
  NSMutableArray *bundlesInfo = [NSMutableArray new];
  NSMutableDictionary *registry;
  NSEnumerator *e;
  NSString *path;
  NSDirectoryEnumerator *de;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *fattrs;
  NSString *file;
  NSString *fp;

  e = [paths objectEnumerator];
  while ((path = [e nextObject]) != nil) {
    de = [fm enumeratorAtPath:path];
    while ((file = [de nextObject]) != nil) {
      if ([[file lastPathComponent] isEqualToString:@"bundle.registry"]) {
        fp = [path stringByAppendingPathComponent:file];
        registry = [NSMutableDictionary dictionaryWithContentsOfFile:fp];
        [registry setObject:[fp stringByDeletingLastPathComponent] forKey:@"path"];
        [bundlesInfo addObject:registry];
      }
    }
  }

  return bundlesInfo;
}

- (void)_registerInspectors
{
  NSArray *searchPaths;
  NSDictionary *d;
  NSMutableDictionary *registry;

  if (!inspectorsRegistry) {
    inspectorsRegistry = [[NSMutableArray alloc] init];
  } else {
    [inspectorsRegistry removeAllObjects];
  }

  // Built-in inspectors
  // Attributes
  d = [@"{path=BUILTIN; type=InspectorCommand; mode=attributes;"
        "class=FileAttributesInspector; selp=selectionOneOrMore;"
        "nodep=isLocalFile; priority=-1;}" propertyList];
  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];
  // Tools
  d = [@"{path=BUILTIN; type=InspectorCommand; mode=tools;"
        "class=FileToolsInspector; selp=selectionOneOrMore;"
        "nodep=hasToolsInspector;}" propertyList];
  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];
  // Access
  d = [@"{path=BUILTIN; type=InspectorCommand; mode=access;"
        "class=FileAccessInspector; selp=selectionOneOrMore;"
        "nodep=isLocalFile; priority=-1;}" propertyList];
  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];

  // Built-in contents inspectors
  d = [@"{path=BUILTIN; type=InspectorCommand; mode=contents;"
        "class=FileInspector; selp=selectionOneOnly;"
        "priority=-1;}" propertyList];
  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];

  d = [@"{path=BUILTIN; type=InspectorCommand; mode=contents;"
        "class=FolderInspector; selp=selectionOneOnly;"
        "nodep=isLocalFile; priority=-1;}" propertyList];
  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];

  d = [@"{path=BUILTIN; type=InspectorCommand; mode=contents;"
        "class=AppInspector; selp=selectionOneOnly; extensions=(app);"
        "nodep=isValidApplication; priority=1;}" propertyList];
  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];

  d = [@"{path=BUILTIN; type=InspectorCommand; mode=contents;"
        "class=ImageInspector; selp=selectionOneOnly; nodep=isLocalFile;"
        "extensions=(tiff, tif, png, jpg, jpeg, gif, xpm, xbm, eps);"
        "priority=-1;}" propertyList];
  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];

  d = [@"{path=BUILTIN; type=InspectorCommand; mode=contents;"
        "class=RTFInspector; selp=selectionOneOnly;"
        "extensions=(rtf); priority=-1;}" propertyList];

  registry = [NSMutableDictionary dictionaryWithDictionary:d];
  [inspectorsRegistry addObject:registry];

  // Find contents inspectors in:
  // /Applications
  searchPaths = NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSAllDomainsMask, YES);
  [inspectorsRegistry addObjectsFromArray:[self _bundlesRegistryInDirectories:searchPaths]];

  // /Library
  searchPaths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSAllDomainsMask, YES);
  [inspectorsRegistry addObjectsFromArray:[self _bundlesRegistryInDirectories:searchPaths]];

  // NSDebugLLog(@"Inspector", @"Found %i inspectors: %@", [inspectorsRegistry count],
  //             inspectorsRegistry);
}

- (id)_inspectorWithRegistry:(NSMutableDictionary *)registry
{
  NSString *inspectorPath = [registry objectForKey:@"path"];
  id object = [registry objectForKey:@"object"];
  NSBundle *bundle = nil;

  if (object == nil) {
    if (![inspectorPath isEqualToString:@"BUILTIN"]) {
      if ([[NSBundle alloc] initWithPath:inspectorPath] == nil) {
        NSDebugLLog(@"Inspector", @"ERROR: corrupted inspector bundle found at path: %@", inspectorPath);
        return nil;
      }
    }

    object = [NSClassFromString([registry objectForKey:@"class"]) new];
    if (object != nil) {
      [registry setObject:object forKey:@"object"];
      // Waiting for inspector section to initialize
      while ([object window] == nil) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:.5]];
      }
      [registry setObject:[[object window] contentView] forKey:@"view"];
    }
  }

  return object;
}

- (id)_inspectorWithRegistryIndex:(NSUInteger)index
{
  return [self _inspectorWithRegistry:[inspectorsRegistry objectAtIndex:index]];
}

- (id)_inspectorWithClassName:(NSString *)className
{
  NSEnumerator *e = [inspectorsRegistry objectEnumerator];
  NSDictionary *registry = nil;
  id inspector = nil;

  while ((registry = [e nextObject]) != nil) {
    if ([className isEqualToString:[registry objectForKey:@"class"]]) {
      inspector = [self _inspectorWithRegistry:registry];
      break;
    }
  }

  return inspector;
}

- (NSDictionary *)_registryForInspector:(id)inspector
{
  NSUInteger count, i;
  NSMutableDictionary *registry = nil;

  count = [inspectorsRegistry count];
  for (i = 0; i < count; i++) {
    registry = [inspectorsRegistry objectAtIndex:i];
    if ([[registry objectForKey:@"object"] isEqual:inspector]) {
      return registry;
    }
  }

  return nil;
}

// mode is one of: attributes, contents, tools, access
- (id)_inspectorForMode:(NSString *)mode path:(NSString *)path files:(NSArray *)files
{
  NSString *fp;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *fattrs;
  NSUInteger count, i;
  NSMutableDictionary *registry;
  id inspector = nil;
  NSInteger priority = -1, pr;
  NSString *extension = [[files objectAtIndex:0] pathExtension];

  // NSDebugLLog(@"Inspector", @"wmInspectorForPath:andFiles:");
  if (!path || !files) {
    [self getSelectedPath:&path andFiles:&files];
  }

  // Built-in contents inspectors
  if ([mode isEqualToString:@"contents"]) {
    if ([files count] > 1) {
      return [self _inspectorWithClassName:@"FileInspector"];
    }

    // select inspector by file extenstion
    count = [inspectorsRegistry count];
    for (i = 0; i < count; i++) {
      registry = [inspectorsRegistry objectAtIndex:i];
      if ([registry objectForKey:@"extensions"] != nil &&
          [[registry objectForKey:@"extensions"] containsObject:extension]) {
        NSDebugLLog(@"Inspector", @"Extensions: '%@', extension: %@", [registry objectForKey:@"extensions"], extension);
        if ([registry objectForKey:@"priority"] == nil) {
          pr = -1;
        } else {
          pr = [[registry objectForKey:@"priority"] integerValue];
        }
        if (pr >= priority) {
          priority = pr;
          inspector = [self _inspectorWithRegistry:registry];
          NSDebugLLog(@"Inspector", @"---Selected inspector with class name: %@ (%@)", [inspector className],
                [[registry objectForKey:@"object"] className]);
        }
      }
    }

    // check if folder selected
    if (([files count] == 1) && (inspector == nil)) {
      NSString *appName, *fileType;
      fp = [path stringByAppendingPathComponent:[files objectAtIndex:0]];
      // NSDebugLLog(@"Inspector", @"Getting attributes for path:%@" , fp);
      [[NSApp delegate] getInfoForFile:fp application:&appName type:&fileType];
      if ([fileType isEqualToString:NSDirectoryFileType] ||
          [fileType isEqualToString:NSFilesystemFileType]) {
        inspector = [self _inspectorWithClassName:@"FolderInspector"];
      }
    }
  } else  // attributes, tools and permissions
  {
    // Get the inspector object
    count = [inspectorsRegistry count];
    for (i = 0; i < count; i++) {
      registry = [inspectorsRegistry objectAtIndex:i];
      NSDebugLLog(@"Inspector", @"--- inspector #%lu: %@", i, [registry objectForKey:@"class"]);
      if ([[registry objectForKey:@"mode"] isEqualToString:mode]) {
        inspector = [self _inspectorWithRegistryIndex:i];
        break;
      }
    }
  }

  return inspector;
}

@end

@implementation Inspector

static Inspector *inspectorPanel = nil;

+ sharedInspector
{
  if (inspectorPanel == nil) {
    inspectorPanel = [self new];
  }

  return inspectorPanel;
}

- init
{
  if (inspectorPanel == nil) {
    // NSDebugLLog(@"Inspector", @"%@: INIT!", [self className]);

    self = inspectorPanel = [super init];
    currentInspector = nil;
    window = nil;
  } else  // subclass init
  {
    // NSDebugLLog(@"Inspector", @"%@: ALTERNATE INIT!", [self className]);

    self = [super init];
  }

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(release)
                                               name:NSApplicationWillTerminateNotification
                                             object:NSApp];

  return self;
}

- (void)setInspectorPanel:(Inspector *)panel
{
  inspectorPanel = panel;
}

- (void)dealloc
{
  NSDebugLLog(@"Inspector", @"Inspector(%@): dealloc", [window title]);

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  // It's an Inspector panel instance
  if ([[window title] isEqualToString:@"Inspector"]) {
    TEST_RELEASE(filePath);

    TEST_RELEASE(noInspectorBox);

    TEST_RELEASE(attributesInspector);
    TEST_RELEASE(toolsInspector);
    TEST_RELEASE(accessInspector);

    TEST_RELEASE(inspectorsRegistry);
  }

  [super dealloc];
}

// This is the real -init of Inspector.
- (void)activateInspector:sender
{
  NSDebugLLog(@"Inspector", @"%@ - activateInspector", [self className]);

  if (self != inspectorPanel) {
    return;
  }

  // Inspector panel window must be loaded
  if (!window) {
    NSDebugLLog(@"Inspector", @"Inspector: loading InspectorPanel GORM");

    if (![NSBundle loadNibNamed:@"InspectorPanel" owner:self]) {
      NSDebugLLog(@"Inspector", @"Error loading Inspector panel GORM file!");
      return;
    }
    [window setFrameAutosaveName:@"Inspector"];
    [okButton setButtonType:NSMomentaryPushInButton];  // GORM bug?
    // [fileInfoField setFont:[NSFont fontWithName:@"Helvetica" size:10.0]];
    [noInspectorBox retain];
    [noInspectorField retain];

    filePath = nil;
    fileSelection = nil;

    // load information about inspectors
    [self _registerInspectors];
  }

  // do it for updates after panel was closed and activated again
  fileViewerSelectionChanged = YES;
  [self _updateDisplay];

  // don't make our panel the key window - we want to allow
  // the user to open the inspector and continue on browsing
  // the file system.
  [window orderFront:nil];
}

- (void)deactivateInspector:sender
{
  // FIXME
  [window close];
}

// Popup button action
- (void)selectView:sender
{
  id theInspector = nil;
  NSString *mode;

  switch ([popUpButton indexOfSelectedItem]) {
    case 0:  // attributes
      [noInspectorField setStringValue:@"No Attributes Inspector"];
      mode = @"attributes";
      break;

    case 1:  // contents
      [noInspectorField setStringValue:@"No Contents Inspector"];
      mode = @"contents";
      break;

    case 2:  // tools
      [noInspectorField setStringValue:@"No Tools Inspector"];
      mode = @"tools";
      break;

    case 3:  // permissions
      [noInspectorField setStringValue:@"No Access Inspector"];
      mode = @"access";
      break;
  }

  theInspector = [self _inspectorForMode:mode path:filePath files:fileSelection];
  NSDebugLLog(@"Inspector", @"Set inspector: %@", [theInspector className]);

  // ---
  if (!theInspector) {
    theInspector = [self _inspectorWithClassName:@"FileInspector"];
  }

  // --- Check for selection predicate
  // if ([fileSelection count] > 1 &&
  //     [[[self _registryForInspector:theInspector]
  //        objectForKey:@"selp"] isEqualToString:@"selectionOneOnly"])
  //   {
  //     theInspector = nil;
  //   }

  NSDebugLLog(@"Inspector", @">>Set inspector class: %@ > '%@'", [theInspector className],
        [[theInspector window] title]);
  [self _setInspector:theInspector];
}

// Menu action
- (void)showAttributesInspector:sender
{
  [self activateInspector:self];
  [popUpButton selectItemAtIndex:0];
  [self selectView:popUpButton];
}

// Menu action
- (void)showContentsInspector:sender
{
  [self activateInspector:self];
  [popUpButton selectItemAtIndex:1];
  [self selectView:popUpButton];
}

// Menu action
- (void)showToolsInspector:sender
{
  [self activateInspector:self];
  [popUpButton selectItemAtIndex:2];
  [self selectView:popUpButton];
}

// Menu action
- (void)showPermissionsInspector:sender
{
  [self activateInspector:self];
  [popUpButton selectItemAtIndex:3];
  [self selectView:popUpButton];
}

// --- Inspired by WMInspector
- (void)ok:sender
{
  [currentInspector ok:sender];
}

- okButton
{
  if (self == inspectorPanel)
    return okButton;
  else
    return [inspectorPanel okButton];
}

// Called in case of:
// 1. Panel activation [self activateInspector]
// 2. New FileViewer creation [Controller openNewViewerRootedAt:]
// 3. Existing FileViewer window become main [FileViewer windowDidBecomeMain:]
// 4. FileViewer selection changed [FileViewer displayPath:selection:sender:]
- (id)revert:sender
{
  if (sender == revertButton) {  // button clicked
    NSDebugLLog(@"Inspector", @"'Revert' button clicked. Send message to '%@'",
                [currentInspector className]);
    // Update contents of section inspector
    [currentInspector revert:sender];
  } else if ([sender isKindOfClass:[FileViewer class]]) {  // selection changed
    if ([window isVisible] == NO) {
      return self;
    }
    NSDebugLLog(@"Inspector", @"Selection changed in FileViewer");
    // Update Inspector panel fields
    fileViewerSelectionChanged = YES;
    [self _updateDisplay];

    // Update contents of section inspector
    [self selectView:popUpButton];
  } else if (self == inspectorPanel) {
    [[okButton cell] setTitle:@"OK"];
    [okButton setEnabled:NO];
    [[revertButton cell] setTitle:@"Revert"];
    [revertButton setEnabled:NO];

    [window setDocumentEdited:NO];
  } else if ([sender isKindOfClass:[Inspector class]]) {  // message from subclass
    [inspectorPanel revert:sender];
  }

  return self;
}

- revertButton
{
  if (self == inspectorPanel)
    return revertButton;
  else
    return [inspectorPanel revertButton];
}

// Returns window of inspectorPanel or window of inpector
- window
{
  return window;
}

- (unsigned)selectionCount
{
  return [fileSelection count];
}

- selectionPathsInto:(char *)pathString separator:(char)character
{
  NSString *path;
  NSArray *files;
  NSEnumerator *e;
  NSString *file;
  NSString *tPath;
  NSString *fPath;

  [self getSelectedPath:&path andFiles:&files];
  e = [files objectEnumerator];

  while ((file = [e nextObject]) != nil) {
    fPath = [path stringByAppendingPathComponent:file];
    tPath = [NSString stringWithFormat:@"%@%c%@", tPath, character, fPath];
  }

  pathString = (char *)[tPath cString];

  return self;
}

- (void)getSelectedPath:(NSString **)pathString andFiles:(NSArray **)fileArray
{
  FileViewer *viewer;
  NSString *path;
  NSArray *selection;
  Controller *appDelegate = [NSApp delegate];

  if (self != inspectorPanel) {
    [inspectorPanel getSelectedPath:pathString andFiles:fileArray];
    return;
  }

  if (fileViewerSelectionChanged == NO) {
    *pathString = filePath;
    *fileArray = fileSelection;
    return;
  }

  NSDebugLLog(@"Inspector", @"%@ getSelectedPath:andFiles:", [self className]);

  viewer = [appDelegate fileViewerForWindow:[NSApp keyWindow]];
  if (viewer == nil) {
    viewer = [appDelegate fileViewerForWindow:[NSApp mainWindow]];
  }
  if (viewer) {
    path = [viewer absolutePath];
    selection = [viewer selection];

    if ([selection count] == 0) {
      selection = [NSArray arrayWithObject:[path lastPathComponent]];
      path = [path stringByDeletingLastPathComponent];
    }

    NSDebugLLog(@"Inspector", @"2:%@:%@", path, selection);

    ASSIGN(filePath, path);
    ASSIGN(fileSelection, selection);

    *pathString = filePath;
    *fileArray = fileSelection;
  } else {
    *pathString = nil;
    *fileArray = nil;
  }

  fileViewerSelectionChanged = NO;
}

- textDidChange:sender
{
  if (self == inspectorPanel) {
    [self touch:sender];
  } else {
    [inspectorPanel touch:sender];
  }
  return self;
}

- (void)touch:sender
{
  if (self == inspectorPanel) {
    [[self window] setDocumentEdited:YES];
    [[self okButton] setEnabled:YES];
    [[self revertButton] setEnabled:YES];
  } else {
    [inspectorPanel touch:sender];
  }
}

@end
