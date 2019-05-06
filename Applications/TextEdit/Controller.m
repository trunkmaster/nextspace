/*
  Controller.m
  Copyright (c) 1995-1996, NeXT Software, Inc.
  All rights reserved.
  Author: Ali Ozer

  You may freely copy, distribute and reuse the code in this example.
  NeXT disclaims any warranty of any kind, expressed or implied,
  as to its fitness for any particular use.

  Central controller object for Edit...
*/

#import <Foundation/NSFileManager.h>
#import <AppKit/NSApplication.h>
#import <DesktopKit/NXTAlert.h>

#import "Controller.h"
#import "Document.h"
#import "Preferences.h"

@implementation Controller

/* 
   If return type is not the same as in AppKit/NSApplication.h runtime
   warning emitted like this: "Calling [...] with incorrect signature.
   Method has ..., selector has ..."
*/
//- (BOOL) applicationShouldTerminate: (NSApplication *)app
- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication *)app;
{
  NSArray  *windows = [app windows];
  unsigned count = [windows count];
  BOOL     needsSaving = NO;

  // Determine if there are any unsaved documents...
  while (!needsSaving && count--)
    {
      NSWindow	*window = [windows objectAtIndex: count];
      Document	*document = [Document documentForWindow: window];
      
      if (document && [document isDocumentEdited])
        needsSaving = YES;
    }

  if (needsSaving)
    {
      int choice = NXTRunAlertPanel 
        (NSLocalizedString (@"Quit", @"Title of alert panel which comes up when user chooses Quit and there are unsaved documents."), 
         NSLocalizedString (@"You have unsaved documents.", @"Message in the alert panel which comes up when user chooses Quit and there are unsaved documents."), 
         NSLocalizedString (@"Review Unsaved", @"Choice (on a button) given to user which allows him/her to review all unsaved documents if he/she quits the application without saving them all first."), 
         NSLocalizedString (@"Quit Anyway", @"Choice (on a button) given to user which allows him/her to quit the application even though there are unsaved documents."), 
         NSLocalizedString (@"Cancel", @"Button choice allowing user to cancel.")
         );

      if (choice == NSAlertOtherReturn)
        {	/* Cancel */
          return NO;
        }
      else if (choice != NSAlertAlternateReturn)
        {	/* Review unsaved; Quit Anyway falls through */
          count = [windows count];

          while (count--)
            {
              NSWindow *window = [windows objectAtIndex: count];
              Document *document = [Document documentForWindow: window];
            
              if (document)
                {
                  [window makeKeyAndOrderFront: nil];
                
                  if (![document canCloseDocument])
                    return NO;
                }
            }
        }
    }

  [Preferences saveDefaults];
  return YES;
}

- (BOOL) application:(NSApplication *)sender openFile:(NSString *)filename
{
  return [Document openDocumentWithPath: filename encoding: UnknownStringEncoding];
}

/*
  This is like -application:openFile:, except the method deletes the
  file once it has been opened.
*/
- (BOOL) application:(NSApplication *)sender openTempFile:(NSString *)filename
{
  NSFileManager	*fm = [NSFileManager defaultManager];
  Document		*document;
  BOOL			tmp = [Document openDocumentWithPath: filename encoding: UnknownStringEncoding];

  document = [Document documentForPath: filename];
  if (document) {
    [document setDocumentEdited: YES];
    [document setDocumentName: nil];
    [fm removeFileAtPath: filename handler: nil];
  }
  return tmp;
}

- (BOOL) applicationOpenUntitledFile:(NSApplication *)sender
{
  return [Document openUntitled];
}

- (BOOL) application:(NSApplication *)sender printFile: (NSString *)filename
{
  BOOL		retval = NO;
  BOOL		releaseDoc = NO;
  Document	*document = [Document documentForPath: filename];
	
  if (!document) {
    document =	[[Document alloc] initWithPath: filename encoding: UnknownStringEncoding];
    releaseDoc = YES;
  }

  if (document) {
    BOOL	useUI = [NSPrintInfo defaultPrinter] ? NO : YES;

    [document printDocumentUsingPrintPanel: useUI];
    retval = YES;

    if (releaseDoc) {	// If we created it, we get rid of it.
      [document release];
    }
  }
  return retval;
}

- (void) createNew:(id)sender
{
  [Document openUntitled];
}

- (void) open:(id)sender
{
  [Document open:sender];
}

- (void) saveAll:(id)sender
{
  NSArray  *windows = [NSApp windows];
  unsigned count = [windows count];

  while (count--)
    {
      NSWindow *window = [windows objectAtIndex:count];
      Document *document = [Document documentForWindow:window];

      if (document && [document isDocumentEdited])
        {
          if (![document saveDocument:NO])
            return;
        }
    }
}

/*** Info Panel related stuff ***/

- (void) showInfoPanel:(id)sender
{
  if (!infoPanel)
    {
      if (![NSBundle loadNibNamed:@"Info" owner:self])
        {
          NSLog (@"Failed to load Info.nib");
          NSBeep ();
          return;
        }
      [infoPanel center];
    }
  [infoPanel makeKeyAndOrderFront:nil];
}

- (void) setVersionField:(id)versionField
{
  const char *TextEdit_VERS_NUM = "40";

  if (strlen (TextEdit_VERS_NUM) > 0)
    {
      NSString *versionString = [NSString stringWithFormat:NSLocalizedString (@"Release 4 (v%s)", @"Version string.  %s is replaced by the version number."), TextEdit_VERS_NUM];

      [versionField setStringValue:versionString];
    }
}

- (void) applicationWillFinishLaunching:(NSNotification *)not
{
}

@end

/*
 1/28/95 aozer	Created for Edit II.
 7/21/95 aozer	Command line file names2
*/
