#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <AppKit/NSFont.h>
#import "Document.h"

/* Keys in the dictionary... */   
#define RichTextFont @"RichTextFont"
#define PlainTextFont @"PlainTextFont"
#define DeleteBackup @"DeleteBackup"
#define SaveFilesWritable @"SaveFilesWritable"
#define RichText @"RichText"
#define ShowPageBreaks @"ShowPageBreaks"
#define WindowWidth @"WidthInChars"
#define WindowHeight @"HeightInChars"
#define PlainTextEncoding @"PlainTextEncoding"
#define TabWidth @"TabWidth"
#define ForegroundLayoutToIndex @"ForegroundLayoutToIndex"
#define OpenPanelFollowsMainWindow @"OpenPanelFollowsMainWindow"

@interface Preferences: NSObject
{
  // Save Options
  id	deleteBackupMatrix;
  id	saveFilesWritableButton;
  // New Document Format
  id	richTextMatrix;
  id	showPageBreaksButton;
  id	tabWidthField;
  // Fonts
  id	richTextFontNameField;
  id	plainTextFontNameField;
  // Window Size
  id	windowWidthField;
  id	windowHeightField;
  // Plain TextEncoding
  id	plainTextEncodingPopup;

  NSDictionary		*curValues;
  NSMutableDictionary	*displayedValues;
}

/* Convenience for getting global preferences */
+ (id)objectForKey:(id)key;
/* Convenience for saving global preferences */
+ (void)saveDefaults;

+ (Preferences *)sharedInstance;

/* The current preferences; contains values for the documented keys */
- (NSDictionary *)preferences;

/* Shows the panel */
- (void)showPanel:(id)sender;

/* Updates the displayed values in the UI */
- (void)updateUI;
/* The displayed values are made current */
- (void)commitDisplayedValues;
/* The displayed values are replaced with current prefs and updateUI is called */
- (void)discardDisplayedValues;

/* Reverts the displayed values to the current preferences */
- (void)revert:(id)sender;
/* Calls commitUI to commit the displayed values as current */
- (void)ok:(id)sender;
- (void)revertToDefault:(id)sender;

/* Action message for most of the misc items in the UI to get displayedValues */
- (void)miscChanged:(id)sender;
/* Request to change the rich text font */
- (void)changeRichTextFont:(id)sender;
/* Request to change the plain text font */
- (void)changePlainTextFont:(id)sender;
/* Sent by the font manager */
- (void)changeFont:(id)fontManager;

+ (NSDictionary *)preferencesFromDefaults;
+ (void)savePreferencesToDefaults:(NSDictionary *)dict;

@end
