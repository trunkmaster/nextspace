/*
   GNUstep ProjectCenter - http://www.gnustep.org/experience/ProjectCenter.html

   Copyright (C) 2000-2014 Free Software Foundation

   Authors: Philippe C.D. Robert
            Serg Stoyan
	    Riccardo Mottola

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

#import <AppKit/AppKit.h>

#import <ProjectCenter/PCDefines.h>
#import <ProjectCenter/PCButton.h>

#import <ProjectCenter/PCFileManager.h>

#import <ProjectCenter/PCProjectManager.h>
#import <ProjectCenter/PCProject.h>
#import <ProjectCenter/PCProjectWindow.h>
#import <ProjectCenter/PCProjectBuilder.h>
#import <ProjectCenter/PCProjectBuilderOptions.h>

#import <ProjectCenter/PCProjectEditor.h>
#import <Protocols/CodeEditor.h>
#import <ProjectCenter/PCSaveModified.h>

#import <ProjectCenter/PCLogController.h>
#import <Protocols/Preferences.h>

#import "../Modules/Preferences/Build/PCBuildPrefs.h"

#ifndef IMAGE
#define IMAGE(X) [NSImage imageNamed: X]
#endif

#ifndef NOTIFICATION_CENTER
#define NOTIFICATION_CENTER [NSNotificationCenter defaultCenter]
#endif

@implementation PCProjectBuilder

- (id)initWithProject:(PCProject *)aProject
{
#ifdef DEBUG
  NSLog (@"PCProjectBuilder: initWithProject");
#endif

  NSAssert(aProject, @"No project specified!");
  
  if ((self = [super init]))
    {
      project = aProject;
      buildStatusTarget = [[NSMutableString alloc] initWithString:@"all"];
      buildTarget = [[NSMutableString alloc] initWithString:@"all"];
      buildArgs = [[NSMutableArray array] retain];
      buildOptions = [[PCProjectBuilderOptions alloc] initWithProject:project
							     delegate:self];
      postProcess = NULL;
      makeTask = nil;
      _isBuilding = NO;
      _isCleaning = NO;
      _isCVLoaded = NO;

      if ([NSBundle loadNibNamed:@"Builder" owner:self] == NO)
	{
	  PCLogError(self, @"error loading Builder NIB file!");
	  return nil;
	}
      [[NSNotificationCenter defaultCenter]
	addObserver:self
	   selector:@selector(loadPreferences:)
	       name:PCPreferencesDidChangeNotification
	     object:nil];
      [self loadPreferences:nil];
    }

  return self;
}

- (void)dealloc
{
#ifdef DEBUG
  NSLog (@"PCProjectBuilder: dealloc");
#endif

  [[NSNotificationCenter defaultCenter] removeObserver:self];

  if ([componentView superview])
    {
      [componentView removeFromSuperview];
    }

  RELEASE(buildStatusTarget);
  RELEASE(buildTarget);
  RELEASE(buildArgs);
  RELEASE(buildOptions);

  RELEASE(successSound);
  RELEASE(failureSound);
  RELEASE(rootBuildDir);
  RELEASE(buildTool);

//  NSLog(@"Project Builder--> componentView RC: %i", 
//	[componentView retainCount]);

  RELEASE(componentView);
  RELEASE(errorArray);
  RELEASE(errorString);

//  NSLog(@"Project Builder--> RC: %i", [self retainCount]);

  [super dealloc];
}

- (void)awakeFromNib
{
  NSScrollView *errorScroll; 
  NSScrollView *logScroll;

  if (_isCVLoaded)
    {
      return;
    }

//  NSLog(@"ProjectBuilder awakeFromNib");

  [componentView retain];
  [componentView removeFromSuperview];

//  NSLog(@"ProjectBuilder awakeFromNib: componentView RC:%i", 
//	[componentView retainCount]);

  /*
   * 4 build Buttons
   */
  [buildButton setToolTip:@"Build"];
  [buildButton setImage:IMAGE(@"Build")];

  [cleanButton setToolTip:@"Clean"];
  [cleanButton setImage:IMAGE(@"Clean")];

  [optionsButton setToolTip:@"Build Options"];
  [optionsButton setImage:IMAGE(@"Options")];
  
  [errorsCountField setStringValue:@""];
  [self updateTargetField];

  /*
   *  Error output
   */
  errorArray = [[NSMutableArray alloc] initWithCapacity:0];
  errorString = [[NSMutableString alloc] initWithString:@""];

  errorImageColumn = [[NSTableColumn alloc] initWithIdentifier:@"ErrorImage"];
  [errorImageColumn setEditable:NO];
  [errorImageColumn setWidth:20.0];
  errorColumn = [[NSTableColumn alloc] initWithIdentifier:@"Error"];
  [errorColumn setEditable:NO];

  errorOutput = [[NSTableView alloc]
    initWithFrame:NSMakeRect(0,0,209,111)];
  [errorOutput setAllowsMultipleSelection:NO];
  [errorOutput setAllowsColumnReordering:NO];
  [errorOutput setAllowsColumnResizing:NO];
  [errorOutput setAllowsEmptySelection:YES];
  [errorOutput setAllowsColumnSelection:NO];
  [errorOutput setRowHeight:19.0];
  [errorOutput setCornerView:nil];
  [errorOutput setHeaderView:nil];
  [errorOutput addTableColumn:errorImageColumn];
  [errorOutput addTableColumn:errorColumn];
  [errorOutput setDataSource:self];
  [errorOutput setBackgroundColor:[NSColor colorWithDeviceRed:0.88
			                                green:0.76 
			                                 blue:0.60 
			                                alpha:1.0]];
  [errorOutput setDrawsGrid:NO];
  [errorOutput setTarget:self];
  [errorOutput setAction:@selector(errorItemClick:)];

  errorScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,464,120)];
  [errorScroll setHasHorizontalScroller:NO];
  [errorScroll setHasVerticalScroller:YES];
  [errorScroll setBorderType:NSBezelBorder];
  [errorScroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

  [errorScroll setDocumentView:errorOutput];
  RELEASE(errorOutput);

  /*
   *  Log output
   */
  logScroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0,0,480,133)];
  [logScroll setHasHorizontalScroller:NO];
  [logScroll setHasVerticalScroller:YES];
  [logScroll setBorderType:NSBezelBorder];
  [logScroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

  logOutput = [[NSTextView alloc] 
    initWithFrame:[[logScroll contentView] frame]];
  [logOutput setRichText:NO];
  [logOutput setEditable:NO];
  [logOutput setSelectable:YES];
  [logOutput setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
  [logOutput setBackgroundColor:[NSColor lightGrayColor]];
  [logOutput setSelectedTextAttributes:
    [NSDictionary dictionaryWithObjectsAndKeys:
      [NSColor whiteColor], NSBackgroundColorAttributeName,
      [NSColor blackColor], NSForegroundColorAttributeName,
      nil]];
  [[logOutput textContainer] setWidthTracksTextView:YES];
  [[logOutput textContainer] setHeightTracksTextView:YES];
  [logOutput setHorizontallyResizable:NO];
  [logOutput setVerticallyResizable:YES];
  [logOutput setMinSize:NSMakeSize(0, 0)];
  [logOutput setMaxSize:NSMakeSize(1E7, 1E7)];
  [[logOutput textContainer] setContainerSize: 
    NSMakeSize ([logOutput frame].size.width, 1e7)];
  [[logOutput textContainer] setWidthTracksTextView:YES];

  [logScroll setDocumentView:logOutput];
  RELEASE(logOutput);

  /*
   * Split view
   */
  [split addSubview:errorScroll];
  RELEASE(errorScroll);
  [split addSubview:logScroll];
  RELEASE(logScroll);

//  [split adjustSubviews];
//  [componentView addSubview:split];
//  RELEASE (split);

  _isCVLoaded = YES;
}

- (NSView *)componentView
{
  return componentView;
}

- (void)loadPreferences:(NSNotification *)aNotification
{
  id <PCPreferences> prefs = [[project projectManager] prefController];

  ASSIGN(successSound, [prefs stringForKey:SuccessSound]);
  ASSIGN(failureSound, [prefs stringForKey:FailureSound]);

  ASSIGN(rootBuildDir, [prefs stringForKey:RootBuildDirectory]);
  ASSIGN(buildTool, [prefs stringForKey:BuildTool]);

  promptOnClean = [prefs boolForKey:PromptOnClean];
}

- (void)updateTargetField
{
  NSString *s;
  NSString *args;

  args = [[[project projectDict] objectForKey:PCBuilderArguments] 
    componentsJoinedByString:@" "];

  if (!args) args = @" ";

  s = [NSString stringWithFormat:@"%@ with args '%@'", buildTarget, args];

  [targetField setStringValue:s];
}

// --- Accessory
- (BOOL)isBuilding
{
  return _isBuilding;
}

- (BOOL)isCleaning
{
  return _isCleaning;
}

- (void)performStartBuild
{
  if (!_isBuilding && !_isCleaning)
    {
      [buildButton performClick:self];
    }
}

- (void)performStartClean
{
  if (!_isCleaning && !_isBuilding)
    {
      [cleanButton performClick:self];
    }
}

- (void)performStopBuild
{
  if (_isBuilding)
    {
      [buildButton performClick:self];
    }
  else if (_isCleaning)
    {
      [cleanButton performClick:self];
    }
}

- (NSArray *)buildArguments
{
  NSDictionary   *projectDict = [project projectDict];
  NSMutableArray *args = [NSMutableArray new];


  [args addObjectsFromArray:[projectDict objectForKey:PCBuilderArguments]];

  // --- Get arguments from options
  if ([[projectDict objectForKey:PCBuilderDebug] isEqualToString:@"YES"])
    { // there is no clear default; the default configuration of GNUstep-make
      // uses debug=no (since release 2.2.1, it had debug=yes before), but
      // that default can easily be changed at configuration time with the
      // --enable-debug-by-default configure option.
      [args addObject:@"debug=yes"];
    }
  else
    { // default is 'debug=yes'
      [args addObject:@"debug=no"];
    }
  if ([[projectDict objectForKey:PCBuilderStrip] isEqualToString:@"YES"])
    { // default is 'strip=no'
      [args addObject:@"strip=yes"];
    }
  if ([[projectDict objectForKey:PCBuilderSharedLibs] isEqualToString:@"NO"])
    { // default is 'shared=yes'
      [args addObject:@"shared=no"];
    }
  // Always add 'messages=yes' argument. Build output parsing assumes this.
  [args addObject:@"messages=yes"];
  // "Verbose ouput" option (Build Options panel) just toogle if build shows
  // as with argument 'messages=yes' or not.
  if ([[projectDict objectForKey:PCBuilderVerbose] isEqualToString:@"YES"])
    {
      verboseBuilding = YES;
    }
  else
    {
      verboseBuilding = NO;
    }

  return args;
}

// --- GUI Actions
- (void)startBuild:(id)sender
{
  if ([self stopMake:self] == YES)
    {// We've just stopped build process
      return;
    }

  // Set build arguments
  [buildArgs addObject:buildTarget];
  [buildArgs addObjectsFromArray:[self buildArguments]];
 
//  NSLog(@"ProjectBuilder arguments: %@", buildArgs);

  currentEL = ELNone;
  lastEL = ELNone;
  nextEL = ELNone;
  lastIndentString = @"";

  buildStatus = @"Building...";
  [buildStatusTarget setString:@"Build"];
  [cleanButton setEnabled:NO];
  _isBuilding = YES;
  [self build:self];
}

- (void)startClean:(id)sender
{
  if ([self stopMake:self] == YES)
    {// We've just stopped build process
      return;
    }

  if (promptOnClean)
    {
      if (NSRunAlertPanel(@"Project Clean",
			  @"Do you really want to clean project '%@'?",
			  @"Clean", @"Stop", nil, [project projectName])
	  == NSAlertAlternateReturn)
	{
	  [cleanButton setState:NSOffState];
	  return;
	}
    }

  // Set build arguments
  [buildArgs addObject:@"clean"];
  [buildArgs addObjectsFromArray:[self buildArguments]];

  buildStatus = @"Cleaning...";
  [buildStatusTarget setString:@"Clean"];
  [buildButton setEnabled:NO];
  _isCleaning = YES;
  [self build:self];
}

- (BOOL)stopMake:(id)sender
{
  if (makeTask && [makeTask isRunning])
    {
      PCLogStatus(self, @"task will terminate");
      NS_DURING
	{
	  [makeTask terminate];
	}
      NS_HANDLER
	{
	  return NO;
	}
      NS_ENDHANDLER
      return YES;
    }

  return NO;
}

- (void)showOptionsPanel:(id)sender
{
  [buildOptions show:[[componentView window] frame]];
}

- (void)cleanupAfterMake:(NSString *)statusString
{
//  NSString *statusString;

  if (_isBuilding || _isCleaning)
    {
//      statusString =[NSString stringWithFormat: 
//	@"%@ - %@ terminated", [project projectName], buildStatusTarget];
      [statusField setStringValue:statusString];
      [[project projectWindow] updateStatusLineWithText:statusString];
    }

  // Restore buttons state
  if (_isBuilding)
    {
      [buildButton setState:NSOffState];
      [cleanButton setEnabled:YES];
      _isBuilding = NO;
    }
  else if (_isCleaning)
    {
      [cleanButton setState:NSOffState];
      [buildButton setEnabled:YES];
      _isCleaning = NO;
    }

  [buildArgs removeAllObjects];
  [buildStatusTarget setString:@"Default"];

  // Initiated in [self build:]
  [currentBuildPath release];
  [currentBuildFile release];
}

// --- Actions
- (BOOL)prebuildCheck
{
  PCFileManager   *pcfm = [PCFileManager defaultManager];
  NSFileManager   *fm = [NSFileManager defaultManager];
  NSString        *buildDir;
  PCProjectEditor *projectEditor;
  int             ret;

  // Checking for project 'edited' state 
  if ([project isProjectChanged])
    {
      ret = NSRunAlertPanel(@"Project Build",
  			    @"Project was changed and not saved.\n"
  			    @"Do you want to save project before building it?",
  			    @"Stop Build", @"Save and Build", nil);
      switch (ret)
	{
	case NSAlertDefaultReturn: // Stop Build
	  return NO;
	  break;

	case NSAlertAlternateReturn: // Save Project
	  [project save];
	  break;
	}
    }
  else
    {
      // Synchronize PC.project and generate files
      [project save];
    }

  // Checking if edited files exist
  projectEditor = [project projectEditor];
  if ([projectEditor hasModifiedFiles])
    {
      if (!PCRunSaveModifiedFilesPanel(projectEditor, 
				       @"Save and Build",
				       @"Build Anyway",
				       @"Cancel"))
	{
	  return NO;
	}
    }

  // Check build tool path
  if (!buildTool || !([fm fileExistsAtPath:buildTool] || [fm fileExistsAtPath:[buildTool stringByAppendingPathExtension: @"exe"]]))
    {
      NSRunAlertPanel(@"Project Build",
  		      @"Build tool '%@' not found. Check preferences.\n"
		      @"Build will be terminated.",
  		      @"Close", nil, nil, buildTool);
      return NO;
    }

  // Create root build directory if not exist
  if (rootBuildDir && ![rootBuildDir isEqualToString:@""])
    {
      buildDir = [NSString 
	stringWithFormat:@"%@.build", [project projectName]];
      buildDir = [rootBuildDir stringByAppendingPathComponent:buildDir];
      if (![fm fileExistsAtPath:rootBuildDir] || 
	  ![fm fileExistsAtPath:buildDir])
	{
	  [pcfm createDirectoriesIfNeededAtPath:buildDir];
	}
    }

  return YES;
}

- (void)build:(id)sender
{
  // Make runtime vars
  // Released in [self cleanupAfterMake]
  currentBuildPath = [[NSMutableString alloc] 
    initWithString:[project projectPath]];
  currentBuildFile = [[NSMutableString alloc] initWithString:@""];

  // Checking build conditions
  if ([self prebuildCheck] == NO)
    {
      [self cleanupAfterMake:[NSString stringWithFormat: 
	@"%@ - %@ terminated", [project projectName], buildStatusTarget]];
      return;
    }

  // Prepearing to building
  stdOutPipe = [[NSPipe alloc] init];
  stdOutHandle = [stdOutPipe fileHandleForReading];

  stdErrorPipe = [[NSPipe alloc] init];
  stdErrorHandle = [stdErrorPipe fileHandleForReading];

  [errorsCountField setStringValue:@""];
  errorsCount = 0;
  warningsCount = 0;

  [statusField setStringValue:buildStatus];
  [[project projectWindow] updateStatusLineWithText:buildStatus];

  // Run make task
  [logOutput setString:@""];
  [errorArray removeAllObjects];
  [errorOutput reloadData];

  [NOTIFICATION_CENTER addObserver:self 
                          selector:@selector(buildDidTerminate:) 
			      name:NSTaskDidTerminateNotification
			    object:nil];

  makeTask = [[NSTask alloc] init];
  [makeTask setArguments:buildArgs];
  [makeTask setCurrentDirectoryPath:[project projectPath]];
  [makeTask setLaunchPath:buildTool];
  [makeTask setStandardOutput:stdOutPipe];
  [makeTask setStandardError:stdErrorPipe];

  [self logBuildString:
    [NSString stringWithFormat:@"=== %@ started ===", buildStatusTarget]
	       newLine:YES];

  NS_DURING
    {
      [makeTask launch];

      // now that we know that the task is running start logging
      [stdOutHandle waitForDataInBackgroundAndNotify];
      [NOTIFICATION_CENTER addObserver:self 
			      selector:@selector(logStdOut:)
				  name:NSFileHandleDataAvailableNotification
				object:stdOutHandle];
      _isLogging = YES;

      [stdErrorHandle waitForDataInBackgroundAndNotify];
      [NOTIFICATION_CENTER addObserver:self 
			      selector:@selector(logErrOut:) 
				  name:NSFileHandleDataAvailableNotification
				object:stdErrorHandle];
      _isErrorLogging = YES;
    }
  NS_HANDLER
    {
      NSRunAlertPanel(@"Problem Launching Build Tool",
		      [localException reason],
		      @"OK", nil, nil, nil);
		      
      //Clean up after task is terminated
      [NOTIFICATION_CENTER 
	postNotificationName:NSTaskDidTerminateNotification
	              object:makeTask];
    }
  NS_ENDHANDLER
}

- (void)buildDidTerminate:(NSNotification *)aNotif
{
  int      status;
  NSString *logString;
  NSString *statusString;

  if ([aNotif object] != makeTask)
    {
      return;
    }

//  NSLog(@"task did terminate");

  [NOTIFICATION_CENTER removeObserver:self 
			         name:NSTaskDidTerminateNotification
			       object:nil];

  // If task was not launched catch exception
  NS_DURING
    {
      status = [makeTask terminationStatus];
    }
  NS_HANDLER
    {
      status = 1;
    }
  NS_ENDHANDLER
 
  // Finish task
  // TODO: Strange behaviour of pipe and file handlers alloc/release. Also
  // they have big retain count here (2 or 3). Why? Notification retains it?
  RELEASE(makeTask);
  makeTask = nil;

  // Wait while logging ends
  while (_isLogging || _isErrorLogging) 
    {
      [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
			       beforeDate:[NSDate distantFuture]];
    }

  RELEASE(stdOutPipe);
  RELEASE(stdErrorPipe);

  [self updateErrorsCountField];

  if (status == 0)
    {
      logString = [NSString stringWithFormat:@"=== %@ succeeded! ===", 
		buildStatusTarget];
      statusString = [NSString stringWithFormat:@"%@ - %@ succeeded", 
		   [project projectName], buildStatusTarget];
    } 
  else
    {
      logString = [NSString stringWithFormat:@"=== %@ terminated! ===", 
		buildStatusTarget];
      if (errorsCount > 0)
	{
	  statusString = [NSString stringWithFormat: 
	    @"%@ - %@ failed (%i errors)", 
	    [project projectName], buildStatusTarget, errorsCount];
	}
      else
	{
	  statusString = [NSString stringWithFormat:@"%@ - %@ failed", 
		       [project projectName], buildStatusTarget];
	}
    }
  [statusField setStringValue:statusString];
  [[project projectWindow] updateStatusLineWithText:statusString];
  [self logBuildString:logString newLine:YES];

  // Run post process if configured
/*  if (status && postProcess)
    {
      [self performSelector:postProcess];
      postProcess = NULL;
    }*/

  [self cleanupAfterMake:statusString];
}

// --- BuilderOptions delegate
- (void)targetDidSet:(NSString *)target
{
  [buildTarget setString:target];
  [self updateTargetField];
}

@end

@implementation PCProjectBuilder (Logging)

- (void)updateErrorsCountField
{
  NSString *string;
  NSString *errorsString = @"";
  NSString *warningsString = @"";

  if (errorsCount > 0)
    {
      if (errorsCount > 1)
	{
	  errorsString = [NSString stringWithFormat:@"%i errors", 
		       errorsCount];
	}
      else
	{
	  errorsString = @"1 error";
	}
    }

  if (warningsCount > 0)
    {
      if (warningsCount > 1)
	{
	  warningsString = [NSString stringWithFormat:@"%i warnings", 
			 warningsCount];
	}
      else
	{
	  warningsString = @"1 warning";
	}
    }

  string = [NSString stringWithFormat:@"%@ %@", errorsString, warningsString];
  [errorsCountField setStringValue:string];
}

// --- Data notifications
// Both methods make call to dipatcher logData:error:
- (void)logStdOut:(NSNotification *)aNotif
{
  NSData *data;

  if ((data = [stdOutHandle availableData]) && [data length] > 0)
    {
      [self logData:data error:NO];
      [stdOutHandle waitForDataInBackgroundAndNotify];
    }
  else
    {
      // stop logging after the task has closed the pipe
      [NOTIFICATION_CENTER removeObserver:self 
			             name:NSFileHandleDataAvailableNotification
			           object:stdOutHandle];
      _isLogging = NO;
    }
}

- (void)logErrOut:(NSNotification *)aNotif
{
  NSData *data;

  if ((data = [stdErrorHandle availableData]) && [data length] > 0)
    {
      [self logData:data error:YES];
      [stdErrorHandle waitForDataInBackgroundAndNotify];
    }
  else
    {
      // stop logging after the task has closed the pipe
      [NOTIFICATION_CENTER removeObserver:self 
			             name:NSFileHandleDataAvailableNotification
			           object:stdErrorHandle];
      _isErrorLogging = NO;
    }
}

// --- Dispatching
- (void)logData:(NSData *)data
          error:(BOOL)isError
{
  NSString *dataString;
  NSRange  newLineRange;
  NSRange  lineRange;
  NSString *lineString;

  dataString = [[NSString alloc] 
    initWithData:data 
	encoding:[NSString defaultCStringEncoding]];
			    
  // Process new data
  lineRange.location = 0;
  newLineRange.location = 0;
  // 'errorString' collects data across logData:error: calls until 
  // new line character is appeared.
  [errorString appendString:dataString];
  while (newLineRange.location != NSNotFound)
    {
      newLineRange = [errorString rangeOfString:@"\n"];
/*      NSLog(@"Line(%i) new line range: %i,%i for string\n<--|%@|-->", 
	    [errorString length],
	    newLineRange.location, newLineRange.length, 
	    errorString);*/

      if (newLineRange.location < [errorString length])
	{
//  	  NSLog(@"<------%@------>", errorString);

	  lineRange.length = newLineRange.location+1;
	  lineString = [errorString substringWithRange:lineRange];
	  [errorString deleteCharactersInRange:lineRange];

	  // Send it to error view
	  // Do not process make errors in other mode but building. Maybe
	  // some day...
	  if (_isBuilding && isError)
	    {
    	      [self logErrorString:lineString];
	    }
	  // Cleaning or building standard out string
	  if (!isError || verboseBuilding)
	    {
	      [self logBuildString:lineString newLine:NO];
	    }
	}
      else
	{
	  newLineRange.location = NSNotFound;
	  continue;
	}
    }

  RELEASE(dataString);
}

@end

@implementation PCProjectBuilder (BuildLogging)

// --- Parsing utilities
- (BOOL)line:(NSString *)lineString startsWithString:(NSString *)substring
{
  NSInteger position = 0;
  NSRange   range = NSMakeRange(position,1);

  while ([[lineString substringWithRange:range] isEqualToString:@" "])
    {
      range.location = ++position;
    }

/*  NSLog(@"Line '%@' position: %i substring '%@'", 
	lineString, position, substring);*/

  range = [lineString rangeOfString:substring];
  if ((range.location == NSNotFound) ||
      (range.location != position))
    {
      return NO;
    }

  return YES;
}

// Clean leading spaces and return cleaned array of components
- (NSArray *)componentsOfLine:(NSString *)lineString
{
  NSArray        *lineComponents;
  NSMutableArray *tempComponents;

  lineComponents = [lineString componentsSeparatedByString:@" "];
  tempComponents = [NSMutableArray arrayWithArray:lineComponents];

  while ([[tempComponents objectAtIndex:0] isEqualToString:@""])
    {
      [tempComponents removeObjectAtIndex:0];
    }

  return tempComponents;
}

// Line starts with 'gmake' or 'make'.
// Changes 'currentBuildPath' if line starts with 
// "Entering directory" or "Leaving directory".
// For example: 
// gmake[1]: Entering directory '/Users/me/Project/Subproject.subproj'
- (void)parseMakeLine:(NSString *)lineString
{
  NSMutableArray *makeLineComponents;
  NSString       *makeLine;
  NSString       *pathComponent;
  NSString       *path;

  //  NSLog(@"parseMakeLine: %@", lineString);

  makeLineComponents = [NSMutableArray 
    arrayWithArray:[lineString componentsSeparatedByString:@" "]];

  // Don't check for item at index 0 contents (it's 'gmake[1]:' or 'make[1]:') 
  // just remove it.
  [makeLineComponents removeObjectAtIndex:0];
  makeLine = [makeLineComponents componentsJoinedByString:@" "];

  if ([self line:makeLine startsWithString:@"Entering directory"])
    {
      pathComponent = [makeLineComponents objectAtIndex:2];
      path = [pathComponent
	substringWithRange:NSMakeRange(1,[pathComponent length]-3)]; 
//      NSLog(@"Go down to %@", path);
      [currentBuildPath setString:path];
    }
  else if ([self line:makeLine startsWithString:@"Leaving directory"])
    {
//      NSLog(@"Go up from %@", [makeLineComponents objectAtIndex:2]);
      [currentBuildPath 
	setString:[currentBuildPath stringByDeletingLastPathComponent]];
    }
//  NSLog(@"Current build path: %@", currentBuildPath);
}

// Should return:
// 'Compiling ...'
// 'Linking ...'
// Also updates currentBuildFile
- (NSString *)parseCompilerLine:(NSString *)lineString
{
  NSArray  *lineComponents = [self componentsOfLine:lineString];
  NSString *outputString = nil;

  if ([lineComponents containsObject:@"-c"])
    {
      [currentBuildFile setString:[lineComponents objectAtIndex:1]];
      outputString = [NSString 
	stringWithFormat:@" Compiling %@...\n", currentBuildFile];
    }
  else if ([lineComponents containsObject:@"-rdynamic"])
    {
      outputString = [NSString 
	stringWithFormat:@" Linking %@...\n", 
	[lineComponents objectAtIndex:[lineComponents indexOfObject:@"-o"]+1]];
    }

  return outputString;
}
// --- Parsing utilities end

// Log output
- (void)logBuildString:(NSString *)string
	       newLine:(BOOL)newLine
{
  NSString *logString = [self parseBuildLine:string];

  if (!logString)
    {
      return;
    }

  [logOutput replaceCharactersInRange:
    NSMakeRange([[logOutput string] length],0) withString:logString];

  if (newLine)
    {
      [logOutput replaceCharactersInRange:
	NSMakeRange([[logOutput string] length], 0) withString:@"\n"];
    }

  [logOutput scrollRangeToVisible:NSMakeRange([[logOutput string] length], 0)];
  [logOutput setNeedsDisplay:YES];
}

// Standard out is parsed for detection of directory, file, etc.
// Gets complete line (ended with '\n') as argument
- (NSString *)parseBuildLine:(NSString *)string
{
  NSArray  *components = [self componentsOfLine:string];
  NSString *parsedString = nil;

  if (!components)
    {
      return nil;
    }

  if ([self line:string startsWithString:@"gmake"] ||
      [self line:string startsWithString:@"make"])
    {// Do current path detection
      [self parseMakeLine:string];
    }
  else if ([self line:string startsWithString:@"gcc"] ||
           [self line:string startsWithString:@"egcc"] ||
           [self line:string startsWithString:@"clang"])
    {// Parse compiler output
      parsedString = [self parseCompilerLine:string];
    }
  else if ([self line:string startsWithString:@"Making"] ||
	   [self line:string startsWithString:@"==="])
    {// It's a gnustep-make and self output
      parsedString = string;
    }

  if (parsedString && ![self line:parsedString startsWithString:@"==="])
    {
      [statusField setStringValue:parsedString];
      [[project projectWindow] updateStatusLineWithText:parsedString];
    }

  if (verboseBuilding)
    {
      return string;
    }
  else
    {
      return parsedString;
    }
}

@end

@implementation PCProjectBuilder (ErrorLogging)

// Entry point for error logging
- (void)logErrorString:(NSString *)string
{
  NSArray *items;

  items = [self parseErrorLine:string];
  if (items)
    {
      [errorArray addObjectsFromArray:items];
      [errorOutput reloadData];
      [errorOutput scrollRowToVisible:[errorArray count]-1];
    }
}

// Used for warning or error message retrieval
- (NSString *)lineTail:(NSString*)line afterString:(NSString*)string
{
  NSRange substrRange;

  substrRange = [line rangeOfString:string];
/*  NSLog(@"In function ':%i:%i", 
	substrRange.location, substrRange.length);*/
  substrRange.location += substrRange.length;
  substrRange.length = [line length] - (substrRange.location);
/*  NSLog(@"In function ':%i:%i", 
	substrRange.location, substrRange.length);*/

  return [line substringWithRange:substrRange];
}

- (NSArray *)parseErrorLine:(NSString *)string
{
  NSArray             *components = [string componentsSeparatedByString:@":"];
  NSString            *file = @"";
  NSString            *includedFile = @"";
  NSString            *position = @"{x=0; y=0}";
  NSString            *type = @"";
  NSString            *message = @"";
  NSMutableArray      *items = [NSMutableArray arrayWithCapacity:1];
  NSMutableDictionary *errorItem;
  NSString            *indentString = @"\t";
  NSString            *lastFile = @"";
  NSString            *lastIncludedFile = @"";

  NSAttributedString  *attributedString;
  NSMutableDictionary *attributes = [NSMutableDictionary new];
  NSFont              *font = [NSFont boldSystemFontOfSize:12.0];

  [attributes setObject:font forKey:NSFontAttributeName];
  [attributes setObject:[NSNumber numberWithInt:NSSingleUnderlineStyle] 
		 forKey:NSUnderlineStyleAttributeName];

  lastEL = currentEL;
  //  NSLog(@"error string: %@", string);
/*  if (lastEL == ELFile) NSLog(@"+++ELFile");
  if (lastEL == ELFunction) NSLog(@"+++ELFunction");
  if (lastEL == ELIncluded) NSLog(@"+++ELIncluded");
  if (lastEL == ELError) NSLog(@"+++ELError");
  if (lastEL == ELNone) NSLog(@"+++ELNone");*/
  //NSLog(@"components: %lu, %@", (unsigned long)[components count], components);
  if ([errorArray count] > 0)
    {
      lastFile = [[errorArray lastObject] objectForKey:@"File"];
      lastIncludedFile = [[errorArray lastObject] objectForKey:@"IncludedFile"];
    }

  if ([string rangeOfString:@"In file included from "].location != NSNotFound)
    {
      currentEL = ELIncluded;
      return nil;
    }
  else if ([string rangeOfString:@"In function '"].location != NSNotFound)
    {
      currentEL = ELFunction;
      return nil;
    }
  else if ([string rangeOfString:@" At top level:"].location != NSNotFound)
    {
      currentEL = ELFile;
      return nil;
    }
  else if ([components count] > 3)
    {
      NSUInteger typeIndex;
      NSString   *substr;

      // file and includedFile
      file = [currentBuildPath  
	stringByAppendingPathComponent:currentBuildFile];
      if (lastEL == ELIncluded 
	  || [[components objectAtIndex:0] isEqualToString:lastIncludedFile])
	{// first message after "In file included from"
//	  NSLog(@"Inlcuded File: %@", file);
	  includedFile = [components objectAtIndex:0];
      	  file = 
	    [currentBuildPath stringByAppendingPathComponent:includedFile];
	  currentEL = ELIncludedError;
	}
      else
	{
	  currentEL = ELError;
	}

      // type
      typeIndex = NSNotFound;
      if ((typeIndex = [components indexOfObject:@" warning"]) != NSNotFound)
	{
	  type = [components objectAtIndex:typeIndex];
	  warningsCount++;
	}
      else if ((typeIndex = [components indexOfObject:@" note"]) != NSNotFound) // generated by clang
	{
	  type = [components objectAtIndex:typeIndex];
	}
      else if ((typeIndex = [components indexOfObject:@" error"]) != NSNotFound)
	{
	  type = [components objectAtIndex:typeIndex];
	  errorsCount++;
	}
      else if ((typeIndex = [components indexOfObject:@" fatal error"]) != NSNotFound)
	{
	  type = [components objectAtIndex:typeIndex];
	  errorsCount++;
	}

      //     NSLog(@"typeIndex: %u", (unsigned int)typeIndex);
      // position
      if (typeIndex == 2) // :line:
	{
	  int      lInt = atoi([[components objectAtIndex:1] cString]);
	  NSNumber *lNumber = [NSNumber numberWithInt:lInt];

          //          NSLog(@"type 2, parsed l: %i", lInt);
	  position = [NSString stringWithFormat:@"{x=%i; y=0}", 
		   [lNumber intValue]];
	}
      else if (typeIndex == 3) // :line:column:
	{
	  int      lInt = atoi([[components objectAtIndex:1] cString]);
	  int      cInt = atoi([[components objectAtIndex:2] cString]);
	  NSNumber *lNumber = [NSNumber numberWithInt:lInt];
	  NSNumber *cNumber = [NSNumber numberWithInt:cInt];

          //          NSLog(@"type 3, parsed l,c: %i, %i", lInt, cInt);
	  position = [NSString stringWithFormat:@"{x=%i; y=%i}", 
	      	   [lNumber intValue], [cNumber intValue]];
	}
      // message
      substr = [NSString stringWithFormat:@"%@:", type];
      message = [self lineTail:string afterString:substr];
    }
  else
    {
      return nil;
    }

  // Insert indentation
  if (currentEL == ELError)
    {
      if (lastEL == ELFunction)
	{
	  indentString = @"\t\t";
	}
      else if (lastEL == ELError)
	{
	  indentString = [NSString stringWithString:lastIndentString];
	}
    }
  else if (currentEL == ELIncluded)
    {
      indentString = @"";
    }
/*  else if (currentEL == ELIncludedError)
    {
      indentString = @"\t\t";
    }*/

  message = [NSString stringWithFormat:@"%@%@", indentString, message];
  lastIndentString = [indentString copy];

  // Create array items
  if ((lastEL == ELNone || ![file isEqualToString:lastFile]) 
      && [includedFile isEqualToString:@""])
    {
//      NSLog(@"lastEL == ELNone (%@)", includedFile);
//      NSLog(@"File: %@ != %@", file, lastFile);
      errorItem = [NSMutableDictionary dictionaryWithCapacity:1];
      [errorItem setObject:@"" forKey:@"ErrorImage"];
      [errorItem setObject:[file copy] forKey:@"File"];
      [errorItem setObject:[includedFile copy] forKey:@"IncludedFile"];
      [errorItem setObject:@"" forKey:@"Position"];
      [errorItem setObject:@"" forKey:@"Type"];
  
      attributedString = [[NSAttributedString alloc] 
	initWithString:[file lastPathComponent]
	    attributes:attributes];
      [errorItem setObject:[attributedString copy] forKey:@"Error"];
      [attributedString release];

      [items addObject:errorItem];
    }

  if ((lastEL == ELIncluded || currentEL == ELIncludedError)
      && ![includedFile isEqualToString:lastIncludedFile])
    {
      NSString *incMessage = [NSString stringWithFormat:@"%@", includedFile];

//      NSLog(@"Included: %@ != %@", includedFile, lastIncludedFile);
      errorItem = [NSMutableDictionary dictionaryWithCapacity:1];
      [errorItem setObject:@"" forKey:@"ErrorImage"];
      [errorItem setObject:[file copy] forKey:@"File"];
      [errorItem setObject:[includedFile copy] forKey:@"IncludedFile"];
      [errorItem setObject:@"" forKey:@"Position"];
      [errorItem setObject:@"" forKey:@"Type"];

      attributedString = [[NSAttributedString alloc] initWithString:incMessage
							 attributes:attributes];
      [errorItem setObject:[attributedString copy] forKey:@"Error"];
      [attributedString release];

      [items addObject:errorItem];
    }

  errorItem = [NSMutableDictionary dictionaryWithCapacity:1];
  [errorItem setObject:@"" forKey:@"ErrorImage"];
  [errorItem setObject:[file copy] forKey:@"File"];
  [errorItem setObject:[includedFile copy] forKey:@"IncludedFile"];
  [errorItem setObject:[position copy] forKey:@"Position"];
  [errorItem setObject:[type copy] forKey:@"Type"];
  [errorItem setObject:[message copy] forKey:@"Error"];

//  NSLog(@"Parsed message:%@ (%@)", message, includedFile);

  [items addObject:errorItem];

  return items;
}

// --- Error output table delegate methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
  if (errorArray != nil && aTableView == errorOutput)
    {
      return [errorArray count];
    }

  return 0;
}
    
- (id)            tableView:(NSTableView *)aTableView
  objectValueForTableColumn:(NSTableColumn *)aTableColumn
                        row:(NSInteger)rowIndex
{
  NSDictionary *errorItem;

  if (errorArray != nil && aTableView == errorOutput)
    {
      errorItem = [errorArray objectAtIndex:rowIndex];

      return [errorItem objectForKey:[aTableColumn identifier]];
    }

  return nil;
}

- (void)errorItemClick:(id)sender
{
  NSInteger       rowIndex = [errorOutput selectedRow];
  NSDictionary    *error = [errorArray objectAtIndex:rowIndex];
  NSPoint         position;
  PCProjectEditor *projectEditor = [project projectEditor];
  id<CodeEditor>  editor;

  editor = [projectEditor openEditorForFile:[error objectForKey:@"File"]
				   editable:YES
				   windowed:NO];
  if (editor)
    {
      // TODO / FIXME using a NSPoint here is weak since it is Float vs. integer line numbers
      position = NSPointFromString([error objectForKey:@"Position"]);
      [projectEditor orderFrontEditorForFile:[error objectForKey:@"File"]];
      [editor scrollToLineNumber:(NSUInteger)position.x];

/*      NSLog(@"%i: %@(%@): %@", 
	    position.x, 
	    [error objectForKey:@"File"], 
	    [error objectForKey:@"IncludedFile"],
	    [error objectForKey:@"Error"]);*/
    }
}

@end

