/*
 File:       ApplicationDelegate.m
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#import <DesktopKit/NXTAlert.h>

#include "ApplicationDelegate.h"
#include "Foundation/NSObjCRuntime.h"
#include "NSArray+utils.h"
#include "NSColor+utils.h"
#include "NSFileManager+unique.h"
#include "NSString+utils.h"

@implementation ApplicationDelegate

// - (BOOL)applicationShouldTerminate:(NSApplication *)app;
//
// The app is about to terminate, so we'll cleanup after ourselves,
// removing temporary files as required.

- (BOOL)applicationShouldTerminate:(NSApplication *)app;
{
  BOOL tempFilesExist;
  BOOL deleteTempFilesOnQuit;

  // If there are no files in the /tmp directory, we will just go
  // ahead and delete the temporary directory
  tempFilesExist =
      ([[[NSFileManager defaultManager] directoryContentsAtPath:appWorkingDirectory] count] != 0);

  // We read this default to determine if we should bother to ask,
  // or just go a head and delete the files
  deleteTempFilesOnQuit =
      [[NSUserDefaults standardUserDefaults] boolForKey:@"DeleteTempFilesOnQuit"];

  // If there are temp files and we are supposed to ask instead
  // of just deleting the directory
  if (tempFilesExist && !deleteTempFilesOnQuit) {
    int result;
    result = NXTRunAlertPanel(
        @"OpenUp",
        NSLocalizedString(@"TempDirectoryDeleteWarning", @"Delete temporary files in %@"),
        NSLocalizedString(@"TempDirectoryDeleteYesButton", @"Yes"),
        NSLocalizedString(@"TempDirectoryDeleteNoButton", @"No"),
        NSLocalizedString(@"TempDirectoryDeleteCancelButton", @"Cancel"), appWorkingDirectory);

    if (result == NSAlertDefaultReturn) {
      // the user has selected to remove all the files so, we
      // delete the temporary directory and return YES so that
      // the app will quit
      [[NSFileManager defaultManager] removeFileAtPath:appWorkingDirectory handler:nil];
      return YES;
    }
    if (result == NSAlertAlternateReturn)
      // the user has selected to retain the temp files
      // so we do nothing and return YES so that the app will quit
      return YES;
    if (result == NSAlertOtherReturn)
      // the user has clicked cancel
      // return NO so that the app will not quit
      return NO;
  } else {
    // Either there are no files in our temporary directory,
    // or the user has elected to delete the temp files by
    // default either way, we delete our temporary directory
    // and fall through
    [[NSFileManager defaultManager] removeFileAtPath:appWorkingDirectory handler:nil];
  }

  return YES;
}

// - (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
// - (BOOL)application:(NSApplication *)sender openTempFile:(NSString *)filename;
//
// These methods are called when a file is double clicked on in the
// Workspace to open OpenUp.

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
{
  // simply forward to the decompressFile: method the filename
  // that we were passed to open
  NSLog(@"openFile: %@", filename);

  [self decompressFile:filename];
  return YES;
}

- (BOOL)application:(NSApplication *)sender openTempFile:(NSString *)filename;
{
  // simply forward to the decompressFile: method the filename
  // that we were passed to open

  return [self application:sender openFile:filename];
}

// - (void)initializationFailure:(NSString *)value;
//
// Its necessary to seperate this from the awakeFromNib method,
// since you can't call NSRunAlertPanel in the awakeFromNib because
// the runloop isn't going yet.  The application hasn't finished
// starting yet.  If an error condition is found during the startup,
// then this method is performed using
// performDelayed:withObject:afterDelay:

- (void)initializationFailure:(NSString *)value;
{
  NXTRunAlertPanel(@"OpenUp", value, NSLocalizedString(@"InitializationFailureButton", @"OK"), NULL,
                  NULL);

  [[NSApplication sharedApplication] terminate:self];
}

// -(void)awakeFromNib;
//
// Another workhorse, this method attempts to setup the working
// directory information and ensure that the information is valid
// before the application finishes launching, or attempts to open
// a file that was double clicked on in the Workspace.

- (void)awakeFromNib;
{
  NSString *baseFilename;
  NSString *thePath;
  NSString *tempFilesDefaultValue;
  NSString *errorString = nil;

  // read the user defaults
  [self setupUserDefaults];

  // read the configuration plist which gives us the launchPath
  // and arguments to use for the decompression of various filetypes,
  // as well as the file types to match
  //
  // the configuration is stored in the application's wrapper and
  // then retain the dictionary and array for further use
  thePath = [[NSBundle mainBundle] pathForResource:@"filesConfig" ofType:@"plist"];
  fileTypeConfigArray = [[NSArray arrayWithContentsOfFile:thePath] retain];
  if (!fileTypeConfigArray) {
    errorString = [NSString stringWithString:NSLocalizedString(@"ErrorLoadingFilesConfig",
                                                               @"Error Loading Files Config")];
  }

  thePath = [[NSBundle mainBundle] pathForResource:@"servicesConfig" ofType:@"plist"];
  servicesDictionary = [[NSDictionary dictionaryWithContentsOfFile:thePath] retain];
  if (!servicesDictionary) {
    errorString = [NSString stringWithString:NSLocalizedString(@"ErrorLoadingServicesConfig",
                                                               @"Error Loading Services Config")];
  }

  // the baseFilename will be used by our Category on NSFileManager
  // to create a unique directory with a more friendly name than
  // we could get using the conventional [NSProcessInfo
  // globallyUniqueString] Its important that it contain a %@
  // somewhere in its name
  //
  // if we can create the directory, then we'll setup the
  // appWorkdingDirectory and retain the path otherwise, we should
  // quit
  //
  // actually in the otherwise case we should determine the problem
  // and inform the user.  Its interesting to note that we can't
  // just put up an NSRunAlertPanel at this point, since the
  // runloop isn't running, so we send our ApplicationDelegate
  // object a performSelector:withObject:afterDelay:  so that the
  // NSRunAlertPanel is delayed until the runloop has already
  // started.
  if (!errorString) {
    NSString *tempPath = nil;

    baseFilename = [NSString stringWithFormat:@"%@_%%@", [[NSProcessInfo processInfo] processName]];
    tempFilesDefaultValue =
        [[NSUserDefaults standardUserDefaults] stringForKey:@"TempFilesDirectory"];
    tempPath = [[NSFileManager defaultManager] createUniqueDirectoryAtPath:tempFilesDefaultValue
                                                          withBaseFilename:baseFilename
                                                                attributes:nil];
    if (tempPath)
      appWorkingDirectory = [tempPath retain];
    else
      errorString =
          [NSString stringWithFormat:NSLocalizedString(@"InitializationFailure",
                                                       @"Failed to Create Directory in %@"),
                                     tempFilesDefaultValue];
  }
  if (errorString)
    [self performSelector:@selector(initializationFailure:) withObject:errorString afterDelay:0];

  // lets set up some other UI bits now too
  //
  [errorTextView setFont:[NSFont userFixedPitchFontOfSize:10]];
  [errorTextView setBackgroundColor:[NSColor tanTextBackgroundColor]];
  [debugTextView setFont:[NSFont userFixedPitchFontOfSize:10]];
  [debugTextView setBackgroundColor:[NSColor tanTextBackgroundColor]];
}

// -(void)applicationDidFinishLaunching:(NSNotification *)aNotification;
//
// Sent when the application is finished loading we set our
// ApplicationDelegate (this object) to be the target for Services
// to notify and register a request for notification on
// windowDidBecomeMain:

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
{
  [NSApp setServicesProvider:self];
}

// - (void)setupUserDefaults;
//
// This should probably be added to NSUserDefaults as a category,
// since its universally useful.  It loads a defaults.plist file
// from the app wrapper, and then sets the defaults if they don't
// already exist.

- (void)setupUserDefaults;
{
  NSUserDefaults *defaults;
  NSDictionary *defaultsPlist;
  NSEnumerator *overDefaults;
  id eachDefault;

  // this isn't required, but saves us a few method calls
  defaults = [NSUserDefaults standardUserDefaults];

  // load the defaults.plist from the app wrapper.  This makes it
  // easy to add new defaults just using a text editor instead of
  // hard-coding them into the application
  defaultsPlist =
      [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"defaults"
                                                                                 ofType:@"plist"]];

  // enumerate over all the keys in the dictionary
  overDefaults = [[defaultsPlist allKeys] objectEnumerator];
  while ((eachDefault = [overDefaults nextObject])) {
    // for each key in the dictionary
    // check if there is a value already registered for it
    // and if there isn't, then register the value that was in the file
    if (![defaults stringForKey:eachDefault])
      [defaults setObject:[defaultsPlist objectForKey:eachDefault] forKey:eachDefault];
  }

  // force the defaults to save to the disk
  [defaults synchronize];
  [preferencesDeleteFilesCheckbox
      setIntValue:[[NSUserDefaults standardUserDefaults] boolForKey:@"DeleteTempFilesOnQuit"]];
}

// - (void)dealloc;
//
// release the objects that we have explicitly retained,
// and then call [super dealloc]

- (void)dealloc;
{
  [infoPanelSupportedTypes release];
  [appWorkingDirectory release];
  [fileTypeConfigArray release];
  [servicesDictionary release];
  [super dealloc];
}

// - selectedDeleteTempFilesOnQuit:sender;
//
// Each time you click on the checkbox in the Preferences Panel,
// this method is called.  It determines the state of the checkbox
// and then sets the default as appropriate

- selectedDeleteTempFilesOnQuit:sender;
{
  // This is called every time you click on the check box, its
  // connection is made in Interface Builder the defaults are
  // saved periodically to disk, but we'll force it in this case.
  [[NSUserDefaults standardUserDefaults] setBool:([sender intValue] == 1)
                                          forKey:@"DeleteTempFilesOnQuit"];
  [[NSUserDefaults standardUserDefaults] synchronize];

  return self;
}

// methods common to decompression and compression

- (NSString *)shellPathUsingConfiguration:(NSDictionary *)fileConfig;
{
  if ([fileConfig objectForKey:@"shell"])
    return [fileConfig objectForKey:@"shell"];

  return [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultShell"];
}

- (NSArray *)shellArgsUsingConfiguration:(NSDictionary *)fileConfig;
{
  if ([fileConfig objectForKey:@"shell_args"])
    return [fileConfig objectForKey:@"shell_args"];

  return [NSArray
      arrayWithObject:[[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultShellArgs"]];
}

- (NSDictionary *)wrappedProgramsUsingConfiguration:(NSDictionary *)fileConfig;
{
  NSMutableArray *outKeys, *outValues;
  NSArray *keys;
  NSMutableDictionary *outDict;
  NSEnumerator *keysEnumerator;
  NSString *eachKey;

  keys = [fileConfig objectForKey:@"wrapped_programs"];
  outKeys = [NSMutableArray array];
  outValues = [NSMutableArray array];

  keysEnumerator = [keys objectEnumerator];
  while ((eachKey = [keysEnumerator nextObject])) {
    NSString *pathToProg;
    NSString *theKey;

    theKey = [NSString stringWithFormat:@"%%%%WRAPPED_PROGRAM_%@%%%%", [eachKey uppercaseString]];
    pathToProg = [[NSBundle mainBundle] pathForResource:eachKey ofType:@""];

    [outKeys addObject:theKey];

    if (pathToProg)
      [outValues addObject:pathToProg];
    else
      [outValues addObject:eachKey];
  }
  outDict = [NSMutableDictionary dictionary];
  [outDict setObject:outKeys forKey:@"keys"];
  [outDict setObject:outValues forKey:@"values"];

  return [NSDictionary dictionaryWithDictionary:outDict];
}

@end
