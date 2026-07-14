#include <AppKit/AppKit.h>

#ifndef	INCLUDED_GormNSPopUpButton_h
#define	INCLUDED_GormNSPopUpButton_h

@interface GormNSPopUpButton : NSPopUpButton
@end

@interface GormNSPopUpButtonCell : NSPopUpButtonCell
{
}
@end

@interface NSPopUpButtonCell (DirtyHack)
- (id) _gormInitTextCell: (NSString *) string;
@end

#endif
