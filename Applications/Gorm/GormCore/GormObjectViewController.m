/* All rights reserved */

#import "GormObjectViewController.h"
#import "GormDocument.h"
#import "GormObjectEditor.h"

@implementation GormObjectViewController

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      _document = nil;
      _iconView = nil;
      _outlineView = nil;
      _editor = NO;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_document);
  RELEASE(_iconView);
  RELEASE(_outlineView);

  [super dealloc];
}

- (GormDocument *) document
{
  return _document;
}

- (void) setDocument: (GormDocument *)document
{
  ASSIGN(_document, document);
}

- (id) iconView
{
  return _iconView;
}

- (void) setIconView: (id)iconView
{
  ASSIGN(_iconView, iconView);
}

- (id) outlineView
{
  return _outlineView;
}

- (void) setOutlineView: (id)outlineView
{
  ASSIGN(_outlineView, outlineView);
}

- (BOOL) editor
{
  return _editor;
}

- (void) setEditor: (BOOL)f
{
  _editor = f;
}

- (IBAction) iconView: (id)sender
{
  NSDebugLog(@"Called %@", NSStringFromSelector(_cmd));
  [self resetDisplayView: _iconView];
}

- (IBAction) outlineView: (id)sender
{
  NSDebugLog(@"Called %@", NSStringFromSelector(_cmd));
  [_document deactivateEditors];
  [[_outlineView documentView] reloadData];
  [_document reactivateEditors];
  [self resetDisplayView: _outlineView];
}

- (IBAction) editorButton: (id)sender
{
  _editor = !_editor;
  [[_outlineView documentView] reloadData];
}

- (void) resetDisplayView: (NSView *)view
{
  [displayView setContentView: view];
  NSDebugLog(@"displayView = %@", view);
}

- (void) reloadOutlineView
{
  if (_editor == NO)
    {
      [_document deactivateEditors];
    }

  [[_outlineView documentView] reloadData];

  if (_editor == NO)
    {
      [_document reactivateEditors];
    }
}

@end
