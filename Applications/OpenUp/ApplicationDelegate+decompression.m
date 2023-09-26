/*
 File:       ApplicationDelegate+decompression.m
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#import <AppKit/NSWorkspace.h>
#import <DesktopKit/NXTOpenPanel.h>

#import "ApplicationDelegate.h"
#import "NSArray+utils.h"
#import "NSColor+utils.h"
#import "NSFileManager+unique.h"
#import "NSString+utils.h"
#import "NSTask+utils.h"

@implementation ApplicationDelegate (decompression)

- (void)openArchive:(id)sender
{
  int result, i, numberOfFiles;
  // NSArray *theArray;
  NXTOpenPanel *sharedOpenPanel = [NXTOpenPanel openPanel];
  NSArray *filesToOpen;

  [sharedOpenPanel setAllowsMultipleSelection:YES];
  [sharedOpenPanel setCanChooseFiles:YES];
  result = [sharedOpenPanel runModalForDirectory:NSHomeDirectory()
                                            file:nil
                                           types:[self allSupportedFileExtensions]];
  if (result == NSOKButton) {
    filesToOpen = [sharedOpenPanel filenames];
    numberOfFiles = [filesToOpen count];
    for (i = 0; i < numberOfFiles; i++) {
      [self decompressFile:[filesToOpen objectAtIndex:i]];
    }
  }
}

- (NSArray *)allSupportedFileExtensions
{
  NSEnumerator *overFileTypes;
  NSDictionary *eachFileType;
  NSMutableArray *theArray = [NSMutableArray array];

  overFileTypes = [fileTypeConfigArray objectEnumerator];
  while ((eachFileType = [overFileTypes nextObject])) {
    id extensions = [eachFileType objectForKey:@"file_extension"];
    if ([extensions isKindOfClass:[NSArray class]]) {
      int i;
      for (i = 0; i < [extensions count]; i++) {
        [theArray addObject:[[extensions objectAtIndex:i] substringFromIndex:1]];
      }
    } else {
      [theArray addObject:[extensions substringFromIndex:1]];
    }
  }
  return theArray;
}

- (NSString *)fileExtensionIn:extensions matchingString:(NSString *)theString
{
  NSArray *fileExtensions;
  NSEnumerator *subEnumerator;
  NSString *eachFileExtension;

  // This method can except either NSArray's or NSString's in the
  // extensions variable.  The reason for this was so that if the
  // user accidently mis-configures the plist, it will still work
  // (I had alot of single string entries at one point)

  if ([extensions isKindOfClass:[NSArray class]])
    fileExtensions = extensions;
  else
    fileExtensions = [NSArray arrayWithObject:extensions];

  subEnumerator = [fileExtensions objectEnumerator];
  while ((eachFileExtension = [subEnumerator nextObject])) {
    if ([theString hasSuffix:eachFileExtension])
      return eachFileExtension;
  }
  return nil;
}

// - (NSDictionary *)matchFileToConfig:(NSString *)archivePath;
//
// This method matches the file that we are trying to decompress to
// the appropriate dictionary which contains the decompression
// instructions
- (NSDictionary *)matchFileToConfig:(NSString *)archivePath
{
  NSString *filename;
  NSEnumerator *overLaunchConfig;
  id eachItem;

  // isolate the filename from the path to the file
  filename = [archivePath lastPathComponent];

  //
  // grab the configuration table that we loaded during the awakeFromNib
  //
  // this object is an array of NSDictionaries with the information
  // we'll use to actually launch a task
  //
  // At first glance, it may appear that it would have been better to
  // keep these values in an NSDictionary with a key for each filetype
  // and select the individual dictionary we need using an
  // objectForKey:[filename pathExtension]
  //
  // The problem there is that we can't predict the order that the
  // keys will be searched, and that is important for our application.
  // Also file.tar.gz and file.gz both would be considered _just_ .gz
  // files by that method, which means we'd have to go through an
  // additional step to decompress the resultant .tar file.  This way
  // we can ensure that a file is checked against the longest match
  // first (.tar.gz) and if it doesn't match that, then try the shorter
  // substrings.

  overLaunchConfig = [fileTypeConfigArray objectEnumerator];
  while ((eachItem = [overLaunchConfig nextObject])) {
    // check the entire fileType key against the end of the
    // filename, if it matches then return that sub dictionary,
    // otherwise, continue testing

    if ([self fileExtensionIn:[eachItem objectForKey:@"file_extension"] matchingString:filename])
      return eachItem;
  }

  // no matches?  Return nil, the calling code will handle the situation
  return nil;
}

// - (void)decompressFile:(NSString *)archivePath;
//
// These two methods handle the decompression and compression of
// the archives
//
- (void)decompressFile:(NSString *)archivePath
{
  NSString *shellPath;
  NSArray *shellArgs;

  NSMutableArray *launchArguments;

  NSString *unarchiveDirectoryPath;
  NSDictionary *fileConfig;
  NSString *commandBeforeSubstitution;
  NSString *commandAfterSubstitution;

  NSString *fileExtension;
  NSString *archiveFilenameWithoutPath;
  NSString *archiveFilenameWithoutFileExtension;
  NSString *archiveFilenameWithoutFileExtensionNoDots;
  NSString *archiveFilenameWithoutPathWithoutFileExtension;
  NSString *basenameForUnarchiveDirectory;
  NSString *applicationWrapperPath;
  NSString *applicationResourcesWrapperPath;
  NSMutableArray *searchValues, *replaceValues;
  NSDictionary *substitutionKeysForWrappedPrograms;
  NSDictionary *taskResults;

  // determine the unix application to launch, and the command
  // line arguments to use based on the filename if we are unable
  // to match the filename to any of the suffixes we know how to
  // decompress then skip it..  mind you, this will only occur if
  // you've edited the config.plist in error or if you've messed
  // with the file types we support.
  //
  // we should probably warn the user at this point..
  fileConfig = [self matchFileToConfig:archivePath];
  //  NSLog(@"fileConfig: %@", fileConfig);
  if (!fileConfig)
    return;

  shellPath = [self shellPathUsingConfiguration:fileConfig];
  shellArgs = [self shellArgsUsingConfiguration:fileConfig];
  NSLog(@"RUN: %@ %@", shellPath, shellArgs);

  applicationWrapperPath = [[NSBundle mainBundle] bundlePath];
  applicationResourcesWrapperPath = [[NSBundle mainBundle] resourcePath];

  fileExtension = [self fileExtensionIn:[fileConfig objectForKey:@"file_extension"]
                         matchingString:archivePath];
  archiveFilenameWithoutPath = [archivePath lastPathComponent];

  archiveFilenameWithoutFileExtension = [archivePath stringByDeletingSuffix:fileExtension];
  archiveFilenameWithoutPathWithoutFileExtension =
      [archiveFilenameWithoutPath stringByDeletingSuffix:fileExtension];

  archiveFilenameWithoutFileExtensionNoDots =
      [archiveFilenameWithoutPathWithoutFileExtension stringByReplacing:@"." with:@"_"];

  basenameForUnarchiveDirectory =
      [NSString stringWithFormat:@"O_%@_%%@", archiveFilenameWithoutFileExtensionNoDots];

  unarchiveDirectoryPath =
      [[NSFileManager defaultManager] createUniqueDirectoryAtPath:appWorkingDirectory
                                                 withBaseFilename:basenameForUnarchiveDirectory
                                                       attributes:nil];

  // If we can't create a new directory in the working directory, we
  // punt.
  if (!unarchiveDirectoryPath) {
    NSRunAlertPanel(@"OpenUp",
                    NSLocalizedString(@"DecompressionFailedTempDirectoryFailed",
                                      @"Unable to create temp directory in %@"),
                    NSLocalizedString(@"DecompressionFailedOK", @"OK"), NULL, NULL,
                    appWorkingDirectory);
    return;
  }

  substitutionKeysForWrappedPrograms = [self wrappedProgramsUsingConfiguration:fileConfig];

  NSLog(@"\r%@\r", substitutionKeysForWrappedPrograms);

  commandBeforeSubstitution = [fileConfig objectForKey:@"command"];
  searchValues = [NSMutableArray
      arrayWithObjects:@"%%FILE%%", @"%%FILENAME-WITHOUT_PATH%%",
                       @"%%FILENAME-WITHOUT_FILE_EXTENSION%%",
                       @"%%FILENAME-WITHOUT_FILE_EXTENSION-WITHOUT_PATH%%", @"%%FILE_EXTENSION%%",
                       @"%%TEMPORARY_DIRECTORY%%", @"%%APP_BUNDLE_DIRECTORY%%",
                       @"%%APP_RESOURCE_DIRECTORY%%", nil];

  [searchValues addObjectsFromArray:[substitutionKeysForWrappedPrograms objectForKey:@"keys"]];

  replaceValues = [NSMutableArray
      arrayWithObjects:[archivePath stringWithShellCharactersQuoted],
                       [archiveFilenameWithoutPath stringWithShellCharactersQuoted],
                       [archiveFilenameWithoutFileExtension stringWithShellCharactersQuoted],
                       [archiveFilenameWithoutPathWithoutFileExtension
                           stringWithShellCharactersQuoted],
                       fileExtension, [unarchiveDirectoryPath stringWithShellCharactersQuoted],
                       [applicationWrapperPath stringWithShellCharactersQuoted],
                       [applicationResourcesWrapperPath stringWithShellCharactersQuoted], nil];
  [replaceValues addObjectsFromArray:[substitutionKeysForWrappedPrograms objectForKey:@"values"]];

  NSLog(@"Search: %@", searchValues);
  NSLog(@"Replace with: %@", replaceValues);

  commandAfterSubstitution =
      [commandBeforeSubstitution stringByReplacingValuesInArray:searchValues
                                              withValuesInArray:replaceValues];
  launchArguments = [shellArgs mutableCopy];
  [launchArguments addObject:[NSString stringWithFormat:@"%@", commandAfterSubstitution]];

  /*  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Debug"])
      {
        NSMutableString *debugString;
        int i;

        debugString=[NSMutableString stringWithString:@""];
        [debugString appendFormat:@"shellPath =  %@\n",shellPath];
        [debugString appendFormat:@"shellArgs = %@\n",shellArgs];
        [debugString appendFormat:@"command = %@\n",commandBeforeSubstitution];
        for (i=0; i< [searchValues count]; i++)
          {
            [debugString appendFormat:@"%@ = %@\n",[searchValues objectAtIndex:i],[replaceValues
  objectAtIndex:i]];
          }
        [debugString appendFormat:@"-----------------\n%@\n",launchArguments];
        [debugString appendFormat:@"Simulated command - \n"];
        [debugString appendFormat:@"%@ %@\n",shellPath,[launchArguments componentsJoinedByString:@"
  "]]; if (![[NSUserDefaults standardUserDefaults] boolForKey:@"RunTask"]) [debugString
  appendFormat:@"** NOTE: TASK WILL NOT BE EXECUTED ***\n"];

  //      [debugTextView setString:debugString];
        NSLog(@"%@", debugString);
  //      [debugWindow makeKeyAndOrderFront:self];

  //    }*/

  //  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"RunTask"])
  //    return;

  NSLog(@"launchArguments: %@", launchArguments);

  taskResults = [NSTask performTask:shellPath
                        inDirectory:unarchiveDirectoryPath
                           withArgs:launchArguments];

  if (([[taskResults objectForKey:@"StandardError"] length] > 0) ||
      ([[taskResults objectForKey:@"TerminationStatus"] intValue] != 0)) {
    // If the termination status non zero, then we've encountered
    // an error during the decompression.  We'll do the right
    // thing and throw up a panel with the error note, as well
    // as a textview with all the details that have been returned
    // to us on stderr above.
    [errorTextField setStringValue:[NSString stringWithFormat:NSLocalizedString(
                                                                  @"ErrorWhileDecompressing",
                                                                  @"Error while decompressing %@"),
                                                              archivePath]];

    NSLog(@"%@", [taskResults objectForKey:@"StandardError"]);
    /*      [errorTextView setString:[taskResults objectForKey:@"StandardError"]];
          [errorWindow makeKeyAndOrderFront:self];*/
  };

  if ([[[NSFileManager defaultManager] directoryContentsAtPath:unarchiveDirectoryPath] count] > 0) {
    // the file is decompressed!  we'll message the workspace
    // to open the temporary directory that we've created.
    // Remember, if the directory has a file extension, even
    // accidentally, the workspace will try and open that
    // application if it exists instead of just a window

    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"RhapsodyDirHack"]) {
      NSMutableDictionary *hackDictionary;
      NSString *viewName;
      NSMutableString *hackFile;

      hackFile = [NSMutableString stringWithFormat:@"%@/.dir5_0.wmd", unarchiveDirectoryPath];
      viewName = [[NSUserDefaults standardUserDefaults] stringForKey:@"RhapsodyDirViewName"];
      hackDictionary = [NSMutableDictionary dictionary];
      [hackDictionary setObject:unarchiveDirectoryPath forKey:@"RootNode"];
      [hackDictionary setObject:viewName forKey:@"ViewName"];
      [hackDictionary writeToFile:hackFile atomically:NO];
    }
    NSLog(@"File was decompressed. Call for workspace.");
    [[NSWorkspace sharedWorkspace] selectFile:unarchiveDirectoryPath
                     inFileViewerRootedAtPath:unarchiveDirectoryPath];
  }

  return;
}

@end
