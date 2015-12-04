
#import <GNUstepGUI/GSTheme.h>
#import <AppKit/NSAttributedString.h>
#import "WMPopUp.h"

@implementation PopUpListCell

- (void)drawBorderAndBackgroundWithFrame:(NSRect)cellFrame
                                  inView:(NSView *)controlView
{
  // NSLog(@"PopUpListCell: drawBorderAndBackgroundWithFrame:inView:!");
  if (!_cell.is_disabled)
    {
      [super drawBorderAndBackgroundWithFrame:cellFrame
                                       inView:controlView];
    }
}


- (void)drawInteriorWithFrame:(NSRect)cellFrame
                       inView:(NSView*)controlView
{
  // NSLog(@"PopUpListCell: drawInteriorWithFrame:inView:! %@, %@, %@",
  //       [self title], [_contents className], [self attributedTitle]);
  
  if (_cell.is_disabled)
    {
      NSMutableAttributedString  *t = [[self attributedTitle] mutableCopy];
      NSRange r;
      NSMutableDictionary *md;

      md = [[t attributesAtIndex:0 effectiveRange:&r] mutableCopy];
      
      [md setObject:[NSColor controlTextColor]
             forKey:NSForegroundColorAttributeName];
      
      [md setObject:[NSParagraphStyle defaultParagraphStyle]
             forKey:NSParagraphStyleAttributeName];

      [t setAttributes:md range:r];
      [md release];
      
      [self _drawAttributedText:t inFrame:cellFrame];
      [t release];
    }
  else
    {
      [super drawInteriorWithFrame:cellFrame inView:controlView];
    }
}

@end
