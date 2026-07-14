#import <Foundation/NSObject.h>
#import <Protocols/CodeEditorView.h>

@interface LineJumper : NSObject
{
  IBOutlet NSTextField *lineField;
  IBOutlet NSButton *goToButton;
}

+ (id)sharedInstance;

- (NSPanel *)linePanel;

/* Gets the first responder and returns it if it's an NSTextView */
- (NSTextView<CodeEditorView> *)editorViewToUse;

/* panel UI methods */
- (void)orderFrontLinePanel:(id)sender;
- (IBAction)goToLine:(id)sender;

@end
