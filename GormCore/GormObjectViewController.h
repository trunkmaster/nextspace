/* All rights reserved */

#ifndef GormObjectViewController_H_INCLUDE
#define GormObjectViewController_H_INCLUDE

#import <AppKit/AppKit.h>

@class GormDocument;

@interface GormObjectViewController : NSViewController
{
  IBOutlet id displayView;
  IBOutlet id iconButton;
  IBOutlet id outlineButton;
  IBOutlet id editorButton;
  
  // Document
  GormDocument *_document;
  id _iconView;
  id _outlineView;

  // Editor flag
  BOOL _editor;
}

- (GormDocument *) document;
- (void) setDocument: (GormDocument *)document;

- (id) iconView;
- (void) setIconView: (id)iconView;

- (id) outlineView;
- (void) setOutlineView: (id)outlineView;

- (BOOL) editor;
- (void) setEditor: (BOOL)f;

- (void) resetDisplayView: (NSView *)view;
- (void) reloadOutlineView;

- (IBAction) iconView: (id)sender;
- (IBAction) outlineView: (id)sender;
- (IBAction) editorButton: (id)sender;

@end

#endif // GormObjectViewController_H_INCLUDE
