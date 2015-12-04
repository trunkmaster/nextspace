#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@class NSTextView;
@class NSTextStorage;
@class NSPrintInfo;

/*
  These get added to the string encodings so we have a common language to
  refer to file types
*/
enum {
  UnknownStringEncoding = -1000,
  RichTextStringEncoding = -1001,
  RichTextWithGraphicsStringEncoding = -1002
};

/* List of encodings to display in the open/save panels */
extern const int *SupportedEncodings (void);

/*
  Set up an encoding popup with the specified parameters. If the popup
  contains 1 item, it's also initialized with the supported encodings.
*/
extern void SetUpEncodingPopupButton(NSPopUpButton *popup, int selectedEncoding, BOOL includeDefaultItem);

@interface Document : NSObject
{
  NSTextStorage *textStorage;
  NSString      *documentName;		 /* If nil, never saved */
  NSScrollView  *scrollView;		 /* ScrollView containing document */
  NSPrintInfo   *printInfo;		 /* PrintInfo, used when hasMultiplePages is true */
  NSString      *potentialSaveDirectory; /* if non-nil, is path prefix where to save it. */
  
  BOOL	isDocumentEdited;
  BOOL	hasMultiplePages;
  BOOL	isRichText;
  int	encodingIfPlainText;
}

// Don't call -init; call one of these methods... */

/*
  Should be an absolute path here; nil for untitled.
*/
- (id) initWithPath: (NSString *)filename encoding: (int)encoding;
/*
  Brings window front. Checks to see if document already open.
*/
+ (BOOL) openDocumentWithPath: (NSString *)filename encoding: (int)encoding;
+ (BOOL) openUntitled;	/* Brings window front */

/*
  These set/get the documentName instance var and also set the window title
  accordingly. "nil" is used if no title.
*/
- (void) setDocumentName: (NSString *)fileName;
- (NSString *) documentName;

/*
  These determine if document has been edited since last save
*/
- (void) setDocumentEdited: (BOOL)flag;
- (BOOL) isDocumentEdited;

/*
  Is the document rich?
*/
- (BOOL) isRichText;
- (void) setRichText: (BOOL)flag;

/*
  Hyphenation factor (0.0-1.0, 0.0 == disabled)
*/
- (float) hyphenationFactor;
- (void) setHyphenationFactor: (float)factor;

/*
  View size (as it should be saved in a RTF file)
*/
- (NSSize) viewSize;
- (void) setViewSize: (NSSize)size;

/* Attributes */
- (NSTextStorage *) textStorage;
- (NSTextView *) firstTextView;
- (NSWindow *) window;
- (NSLayoutManager *) layoutManager;

/* Misc methods */
+ (Document *) documentForWindow: (NSWindow *)window;
+ (Document *) documentForPath: (NSString *)filename;
+ (NSString *) cleanedUpPath: (NSString *)filename;
+ (NSView *) encodingAccessory: (int)defaultEncoding
           includeDefaultEntry: (BOOL)includeDefaultItem;
+ (unsigned int) numberOfOpenDocuments;
- (void) doForegroundLayoutToCharacterIndex: (unsigned)loc;

/* Page-oriented methods */
- (void) addPage;
- (void) removePage;
- (unsigned int) numberOfPages;
- (void) setHasMultiplePages:(BOOL)flag;
- (BOOL) hasMultiplePages;
- (void) setPrintInfo:(NSPrintInfo *)anObject;
- (NSPrintInfo *) printInfo;

/* Printing a document */
- (void) printDocumentUsingPrintPanel: (BOOL)uiFlag;

// Saving helpers. These return NO or nil if user cancels the save...
- (BOOL) getDocumentName: (NSString **)newName
                encoding: (int *)encodingForSaving
                 oldName: (NSString *)oldName
             oldEncoding: (int)encoding;
/*
  Saves under documentName; if not set, tries to set it first
*/
- (BOOL) saveDocument: (BOOL)showSavePanel;
/*
  Assures document is saved or user doesn't care about the changes; returns
  NO if user cancels
*/
- (BOOL) canCloseDocument;
+ (void) openWithEncodingAccessory: (BOOL)flag;

/* Outlet methods */
+ (void) setEncodingPopupButton: (id)anObject;	/* In the save panel... */
+ (void) setEncodingAccessory: (id)anObject;	/* In the save panel... */

/* Action methods */
+ (void) open: (id)sender;
- (void) saveAs: (id)sender;
- (void) saveTo: (id)sender;
- (void) save: (id)sender;
- (void) revert: (id)sender;
- (void) close: (id)sender;
- (void) runPageLayout: (id)sender;
- (void) orderFrontFindPanel: (id)sender;
- (void) findNext: (id)sender;
- (void) findPrevious: (id)sender;
- (void) enterSelection: (id)sender;
- (void) jumpToSelection: (id)sender;
- (void) toggleRich: (id)sender;
- (void) togglePageBreaks: (id)sender;
/*
  action cover for [self printDocumentUsingPrintPanel:YES]
*/
- (void) printDocument: (id)sender;

/*
  When the preference "OpenPanelFollowsMainWindow" is set to YES, this is
  used to save/get the last used directory for the save/open panel.
*/
+ (void) setLastOpenSavePanelDirectory: (NSString *)dir;
+ (NSString *) openSavePanelDirectory;

/*
  setPotentialSaveDirectory gets called automatically when a doc is made
  "new" UNTITLED.  The name is taken from the current main window, if any.
  The directory is used to put up the save panel the first time the doc is
  saved from the UNTITLED state.  It is only used when the preference
  "OpenPanelFollowsMainWindow" is set to YES.
*/
- (void) setPotentialSaveDirectory: (NSString *)nm;
- (NSString *) potentialSaveDirectory;


/* Delegation messages */
- (void) textView: (NSTextView *)view doubleClickedOnCell: (id <NSTextAttachmentCell>)cell
           inRect: (NSRect)rect;

- (void) textView: (NSTextView *)view draggedCell: (id <NSTextAttachmentCell>)cell
           inRect: (NSRect)rect
            event: (NSEvent *)event;
- (void) textDidChange: (NSNotification *)textObject;
- (void) layoutManager: (NSLayoutManager *)layoutManager didCompleteLayoutForTextContainer: (NSTextContainer *)textContainer atEnd: (BOOL)layoutFinishedFlag;
- (BOOL) windowShouldClose: (id)sender;
- (void) windowWillClose: (NSNotification *)notification;

@end

@interface Document (ReadWrite)

/*
  File loading. Returns NO if not successful. Doesn't set documentName.
  If encoding is Unknown, try to guess.
*/
- (BOOL) loadFromPath:(NSString *)fileName encoding:(int)encoding;
- (BOOL) saveToPath:(NSString *)fileName encoding:(int)encoding updateFilenames:(BOOL)updateFileNamesFlag;

@end
