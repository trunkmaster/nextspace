#ifndef INCLUDED_GormHeadersPref_h
#define INCLUDED_GormHeadersPref_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@interface GormHeadersPref : NSObject
{
  id preloadButton;
  id table;
  id addButton;
  id removeButton;
  id window;
  id _view;

  NSMutableArray *headers;
}

/**
 * View to show in prefs panel.
 */
- (NSView *) view;

/**
 * Add a header.
 */
- (void) addAction: (id)sender;

/**
 * Remove a header.
 */
- (void) removeAction: (id)sender;

/**
 * Called when the "preload" switch is set.
 */
- (void) preloadAction: (id)sender;
@end

#endif
