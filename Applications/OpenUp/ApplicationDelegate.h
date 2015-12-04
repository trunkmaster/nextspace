/*
 File:       ApplicationDelegate.h
 Written By: Scott Anguish
 Created:    Dec 9, 1997
 Copyright:  Copyright 1997 by Scott Anguish, all rights reserved.
*/

#include <AppKit/AppKit.h>

@interface ApplicationDelegate : NSObject
{
    NSString *appWorkingDirectory;
    NSArray *fileTypeConfigArray;
    NSDictionary *servicesDictionary;
    
    id errorWindow;
    id errorTextView;
    id errorTextField;
    id preferencesWindow;
    id preferencesDeleteFilesCheckbox;


    id infoPanel;
    id infoPanelTextField;

    id debugWindow;
    id debugTextView;
    NSArray *infoPanelSupportedTypes;
    id infoTableView;
}


- (BOOL)applicationShouldTerminate:(NSApplication *)app;
- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename;
- (BOOL)application:(NSApplication *)sender openTempFile:(NSString *)filename;
- (void)initializationFailure:(NSString *)value;
- (void)awakeFromNib;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification;
- (void)setupUserDefaults;
- (void)dealloc;
- selectedDeleteTempFilesOnQuit:sender;
- (NSString *)shellPathUsingConfiguration:(NSDictionary *)fileConfig;
- (NSArray *)shellArgsUsingConfiguration:(NSDictionary *)fileConfig;
- (NSDictionary *)wrappedProgramsUsingConfiguration:(NSDictionary *)fileConfig;
@end

@interface ApplicationDelegate(compression)
- (void)compressFiles:(NSPasteboard *)pboard userData:(NSString *)data error:(NSString **)error;
- (BOOL)compressFiles:(NSArray *)files withFileExtension:(NSString *)extension;
- (void)compressFiles:(NSArray *)files intoArchive:(NSString *)archivePath usingConfig:(NSDictionary *)fileConfig;
@end


@interface ApplicationDelegate(decompression)
- (void)openArchive:(id)sender;
- (NSArray *)allSupportedFileExtensions;
- (NSString *)fileExtensionIn:extensions matchingString:(NSString *)theString;
- (NSDictionary *)matchFileToConfig:(NSString *)archivePath;
- (void)decompressFile:(NSString *)archivePath;
@end



@interface ApplicationDelegate(infopanel)
- (NSArray *)infoAboutSupportedFileExtensions;
- showInfoPanel:sender;
@end


