/*
 * File:       ApplicationDelegate+compression.m
 * Written By: Scott Anguish
 * Created:    Dec 9, 1997
 * Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
 */

#include "ApplicationDelegate.h"
#include "NSArray+utils.h"
#include "NSFileManager+unique.h"
#include "NSString+utils.h"
#include "NSTask+utils.h"

@implementation ApplicationDelegate (compression)

// - (void)compressFiles:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
//
// This method is not explicitly called in our application, but is specified in the CustomInfo.plist
// in the Application Wrapper that is parsed by the Services facilities.  When a user selects the
// OpenUp->Compress method in the Services menu, this is the method that is eventually called.

- (void)compressFiles:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
{
  NSArray *pasteboardTypes = [pboard types];
  NSArray *filesArray;

  if (![pasteboardTypes containsObject:NSFilenamesPboardType]) {
    *error = NSLocalizedString(@"ErrorCompressingFiles", @"pboard couldn't give filenames.");
    return;
  }

  filesArray = [pboard propertyListForType:NSFilenamesPboardType];
  [self compressFiles:filesArray withFileExtension:data];
  return;
}

// - (BOOL)compressFiles:(NSArray *)files withFileExtension:(NSString *)extension;
//
// This is the next logical place to break out a method.  This method takes the array of files
// and the filetype extension (i.e. .tgz) and compresses using that information.  It askes
// the name of the file using the standard NSOpenPanel first.
//
// The real work is done in another method below.

- (BOOL)compressFiles:(NSArray *)files withFileExtension:(NSString *)extension;
{
  NSSavePanel *sharedSavePanel;
  int runResult;
  NSDictionary *compressionConfiguration;

  compressionConfiguration = [servicesDictionary objectForKey:extension];
  if (compressionConfiguration) {
    NSString *extensionWithoutPeriod;
    NSString *titleString;

    extensionWithoutPeriod =
        [[compressionConfiguration objectForKey:@"file_extension"] substringFromIndex:1];

    sharedSavePanel = [NSSavePanel savePanel];

    /* set up new attributes */
    [sharedSavePanel setAccessoryView:nil];

    titleString = [NSString stringWithFormat:NSLocalizedString(@"CompressFilesToArchiveOfType",
                                                               @"Compress to archive of type %@"),
                                             extensionWithoutPeriod];
    [sharedSavePanel setTitle:titleString];

    [sharedSavePanel setRequiredFileType:extensionWithoutPeriod];

    /* display the NSSavePanel */
    runResult = [sharedSavePanel runModalForDirectory:NSHomeDirectory() file:@""];

    /* if successful, save file under designated name */
    if (runResult == NSOKButton) {
      [self compressFiles:files
              intoArchive:[sharedSavePanel filename]
              usingConfig:compressionConfiguration];
      return YES;
    }
  }
  return NO;
}

- (void)compressFiles:(NSArray *)files
          intoArchive:(NSString *)archivePath
          usingConfig:(NSDictionary *)fileConfig;
{
  NSString *shellPath;
  NSArray *shellArgs;
  NSMutableArray *launchArguments;
  NSEnumerator *overEachFileToArchive;
  NSString *archiveDirectoryPath;
  NSMutableArray *lastPathComponents;
  id eachFileToCompress;
  NSString *filesToArchive;
  NSDictionary *substitutionKeysForWrappedPrograms;
  NSString *commandBeforeSubstitution;
  NSString *commandAfterSubstitution;
  NSMutableArray *searchValues, *replaceValues;
  NSMutableString *filesToArchiveWithPath;
  NSDictionary *taskResults;

  shellPath = [self shellPathUsingConfiguration:fileConfig];
  shellArgs = [self shellArgsUsingConfiguration:fileConfig];

  // iterate over all the files that have been selected, sticking the lastPathComponent
  // for each into a temporary array.
  //
  // we do this so that the .tar'd files will be relative to their parent directory, instead
  // of absolute paths
  filesToArchiveWithPath = [NSMutableString stringWithString:@""];
  lastPathComponents = [NSMutableArray array];
  overEachFileToArchive = [files objectEnumerator];
  while ((eachFileToCompress = [overEachFileToArchive nextObject])) {
    [lastPathComponents
        addObject:[[eachFileToCompress lastPathComponent] stringWithShellCharactersQuoted]];
    [filesToArchiveWithPath
        appendFormat:@"%@ ", [eachFileToCompress stringWithShellCharactersQuoted]];
  }

  filesToArchive = [lastPathComponents componentsJoinedByString:@" "];

  substitutionKeysForWrappedPrograms = [self wrappedProgramsUsingConfiguration:fileConfig];
  archiveDirectoryPath = [[files lastObject] stringByDeletingLastPathComponent];

  commandBeforeSubstitution = [fileConfig objectForKey:@"command"];

  searchValues = [NSMutableArray
      arrayWithObjects:@"%%DESTINATION_FILE_WITH_PATH%%", @"%%SOURCE_FILES_WITHOUT_PATHS%%",
                       @"%%SOURCE_FILES_WITH_PATHS%%", @"%%SOURCE_FILES_PATH%%", nil];
  [searchValues addObjectsFromArray:[substitutionKeysForWrappedPrograms objectForKey:@"keys"]];

  replaceValues =
      [NSMutableArray arrayWithObjects:[archivePath stringWithShellCharactersQuoted],
                                       filesToArchive, filesToArchiveWithPath,
                                       [archiveDirectoryPath stringWithShellCharactersQuoted], nil];
  [replaceValues addObjectsFromArray:[substitutionKeysForWrappedPrograms objectForKey:@"values"]];

  commandAfterSubstitution =
      [commandBeforeSubstitution stringByReplacingValuesInArray:searchValues
                                              withValuesInArray:replaceValues];

  launchArguments = [shellArgs mutableCopy];
  [launchArguments addObject:commandAfterSubstitution];

  // duplicate the config dictionary entry for the launchArguments
  // so we can append our destination filename and our list of files to compress
  // to the arguement

  // make our tasks' work directory the parent directory for the files
  // again, this is so we get files in the compressed archive that are
  // not absolute paths

  if ([[NSUserDefaults standardUserDefaults] boolForKey:@"Debug"]) {
    NSMutableString *debugString;
    int i;

    debugString = [NSMutableString stringWithString:@""];
    [debugString appendFormat:@"archiveDirectoryPath =  %@\n", archiveDirectoryPath];
    [debugString appendFormat:@"shellPath =  %@\n", shellPath];
    [debugString appendFormat:@"shellArgs =  %@\n", shellArgs];
    [debugString appendFormat:@"command = %@\n", commandBeforeSubstitution];
    for (i = 0; i < [searchValues count]; i++) {
      [debugString appendFormat:@"%@ = %@\n", [searchValues objectAtIndex:i],
                                [replaceValues objectAtIndex:i]];
    }
    [debugString appendFormat:@"-----------------\n"];
    [debugString appendFormat:@"Simulated command - \n"];
    [debugString
        appendFormat:@"%@ %@\n", shellPath, [launchArguments componentsJoinedByString:@" "]];

    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"RunTask"])
      [debugString appendFormat:@"** NOTE: TASK WILL NOT BE EXECUTED ***\n"];

    [debugTextView setString:debugString];
    [debugWindow makeKeyAndOrderFront:self];
  }

  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"RunTask"])
    return;

  taskResults = [NSTask performTask:shellPath
                        inDirectory:archiveDirectoryPath
                           withArgs:launchArguments];

  if ([[taskResults objectForKey:@"TerminationStatus"] intValue] != 0) {
    // If the termination status non zero, then we've encountered an error
    // during the compression.  We'll do the right thing and throw up a
    // panel with the error note, as well as a textview with all the details
    // that have been returned to us on stderr above.
    [errorTextField
        setStringValue:[NSString stringWithFormat:NSLocalizedString(@"ErrorWhileCompressing",
                                                                    @"Error while compressing %@"),
                                                  archivePath]];

    [errorTextView setString:[taskResults objectForKey:@"StandardError"]];
    [errorWindow makeKeyAndOrderFront:self];
  } else {
    [[NSWorkspace sharedWorkspace] noteFileSystemChanged];
    [[NSWorkspace sharedWorkspace] selectFile:archivePath
                     inFileViewerRootedAtPath:[archivePath stringByDeletingLastPathComponent]];
  }
  return;
}

@end
