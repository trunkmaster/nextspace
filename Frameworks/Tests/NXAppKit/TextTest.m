/*
  Tests for NSTextField, NSText and so on.
*/

#import "TextTest.h"

static inline NSRect IncrementedRect(NSRect r)
{
        r.origin.x--;
        r.origin.y--;
        r.size.width += 2;
        r.size.height += 2;

        return r;
}

@interface TextTest (Private)

- (void)setupArrows;

@end

@implementation TextTest (Private)

- (void)setupArrows
{
  NSRect     frame;
  NSSize     s = [[leftArr superview] frame].size;
  float      width = [shrinkedText frame].size.width;

  frame = [leftArr frame];
  frame.origin.x = s.width / 2 - width / 2 - frame.size.width;
  [leftArr setFrame:frame];
  
  frame = [rightArr frame];
  frame.origin.x = s.width / 2 + width / 2;
  [rightArr setFrame:frame];

  frame = [shrinkedText frame];
  frame.origin.x = [leftArr frame].origin.x + [leftArr frame].size.width;
  frame.size.width = ([rightArr frame].origin.x - frame.origin.x);
  [shrinkedText setFrame:frame];
  [[shrinkedText superview] setNeedsDisplay:YES];
}

@end

@implementation TextTest

- (void)dealloc
{
  NSDebugLLog(@"TextTest", @"TextTest: dealloc");

  [super dealloc];
}

- (id)init
{
  self = [super init];
  
  if (window == nil) {
    [NSBundle loadNibNamed:@"Text" owner:self];
  }

  return self;
}

- (void)awakeFromNib
{
  [shrinkedText setStringValue:@"Drag arrows to see shrinked text"];
  [textToShrink setStringValue:@"Drag arrows to see shrinked text"];
  [self setupArrows];
}

- (void)show
{
  [window makeKeyAndOrderFront:self];
  [window makeFirstResponder:textToShrink];
}

// --- NXSizer delegate

- (BOOL) arrowView:(NXSizer *)sender
 shouldMoveByDelta:(float)delta
{
  NSView   *superview = [sender superview];
  NSSize   s = [superview frame].size;
  NSRect   arrowFrame;
  NSRect   textFrame = [shrinkedText frame];
  float    diff;
  unsigned newWidth;
  NSString *newText;

  if (sender == rightArr) {
    arrowFrame = [rightArr frame];

    diff = (arrowFrame.origin.x + delta) - s.width / 2;

    if (diff <= 40 || diff >= ((s.width/2) - arrowFrame.size.width))
      return NO;

    textFrame.origin.x = textFrame.origin.x - delta;

    arrowFrame = [leftArr frame];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
    arrowFrame.origin.x = s.width / 2 - diff - arrowFrame.size.width;
    [leftArr setFrame:arrowFrame];
    [leftArr setNeedsDisplay:YES];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
  }
  else {
    arrowFrame = [leftArr frame];

    diff = s.width / 2 - (arrowFrame.origin.x + delta +
                          arrowFrame.size.width);

    if (diff <= 40 || diff >= 100)
      return NO;

    textFrame.origin.x = textFrame.origin.x + delta;
      
    arrowFrame = [rightArr frame];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
    arrowFrame.origin.x = s.width / 2 + diff;
    [rightArr setFrame:arrowFrame];
    [rightArr setNeedsDisplay:YES];
    [superview setNeedsDisplayInRect:IncrementedRect(arrowFrame)];
  }

  newWidth = diff * 2;

  textFrame.size.width = newWidth;
  [shrinkedText setFrame:textFrame];

  newText = NXShortenString([textToShrink stringValue],
                            newWidth - 4, [shrinkedText font],
                            [[elementType selectedCell] tag],
                            [[dotsPosition selectedCell] tag]);
  [shrinkedText setStringValue:newText];

  return YES;
}

- (void)arrowViewStoppedMoving:(NXSizer *)sender
{
  [window makeFirstResponder:textToShrink];
}

@end
