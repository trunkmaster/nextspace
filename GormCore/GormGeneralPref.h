#ifndef INCLUDED_GormGeneralPref_h
#define INCLUDED_GormGeneralPref_h

#include <Foundation/Foundation.h>
#include <AppKit/AppKit.h>

@interface GormGeneralPref : NSObject
{
  id window;
  id backupButton;
  id interfaceMatrix;
  id checkConsistency;
  id _view;
}

/**
 * View to be shown.
 */
- (NSView *) view;

/**
 * Should create a backup file.
 */
- (void) backupAction: (id)sender;

/**
 * Show the classes view as a browser or an outline.
 */
- (void) classesAction: (id)sender;

- (void) consistencyAction: (id)sender;
@end


#endif
