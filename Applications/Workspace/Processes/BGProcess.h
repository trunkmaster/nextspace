/* All Rights reserved */

#import <AppKit/AppKit.h>

@class BGOperation;

@interface BGProcess : NSObject
{
  BGOperation *operation;

  NSLock *guiLock;
  NSDate *lastViewUpdateDate;

  // SimpleBGProcess.gorm
  id window;
  id processBox;
  id currentField;
  id progressPie;
  id stopButton;

  // OperationAlert.gorm
  id alertWindow;
  id alertBox;
  id alertDescription;
  id alertMessage;
  IBOutlet NSButton *alertRepeatButton;
  id alertButton0, alertButton1, alertButton2;

  NSArray *alertButtons;
}

- (id)initWithOperation:(BGOperation *)op;

// Process view or alert view
- (NSView *)processView;

// Used for processes list
- (NSImage *)miniIcon;

// Process views (below process list)
- (void)updateAlertWithMessage:(NSString *)messageText
                          help:(NSString *)helpText
                     solutions:(NSArray *)buttonLabels;

- (void)updateWithMessage:(NSString *)message
                     file:(NSString *)currFile
                   source:(NSString *)currSourceDir
                   target:(NSString *)currTargetDir
                 progress:(float)progress;

- (void)stop:(id)sender;

@end
