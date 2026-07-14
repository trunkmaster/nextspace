/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2023 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan
            Riccardo Mottola
            German Arias

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

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectBrowser.h>
#import <ProjectCenter/PCProjectWindow.h>
#import <ProjectCenter/PCProjectInspector.h>
#import <ProjectCenter/PCFileManager.h>
#import <ProjectCenter/PCLogController.h>

@implementation PCProjectInspector

// ============================================================================
// ==== Intialization & deallocation
// ============================================================================

- (id)initWithProjectManager:(PCProjectManager *)manager
{
  projectManager = manager;

  [self loadPanel];

  // Track project switching
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(activeProjectDidChange:)
           name:PCActiveProjectDidChangeNotification
         object:nil];

  // Track project dictionary changing
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(updateValues:)
           name:PCProjectDictDidChangeNotification
         object:nil];
         
  // Track Browser selection changes
  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector (browserDidSetPath:)
           name:PCBrowserDidSetPathNotification
         object:nil];

  [self inspectorPopupDidChange:inspectorPopup];

  return self;
}

- (void)close
{
  [inspectorPanel performClose:self];
}

- (void)dealloc
{
#ifdef DEVELOPMENT
  NSLog (@"PCProjectInspector: dealloc");
#endif
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  RELEASE(buildAttributesView);
  RELEASE(projectAttributesSubview);
  RELEASE(projectAttributesView);
  RELEASE(projectDescriptionView);
  RELEASE(projectLanguagesView);
  RELEASE(fileAttributesView);

  RELEASE(inspectorPanel);
  RELEASE(fileName);

  [super dealloc];
}

// ============================================================================
// ==== Panel & contents
// ============================================================================

- (BOOL)loadPanel
{
  if ([NSBundle loadNibNamed:@"ProjectInspector" owner:self] == NO)
    {
      PCLogError(self, @"error loading NIB file!");
      return NO;
    }

  // Panel
  [inspectorPanel setFrameAutosaveName:@"ProjectInspector"];
  [inspectorPanel setFrameUsingName:@"ProjectInspector"];
  project = [projectManager activeProject];
  projectDict = [project projectDict];
  
  // PopUp
  [inspectorPopup selectItemAtIndex:0];
  
  // Build Attributes
  [self createBuildAttributes];

  // Project Attributes
  [self createProjectAttributes];

  // Project Description
  [self createProjectDescription];

  // Project Languages
  [self createProjectLanguages];

  // File Attributes
  [self createFileAttributes];

  [self activeProjectDidChange:nil];

  return YES;
}

- (NSPanel *)panel
{
  if (!inspectorPanel && ([self loadPanel] == NO))
    {
      return nil;
    }

  return inspectorPanel;
}

- (NSView *)contentView
{
  if (!contentView && ([self loadPanel] == NO))
    {
      return nil;
    }
    
  return contentView;
}

// ============================================================================
// ==== Actions
// ============================================================================

- (void)inspectorPopupDidChange:(id)sender
{
  switch([sender indexOfSelectedItem]) 
    {
    case 0:
      [inspectorView setContentView:buildAttributesView];
      break;
    case 1:
      [inspectorView setContentView:projectAttributesView];
      break;
    case 2:
      [inspectorView setContentView:projectDescriptionView];
      break;
    case 3:
      [inspectorView setContentView:projectLanguagesView];
      break;
    case 4:
      [inspectorView setContentView:fileAttributesView];
      break;
    }

  [inspectorView display];
}

- (void)changeCommonProjectEntry:(id)sender
{
  NSString *newEntry = [sender stringValue];

  // Build Atributes
  if (sender == installDomainPopup)
    {
      [project setProjectDictObject:newEntry
                             forKey:PCInstallDomain
                             notify:YES];
    }
  else if (sender == cppOptField)
    {
      [project setProjectDictObject:newEntry
                             forKey:PCPreprocessorOptions
                             notify:YES];
    }
  else if (sender == objcOptField)
    {
      [project setProjectDictObject:newEntry
                             forKey:PCObjCCompilerOptions
                             notify:YES];
    }
  else if (sender == cOptField)
    {
      [project setProjectDictObject:newEntry
                             forKey:PCCompilerOptions
                             notify:YES];
    }
  else if (sender == ldOptField)
    {
      [project setProjectDictObject:newEntry
                             forKey:PCLinkerOptions
                             notify:YES];
    }
  // Project Description
  else if (sender == descriptionField)
    {
      [project setProjectDictObject:newEntry forKey:PCDescription notify:YES];
    }
  else if (sender == releaseField)
    {
      [project setProjectDictObject:newEntry forKey:PCRelease notify:YES];
    }
  else if (sender == licenseField)
    {
      [project setProjectDictObject:newEntry forKey:PCCopyright notify:YES];
    }
  else if (sender == licDescriptionField)
    {
      [project setProjectDictObject:newEntry
                             forKey:PCCopyrightDescription
                             notify:YES];
    }
  else if (sender == urlField)
    {
      [project setProjectDictObject:newEntry forKey:PCURL notify:YES];
    }
}

- (void)selectSectionWithTitle:(NSString *)sectionTitle
{
  [inspectorPopup selectItemWithTitle:sectionTitle];
  [self inspectorPopupDidChange:inspectorPopup];
}

// When user ends editing of text field with Tab or changing focus, entered
// changes should be accepted. The exception is PCFileName fields. I'm not sure
// if this is correct implementation. Action is performed twice if user ends
// editing with Enter key.

- (void)controlTextDidEndEditing:(NSNotification *)aNotif
{
  NSControl *anObject = [aNotif object];
  id        target = [anObject target];
  SEL       action = [anObject action];

  if ([anObject isKindOfClass:[PCFileNameField class]])
    {
      return;
    }

  if ([target respondsToSelector:action])
    {
      [target performSelector:action withObject:anObject];
    }
}

// ============================================================================
// ==== Notifications
// ============================================================================

- (void)activeProjectDidChange:(NSNotification *)aNotif
{
  PCProject *rootProject = [projectManager rootActiveProject];
  NSView    *newProjAttrSubview = nil;
  
  if (rootProject != project)
    {
      [inspectorPanel setTitle: [NSString stringWithFormat: 
        @"%@ - Project Inspector", [rootProject projectName]]];
    }

  project = [projectManager activeProject];
  projectDict = [project projectDict];

  PCLogStatus(self, @"Active projectChanged to %@", 
              [[project projectDict] objectForKey:PCProjectName]);

  // 1. Get custom project attributes view
  newProjAttrSubview = [project projectAttributesView];
  if (projectAttributesSubview == nil)
    {
      [projectAttributesView addSubview:newProjAttrSubview];
    }
  else
    {
      [projectAttributesView replaceSubview:projectAttributesSubview 
                                       with:newProjAttrSubview];
    }
  projectAttributesSubview = newProjAttrSubview;

  // 2. Update values in UI elements
  [self updateValues:nil];

  // 3. Display current view
  [self inspectorPopupDidChange:inspectorPopup];
}

- (void)updateValues:(NSNotification *)aNotif
{
  // Build Attributes view
  searchHeaders = [projectDict objectForKey:PCSearchHeaders];
  searchLibs = [projectDict objectForKey:PCSearchLibs];
  [self searchOrderPopupDidChange:searchOrderPopup];

  [projectNameLabel setStringValue:[project projectName]];

  [cppOptField setStringValue:
    [projectDict objectForKey:PCPreprocessorOptions]];
  [objcOptField setStringValue:
    [projectDict objectForKey:PCObjCCompilerOptions]];
  [cOptField setStringValue:
    [projectDict objectForKey:PCCompilerOptions]];
  [ldOptField setStringValue:
    [projectDict objectForKey:PCLinkerOptions]];
  [installDomainPopup selectItemWithTitle:
    [projectDict objectForKey:PCInstallDomain]];
    
  // Project Attributes
  [projectTypeField setStringValue:[projectDict objectForKey:PCProjectType]];
  [projectNameField setStringValue:[projectDict objectForKey:PCProjectName]];
  [projectLanguagePB removeAllItems];
  [projectLanguagePB addItemsWithTitles:
    [projectDict objectForKey:PCUserLanguages]];
  [projectLanguagePB selectItemWithTitle:
    [projectDict objectForKey:PCLanguage]];

  // Project Description view
  [descriptionField setStringValue:
    [projectDict objectForKey:PCDescription]];
  [releaseField setStringValue:
    [projectDict objectForKey:PCRelease]];
  [licenseField setStringValue:
    [projectDict objectForKey:PCCopyright]];
  [licDescriptionField setStringValue:
    [projectDict objectForKey:PCCopyrightDescription]];
  [urlField setStringValue:
    [projectDict objectForKey:PCURL]];

  authorsItems = [projectDict objectForKey:PCAuthors];
  [authorsList reloadData];
  
  //Project Languages
  languagesItems = [projectDict objectForKey:PCUserLanguages];
  [languagesList reloadData];

  // File Attributes
  [fileIconView setDelegate:[project projectBrowser]];
  [fileIconView updateIcon];
  [self updateFileAttributes];
}

- (void)browserDidSetPath:(NSNotification *)aNotif
{
  [fileIconView updateIcon];
  [self updateFileAttributes];
}

// ============================================================================
// ==== Build Attributes
// ============================================================================

- (void)createBuildAttributes
{
  if (buildAttributesView)
    {
      return;
    }

  if ([NSBundle loadNibNamed:@"BuildAttributes" owner:self] == NO)
    {
      PCLogError(self, @"error loading BuildAttributes NIB file!");
      return;
    }

  // Search Order
  // Popup
  [searchOrderPopup selectItemAtIndex:0];

  // Table
  [searchOrderList setCornerView:nil];
  [searchOrderList setHeaderView:nil];
  [searchOrderList setTarget:self];
  [searchOrderList setAction:@selector(searchOrderClick:)];
//  [searchOrderColumn setEditable:NO];

  // Buttons
  [self setSearchOrderButtonsState];

  // Retain view
  [buildAttributesView retain];
}

// --- Search Order
- (void)searchOrderPopupDidChange:(id)sender
{
  NSString *selectedTitle = [sender titleOfSelectedItem];
  
  if ([selectedTitle isEqualToString:@"Header Directories Search Order"])
    {
      ASSIGN(searchItems, [NSMutableArray arrayWithArray:searchHeaders]);
    }
  else if ([selectedTitle isEqualToString:@"Library Directories Search Order"])
    {
      ASSIGN(searchItems, [NSMutableArray arrayWithArray:searchLibs]);
    }
  else if ([selectedTitle isEqualToString:@"Build Targets"])
    {
      ASSIGN(searchItems,[NSMutableArray arrayWithArray:[project buildTargets]]);
    }
  else  
    {
      DESTROY(searchItems);
    }

  [searchOrderList reloadData];
  [searchOrderList deselectAll:self];
  [searchOrderTF setStringValue:@""];

  // Enable/disable buttons according to selected/not selected item
  [self setSearchOrderButtonsState];
}

- (void)searchOrderDoubleClick:(id)sender
{
}

- (void)searchOrderClick:(id)sender
{
  int row = [searchOrderList selectedRow];
  [searchOrderTF setStringValue:[searchItems objectAtIndex:row]];
  [searchOrderTF selectText:self];
  [self setSearchOrderButtonsState];
}

- (void)setSearchOrderButtonsState
{
  // "Set..." button is always off until functionality will be implemented
  [searchOrderSet setEnabled:NO];

  // After loadable inspectors implementation make it work by
  // detection of text field becoming first responder.
/*  if ([inspectorPanel firstResponder] == searchOrderTF)
    {
      [searchOrderAdd setEnabled:YES];
    }
  else
    {
      [searchOrderAdd setEnabled:NO];
    }*/

  if ([searchOrderList selectedRow] == -1)
    {
      [searchOrderRemove setEnabled:NO];
    }
  else
    {
      [searchOrderRemove setEnabled:YES];
    }
}

- (void)setSearchOrder:(id)sender
{
}

- (void)removeSearchOrder:(id)sender
{
  int row = [searchOrderList selectedRow];

  if (row != -1)
    {
      [searchItems removeObjectAtIndex:row];
      [self syncSearchOrder];

      [searchOrderList reloadData];
    }
}

- (void)addSearchOrder:(id)sender
{
  NSString *value = [searchOrderTF stringValue];

  if ([value isEqualToString:@""])
    {
      return;
    }

  [searchItems addObject:value];
  [searchOrderTF setStringValue:@""];
  [self syncSearchOrder];
  
  [searchOrderList reloadData];
}

- (void)syncSearchOrder
{
  int pIndex;

  pIndex = [searchOrderPopup indexOfSelectedItem];
  switch (pIndex)
    {
    case 0: // Headers
      [project setProjectDictObject:searchItems
                             forKey:PCSearchHeaders
                             notify:YES];
      break;
    case 1: // Libraries
      [project setProjectDictObject:searchItems
                             forKey:PCSearchLibs
                             notify:YES];
      break;
    case 2: // Targets
      [project setProjectDictObject:searchItems
                             forKey:PCBuilderTargets
                             notify:YES];
      return;
    }
}

// ============================================================================
// ==== Project Attributes
// ============================================================================

- (void)createProjectAttributes
{
  if (projectAttributesView)
    {
      return;
    }

  if ([NSBundle loadNibNamed:@"ProjectAttributes" owner:self] == NO)
    {
      PCLogError(self, @"error loading ProjectAttributes NIB file!");
      return;
    }

  // Languages
  [projectLanguagePB removeAllItems];
  [projectLanguagePB addItemsWithTitles:
    [projectDict objectForKey:PCUserLanguages]];
  
  // Retain view
  [projectAttributesView retain];
}

- (void)setCurrentLanguage:(id)sender
{
  NSLog(@"set current language to %@", [sender titleOfSelectedItem]);
  [project setProjectDictObject:[sender titleOfSelectedItem]
                         forKey:PCLanguage
                           notify:NO];
  [[project projectWindow] setTitle];
}

// ============================================================================
// ==== Project Description
// ============================================================================

- (void)createProjectDescription
{
  if (projectDescriptionView)
    {
      return;
    }
    
  if ([NSBundle loadNibNamed:@"ProjectDescription" owner:self] == NO)
    {
      PCLogError(self, @"error loading ProjectDescription NIB file!");
      return;
    }

  // Authors table
  authorsColumn = [(NSTableColumn *)[NSTableColumn alloc] 
    initWithIdentifier: @"Authors List"];
  [authorsColumn setEditable:YES];

  authorsList = [[NSTableView alloc]
    initWithFrame:NSMakeRect(6,6,209,111)];
  [authorsList setAllowsMultipleSelection:NO];
  [authorsList setAllowsColumnReordering:NO];
  [authorsList setAllowsColumnResizing:NO];
  [authorsList setAllowsEmptySelection:YES];
  [authorsList setAllowsColumnSelection:NO];
  [authorsList setRowHeight:17.0];
  [authorsList setCornerView:nil];
  [authorsList setHeaderView:nil];
  [authorsList addTableColumn:authorsColumn];
  [authorsList setDataSource:self];
  [authorsList setDelegate:self];

  //
  [authorsScroll setDocumentView:authorsList];
  [authorsScroll setHasHorizontalScroller:NO];
  [authorsScroll setHasVerticalScroller:YES];
  [authorsScroll setBorderType:NSBezelBorder];

  // Authors' buttons
  [authorAdd setRefusesFirstResponder:YES];
  [authorRemove setRefusesFirstResponder:YES];
  
  [authorUp setRefusesFirstResponder:YES];
  [authorUp setImage: [NSImage imageNamed:@"common_ArrowUp"]];
  
  [authorDown setRefusesFirstResponder:YES];
  [authorDown setImage: [NSImage imageNamed:@"common_ArrowDown"]];

  // Link textfields
  [descriptionField setNextText:releaseField];
  [releaseField setNextText:licenseField];
  [licenseField setNextText:licDescriptionField];
  [licDescriptionField setNextText:urlField];
  [urlField setNextText:descriptionField];

  [projectDescriptionView retain];
}

// --- Actions
- (void)addAuthor:(id)sender
{
  int row;

  [authorsItems addObject:[NSMutableString stringWithString:@""]];
  [authorsList reloadData];
  
  row = [authorsItems count] - 1;
  [authorsList selectRow:row byExtendingSelection:NO];
  [authorsList editColumn:0 row:row withEvent:nil select:YES];

  [project setProjectDictObject:authorsItems forKey:PCAuthors notify:YES];
}

- (void)removeAuthor:(id)sender
{
  int selectedRow = [authorsList selectedRow];

  if (selectedRow >= 0)
    {
      [authorsList selectRow:selectedRow byExtendingSelection:NO];
      [authorsItems removeObjectAtIndex:selectedRow];
      [authorsList reloadData];
    }
  
  if ([authorsList selectedRow] < 0 && [authorsItems count] > 0)
    {
      [authorsList selectRow:[authorsItems count]-1 byExtendingSelection:NO];
    }

  [project setProjectDictObject:authorsItems forKey:PCAuthors notify:YES];
}

- (void)upAuthor:(id)sender
{
  int selectedRow = [authorsList selectedRow];
  id  previousRow;
  id  currentRow;

  if (selectedRow > 0)
  {
    previousRow = [[authorsItems objectAtIndex: selectedRow-1] copy];
    currentRow = [authorsItems objectAtIndex: selectedRow];
      
    [authorsItems replaceObjectAtIndex: selectedRow-1 withObject: currentRow];
    [authorsItems replaceObjectAtIndex: selectedRow withObject: previousRow];
  
    [authorsList selectRow: selectedRow-1 byExtendingSelection: NO];

    [authorsList reloadData];
    [project setProjectDictObject:authorsItems forKey:PCAuthors notify:YES];
  }
}

- (void)downAuthor:(id)sender
{
  unsigned selectedRow = [authorsList selectedRow];
  id       nextRow;
  id       currentRow;

  if (selectedRow < [authorsItems count]-1)
  {
    nextRow = [[authorsItems objectAtIndex: selectedRow+1] copy];
    currentRow = [authorsItems objectAtIndex: selectedRow];

    [authorsItems replaceObjectAtIndex: selectedRow+1 withObject: currentRow];
    [authorsItems replaceObjectAtIndex: selectedRow withObject: nextRow];

    [authorsList selectRow: selectedRow+1 byExtendingSelection: NO];

    [authorsList reloadData];
    [project setProjectDictObject:authorsItems forKey:PCAuthors notify:YES];
  }
}

// ============================================================================
// ==== Project Languages
// ============================================================================

- (void)createProjectLanguages
{
  if (projectLanguagesView)
    {
      return;
    }

  if ([NSBundle loadNibNamed:@"ProjectLanguages" owner:self] == NO)
    {
      PCLogError(self, @"error loading ProjectLanguages NIB file!");
      return;
    }

  [projectLanguagesView retain];
  [languagesList setDataSource:self];
}

- (void)addLanguage:(id)sender
{
  NSString *language = [newLanguage stringValue];
  [newLanguage setStringValue: @""];
  
  //If there is a language and is new, add this
  if (([language length] > 0) && (![languagesItems containsObject: language]))
    {
      //Add the language to the projectDict
      [languagesItems addObject: language];
      [project setProjectDictObject:languagesItems
                             forKey:PCUserLanguages
                             notify:YES];
      
      /* If there are localizable resources, copy these into the new language
       directory */
      if ([[projectDict objectForKey:PCLocalizedResources] count] > 0)
        {
          NSString *file, *englishPath, *languagePath; 
          NSEnumerator *resources = 
            [[projectDict objectForKey:PCLocalizedResources] objectEnumerator];
          
          englishPath = [project resourceDirForLanguage:@"English"];
          languagePath = [project resourceDirForLanguage:language];
          
          while ((file = [resources nextObject]))
            {
              if ([[projectManager fileManager] copyFile:file
                   fromDirectory:englishPath 
                   intoDirectory:languagePath])
                {
                  NSLog(@"file copied: %@", file);
                }
            }
        }
    }
}

- (void)removeLanguage:(id)sender
{
  /* We don't remove the English language sice is needed if the app
  isn't available at the end user language */
  if (![[languagesItems objectAtIndex:
       [languagesList selectedRow]] isEqualToString:@"English"])
    {
      NSString *language =
        [languagesItems objectAtIndex:[languagesList selectedRow]];
      NSString *languagePath = [project resourceDirForLanguage:language];
      NSArray *resources = [projectDict objectForKey:PCLocalizedResources];
      
      /* If there are localizable resources, remove these at the language 
      directory and the directory itsel */
      if ([resources count] > 0)
        {
          if ([[projectManager fileManager] removeFiles:resources
               fromDirectory:languagePath 
               removeDirsIfEmpty:YES])
            {
              NSLog(@"removed resources for language %@",language);
            }
        }
      
      //Update the languages list
      [languagesItems removeObject:language];
      
      //If the removed language is the actual PCLanguage, set English
      if ([[projectDict objectForKey: PCLanguage] isEqualToString:language])
        {
          NSLog(@"set current language to English");
          [project setProjectDictObject:@"English"
                                 forKey:PCLanguage
                                 notify:NO];
        }
      
      //Update the projectDict
      [project setProjectDictObject:languagesItems
                             forKey:PCUserLanguages
                             notify:YES];
    }
  else
    {
      NSRunAlertPanel(@"Remove Language",
                      @"You shouldn't remove language English",
                      @"Ok",nil,nil);
    }   
}

// ============================================================================
// ==== File Attributes
// ============================================================================

- (void)createFileAttributes
{
  if (fileAttributesView)
    {
      return;
    }

  if ([NSBundle loadNibNamed:@"FileAttributes" owner:self] == NO)
    {
      PCLogError(self, @"error loading FileAttributes NIB file!");
      return;
    }

  [fileAttributesView retain];
  [localizableButton setRefusesFirstResponder:YES];
  [publicHeaderButton setRefusesFirstResponder:YES];

  [fileIconView setFileNameField:fileNameField];

  [[NSNotificationCenter defaultCenter] 
    addObserver:self
       selector:@selector(panelDidResignKey:)
           name: NSWindowDidResignKeyNotification
         object:inspectorPanel];
}

- (void)updateFileAttributes
{
  PCProjectBrowser *browser = [project projectBrowser];
  NSString         *category = [browser nameOfSelectedCategory];
  NSString         *categoryKey = [project keyForCategory:category];
  NSArray          *files = [browser selectedFiles];
  NSString         *file = nil;
  int              array_count = [files count];
  int              present_count = 0;
  NSArray          *publicHeaders = nil;
  NSArray          *localizedResources = nil;
  NSEnumerator     *enumerator = nil;

  // Initial default buttons state
  [localizableButton setEnabled:NO];
  [localizableButton setState:NSOffState];
  [publicHeaderButton setEnabled:NO];
  [publicHeaderButton setState:NSOffState];

  if (files == nil)
    {
      return;
    }

  // --- Enable buttons
    
  // If selection is not category AND category is allow localization 
  // enable localizableButton checkbox
  if ([[project localizableKeys] containsObject:categoryKey])
    {
      [localizableButton setEnabled:YES];
    }

  // If selection is not category 
  // AND project accepts public headers 
  // AND file extension is .h or .H enable publicHeaders checkbox.
  if ([project canHavePublicHeaders] == YES )
    {
      BOOL enable = YES;

      enumerator = [files objectEnumerator];
      while ((file = [enumerator nextObject]))
        {
            if (![[file pathExtension] isEqualToString:@"h"] &&
                ![[file pathExtension] isEqualToString:@"H"])
            {
              enable = NO;
            }
        }

      if (enable)
        {
          [publicHeaderButton setEnabled:YES];
        }
    }

  // --- Set state of buttons
  // There are 3 sutiuations:
  // - all files present in group (state: ON)
  // - part of file present in group (state: OFF)
  // - no files present in group (state: OFF)

  // Set state of Public Headers button
  if ([publicHeaderButton isEnabled])
    {
      publicHeaders = [project publicHeaders];
      enumerator = [files objectEnumerator];
      present_count = 0;
      while ((file = [enumerator nextObject]))
        {
          if ([publicHeaders containsObject:file]) 
            {
              present_count++;
            }
        }
      if (array_count == present_count)
        {
          [publicHeaderButton setState:NSOnState];
        }
    }

  // Set state of Localized Resource button
  if ([localizableButton isEnabled])
    {
      localizedResources = [project localizedResources];
      enumerator = [files objectEnumerator];
      present_count = 0;
      while ((file = [enumerator nextObject]))
        {
          if ([localizedResources containsObject:file]) 
            {
              present_count++;
            }
        }
      if (array_count == present_count)
        {
          [localizableButton setState:NSOnState];
        }
    }
}

- (void)beginFileRename
{
  [fileNameField setEditableField:YES];
  [inspectorPanel makeFirstResponder:fileNameField];
}

// Delegate method of PCFileNameField class
- (void)controlStringValueDidChange:(NSString *)aString
{
  if (fileName != nil)
    {
      [fileName release];
    }
  fileName = [aString copy];
}

// Delegate method of PCFileNameField class
- (BOOL)textShouldSetEditable:(NSString *)text
{
  if ([[project rootCategories] containsObject:text])
    {
      return NO;
    }

  return YES;
}

- (void)fileNameDidChange:(id)sender
{
  NSString *newName;

  newName = [fileNameField stringValue];
  if ([fileName isEqualToString:newName])
    {
      [fileNameField setStringValue:fileName];
      return;
    }
  if ([[newName stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 0)
    {
      [fileNameField setStringValue:fileName];
      return;
    }

/*  PCLogInfo(self, @"{%@} file name changed from: %@ to: %@",
            [project projectName], fileName, [fileNameField stringValue]);*/

  if ([project renameFile:fileName toFile:[fileNameField stringValue]] == NO)
    {
      [fileNameField setStringValue:fileName];
    }
}

- (void)setPublicHeader:(id)sender
{
  PCProjectBrowser *browser = [project projectBrowser];
  NSArray          *files = [browser selectedFiles];
  NSEnumerator     *enumerator = [files objectEnumerator];
  NSString         *file = nil;

  while ((file = [enumerator nextObject]))
    {
      if ([sender state] == NSOffState)
        {
          [project setHeaderFile:fileName public:NO];
        }
      else
        {
          [project setHeaderFile:fileName public:YES];
        }
    }
}

- (void)setLocalizableResource:(id)sender
{
  PCProjectBrowser *browser = [project projectBrowser];
  NSArray          *files = [browser selectedFiles];
  NSEnumerator     *enumerator = [files objectEnumerator];
  NSString         *file = nil;

  while ((file = [enumerator nextObject]))
    {
      if ([sender state] == NSOffState)
        {
          [project setResourceFile:file localizable:NO];
        }
      else
        {
          [project setResourceFile:file localizable:YES];
        }
    }
}

- (void)panelDidResignKey:(NSNotification *)aNotif
{
  if ([fileNameField isEditable] == YES)
    {
      [inspectorPanel makeFirstResponder:fileIconView];
      [fileNameField setStringValue:fileName];
    }
}

// ============================================================================
// ==== NSTableViews
// ============================================================================

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if (searchOrderList != nil && aTableView == searchOrderList)
    {
      return [searchItems count];
    }
  else if (authorsList != nil && aTableView == authorsList)
    {
      return [authorsItems count];
    }
  else if (languagesList != nil && aTableView == languagesList)
    {
      return [languagesItems count];
    }

  return 0;
}
    
- (id)            tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
                        row:(NSInteger)rowIndex
{
  if (searchOrderList != nil && aTableView == searchOrderList)
    {
      return [searchItems objectAtIndex:rowIndex];
    }
  else if (authorsList != nil && aTableView == authorsList)
    {
      return [authorsItems objectAtIndex:rowIndex];
    }
  else if (languagesList != nil && aTableView == languagesList)
    {
      return [languagesItems objectAtIndex:rowIndex];
    }

  return nil;
}
  
- (void) tableView:(NSTableView *)aTableView
    setObjectValue:anObject
    forTableColumn:(NSTableColumn *)aTableColumn
                row:(NSInteger)rowIndex
{
  if (authorsList != nil && aTableView == authorsList)
    {
      if([authorsItems count] == 0)
        {
          return;
        }
        
      [authorsItems removeObjectAtIndex:rowIndex];
      [authorsItems insertObject:anObject atIndex:rowIndex];

      [project setProjectDictObject:authorsItems forKey:PCAuthors notify:YES];
    }
}

- (void) tableView: (NSTableView*)aTableView
   willDisplayCell: (id)aCell
    forTableColumn: (NSTableColumn*)aTableColumn
               row: (NSInteger)rowIndex
{
  [(NSTextFieldCell *)aCell setScrollable:YES];
}

@end
