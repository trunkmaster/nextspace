#import <Foundation/NSObject.h>

#define Forward YES
#define Backward NO

@interface TextFinder : NSObject {
    NSString *findString;
    id findTextField;
    id replaceTextField;
    id ignoreCaseButton;
    id findNextButton;
    id replaceAllScopeMatrix;
    id statusField;
    BOOL findStringChangedSinceLastPasteboardUpdate;
    BOOL lastFindWasSuccessful;		/* A bit of a kludge */
}

/* Common way to get a text finder. One instance of TextFinder per app is good enough. */
+ (id)sharedInstance;

/* Main method for external users; does a find in the first responder. Selects found range or beeps. */
- (BOOL)find:(BOOL)direction;

/* Loads UI lazily */
- (NSPanel *)findPanel;

/* Gets the first responder and returns it if it's an NSTextView */
- (NSTextView *)textObjectToSearchIn;

/* Get/set the current find string. Will update UI if UI is loaded */
- (NSString *)findString;
- (void)setFindString:(NSString *)string;

/* Misc internal methods */
- (void)appDidActivate:(NSNotification *)notification;
- (void)addWillDeactivate:(NSNotification *)notification;
- (void)loadFindStringFromPasteboard;
- (void)loadFindStringToPasteboard;

/* Methods sent from the find panel UI */
- (void)findNext:(id)sender;
- (void)findPrevious:(id)sender;
- (void)findNextAndOrderFindPanelOut:(id)sender;
- (void)replace:(id)sender;
- (void)replaceAndFind:(id)sender;
- (void)replaceAll:(id)sender;
- (void)orderFrontFindPanel:(id)sender;

@end


@interface NSString (NSStringTextFinding)

- (NSRange)findString:(NSString *)string selectedRange:(NSRange)selectedRange options:(unsigned)mask wrap:(BOOL)wrapFlag;

@end
        
