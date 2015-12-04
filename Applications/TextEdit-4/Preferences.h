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

@interface Preferences: NSObject {
	id	richTextFontNameField;
	id	plainTextFontNameField;
	id	deleteBackupMatrix;
	id	saveFilesWritableButton;
	id	richTextMatrix;
	id	showPageBreaksButton;
	id	windowWidthField;
	id	windowHeightField;
	id	plainTextEncodingPopup;
	id	tabWidthField;

	NSDictionary		*curValues;
	NSMutableDictionary	*displayedValues;
}

+ (id) objectForKey: (id)key;	/* Convenience for getting global preferences */
+ (void) saveDefaults;		/* Convenience for saving global preferences */

+ (Preferences *) sharedInstance;

- (NSDictionary *) preferences;	/* The current preferences; contains values for the documented keys */

- (void) showPanel: (id)sender;	/* Shows the panel */

- (void) updateUI;		/* Updates the displayed values in the UI */
- (void) commitDisplayedValues;	/* The displayed values are made current */
- (void) discardDisplayedValues;	/* The displayed values are replaced with current prefs and updateUI is called */

- (void) revert: (id)sender;	/* Reverts the displayed values to the current preferences */
- (void) ok: (id)sender;		/* Calls commitUI to commit the displayed values as current */
- (void) revertToDefault: (id)sender;    

- (void) miscChanged: (id)sender;		/* Action message for most of the misc items in the UI to get displayedValues */
- (void) changeRichTextFont: (id)sender;	/* Request to change the rich text font */
- (void) changePlainTextFont: (id)sender;	/* Request to change the plain text font */
- (void) changeFont: (id)fontManager;	/* Sent by the font manager */

+ (NSDictionary *) preferencesFromDefaults;
+ (void) savePreferencesToDefaults:(NSDictionary *)dict;

@end
